"""Categories service (Feature 06)."""

from __future__ import annotations

from app.api.schemas.categories import CategoryCreate, CategoryUpdate
from app.exceptions import (
    BadRequestError,
    CannotDeleteInUseError,
    DuplicateResourceError,
    NotFoundError,
    ValidationError_,
)
from app.models.catalog import Category
from app.models.users import User
from app.repositories.catalog_repo import CategoryRepository, ProductRepository
from app.services.audit_service import AuditService
from app.services.base import BaseService
from app.utils.pagination import PageParams


class CategoryService(BaseService):
    service_name = "categories"

    def __init__(self, session) -> None:  # noqa: ANN001
        super().__init__(session)
        self.categories = CategoryRepository(session)
        self.products = ProductRepository(session)
        self.audit = AuditService(session)

    # ------------------------------------------------------------------
    def list(
        self,
        page: PageParams,
        search: str | None,
        parent_id: int | None,
        is_active: bool | None,
    ) -> tuple[list[Category], int]:
        return self.categories.search(
            search=search,
            parent_id=parent_id,
            is_active=is_active,
            page=page.page,
            page_size=page.page_size,
        )

    def get(self, category_id: int) -> Category:
        category = self.categories.get(category_id)
        if category is None or category.is_deleted:
            raise NotFoundError("Category not found.")
        return category

    def create(self, payload: CategoryCreate, actor: User) -> Category:
        if payload.parent_id is not None:
            parent = self.get(payload.parent_id)
            if not parent.is_active:
                raise ValidationError_(
                    "Parent category is inactive.",
                    [{"field": "parent_id", "message": "Parent must be active"}],
                )
        if self.categories.get_by_name_parent(payload.category_name, payload.parent_id):
            raise DuplicateResourceError(
                "A category with this name already exists under the same parent.",
                resource_type="Category",
            )
        category = Category(
            category_name=payload.category_name.strip(),
            parent_id=payload.parent_id,
            description=payload.description,
            sort_order=payload.sort_order,
            created_by=actor.user_id,
            updated_by=actor.user_id,
        )
        self.categories.add(category)
        self.audit.activity(
            activity_type="CATEGORY_CREATED",
            activity_desc=f"Created category {category.category_name}",
            entity_type="Category",
            entity_id=category.category_id,
            user_id=actor.user_id,
        )
        self.session.commit()
        return self.categories.get(category.category_id)

    def update(self, category_id: int, payload: CategoryUpdate, actor: User) -> Category:
        category = self.get(category_id)
        data = payload.model_dump(exclude_unset=True)

        if "parent_id" in data:
            if data["parent_id"] == category_id:
                raise ValidationError_(
                    "A category cannot be its own parent.",
                    [{"field": "parent_id", "message": "Cannot reference self"}],
                )
            if data["parent_id"] is not None:
                parent = self.get(data["parent_id"])
                if self._is_descendant(category_id, parent.category_id):
                    raise ValidationError_(
                        "Moving a category under one of its descendants would create a cycle.",
                        [{"field": "parent_id", "message": "Circular reference"}],
                    )
            category.parent_id = data["parent_id"]

        if "category_name" in data and data["category_name"]:
            name = data["category_name"].strip()
            duplicate = self.categories.get_by_name_parent(name, category.parent_id)
            if duplicate and duplicate.category_id != category.category_id:
                raise DuplicateResourceError(
                    "A category with this name already exists under the same parent.",
                    resource_type="Category",
                )
            category.category_name = name
        if "description" in data:
            category.description = data["description"]
        if "sort_order" in data and data["sort_order"] is not None:
            category.sort_order = data["sort_order"]
        if "is_active" in data and data["is_active"] is not None:
            category.is_active = data["is_active"]

        category.updated_by = actor.user_id
        self.audit.activity(
            activity_type="CATEGORY_UPDATED",
            activity_desc=f"Updated category {category.category_name}",
            entity_type="Category",
            entity_id=category.category_id,
            user_id=actor.user_id,
        )
        self.session.commit()
        return self.categories.get(category.category_id)

    def delete(self, category_id: int, actor: User) -> None:
        category = self.get(category_id)
        if self.categories.has_children(category_id):
            raise CannotDeleteInUseError("Category has child categories and cannot be deleted.")
        if self.categories.has_products(category_id):
            raise CannotDeleteInUseError("Category has products and cannot be deleted.")
        category.is_deleted = True
        category.is_active = False
        category.deleted_by = actor.user_id
        self.audit.activity(
            activity_type="CATEGORY_DELETED",
            activity_desc=f"Deleted category {category.category_name}",
            entity_type="Category",
            entity_id=category.category_id,
            user_id=actor.user_id,
        )
        self.session.commit()

    def _is_descendant(self, root_id: int, candidate_id: int) -> bool:
        """Return True if candidate_id is a descendant of root_id."""
        current = candidate_id
        seen: set[int] = set()
        while current is not None and current not in seen:
            if current == root_id:
                return True
            seen.add(current)
            parent = self.categories.get(current)
            current = parent.parent_id if parent else None
        return False
