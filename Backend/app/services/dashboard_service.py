"""Dashboard service (Feature 16).

Aggregates KPIs, trends and chart data mirroring the SQL dashboard views.
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

from sqlalchemy import func, select

from app.core.constants import SaleStatus
from app.models.catalog import Category, Product
from app.models.credits import CreditSale
from app.models.inventory import Inventory
from app.models.notifications import Notification
from app.models.payments import Payment, PaymentMethod
from app.models.returns import Return as ReturnHeader
from app.models.sales import Sale, SaleItem
from app.models.users import User
from app.services.base import BaseService


def _today_bounds() -> tuple[datetime, datetime]:
    today = datetime.now(UTC).date()
    return (
        datetime.combine(today, datetime.min.time()),
        datetime.combine(today, datetime.max.time()),
    )


class DashboardService(BaseService):
    service_name = "dashboard"

    def __init__(self, session) -> None:  # noqa: ANN001
        super().__init__(session)
        self.session = session

    # ------------------------------------------------------------------
    def kpis(self) -> dict:
        today_from, today_to = _today_bounds()
        session = self.session

        today_sales_total = session.scalar(
            select(func.coalesce(func.sum(Sale.total_amount), 0)).where(
                Sale.status == SaleStatus.COMPLETED.value,
                Sale.sale_date >= today_from,
                Sale.sale_date <= today_to,
            )
        )
        today_sales_count = session.scalar(
            select(func.count(Sale.sale_id)).where(
                Sale.status == SaleStatus.COMPLETED.value,
                Sale.sale_date >= today_from,
                Sale.sale_date <= today_to,
            )
        )
        today_returns_total = session.scalar(
            select(func.coalesce(func.sum(ReturnHeader.total_refund_amount), 0)).where(
                ReturnHeader.status == "COMPLETED",
                ReturnHeader.created_at >= today_from,
                ReturnHeader.created_at <= today_to,
            )
        )
        today_refunds = session.scalar(
            select(func.count(ReturnHeader.return_id)).where(
                ReturnHeader.status == "COMPLETED",
                ReturnHeader.created_at >= today_from,
                ReturnHeader.created_at <= today_to,
            )
        )
        low_stock_count = session.scalar(
            select(func.count(Product.product_id)).join(Inventory).where(
                Product.is_deleted.is_(False),
                Inventory.quantity_on_hand <= Product.low_stock_threshold,
            )
        )
        out_of_stock_count = session.scalar(
            select(func.count(Product.product_id)).join(Inventory).where(
                Product.is_deleted.is_(False),
                Inventory.quantity_on_hand <= 0,
            )
        )
        pending_credit = session.scalar(
            select(func.coalesce(func.sum(CreditSale.outstanding_balance), 0)).where(
                CreditSale.status.in_(["OPEN", "PARTIAL", "OVERDUE"])
            )
        )
        active_users = session.scalar(
            select(func.count(User.user_id)).where(
                User.is_active.is_(True),
                User.is_deleted.is_(False),
            )
        )
        total_products = session.scalar(
            select(func.count(Product.product_id)).where(
                Product.is_active.is_(True),
                Product.is_deleted.is_(False),
            )
        )

        return {
            "today_sales_total": float(today_sales_total or 0),
            "today_sales_count": int(today_sales_count or 0),
            "today_returns_total": float(today_returns_total or 0),
            "today_refunds": int(today_refunds or 0),
            "low_stock_count": int(low_stock_count or 0),
            "out_of_stock_count": int(out_of_stock_count or 0),
            "pending_credit_balance": float(pending_credit or 0),
            "active_users_count": int(active_users or 0),
            "total_products_active": int(total_products or 0),
        }

    # ------------------------------------------------------------------
    def recent_sales(self, limit: int = 20) -> list[dict]:
        stmt = (
            select(Sale, User.full_name)
            .join(User, User.user_id == Sale.user_id)
            .where(Sale.status == SaleStatus.COMPLETED.value)
            .order_by(Sale.sale_date.desc())
            .limit(limit)
        )
        rows = []
        for sale, cashier_name in self.session.execute(stmt):
            rows.append(
                {
                    "sale_id": sale.sale_id,
                    "receipt_number": sale.receipt_number,
                    "sale_date": sale.sale_date.isoformat(),
                    "cashier_name": cashier_name,
                    "sale_type": sale.sale_type,
                    "total_amount": float(sale.total_amount),
                    "status": sale.status,
                }
            )
        return rows

    # ------------------------------------------------------------------
    def sales_trend_7d(self) -> list[dict]:
        today = datetime.now(UTC).date()
        start = today - timedelta(days=6)
        stmt = (
            select(
                func.date(Sale.sale_date).label("sale_date"),
                func.coalesce(func.sum(Sale.total_amount), 0).label("total"),
                func.count(Sale.sale_id).label("cnt"),
            )
            .where(
                Sale.status == SaleStatus.COMPLETED.value,
                Sale.sale_date >= datetime.combine(start, datetime.min.time()),
            )
            .group_by(func.date(Sale.sale_date))
        )
        totals = {row.sale_date: (float(row.total), int(row.cnt)) for row in self.session.execute(stmt)}
        rows = []
        for offset in range(7):
            day = start + timedelta(days=offset)
            total, cnt = totals.get(day, (0.0, 0))
            rows.append(
                {
                    "date": day.isoformat(),
                    "weekday": day.strftime("%A"),
                    "total_sales": total,
                    "sale_count": cnt,
                }
            )
        return rows

    # ------------------------------------------------------------------
    def top_products(self, days: int = 30, limit: int = 10) -> list[dict]:
        start = datetime.now(UTC) - timedelta(days=days)
        stmt = (
            select(
                Product.product_id,
                Product.product_name,
                Product.sku,
                func.sum(SaleItem.quantity).label("qty"),
                func.sum(SaleItem.line_total).label("revenue"),
            )
            .join(Sale, Sale.sale_id == SaleItem.sale_id)
            .join(Product, Product.product_id == SaleItem.product_id)
            .where(
                Sale.status == SaleStatus.COMPLETED.value,
                Sale.sale_date >= start,
            )
            .group_by(Product.product_id, Product.product_name, Product.sku)
            .order_by(func.sum(SaleItem.line_total).desc())
            .limit(limit)
        )
        rows = []
        total_revenue = sum(float(r.revenue or 0) for r in self.session.execute(stmt))
        for row in self.session.execute(stmt):
            revenue = float(row.revenue or 0)
            rows.append(
                {
                    "product_id": row.product_id,
                    "product_name": row.product_name,
                    "sku": row.sku,
                    "qty_sold": float(row.qty or 0),
                    "revenue": revenue,
                    "share_pct": round(revenue / total_revenue * 100, 2) if total_revenue else 0,
                }
            )
        return rows

    # ------------------------------------------------------------------
    def sales_by_category(self, days: int = 30) -> list[dict]:
        start = datetime.now(UTC) - timedelta(days=days)
        stmt = (
            select(
                Category.category_id,
                func.coalesce(Category.category_name, "Uncategorized").label("name"),
                func.sum(SaleItem.line_total).label("revenue"),
                func.sum(SaleItem.quantity).label("qty"),
                func.count(func.distinct(Sale.sale_id)).label("sale_count"),
            )
            .join(Product, Product.product_id == SaleItem.product_id)
            .outerjoin(Category, Category.category_id == Product.category_id)
            .join(Sale, (Sale.sale_id == SaleItem.sale_id) & (Sale.status == SaleStatus.COMPLETED.value))
            .where(Sale.sale_date >= start)
            .group_by(Category.category_id, Category.category_name)
        )
        return [
            {
                "category_id": row.category_id,
                "category_name": row.name,
                "revenue": float(row.revenue or 0),
                "qty_sold": float(row.qty or 0),
                "sale_count": int(row.sale_count or 0),
            }
            for row in self.session.execute(stmt)
        ]

    def sales_by_payment_method(self) -> list[dict]:
        stmt = (
            select(
                PaymentMethod.payment_method_id,
                PaymentMethod.method_name,
                func.sum(Payment.amount).label("total"),
                func.count(Payment.payment_id).label("cnt"),
            )
            .join(Payment, Payment.payment_method_id == PaymentMethod.payment_method_id)
            .join(Sale, (Sale.sale_id == Payment.sale_id) & (Sale.status == SaleStatus.COMPLETED.value))
            .where(Payment.pay_status.in_(["COMPLETED", "PARTIAL"]))
            .group_by(PaymentMethod.payment_method_id, PaymentMethod.method_name)
        )
        rows = [
            {
                "payment_method_id": row.payment_method_id,
                "method_name": row.method_name,
                "total_amount": float(row.total or 0),
                "payment_count": int(row.cnt or 0),
            }
            for row in self.session.execute(stmt)
        ]
        grand_total = sum(r["total_amount"] for r in rows)
        for row in rows:
            row["share_pct"] = round(row["total_amount"] / grand_total * 100, 2) if grand_total else 0
        return rows

    def outstanding_credit(self, limit: int = 20) -> list[dict]:
        from app.models.credits import Customer

        stmt = (
            select(
                Customer.customer_id,
                Customer.customer_code,
                Customer.full_name,
                Customer.phone,
                func.coalesce(func.sum(CreditSale.outstanding_balance), 0).label("balance"),
                func.count(CreditSale.credit_sale_id).label("open_count"),
            )
            .join(CreditSale, CreditSale.customer_id == Customer.customer_id)
            .where(
                CreditSale.status.in_(["OPEN", "PARTIAL", "OVERDUE"]),
                Customer.is_deleted.is_(False),
            )
            .group_by(Customer.customer_id, Customer.customer_code, Customer.full_name, Customer.phone)
            .having(func.coalesce(func.sum(CreditSale.outstanding_balance), 0) > 0)
            .order_by(func.coalesce(func.sum(CreditSale.outstanding_balance), 0).desc())
            .limit(limit)
        )
        return [
            {
                "customer_id": row.customer_id,
                "customer_code": row.customer_code,
                "customer_name": row.full_name,
                "phone": row.phone,
                "outstanding_balance": float(row.balance or 0),
                "open_credit_count": int(row.open_count or 0),
            }
            for row in self.session.execute(stmt)
        ]

    def recent_notifications(self, limit: int = 10) -> list[dict]:
        stmt = (
            select(Notification)
            .order_by(Notification.created_at.desc())
            .limit(limit)
        )
        return [
            {
                "notification_id": n.notification_id,
                "user_id": n.user_id,
                "title": n.title,
                "message": n.message,
                "severity": n.severity,
                "is_read": n.is_read,
                "created_at": n.created_at.isoformat(),
            }
            for n in self.session.scalars(stmt)
        ]

    def cashier_dashboard(self, user: User) -> dict:
        today_from, today_to = _today_bounds()
        session = self.session
        my_today = session.scalar(
            select(func.count(Sale.sale_id)).where(
                Sale.user_id == user.user_id,
                Sale.status == SaleStatus.COMPLETED.value,
                Sale.sale_date >= today_from,
                Sale.sale_date <= today_to,
            )
        )
        my_today_total = session.scalar(
            select(func.coalesce(func.sum(Sale.total_amount), 0)).where(
                Sale.user_id == user.user_id,
                Sale.status == SaleStatus.COMPLETED.value,
                Sale.sale_date >= today_from,
                Sale.sale_date <= today_to,
            )
        )
        unread = session.scalar(
            select(func.count(Notification.notification_id)).where(
                Notification.user_id == user.user_id,
                Notification.is_read.is_(False),
            )
        )
        low_stock = session.scalar(
            select(func.count(Product.product_id)).join(Inventory).where(
                Product.is_deleted.is_(False),
                Inventory.quantity_on_hand <= Product.low_stock_threshold,
            )
        )
        return {
            "today_sales_count": int(my_today or 0),
            "today_sales_total": float(my_today_total or 0),
            "unread_notifications": int(unread or 0),
            "low_stock_products": int(low_stock or 0),
            "recent_sales": self.recent_sales(limit=10),
        }
