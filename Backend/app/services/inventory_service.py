"""Inventory service (Feature 09).

Restock, adjust, history and low-stock handling. Every movement is written to
``inventory_transactions`` and low-stock alerts are raised/resolved
automatically.
"""

from __future__ import annotations

from datetime import datetime

from app.api.schemas.inventory import AdjustStockRequest, RestockRequest
from app.core.constants import AdjustmentType, MovementType
from app.core.logging import get_logger
from app.database.base import utcnow
from app.exceptions import (
    BadRequestError,
    ConflictError,
    InsufficientStockError,
    NotFoundError,
    ValidationError_,
)
from app.models.catalog import Product
from app.models.inventory import (
    Inventory,
    InventoryTransaction,
    LowStockAlert,
    StockReconciliation,
)
from app.models.users import User
from app.repositories.catalog_repo import ProductRepository
from app.repositories.ops_repo import (
    InventoryRepository,
    InventoryTransactionRepository,
    LowStockAlertRepository,
    StockReconciliationRepository,
)
from app.repositories.system_repo import NotificationTypeRepository
from app.services.audit_service import AuditService
from app.services.base import BaseService
from app.utils.pagination import PageParams

logger = get_logger("services.inventory")


class InventoryService(BaseService):
    service_name = "inventory"

    def __init__(self, session) -> None:  # noqa: ANN001
        super().__init__(session)
        self.inventory = InventoryRepository(session)
        self.transactions = InventoryTransactionRepository(session)
        self.reconciliations = StockReconciliationRepository(session)
        self.alerts = LowStockAlertRepository(session)
        self.products = ProductRepository(session)
        self.notification_types = NotificationTypeRepository(session)
        self.audit = AuditService(session)

    # ------------------------------------------------------------------
    # Queries
    # ------------------------------------------------------------------
    def list(
        self,
        page: PageParams,
        search: str | None,
        stock_status: str | None,
    ) -> tuple[list[Inventory], int]:
        return self.inventory.list_with_products(
            search=search,
            stock_status=stock_status,
            page=page.page,
            page_size=page.page_size,
        )

    def get_stock(self, product_id: int) -> Inventory:
        product = self._get_product(product_id)
        inventory = self.inventory.get_by_product(product_id)
        if inventory is None:
            inventory = Inventory(product_id=product.product_id, quantity_on_hand=0, quantity_reserved=0)
            self.inventory.add(inventory)
            self.session.flush()
        return inventory

    def movements(
        self,
        page: PageParams,
        product_id: int | None,
        movement_type: str | None,
        date_from: datetime | None,
        date_to: datetime | None,
    ) -> tuple[list[InventoryTransaction], int]:
        return self.transactions.list_filtered(
            product_id=product_id,
            movement_type=movement_type,
            date_from=date_from,
            date_to=date_to,
            page=page.page,
            page_size=page.page_size,
        )

    def low_stock_alerts(
        self,
        page: PageParams,
        status: str | None,
    ) -> tuple[list[LowStockAlert], int]:
        filters = []
        if status:
            filters.append(LowStockAlert.status == status)
        alerts = self.alerts.list_all()
        if status:
            alerts = [a for a in alerts if a.status == status]
        total = len(alerts)
        start = (page.page - 1) * page.page_size
        return alerts[start : start + page.page_size], total

    # ------------------------------------------------------------------
    # Mutations
    # ------------------------------------------------------------------
    def restock(
        self,
        product_id: int,
        quantity: int,
        unit_cost: float | None,
        reason: str | None,
        user_id: int | None,
        skip_commit: bool = False,
    ) -> Inventory:
        if quantity <= 0:
            raise ValidationError_(
                "Restock quantity must be positive.",
                [{"field": "quantity", "message": "Must be > 0"}],
            )
        product = self._get_product(product_id)
        if product.is_service:
            raise BadRequestError("Services do not hold inventory.")

        inventory = self.inventory.get_by_product(product_id)
        if inventory is None:
            inventory = Inventory(
                product_id=product_id,
                quantity_on_hand=0,
                quantity_reserved=0,
            )
            self.inventory.add(inventory)
            self.session.flush()

        quantity_before = inventory.quantity_on_hand
        quantity_after = quantity_before + quantity
        inventory.quantity_on_hand = quantity_after
        inventory.last_restocked_at = utcnow()

        self.transactions.add(
            InventoryTransaction(
                product_id=product_id,
                movement_type=MovementType.RESTOCK.value,
                quantity=quantity,
                quantity_before=quantity_before,
                quantity_after=quantity_after,
                unit_cost=unit_cost,
                reference_type="Restock",
                reason=reason,
                user_id=user_id,
            )
        )
        self._handle_low_stock(product, inventory)
        self.audit.activity(
            activity_type="INVENTORY_RESTOCKED",
            activity_desc=f"Restocked {product.sku} by {quantity}",
            entity_type="Product",
            entity_id=product_id,
            user_id=user_id,
        )
        if not skip_commit:
            self.session.commit()
        return inventory

    def adjust(self, payload: AdjustStockRequest, user: User) -> Inventory:
        product = self._get_product(payload.product_id)
        if product.is_service:
            raise BadRequestError("Services do not hold inventory.")

        inventory = self.inventory.get_by_product(payload.product_id)
        if inventory is None:
            inventory = Inventory(
                product_id=payload.product_id,
                quantity_on_hand=0,
                quantity_reserved=0,
            )
            self.inventory.add(inventory)
            self.session.flush()

        system_quantity = inventory.quantity_on_hand
        if payload.counted_quantity is not None:
            difference = payload.counted_quantity - system_quantity
        elif payload.quantity_change is not None:
            difference = payload.quantity_change
        else:
            raise ValidationError_(
                "Provide either counted_quantity or quantity_change.",
                [{"field": "quantity_change", "message": "One is required"}],
            )

        quantity_after = system_quantity + difference
        if quantity_after < 0:
            raise InsufficientStockError(
                "Adjustment would result in negative stock.",
                resource_type="Product",
                resource_id=payload.product_id,
            )

        inventory.quantity_on_hand = quantity_after

        transaction = InventoryTransaction(
            product_id=payload.product_id,
            movement_type=MovementType.ADJUSTMENT.value,
            quantity=difference,
            quantity_before=system_quantity,
            quantity_after=quantity_after,
            unit_cost=product.cost_price,
            reference_type="Adjustment",
            reason=payload.reason,
            user_id=user.user_id,
        )
        self.transactions.add(transaction)
        self.session.flush()

        self.reconciliations.add(
            StockReconciliation(
                product_id=payload.product_id,
                system_quantity=system_quantity,
                counted_quantity=payload.counted_quantity if payload.counted_quantity is not None else quantity_after,
                difference=difference,
                adjustment_type=payload.adjustment_type,
                reason=payload.reason,
                user_id=user.user_id,
                transaction_id=transaction.transaction_id,
            )
        )
        self._handle_low_stock(product, inventory)
        self.audit.activity(
            activity_type="INVENTORY_ADJUSTED",
            activity_desc=f"Adjusted {product.sku} by {difference} ({payload.adjustment_type})",
            entity_type="Product",
            entity_id=payload.product_id,
            user_id=user.user_id,
        )
        self.audit.record(
            action_type="UPDATE",
            resource_type="Inventory",
            resource_id=inventory.inventory_id,
            user_id=user.user_id,
            old_values={"quantity_on_hand": system_quantity},
            new_values={"quantity_on_hand": quantity_after, "adjustment_type": payload.adjustment_type},
        )
        self.session.commit()
        return inventory

    # ------------------------------------------------------------------
    # Internal helpers used by sales/returns too
    # ------------------------------------------------------------------
    def ensure_sufficient_stock(self, product: Product, quantity: float) -> None:
        if product.is_service:
            return
        inventory = self.inventory.get_by_product(product.product_id)
        available = inventory.quantity_on_hand - inventory.quantity_reserved if inventory else 0
        if available < quantity:
            raise InsufficientStockError(
                f"Insufficient stock for '{product.product_name}' "
                f"(available: {int(available)}, requested: {quantity}).",
                resource_type="Product",
                resource_id=product.product_id,
            )

    def deduct_stock(
        self,
        product_id: int,
        quantity: float,
        movement_type: str,
        reference_type: str,
        reference_id: int,
        user_id: int | None,
        reason: str | None = None,
    ) -> None:
        product = self._get_product(product_id)
        if product.is_service:
            return
        inventory = self.inventory.get_by_product(product_id)
        if inventory is None:
            raise InsufficientStockError(
                "Product has no inventory record.",
                resource_type="Product",
                resource_id=product_id,
            )
        qty = int(quantity)
        quantity_before = inventory.quantity_on_hand
        quantity_after = quantity_before - qty
        if quantity_after < 0:
            raise InsufficientStockError(
                "Insufficient stock.",
                resource_type="Product",
                resource_id=product_id,
            )
        inventory.quantity_on_hand = quantity_after
        inventory.last_sold_at = utcnow()

        self.transactions.add(
            InventoryTransaction(
                product_id=product_id,
                movement_type=movement_type,
                quantity=-qty,
                quantity_before=quantity_before,
                quantity_after=quantity_after,
                unit_cost=product.cost_price,
                reference_type=reference_type,
                reference_id=str(reference_id),
                reason=reason,
                user_id=user_id,
            )
        )
        self._handle_low_stock(product, inventory)

    def restore_stock(
        self,
        product_id: int,
        quantity: float,
        movement_type: str,
        reference_type: str,
        reference_id: int,
        user_id: int | None,
        reason: str | None = None,
    ) -> None:
        product = self._get_product(product_id)
        if product.is_service:
            return
        inventory = self.inventory.get_by_product(product_id)
        if inventory is None:
            inventory = Inventory(product_id=product_id, quantity_on_hand=0, quantity_reserved=0)
            self.inventory.add(inventory)
            self.session.flush()

        qty = int(quantity)
        quantity_before = inventory.quantity_on_hand
        quantity_after = quantity_before + qty
        inventory.quantity_on_hand = quantity_after

        self.transactions.add(
            InventoryTransaction(
                product_id=product_id,
                movement_type=movement_type,
                quantity=qty,
                quantity_before=quantity_before,
                quantity_after=quantity_after,
                unit_cost=product.cost_price,
                reference_type=reference_type,
                reference_id=str(reference_id),
                reason=reason,
                user_id=user_id,
            )
        )
        self._handle_low_stock(product, inventory)

    def _handle_low_stock(self, product: Product, inventory: Inventory) -> None:
        threshold = product.low_stock_threshold
        if inventory.quantity_on_hand <= threshold:
            alert = self.alerts.open_for_product(product.product_id)
            if alert is None:
                alert = LowStockAlert(
                    product_id=product.product_id,
                    quantity_on_hand=inventory.quantity_on_hand,
                    low_stock_threshold=threshold,
                    status="OPEN",
                )
                self.alerts.add(alert)
            else:
                alert.quantity_on_hand = inventory.quantity_on_hand
                alert.low_stock_threshold = threshold
        else:
            alert = self.alerts.open_for_product(product.product_id)
            if alert is not None:
                alert.status = "RESOLVED"
                alert.resolved_at = utcnow()

    def _get_product(self, product_id: int) -> Product:
        product = self.products.get(product_id)
        if product is None or product.is_deleted:
            raise NotFoundError("Product not found.")
        return product
