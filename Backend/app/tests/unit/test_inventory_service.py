"""Unit tests for the inventory service stock operations."""

from __future__ import annotations

import pytest

from app.api.schemas.inventory import AdjustStockRequest
from app.core.constants import MovementType
from app.exceptions import InsufficientStockError, NotFoundError
from app.models.catalog import Category, Product
from app.models.inventory import Inventory
from app.services.inventory_service import InventoryService


@pytest.fixture()
def product(db_session):
    category = Category(category_name="Beverages")
    db_session.add(category)
    db_session.flush()
    product = Product(
        sku="TEST-001",
        product_name="Test Soda",
        category_id=category.category_id,
        unit="pcs",
        unit_price=1.5,
        cost_price=0.8,
        low_stock_threshold=5,
        is_service=False,
    )
    db_session.add(product)
    db_session.flush()
    db_session.add(Inventory(product_id=product.product_id))
    db_session.commit()
    return product


def test_restock_increases_quantity(db_session, product) -> None:
    service = InventoryService(db_session)
    inventory = service.restock(
        product_id=product.product_id,
        quantity=10,
        unit_cost=0.9,
        reason="Initial stock",
        user_id=None,
    )
    assert inventory.quantity_on_hand == 10
    txn = service.transactions.list_all()
    assert txn and txn[0].movement_type == MovementType.RESTOCK.value
    assert txn[0].quantity == 10


def test_adjust_with_counted_quantity(db_session, product, admin_user) -> None:
    service = InventoryService(db_session)
    service.restock(product_id=product.product_id, quantity=10, unit_cost=None, reason="init", user_id=None)
    payload = AdjustStockRequest(
        product_id=product.product_id,
        adjustment_type="COUNT",
        counted_quantity=7,
    )
    inventory = service.adjust(payload, admin_user)
    assert inventory.quantity_on_hand == 7


def test_deduct_stock_below_zero_raises(db_session, product) -> None:
    service = InventoryService(db_session)
    with pytest.raises(InsufficientStockError):
        service.deduct_stock(
            product_id=product.product_id,
            quantity=5,
            movement_type=MovementType.SALE.value,
            reference_type="Sale",
            reference_id=1,
            user_id=None,
        )


def test_restore_stock(db_session, product) -> None:
    service = InventoryService(db_session)
    service.restore_stock(
        product_id=product.product_id,
        quantity=3,
        movement_type=MovementType.RETURN.value,
        reference_type="Return",
        reference_id=1,
        user_id=None,
    )
    inventory = service.get_stock(product.product_id)
    assert inventory.quantity_on_hand == 3


def test_get_stock_for_missing_product_raises(db_session) -> None:
    service = InventoryService(db_session)
    with pytest.raises(NotFoundError):
        service.get_stock(9999)
