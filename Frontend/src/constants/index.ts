export const API_URL = import.meta.env.VITE_API_URL || "http://localhost:8000/api/v1";
export const APP_NAME = import.meta.env.VITE_APP_NAME || "SmartPOS";
export const APP_ENV = import.meta.env.VITE_APP_ENV || "development";

export const TOKEN_KEY = "smartpos_access_token";
export const REFRESH_TOKEN_KEY = "smartpos_refresh_token";
export const USER_KEY = "smartpos_user";

export const ROLES = {
  ADMIN: "ADMIN",
  MANAGER: "MANAGER",
  CASHIER: "CASHIER",
} as const;

export type RoleCode = (typeof ROLES)[keyof typeof ROLES];

export const PERMISSIONS = {
  DASHBOARD_VIEW: "dashboard.view",
  PRODUCTS_VIEW: "products.view",
  PRODUCTS_CREATE: "products.create",
  PRODUCTS_UPDATE: "products.update",
  PRODUCTS_DELETE: "products.delete",
  CATEGORIES_VIEW: "categories.view",
  CATEGORIES_CREATE: "categories.create",
  CATEGORIES_UPDATE: "categories.update",
  CATEGORIES_DELETE: "categories.delete",
  SUPPLIERS_VIEW: "suppliers.view",
  SUPPLIERS_CREATE: "suppliers.create",
  SUPPLIERS_UPDATE: "suppliers.update",
  SUPPLIERS_DELETE: "suppliers.delete",
  INVENTORY_VIEW: "inventory.view",
  INVENTORY_CREATE: "inventory.create",
  INVENTORY_UPDATE: "inventory.update",
  INVENTORY_DELETE: "inventory.delete",
  SALES_VIEW: "sales.view",
  SALES_CREATE: "sales.create",
  SALES_UPDATE: "sales.update",
  SALES_DELETE: "sales.delete",
  RETURNS_VIEW: "returns.view",
  RETURNS_CREATE: "returns.create",
  RETURNS_UPDATE: "returns.update",
  RETURNS_DELETE: "returns.delete",
  CREDIT_SALES_VIEW: "credit_sales.view",
  CREDIT_SALES_CREATE: "credit_sales.create",
  CREDIT_SALES_UPDATE: "credit_sales.update",
  CREDIT_SALES_DELETE: "credit_sales.delete",
  REPORTS_VIEW: "reports.view",
  USERS_VIEW: "users.view",
  USERS_CREATE: "users.create",
  USERS_UPDATE: "users.update",
  USERS_DELETE: "users.delete",
  SETTINGS_VIEW: "settings.view",
  SETTINGS_CREATE: "settings.create",
  SETTINGS_UPDATE: "settings.update",
  SETTINGS_DELETE: "settings.delete",
  NOTIFICATIONS_VIEW: "notifications.view",
  NOTIFICATIONS_CREATE: "notifications.create",
  NOTIFICATIONS_UPDATE: "notifications.update",
  NOTIFICATIONS_DELETE: "notifications.delete",
  AUDIT_VIEW: "audit.view",
  AUDIT_CREATE: "audit.create",
  AUDIT_UPDATE: "audit.update",
  AUDIT_DELETE: "audit.delete",
  PAYMENTS_VIEW: "payments.view",
  PAYMENTS_CREATE: "payments.create",
  PAYMENTS_UPDATE: "payments.update",
  PAYMENTS_DELETE: "payments.delete",
} as const;

export const SALE_STATUS = {
  COMPLETED: "COMPLETED",
  VOIDED: "VOIDED",
  REFUNDED: "REFUNDED",
} as const;

export const SALE_TYPE = {
  CASH: "CASH",
  CREDIT: "CREDIT",
  CREDIT_PARTIAL: "CREDIT_PARTIAL",
} as const;

export const CREDIT_STATUS = {
  OPEN: "OPEN",
  PARTIAL: "PARTIAL",
  SETTLED: "SETTLED",
  OVERDUE: "OVERDUE",
  WRITTEN_OFF: "WRITTEN_OFF",
} as const;

export const RETURN_STATUS = {
  PENDING: "PENDING",
  COMPLETED: "COMPLETED",
  REJECTED: "REJECTED",
} as const;

export const STOCK_STATUS = {
  IN_STOCK: "IN_STOCK",
  LOW_STOCK: "LOW_STOCK",
  OUT_OF_STOCK: "OUT_OF_STOCK",
} as const;

export const MOVEMENT_TYPE = {
  SALE: "SALE",
  RESTOCK: "RESTOCK",
  RETURN: "RETURN",
  ADJUSTMENT: "ADJUSTMENT",
  VOID: "VOID",
  TRANSFER: "TRANSFER",
} as const;

export const NOTIFICATION_SEVERITY = {
  INFO: "INFO",
  WARNING: "WARNING",
  CRITICAL: "CRITICAL",
} as const;

export const REPORT_TYPES = {
  DAILY_SALES: "daily_sales",
  MONTHLY_SALES: "monthly_sales",
  INVENTORY: "inventory",
  PROFIT: "profit",
  CASHIER: "cashier",
  SUPPLIER: "supplier",
  CREDIT: "credit",
} as const;

export const PAGE_SIZES = [10, 25, 50, 100] as const;
export const DEFAULT_PAGE_SIZE = 50;

export const KEYBOARD_SHORTCUTS = {
  FOCUS_SEARCH: "/",
  COMPLETE_SALE: "Ctrl+Enter",
  CANCEL: "Escape",
} as const;
