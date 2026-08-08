"""Unit tests for the credit sales service (feature 12)."""

from __future__ import annotations

import pytest

from app.api.schemas.credits import CreditSettlementRequest, CustomerCreate
from app.api.schemas.sales import SaleCreate, SaleItemCreate
from app.core.constants import CreditStatus
from app.exceptions import BadRequestError, NotFoundError, ValidationError_
from app.models.catalog import Category, Product
from app.models.inventory import Inventory
from app.models.payments import PaymentMethod
from app.services.credits_service import CreditService
from app.services.sales_service import SalesService


@pytest.fixture()
def credit_setup(db_session):
    from app.models.users import User

    cashier = db_session.query(User).filter(User.username == "cashier").first()
    customer = CreditService(db_session).create_customer(
        CustomerCreate(customer_code="CUST-001", full_name="John Doe", credit_limit=1000),
        cashier,
    )
    category = Category(category_name="Furniture")
    db_session.add(category)
    db_session.flush()
    product = Product(
        sku="FUR-001",
        product_name="Chair",
        category_id=category.category_id,
        unit="pcs",
        unit_price=50.0,
        cost_price=30.0,
        low_stock_threshold=2,
        is_service=False,
    )
    db_session.add(product)
    db_session.flush()
    db_session.add(Inventory(product_id=product.product_id, quantity_on_hand=20, quantity_reserved=0))
    db_session.add(PaymentMethod(method_code="CASH", method_name="Cash", is_cash=True, is_active=True))
    db_session.commit()
    return db_session, cashier, customer, product


def _credit_sale(product, customer_id) -> SaleCreate:
    return SaleCreate(
        sale_type="CREDIT",
        customer_id=customer_id,
        items=[SaleItemCreate(product_id=product.product_id, quantity=1)],
        due_date="2026-09-01",
    )


def test_create_credit_sale_creates_ledger(credit_setup) -> None:
    db_session, cashier, customer, product = credit_setup
    sale = SalesService(db_session).create_sale(_credit_sale(product, customer.customer_id), cashier)

    credit_sale = CreditService(db_session).get_credit_sale(sale.credit_sales[0].credit_sale_id)
    assert credit_sale.status == CreditStatus.OPEN.value
    assert credit_sale.outstanding_balance == 50.0


def test_settle_credit_sale(credit_setup) -> None:
    db_session, cashier, customer, product = credit_setup
    sale = SalesService(db_session).create_sale(_credit_sale(product, customer.customer_id), cashier)
    service = CreditService(db_session)
    credit_sale = service.get_credit_sale(sale.credit_sales[0].credit_sale_id)

    settled = service.settle(
        credit_sale.credit_sale_id,
        CreditSettlementRequest(amount=50.0),
        cashier,
    )
    assert settled.status == CreditStatus.SETTLED.value
    assert settled.outstanding_balance == 0


def test_settle_more_than_outstanding_raises(credit_setup) -> None:
    db_session, cashier, customer, product = credit_setup
    sale = SalesService(db_session).create_sale(_credit_sale(product, customer.customer_id), cashier)
    service = CreditService(db_session)
    credit_sale = service.get_credit_sale(sale.credit_sales[0].credit_sale_id)

    with pytest.raises(ValidationError_):
        service.settle(
            credit_sale.credit_sale_id,
            CreditSettlementRequest(amount=9999),
            cashier,
        )


def test_get_missing_customer_raises(credit_setup) -> None:
    db_session = credit_setup[0]
    with pytest.raises(NotFoundError):
        CreditService(db_session).get_customer(9999)
