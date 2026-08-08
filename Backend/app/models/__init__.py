"""ORM models package.

One module per database module, mirroring the SQL Server schema exactly.
Column types use portable SQLAlchemy generics (Unicode, DateTime, Boolean,
Numeric) which render correctly on SQL Server (the production target) and
remain usable on SQLite for local development and tests.
"""

from app.models.audit import (
    ActivityLog,
    AuditLog,
    AuditLogArchive,
    ErrorLog,
    SecurityLog,
)
from app.models.auth import Permission, Role, RolePermission
from app.models.business import BusinessInformation, Currency, TaxRate
from app.models.catalog import (
    Category,
    Product,
    ProductImage,
    Supplier,
    SupplierContact,
    SupplierHistory,
)
from app.models.credits import CreditPayment, CreditSale, Customer
from app.models.inventory import (
    Inventory,
    InventoryTransaction,
    LowStockAlert,
    StockReconciliation,
)
from app.models.notifications import Notification, NotificationHistory, NotificationType
from app.models.payments import Payment, PaymentMethod, Receipt
from app.models.returns import Return, ReturnItem, ReturnReason
from app.models.sales import Sale, SaleItem
from app.models.settings import Setting, UserSetting
from app.models.users import PasswordHistory, PasswordReset, User, UserSession

__all__ = [
    "ActivityLog",
    "AuditLog",
    "AuditLogArchive",
    "BusinessInformation",
    "Category",
    "CreditPayment",
    "CreditSale",
    "Currency",
    "Customer",
    "ErrorLog",
    "Inventory",
    "InventoryTransaction",
    "LowStockAlert",
    "Notification",
    "NotificationHistory",
    "NotificationType",
    "PasswordHistory",
    "PasswordReset",
    "Payment",
    "PaymentMethod",
    "Permission",
    "Product",
    "ProductImage",
    "Receipt",
    "Return",
    "ReturnItem",
    "ReturnReason",
    "Role",
    "RolePermission",
    "Sale",
    "SaleItem",
    "SecurityLog",
    "Setting",
    "StockReconciliation",
    "Supplier",
    "SupplierContact",
    "SupplierHistory",
    "TaxRate",
    "User",
    "UserSession",
    "UserSetting",
]
