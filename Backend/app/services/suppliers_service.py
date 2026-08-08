"""Suppliers service (Feature 08)."""

from __future__ import annotations

from app.api.schemas.suppliers import (
    SupplierContactCreate,
    SupplierContactUpdate,
    SupplierCreate,
    SupplierUpdate,
)
from app.exceptions import (
    BadRequestError,
    CannotDeleteInUseError,
    DuplicateResourceError,
    NotFoundError,
    ValidationError_,
)
from app.models.catalog import Supplier, SupplierContact, SupplierHistory
from app.models.users import User
from app.repositories.catalog_repo import (
    ProductRepository,
    SupplierContactRepository,
    SupplierHistoryRepository,
    SupplierRepository,
)
from app.services.audit_service import AuditService
from app.services.base import BaseService
from app.utils.pagination import PageParams
from app.validators.common import is_valid_email


class SupplierService(BaseService):
    service_name = "suppliers"

    def __init__(self, session) -> None:  # noqa: ANN001
        super().__init__(session)
        self.suppliers = SupplierRepository(session)
        self.contacts = SupplierContactRepository(session)
        self.history = SupplierHistoryRepository(session)
        self.products = ProductRepository(session)
        self.audit = AuditService(session)

    # ------------------------------------------------------------------
    def list(self, page: PageParams, search: str | None, is_active: bool | None) -> tuple[list[Supplier], int]:
        return self.suppliers.search(
            search=search,
            is_active=is_active,
            page=page.page,
            page_size=page.page_size,
        )

    def get(self, supplier_id: int) -> Supplier:
        supplier = self.suppliers.get(supplier_id)
        if supplier is None or supplier.is_deleted:
            raise NotFoundError("Supplier not found.")
        return supplier

    def create(self, payload: SupplierCreate, actor: User) -> Supplier:
        if self.suppliers.get_by_code(payload.supplier_code):
            raise DuplicateResourceError("Supplier code already exists.", resource_type="Supplier")
        if self.suppliers.get_by_name(payload.supplier_name):
            raise DuplicateResourceError("Supplier name already exists.", resource_type="Supplier")
        if payload.email and not is_valid_email(payload.email):
            raise ValidationError_(
                "A valid email is required.",
                [{"field": "email", "message": "Invalid email format"}],
            )

        supplier = Supplier(
            **payload.model_dump(),
            created_by=actor.user_id,
            updated_by=actor.user_id,
        )
        self.suppliers.add(supplier)
        self.session.flush()
        self._log_history(
            supplier, "CREATED", f"Supplier created as {supplier.supplier_code}", actor.user_id
        )
        self.audit.activity(
            activity_type="SUPPLIER_CREATED",
            activity_desc=f"Created supplier {supplier.supplier_name}",
            entity_type="Supplier",
            entity_id=supplier.supplier_id,
            user_id=actor.user_id,
        )
        self.session.commit()
        return self.suppliers.get(supplier.supplier_id)

    def update(self, supplier_id: int, payload: SupplierUpdate, actor: User) -> Supplier:
        supplier = self.get(supplier_id)
        data = payload.model_dump(exclude_unset=True)

        if "supplier_code" in data and data["supplier_code"]:
            existing = self.suppliers.get_by_code(data["supplier_code"])
            if existing and existing.supplier_id != supplier_id:
                raise DuplicateResourceError("Supplier code already exists.", resource_type="Supplier")
            supplier.supplier_code = data["supplier_code"]
        if "supplier_name" in data and data["supplier_name"]:
            existing = self.suppliers.get_by_name(data["supplier_name"])
            if existing and existing.supplier_id != supplier_id:
                raise DuplicateResourceError("Supplier name already exists.", resource_type="Supplier")
            supplier.supplier_name = data["supplier_name"]
        if "email" in data and data["email"]:
            if not is_valid_email(data["email"]):
                raise ValidationError_(
                    "A valid email is required.",
                    [{"field": "email", "message": "Invalid email format"}],
                )
            supplier.email = data["email"]

        for field in (
            "contact_person",
            "phone",
            "address_line1",
            "address_line2",
            "city",
            "state",
            "postal_code",
            "country",
            "notes",
        ):
            if field in data:
                setattr(supplier, field, data[field])
        if "is_active" in data and data["is_active"] is not None:
            supplier.is_active = data["is_active"]

        supplier.updated_by = actor.user_id
        self._log_history(supplier, "UPDATED", "Supplier details updated", actor.user_id)
        self.audit.activity(
            activity_type="SUPPLIER_UPDATED",
            activity_desc=f"Updated supplier {supplier.supplier_name}",
            entity_type="Supplier",
            entity_id=supplier.supplier_id,
            user_id=actor.user_id,
        )
        self.session.commit()
        return self.suppliers.get(supplier.supplier_id)

    def delete(self, supplier_id: int, actor: User) -> None:
        supplier = self.get(supplier_id)
        if self.products.count(self.products.model.supplier_id == supplier_id) > 0:
            raise CannotDeleteInUseError("Supplier has products and cannot be deleted.")
        supplier.is_deleted = True
        supplier.is_active = False
        supplier.deleted_by = actor.user_id
        self.audit.activity(
            activity_type="SUPPLIER_DELETED",
            activity_desc=f"Deleted supplier {supplier.supplier_name}",
            entity_type="Supplier",
            entity_id=supplier.supplier_id,
            user_id=actor.user_id,
        )
        self.session.commit()

    # ------------------------------------------------------------------
    # Contacts
    # ------------------------------------------------------------------
    def add_contact(self, supplier_id: int, payload: SupplierContactCreate, actor: User) -> SupplierContact:
        supplier = self.get(supplier_id)
        contact = SupplierContact(supplier_id=supplier.supplier_id, **payload.model_dump())
        self.contacts.add(contact)
        if payload.is_primary:
            self._clear_primary_contacts(supplier_id)
            contact.is_primary = True
        self._log_history(supplier, "CONTACT_CHANGED", f"Added contact {contact.full_name}", actor.user_id)
        self.session.commit()
        return self.contacts.get(contact.contact_id)

    def update_contact(
        self, supplier_id: int, contact_id: int, payload: SupplierContactUpdate, actor: User
    ) -> SupplierContact:
        supplier = self.get(supplier_id)
        contact = self.contacts.get(contact_id)
        if contact is None or contact.supplier_id != supplier_id:
            raise NotFoundError("Supplier contact not found.")
        data = payload.model_dump(exclude_unset=True)
        for field, value in data.items():
            if value is not None:
                setattr(contact, field, value)
        if data.get("is_primary") is True:
            self._clear_primary_contacts(supplier_id)
            contact.is_primary = True
        self._log_history(supplier, "CONTACT_CHANGED", f"Updated contact {contact.full_name}", actor.user_id)
        self.session.commit()
        return self.contacts.get(contact_id)

    def delete_contact(self, supplier_id: int, contact_id: int, actor: User) -> None:
        supplier = self.get(supplier_id)
        contact = self.contacts.get(contact_id)
        if contact is None or contact.supplier_id != supplier_id:
            raise NotFoundError("Supplier contact not found.")
        self.contacts.delete(contact)
        self._log_history(supplier, "CONTACT_CHANGED", f"Removed contact {contact.full_name}", actor.user_id)
        self.session.commit()

    # ------------------------------------------------------------------
    # History
    # ------------------------------------------------------------------
    def list_history(
        self, supplier_id: int, page: PageParams
    ) -> tuple[list[SupplierHistory], int]:
        self.get(supplier_id)
        return self.history.list_for_supplier(supplier_id, page.page, page.page_size)

    def _clear_primary_contacts(self, supplier_id: int) -> None:
        for contact in self.contacts.list_all():
            if contact.supplier_id == supplier_id:
                contact.is_primary = False

    def _log_history(self, supplier: Supplier, history_type: str, description: str, changed_by: int | None) -> None:
        self.history.add(
            SupplierHistory(
                supplier_id=supplier.supplier_id,
                history_type=history_type,
                description=description,
                changed_by=changed_by,
            )
        )
