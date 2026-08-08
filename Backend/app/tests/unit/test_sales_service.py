"""Unit tests for the sales service (feature 10)."""

from __future__ import annotations

import pytest

from app.api.schemas.sales import SaleCreate, SaleItemCreate
from app.core.constants import SaleStatus
from app.exceptions import InsufficientStockError, NotFoundError, ValidationError_
from app.models.catalog import Category, Product
from app.models.inventory import Inventory
from app.models.payments import PaymentMethod
from app.services.inventory_service import InventoryService
from app.services.sales_service import SalesService


@pytest.fixture()
def cashier(db_session, admin_user):
    from app.models.users import User

    user = db_session.query(User).filter(User.username == "cashier").first()
    return user or admin_user


@pytest.fixture()
def sale_setup(db_session, cashier):
    category = Category(category_name="Snacks")
    db_session.add(category)
    db_session.flush()

    product = Product(
        sku="SNK-001",
        product_name="Chips",
        category_id=category.category_id,
        unit="pcs",
        unit_price=2.0,
        cost_price=1.0,
        low_stock_threshold=5,
        is_service=False,
    )
    db_session.add(product)
    db_session.flush()
    db_session.add(Inventory(product_id=product.product_id, quantity_on_hand=20, quantity_reserved=0))
    db_session.add(
        PaymentMethod(method_code="CASH", method_name="Cash", is_cash=True, is_active=True)
    )
    db_session.commit()
    return product


def _build_sale(product, qty=2) -> SaleCreate:
    return SaleCreate(
        sale_type="CASH",
        items=[SaleItemCreate(product_id=product.product_id, quantity=qty)],
        payments=[],
        amount_received=100,
    )


def test_create_cash_sale(db_session, sale_setup, cashier) -> None:
    product = sale_setup
    service = SalesService(db_session)
    sale = service.create_sale(_build_sale(product), cashier)

    assert sale.status == SaleStatus.COMPLETED.value
    assert sale.total_amount == 4.0
    assert sale.amount_received == 100
    assert sale.receipt_number.startswith("SLS-")
    assert len(sale.items) == 1

    inventory = InventoryService(db_session).get_stock(product.product_id)
    assert inventory.quantity_on_hand == 18


def test_create_sale_insufficient_stock(db_session, sale_setup, cashier) -> None:
    product = sale_setup
    service = SalesService(db_session)
    with pytest.raises(InsufficientStockError):
        service.create_sale(_build_sale(product, qty=50), cashier)


def test_create_sale_requires_items(db_session, sale_setup, cashier) -> None:
    with pytest.raises(ValidationError_):
        _build_sale(sale_setup, qty=0)


def test_void_sale_restores_stock(db_session, sale_setup, cashier) -> None:
    product = sale_setup
    service = SalesService(db_session)
    sale = service.create_sale(_build_sale(product, qty=2), cashier)
    service.void_sale(sale.sale_id, cashier, "Testing void")

    updated = service.get(sale.sale_id)
    assert updated.status == SaleStatus.VOIDED.value
    inventory = InventoryService(db_session).get_stock(product.product_id)
    assert inventory.quantity_on_hand == 20


def test_get_missing_sale_raises(db_session, cashier) -> None:
    with pytest.raises(NotFoundError):
        SalesService(db_session).get(9999)
