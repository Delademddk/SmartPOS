"""Products service (Feature 07)."""

from __future__ import annotations

from fastapi import UploadFile

from app.api.schemas.products import ProductCreate, ProductUpdate, PriceUpdate
from app.core.constants import MovementType, StockStatus
from app.exceptions import (
    BadRequestError,
    CannotDeleteInUseError,
    DuplicateResourceError,
    NotFoundError,
    ValidationError_,
)
from app.models.catalog import Product
from app.models.inventory import Inventory, InventoryTransaction
from app.models.users import User
from app.repositories.catalog_repo import (
    CategoryRepository,
    ProductRepository,
    SupplierRepository,
)
from app.repositories.ops_repo import InventoryRepository, SaleItemRepository
from app.services.audit_service import AuditService
from app.services.base import BaseService
from app.services.image_storage import get_image_storage_service
from app.utils.pagination import PageParams


def classify_stock(quantity_on_hand: int, low_stock_threshold: int) -> str:
    if quantity_on_hand <= 0:
        return StockStatus.OUT_OF_STOCK.value
    if quantity_on_hand <= low_stock_threshold:
        return StockStatus.LOW_STOCK.value
    return StockStatus.IN_STOCK.value


class ProductService(BaseService):
    service_name = "products"

    def __init__(self, session) -> None:  # noqa: ANN001
        super().__init__(session)
        self.products = ProductRepository(session)
        self.categories = CategoryRepository(session)
        self.suppliers = SupplierRepository(session)
        self.inventory = InventoryRepository(session)
        self.sale_items = SaleItemRepository(session)
        self.audit = AuditService(session)
        self.storage = get_image_storage_service()

    # ------------------------------------------------------------------
    def list(
        self,
        page: PageParams,
        search: str | None,
        category_id: int | None,
        supplier_id: int | None,
        is_active: bool | None,
        min_price: float | None,
        max_price: float | None,
        stock_status: str | None,
    ) -> tuple[list[Product], int]:
        return self.products.search(
            search=search,
            category_id=category_id,
            supplier_id=supplier_id,
            is_active=is_active,
            min_price=min_price,
            max_price=max_price,
            stock_status=stock_status,
            page=page.page,
            page_size=page.page_size,
        )

    def get(self, product_id: int) -> Product:
        product = self.products.get(product_id)
        if product is None or product.is_deleted:
            raise NotFoundError("Product not found.")
        return product

    def get_by_sku(self, sku: str) -> Product:
        product = self.products.get_by_sku(sku)
        if product is None or product.is_deleted:
            raise NotFoundError("Product not found.")
        return product

    def create(
        self,
        payload: ProductCreate,
        actor: User,
        image: UploadFile | None = None,
    ) -> Product:
        if self.products.get_by_sku(payload.sku):
            raise DuplicateResourceError("SKU already exists.", resource_type="Product")
        if payload.barcode and self.products.get_by_barcode(payload.barcode):
            raise DuplicateResourceError("Barcode already exists.", resource_type="Product")
        self._validate_references(payload.category_id, payload.supplier_id)

        if image is not None:
            image_url = self.storage.save_product_image(image)
        elif payload.image_url:
            image_url = payload.image_url
        else:
            image_url = None

        product = Product(
            sku=payload.sku.upper(),
            barcode=payload.barcode,
            product_name=payload.product_name.strip(),
            description=payload.description,
            category_id=payload.category_id,
            supplier_id=payload.supplier_id,
            unit=payload.unit,
            unit_price=payload.unit_price,
            cost_price=payload.cost_price,
            image_url=image_url,
            low_stock_threshold=payload.low_stock_threshold,
            is_service=payload.is_service,
            created_by=actor.user_id,
            updated_by=actor.user_id,
        )
        self.products.add(product)
        self.session.flush()

        if not payload.is_service:
            inventory = Inventory(
                product_id=product.product_id,
                quantity_on_hand=0,
                quantity_reserved=0,
            )
            self.inventory.add(inventory)
            if payload.initial_quantity > 0:
                self.inventory.flush()
                from app.services.inventory_service import InventoryService

                InventoryService(self.session).restock(
                    product_id=product.product_id,
                    quantity=payload.initial_quantity,
                    unit_cost=payload.cost_price,
                    reason="Initial stock",
                    user_id=actor.user_id,
                    skip_commit=True,
                )

        self.audit.activity(
            activity_type="PRODUCT_CREATED",
            activity_desc=f"Created product {product.sku}",
            entity_type="Product",
            entity_id=product.product_id,
            user_id=actor.user_id,
        )
        self.audit.record(
            action_type="INSERT",
            resource_type="Product",
            resource_id=product.product_id,
            user_id=actor.user_id,
            new_values={"sku": product.sku, "unit_price": float(product.unit_price)},
        )
        self.session.commit()
        return self.products.get(product.product_id)

    def update(
        self,
        product_id: int,
        payload: ProductUpdate,
        actor: User,
        image: UploadFile | None = None,
        remove_image: bool = False,
    ) -> Product:
        product = self.get(product_id)
        data = payload.model_dump(exclude_unset=True)
        old_image_url = product.image_url

        if remove_image and image is not None:
            raise BadRequestError(
                "Cannot replace and remove a product image at the same time.",
                [{"field": "image", "message": "Provide either an image or remove_image, not both."}],
            )

        if remove_image:
            product.image_url = None
            if old_image_url:
                self.storage.delete_product_image(old_image_url)
        elif image is not None:
            new_image_url = self.storage.save_product_image(image)
            product.image_url = new_image_url
            if old_image_url:
                self.storage.delete_product_image(old_image_url)
        elif "image_url" in data:
            new_image_url = data["image_url"]
            product.image_url = new_image_url
            if old_image_url and old_image_url != new_image_url:
                self.storage.delete_product_image(old_image_url)

        if "sku" in data and data["sku"]:
            sku = data["sku"].upper()
            existing = self.products.get_by_sku(sku)
            if existing and existing.product_id != product_id:
                raise DuplicateResourceError("SKU already exists.", resource_type="Product")
            product.sku = sku
        if "barcode" in data:
            barcode = data["barcode"]
            if barcode:
                existing = self.products.get_by_barcode(barcode)
                if existing and existing.product_id != product_id:
                    raise DuplicateResourceError("Barcode already exists.", resource_type="Product")
            product.barcode = barcode
        if "product_name" in data and data["product_name"]:
            product.product_name = data["product_name"].strip()
        if "description" in data:
            product.description = data["description"]
        if "category_id" in data:
            self._validate_references(data["category_id"], None)
            product.category_id = data["category_id"]
        if "supplier_id" in data:
            self._validate_references(None, data["supplier_id"])
            product.supplier_id = data["supplier_id"]
        if "unit" in data and data["unit"]:
            product.unit = data["unit"]
        if "unit_price" in data and data["unit_price"] is not None:
            product.unit_price = data["unit_price"]
        if "cost_price" in data:
            product.cost_price = data["cost_price"]
        if "low_stock_threshold" in data and data["low_stock_threshold"] is not None:
            product.low_stock_threshold = data["low_stock_threshold"]
        if "is_service" in data and data["is_service"] is not None:
            product.is_service = data["is_service"]
        if "is_active" in data and data["is_active"] is not None:
            product.is_active = data["is_active"]

        product.updated_by = actor.user_id
        self.audit.activity(
            activity_type="PRODUCT_UPDATED",
            activity_desc=f"Updated product {product.sku}",
            entity_type="Product",
            entity_id=product.product_id,
            user_id=actor.user_id,
        )
        self.audit.record(
            action_type="UPDATE",
            resource_type="Product",
            resource_id=product.product_id,
            user_id=actor.user_id,
            new_values=data,
        )
        self.session.commit()
        return self.products.get(product.product_id)

    def update_price(self, product_id: int, payload: PriceUpdate, actor: User) -> Product:
        product = self.get(product_id)
        old_price = float(product.unit_price)
        product.unit_price = payload.unit_price
        if payload.cost_price is not None:
            product.cost_price = payload.cost_price
        product.updated_by = actor.user_id
        self.audit.record(
            action_type="PRICE_UPDATE",
            resource_type="Product",
            resource_id=product.product_id,
            user_id=actor.user_id,
            old_values={"unit_price": old_price},
            new_values={"unit_price": float(payload.unit_price)},
        )
        self.session.commit()
        return self.products.get(product.product_id)

    def delete(self, product_id: int, actor: User) -> None:
        product = self.get(product_id)
        if self.sale_items.count(self.sale_items.model.product_id == product_id) > 0:
            raise CannotDeleteInUseError("Product has sales history and cannot be deleted.")
        product.is_deleted = True
        product.is_active = False
        product.deleted_by = actor.user_id
        self.audit.activity(
            activity_type="PRODUCT_ARCHIVED",
            activity_desc=f"Archived product {product.sku}",
            entity_type="Product",
            entity_id=product.product_id,
            user_id=actor.user_id,
        )
        self.session.commit()

    def archive(self, product_id: int, actor: User) -> Product:
        product = self.get(product_id)
        product.is_active = False
        product.updated_by = actor.user_id
        self.audit.activity(
            activity_type="PRODUCT_ARCHIVED",
            activity_desc=f"Archived product {product.sku}",
            entity_type="Product",
            entity_id=product.product_id,
            user_id=actor.user_id,
        )
        self.session.commit()
        return self.products.get(product.product_id)

    def _validate_references(self, category_id: int | None, supplier_id: int | None) -> None:
        if category_id is not None:
            category = self.categories.get(category_id)
            if category is None or category.is_deleted:
                raise ValidationError_(
                    "Category does not exist.",
                    [{"field": "category_id", "message": "Invalid category"}],
                )
        if supplier_id is not None:
            supplier = self.suppliers.get(supplier_id)
            if supplier is None or supplier.is_deleted:
                raise ValidationError_(
                    "Supplier does not exist.",
                    [{"field": "supplier_id", "message": "Invalid supplier"}],
                )
