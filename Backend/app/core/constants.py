"""Shared constants and enums that mirror the SQL Server schema constraints."""

from __future__ import annotations

from enum import Enum


class StrEnum(str, Enum):
    """String enum helper for Swagger-friendly string values."""

    @classmethod
    def values(cls) -> list[str]:
        return [member.value for member in cls]


class SaleStatus(StrEnum):
    COMPLETED = "COMPLETED"
    VOIDED = "VOIDED"
    REFUNDED = "REFUNDED"


class SaleType(StrEnum):
    CASH = "CASH"
    CREDIT = "CREDIT"
    CREDIT_PARTIAL = "CREDIT_PARTIAL"


class PaymentStatus(StrEnum):
    COMPLETED = "COMPLETED"
    PARTIAL = "PARTIAL"
    REFUNDED = "REFUNDED"
    FAILED = "FAILED"


class CreditStatus(StrEnum):
    OPEN = "OPEN"
    PARTIAL = "PARTIAL"
    SETTLED = "SETTLED"
    OVERDUE = "OVERDUE"
    WRITTEN_OFF = "WRITTEN_OFF"


class ReturnStatus(StrEnum):
    PENDING = "PENDING"
    COMPLETED = "COMPLETED"
    REJECTED = "REJECTED"


class MovementType(StrEnum):
    SALE = "SALE"
    RESTOCK = "RESTOCK"
    RETURN = "RETURN"
    ADJUSTMENT = "ADJUSTMENT"
    VOID = "VOID"
    TRANSFER = "TRANSFER"


class AdjustmentType(StrEnum):
    COUNT = "COUNT"
    DAMAGE = "DAMAGE"
    THEFT = "THEFT"
    EXPIRY = "EXPIRY"
    CORRECTION = "CORRECTION"


class AlertStatus(StrEnum):
    OPEN = "OPEN"
    RESOLVED = "RESOLVED"
    DISMISSED = "DISMISSED"


class NotificationSeverity(StrEnum):
    INFO = "INFO"
    WARNING = "WARNING"
    CRITICAL = "CRITICAL"


class SettingDataType(StrEnum):
    STRING = "string"
    INT = "int"
    DECIMAL = "decimal"
    BOOL = "bool"
    JSON = "json"


class StockStatus(StrEnum):
    IN_STOCK = "IN_STOCK"
    LOW_STOCK = "LOW_STOCK"
    OUT_OF_STOCK = "OUT_OF_STOCK"


class PermissionCode(StrEnum):
    DASHBOARD_VIEW = "dashboard.view"
    PRODUCTS_VIEW = "products.view"
    PRODUCTS_CREATE = "products.create"
    PRODUCTS_UPDATE = "products.update"
    PRODUCTS_DELETE = "products.delete"
    CATEGORIES_VIEW = "categories.view"
    CATEGORIES_CREATE = "categories.create"
    CATEGORIES_UPDATE = "categories.update"
    CATEGORIES_DELETE = "categories.delete"
    SUPPLIERS_VIEW = "suppliers.view"
    SUPPLIERS_CREATE = "suppliers.create"
    SUPPLIERS_UPDATE = "suppliers.update"
    SUPPLIERS_DELETE = "suppliers.delete"
    INVENTORY_VIEW = "inventory.view"
    INVENTORY_CREATE = "inventory.create"
    INVENTORY_UPDATE = "inventory.update"
    INVENTORY_DELETE = "inventory.delete"
    SALES_VIEW = "sales.view"
    SALES_CREATE = "sales.create"
    SALES_UPDATE = "sales.update"
    SALES_DELETE = "sales.delete"
    RETURNS_VIEW = "returns.view"
    RETURNS_CREATE = "returns.create"
    RETURNS_UPDATE = "returns.update"
    RETURNS_DELETE = "returns.delete"
    CREDIT_SALES_VIEW = "credit_sales.view"
    CREDIT_SALES_CREATE = "credit_sales.create"
    CREDIT_SALES_UPDATE = "credit_sales.update"
    CREDIT_SALES_DELETE = "credit_sales.delete"
    REPORTS_VIEW = "reports.view"
    USERS_VIEW = "users.view"
    USERS_CREATE = "users.create"
    USERS_UPDATE = "users.update"
    USERS_DELETE = "users.delete"
    SETTINGS_VIEW = "settings.view"
    SETTINGS_CREATE = "settings.create"
    SETTINGS_UPDATE = "settings.update"
    SETTINGS_DELETE = "settings.delete"
    NOTIFICATIONS_VIEW = "notifications.view"
    NOTIFICATIONS_CREATE = "notifications.create"
    NOTIFICATIONS_UPDATE = "notifications.update"
    NOTIFICATIONS_DELETE = "notifications.delete"
    AUDIT_VIEW = "audit.view"
    AUDIT_CREATE = "audit.create"
    AUDIT_UPDATE = "audit.update"
    AUDIT_DELETE = "audit.delete"
    PAYMENTS_VIEW = "payments.view"
    PAYMENTS_CREATE = "payments.create"
    PAYMENTS_UPDATE = "payments.update"
    PAYMENTS_DELETE = "payments.delete"


class RoleCode(StrEnum):
    ADMIN = "ADMIN"
    MANAGER = "MANAGER"
    CASHIER = "CASHIER"


class ResourceType(StrEnum):
    USER = "User"
    ROLE = "Role"
    PERMISSION = "Permission"
    BUSINESS = "Business"
    CATEGORY = "Category"
    PRODUCT = "Product"
    SUPPLIER = "Supplier"
    INVENTORY = "Inventory"
    SALE = "Sale"
    PAYMENT = "Payment"
    CUSTOMER = "Customer"
    CREDIT_SALE = "CreditSale"
    RETURN = "Return"
    NOTIFICATION = "Notification"
    SETTING = "Setting"
    RECEIPT = "Receipt"
