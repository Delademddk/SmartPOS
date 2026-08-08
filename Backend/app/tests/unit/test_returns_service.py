"""Unit tests for the returns service (feature 13)."""

from __future__ import annotations

import pytest

from app.api.schemas.returns import ReturnCreate, ReturnItemCreate
from app.exceptions import ReturnLimitExceededError
from app.models.catalog import Category, Product
from app.models.inventory import Inventory
from app.models.payments import PaymentMethod
from app.models.returns import ReturnReason
from app.services.inventory_service import InventoryService
from app.services.returns_service import ReturnService
from app.services.sales_service import SalesService
from app.api.schemas.sales import SaleCreate, SaleItemCreate


@pytest.fixture()
def return_setup(db_session):
    from app.models.users import User

    cashier = db_session.query(User).filter(User.username == "cashier").first()
    category = Category(category_name="Electronics")
    db_session.add(category)
    db_session.flush()
    product = Product(
        sku="ELC-001",
        product_name="Charger",
        category_id=category.category_id,
        unit="pcs",
        unit_price=10.0,
        cost_price=6.0,
        low_stock_threshold=2,
        is_service=False,
    )
    db_session.add(product)
    db_session.flush()
    db_session.add(Inventory(product_id=product.product_id, quantity_on_hand=10, quantity_reserved=0))
    db_session.add(PaymentMethod(method_code="CASH", method_name="Cash", is_cash=True, is_active=True))
    db_session.add(ReturnReason(reason_code="DEFECTIVE", reason_name="Defective item"))
    db_session.commit()

    sale = SalesService(db_session).create_sale(
        SaleCreate(
            sale_type="CASH",
            items=[SaleItemCreate(product_id=product.product_id, quantity=2)],
            amount_received=50,
        ),
        cashier,
    )
    return db_session, cashier, product, sale


def test_process_return_restores_stock_and_marks_items(return_setup) -> None:
    db_session, cashier, product, sale = return_setup
    sale_item = sale.items[0]
    service = ReturnService(db_session)

    return_header = service.process(
        ReturnCreate(
            sale_id=sale.sale_id,
            items=[ReturnItemCreate(sale_item_id=sale_item.sale_item_id, quantity=1)],
        ),
        cashier,
    )

    assert return_header.return_number.startswith("RET-")
    assert return_header.total_refund_amount == 10.0

    inventory = InventoryService(db_session).get_stock(product.product_id)
    assert inventory.quantity_on_hand == 9
    refreshed_item = db_session.get(sale.items[0].__class__, sale_item.sale_item_id)
    assert refreshed_item.returned_qty == 1


def test_process_return_exceeding_quantity_raises(return_setup) -> None:
    db_session, cashier, _product, sale = return_setup
    sale_item = sale.items[0]
    service = ReturnService(db_session)

    with pytest.raises(ReturnLimitExceededError):
        service.process(
            ReturnCreate(
                sale_id=sale.sale_id,
                items=[ReturnItemCreate(sale_item_id=sale_item.sale_item_id, quantity=5)],
            ),
            cashier,
        )
