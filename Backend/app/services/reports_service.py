"""Reports service (Feature 15).

Produces the documented report types by aggregating the transactional tables
with the same business rules as the SQL reporting views (COMPLETED sales
only, UTC date windows).
"""

from __future__ import annotations

from datetime import date, datetime, time
from decimal import Decimal

from sqlalchemy import func, select

from app.api.schemas.reports import ReportRequest, ReportResponse
from app.core.constants import SaleStatus
from app.models.catalog import Category, Product, Supplier
from app.models.credits import CreditSale, Customer
from app.models.inventory import Inventory, InventoryTransaction
from app.models.payments import Payment, PaymentMethod
from app.models.returns import Return as ReturnHeader
from app.models.returns import ReturnReason
from app.models.sales import Sale, SaleItem
from app.models.users import User
from app.services.base import BaseService


def _d(value) -> float:  # noqa: ANN001
    return float(value or 0)


class ReportsService(BaseService):
    service_name = "reports"

    def __init__(self, session) -> None:  # noqa: ANN001
        super().__init__(session)
        self.session = session

    # ------------------------------------------------------------------
    def generate(self, payload: ReportRequest) -> ReportResponse:
        handlers = {
            "daily": self._daily,
            "weekly": self._weekly,
            "monthly": self._monthly,
            "annual": self._annual,
            "inventory": self._inventory,
            "profit": self._profit,
            "cashier": self._cashier,
            "supplier": self._supplier,
            "credit": self._credit,
            "returns": self._returns,
            "tax": self._tax,
            "payment_methods": self._payment_methods,
        }
        handler = handlers.get(payload.report_type)
        if handler is None:
            raise ValueError(f"Unsupported report type: {payload.report_type}")
        rows, summary = handler(payload)
        return ReportResponse(
            report_type=payload.report_type,
            period={
                "date_from": payload.date_from.isoformat() if payload.date_from else None,
                "date_to": payload.date_to.isoformat() if payload.date_to else None,
            },
            rows=rows,
            summary=summary,
        )

    # ------------------------------------------------------------------
    # Date-range sales aggregations
    # ------------------------------------------------------------------
    def _date_range(self, payload: ReportRequest) -> tuple[datetime | None, datetime | None]:
        date_from = None
        date_to = None
        if payload.date_from:
            date_from = datetime.combine(payload.date_from, time.min)
        if payload.date_to:
            date_to = datetime.combine(payload.date_to, time.max)
        return date_from, date_to

    def _sales_between(self, payload: ReportRequest):
        date_from, date_to = self._date_range(payload)
        filters = [Sale.status == SaleStatus.COMPLETED.value]
        if date_from:
            filters.append(Sale.sale_date >= date_from)
        if date_to:
            filters.append(Sale.sale_date <= date_to)
        if payload.cashier_id:
            filters.append(Sale.user_id == payload.cashier_id)
        if payload.customer_id:
            filters.append(Sale.customer_id == payload.customer_id)
        return filters

    def _period_rows(self, payload: ReportRequest, date_part):
        filters = self._sales_between(payload)
        stmt = (
            select(
                func.year(Sale.sale_date).label("yr"),
                date_part.label("period_label"),
                func.sum(Sale.total_amount).label("total_sales"),
                func.count(Sale.sale_id).label("sale_count"),
                func.sum(Sale.tax_amount).label("total_tax"),
                func.sum(Sale.discount_amount).label("total_discount"),
                func.avg(Sale.total_amount).label("avg_sale_value"),
            )
            .where(*filters)
            .group_by(func.year(Sale.sale_date), date_part)
            .order_by(func.year(Sale.sale_date), date_part)
        )
        rows = []
        for row in self.session.execute(stmt):
            rows.append(
                {
                    "year": row.yr,
                    "period": row.period_label,
                    "total_sales": _d(row.total_sales),
                    "sale_count": row.sale_count,
                    "total_tax": _d(row.total_tax),
                    "total_discount": _d(row.total_discount),
                    "avg_sale_value": _d(row.avg_sale_value),
                }
            )
        summary = {
            "total_sales": sum(r["total_sales"] for r in rows),
            "sale_count": sum(r["sale_count"] for r in rows),
        }
        return rows, summary

    def _daily(self, payload: ReportRequest) -> tuple[list, dict]:
        return self._period_rows(payload, func.day(Sale.sale_date))

    def _weekly(self, payload: ReportRequest) -> tuple[list, dict]:
        return self._period_rows(payload, func.datepart("iso_week", Sale.sale_date))

    def _monthly(self, payload: ReportRequest) -> tuple[list, dict]:
        return self._period_rows(payload, func.month(Sale.sale_date))

    def _annual(self, payload: ReportRequest) -> tuple[list, dict]:
        filters = self._sales_between(payload)
        stmt = (
            select(
                func.year(Sale.sale_date).label("yr"),
                func.sum(Sale.total_amount).label("total_sales"),
                func.count(Sale.sale_id).label("sale_count"),
                func.sum(Sale.tax_amount).label("total_tax"),
            )
            .where(*filters)
            .group_by(func.year(Sale.sale_date))
            .order_by(func.year(Sale.sale_date))
        )
        rows = [
            {
                "year": row.yr,
                "total_sales": _d(row.total_sales),
                "sale_count": row.sale_count,
                "total_tax": _d(row.total_tax),
            }
            for row in self.session.execute(stmt)
        ]
        summary = {"total_sales": sum(r["total_sales"] for r in rows), "sale_count": sum(r["sale_count"] for r in rows)}
        return rows, summary

    # ------------------------------------------------------------------
    # Specialised reports
    # ------------------------------------------------------------------
    def _inventory(self, payload: ReportRequest) -> tuple[list, dict]:
        stmt = (
            select(
                Product.product_id,
                Product.product_name,
                Product.sku,
                Category.category_name,
                Supplier.supplier_name,
                func.coalesce(Inventory.quantity_on_hand, 0).label("qty"),
                func.coalesce(Inventory.quantity_reserved, 0).label("reserved"),
                Product.low_stock_threshold,
                Product.cost_price,
            )
            .outerjoin(Category, Category.category_id == Product.category_id)
            .outerjoin(Supplier, Supplier.supplier_id == Product.supplier_id)
            .outerjoin(Inventory, Inventory.product_id == Product.product_id)
            .where(Product.is_deleted.is_(False))
        )
        if payload.category_id:
            stmt = stmt.where(Product.category_id == payload.category_id)
        if payload.supplier_id:
            stmt = stmt.where(Product.supplier_id == payload.supplier_id)
        rows = []
        stock_value = 0.0
        low_count = 0
        for row in self.session.execute(stmt.order_by(Product.product_name)):
            qty = int(row.qty)
            threshold = row.low_stock_threshold
            cost = _d(row.cost_price)
            status = "OUT_OF_STOCK" if qty <= 0 else ("LOW_STOCK" if qty <= threshold else "IN_STOCK")
            if status == "LOW_STOCK":
                low_count += 1
            stock_value += qty * cost
            rows.append(
                {
                    "product_id": row.product_id,
                    "product_name": row.product_name,
                    "sku": row.sku,
                    "category": row.category_name,
                    "supplier": row.supplier_name,
                    "quantity_on_hand": qty,
                    "quantity_reserved": int(row.reserved),
                    "low_stock_threshold": threshold,
                    "stock_status": status,
                    "unit_cost": cost,
                    "stock_value": round(qty * cost, 4),
                }
            )
        summary = {"total_stock_value": round(stock_value, 4), "low_stock_products": low_count, "product_count": len(rows)}
        return rows, summary

    def _profit(self, payload: ReportRequest) -> tuple[list, dict]:
        filters = self._sales_between(payload)
        stmt = (
            select(
                Product.product_id,
                Product.product_name,
                Product.sku,
                Category.category_name,
                func.sum(SaleItem.quantity).label("qty"),
                func.sum(SaleItem.line_total).label("revenue"),
                func.coalesce(Product.cost_price, 0).label("cost"),
            )
            .join(Sale, Sale.sale_id == SaleItem.sale_id)
            .join(Product, Product.product_id == SaleItem.product_id)
            .outerjoin(Category, Category.category_id == Product.category_id)
            .where(*filters)
            .group_by(Product.product_id, Product.product_name, Product.sku, Category.category_name, Product.cost_price)
            .order_by(func.sum(SaleItem.line_total).desc())
        )
        rows = []
        total_profit = 0.0
        total_revenue = 0.0
        for row in self.session.execute(stmt):
            revenue = _d(row.revenue)
            qty = float(row.qty or 0)
            cost = _d(row.cost)
            cogs = qty * cost
            profit = revenue - cogs
            margin = (profit / revenue * 100) if revenue else 0
            total_profit += profit
            total_revenue += revenue
            rows.append(
                {
                    "product_id": row.product_id,
                    "product_name": row.product_name,
                    "sku": row.sku,
                    "category": row.category_name,
                    "qty_sold": float(row.qty or 0),
                    "revenue": round(revenue, 4),
                    "cost_of_goods": round(cogs, 4),
                    "gross_profit": round(profit, 4),
                    "gross_margin_pct": round(margin, 2),
                }
            )
        summary = {"total_revenue": round(total_revenue, 4), "total_profit": round(total_profit, 4)}
        return rows, summary

    def _cashier(self, payload: ReportRequest) -> tuple[list, dict]:
        filters = self._sales_between(payload)
        stmt = (
            select(
                User.user_id,
                User.full_name,
                func.count(Sale.sale_id).label("sale_count"),
                func.sum(Sale.total_amount).label("total_sales"),
                func.sum(Sale.tax_amount).label("total_tax"),
            )
            .join(Sale, Sale.user_id == User.user_id)
            .where(*filters)
            .group_by(User.user_id, User.full_name)
            .order_by(func.sum(Sale.total_amount).desc())
        )
        rows = [
            {
                "user_id": row.user_id,
                "cashier_name": row.full_name,
                "sale_count": row.sale_count,
                "total_sales": _d(row.total_sales),
                "total_tax": _d(row.total_tax),
            }
            for row in self.session.execute(stmt)
        ]
        summary = {"total_sales": sum(r["total_sales"] for r in rows), "sale_count": sum(r["sale_count"] for r in rows)}
        return rows, summary

    def _supplier(self, payload: ReportRequest) -> tuple[list, dict]:
        stmt = (
            select(
                Supplier.supplier_id,
                Supplier.supplier_code,
                Supplier.supplier_name,
                Supplier.contact_person,
                Supplier.email,
                Supplier.phone,
                func.count(Product.product_id).label("product_count"),
                func.coalesce(func.sum(func.coalesce(Inventory.quantity_on_hand, 0) * func.coalesce(Product.cost_price, 0)), 0).label("stock_value"),
            )
            .outerjoin(Product, (Product.supplier_id == Supplier.supplier_id) & (Product.is_deleted.is_(False)))
            .outerjoin(Inventory, Inventory.product_id == Product.product_id)
            .where(Supplier.is_deleted.is_(False))
            .group_by(
                Supplier.supplier_id,
                Supplier.supplier_code,
                Supplier.supplier_name,
                Supplier.contact_person,
                Supplier.email,
                Supplier.phone,
            )
        )
        if payload.supplier_id:
            stmt = stmt.where(Supplier.supplier_id == payload.supplier_id)
        rows = [
            {
                "supplier_id": row.supplier_id,
                "supplier_code": row.supplier_code,
                "supplier_name": row.supplier_name,
                "contact_person": row.contact_person,
                "email": row.email,
                "phone": row.phone,
                "product_count": row.product_count,
                "total_stock_value": _d(row.stock_value),
            }
            for row in self.session.execute(stmt.order_by(Supplier.supplier_name))
        ]
        summary = {"supplier_count": len(rows), "total_stock_value": sum(r["total_stock_value"] for r in rows)}
        return rows, summary

    def _credit(self, payload: ReportRequest) -> tuple[list, dict]:
        stmt = (
            select(
                CreditSale,
                Sale.receipt_number,
                Customer.full_name.label("customer_name"),
                Customer.phone,
            )
            .join(Sale, Sale.sale_id == CreditSale.sale_id)
            .join(Customer, Customer.customer_id == CreditSale.customer_id)
        )
        if payload.customer_id:
            stmt = stmt.where(CreditSale.customer_id == payload.customer_id)
        if payload.date_from:
            stmt = stmt.where(CreditSale.created_at >= datetime.combine(payload.date_from, time.min))
        if payload.date_to:
            stmt = stmt.where(CreditSale.created_at <= datetime.combine(payload.date_to, time.max))
        rows = []
        outstanding_total = 0.0
        for cs, receipt_number, customer_name, phone in self.session.execute(stmt.order_by(CreditSale.created_at.desc())):
            days_overdue = 0
            if cs.due_date and cs.status in ("OPEN", "PARTIAL", "OVERDUE"):
                days_overdue = max((date.today() - cs.due_date).days, 0)
            outstanding_total += _d(cs.outstanding_balance)
            rows.append(
                {
                    "credit_sale_id": cs.credit_sale_id,
                    "sale_id": cs.sale_id,
                    "receipt_number": receipt_number,
                    "customer_name": customer_name,
                    "customer_phone": phone,
                    "total_amount": _d(cs.total_amount),
                    "amount_paid": _d(cs.amount_paid),
                    "outstanding_balance": _d(cs.outstanding_balance),
                    "status": cs.status,
                    "due_date": cs.due_date.isoformat() if cs.due_date else None,
                    "days_overdue": days_overdue,
                }
            )
        summary = {"outstanding_balance": round(outstanding_total, 4), "credit_count": len(rows)}
        return rows, summary

    def _returns(self, payload: ReportRequest) -> tuple[list, dict]:
        filters = []
        if payload.date_from:
            filters.append(ReturnHeader.created_at >= datetime.combine(payload.date_from, time.min))
        if payload.date_to:
            filters.append(ReturnHeader.created_at <= datetime.combine(payload.date_to, time.max))
        stmt = (
            select(
                ReturnHeader.return_id,
                ReturnHeader.return_number,
                Sale.receipt_number,
                Customer.full_name.label("customer_name"),
                User.full_name.label("processor_name"),
                ReturnHeader.total_refund_amount,
                ReturnHeader.status,
                ReturnReason.reason_name,
                ReturnHeader.created_at,
            )
            .join(Sale, Sale.sale_id == ReturnHeader.sale_id)
            .outerjoin(Customer, Customer.customer_id == ReturnHeader.customer_id)
            .join(User, User.user_id == ReturnHeader.user_id)
            .outerjoin(ReturnReason, ReturnReason.return_reason_id == ReturnHeader.return_reason_id)
            .where(*filters)
        )
        rows = [
            {
                "return_id": row.return_id,
                "return_number": row.return_number,
                "sale_receipt_number": row.receipt_number,
                "customer_name": row.customer_name,
                "processor_name": row.processor_name,
                "total_refund_amount": _d(row.total_refund_amount),
                "status": row.status,
                "return_reason": row.reason_name,
                "created_at": row.created_at.isoformat(),
            }
            for row in self.session.execute(stmt.order_by(ReturnHeader.created_at.desc()))
        ]
        summary = {"total_refunded": round(sum(r["total_refund_amount"] for r in rows), 4), "return_count": len(rows)}
        return rows, summary

    def _tax(self, payload: ReportRequest) -> tuple[list, dict]:
        from app.models.business import TaxRate

        date_from, date_to = self._date_range(payload)
        sale_filters = [Sale.status == SaleStatus.COMPLETED.value]
        if date_from:
            sale_filters.append(Sale.sale_date >= date_from)
        if date_to:
            sale_filters.append(Sale.sale_date <= date_to)

        stmt = (
            select(
                TaxRate.tax_rate_id,
                TaxRate.tax_name,
                TaxRate.rate_percent,
                func.count(Sale.sale_id).label("taxable_sales_count"),
                func.sum(Sale.tax_amount).label("total_tax_amount"),
            )
            .outerjoin(Sale, (Sale.tax_rate_id == TaxRate.tax_rate_id) & func.and_(*sale_filters))
            .group_by(TaxRate.tax_rate_id, TaxRate.tax_name, TaxRate.rate_percent)
        )
        rows = [
            {
                "tax_rate_id": row.tax_rate_id,
                "tax_name": row.tax_name,
                "rate_percent": float(row.rate_percent),
                "taxable_sales_count": row.taxable_sales_count or 0,
                "total_tax_amount": _d(row.total_tax_amount),
            }
            for row in self.session.execute(stmt)
        ]
        summary = {"total_tax": round(sum(r["total_tax_amount"] for r in rows), 4)}
        return rows, summary

    def _payment_methods(self, payload: ReportRequest) -> tuple[list, dict]:
        filters = self._sales_between(payload)
        stmt = (
            select(
                PaymentMethod.payment_method_id,
                PaymentMethod.method_name,
                func.count(Payment.payment_id).label("payment_count"),
                func.sum(Payment.amount).label("total_amount"),
            )
            .join(Payment, Payment.payment_method_id == PaymentMethod.payment_method_id)
            .join(Sale, (Sale.sale_id == Payment.sale_id) & (Sale.status == SaleStatus.COMPLETED.value))
            .where(Payment.pay_status.in_(["COMPLETED", "PARTIAL"]), *filters)
            .group_by(PaymentMethod.payment_method_id, PaymentMethod.method_name)
            .order_by(PaymentMethod.method_name)
        )
        rows = [
            {
                "payment_method_id": row.payment_method_id,
                "method_name": row.method_name,
                "payment_count": row.payment_count,
                "total_amount": _d(row.total_amount),
            }
            for row in self.session.execute(stmt)
        ]
        summary = {"total_amount": round(sum(r["total_amount"] for r in rows), 4)}
        return rows, summary
