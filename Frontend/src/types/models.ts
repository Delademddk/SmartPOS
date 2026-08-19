export interface User {
  user_id: number;
  username: string;
  email: string;
  full_name: string;
  phone: string | null;
  role_id: number;
  role_code: string;
  role_name: string;
  is_active: boolean;
  must_change_password: boolean;
  last_login_at: string | null;
  created_at: string;
  updated_at: string;
}

export interface Role {
  role_id: number;
  role_code: string;
  role_name: string;
  description: string | null;
  is_system: boolean;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface RoleWithPermissions extends Role {
  permissions: Permission[];
}

export interface Permission {
  permission_id: number;
  permission_code: string;
  permission_name: string;
  description: string | null;
  module_name: string;
  is_system: boolean;
  is_active: boolean;
}

export interface Category {
  category_id: number;
  category_name: string;
  description: string | null;
  parent_id: number | null;
  is_active: boolean;
  child_count: number;
  product_count: number;
  created_at: string;
  updated_at: string;
}

export interface Product {
  product_id: number;
  sku: string;
  barcode: string | null;
  product_name: string;
  description: string | null;
  category_id: number | null;
  category_name: string | null;
  supplier_id: number | null;
  supplier_name: string | null;
  unit: string;
  unit_price: number;
  cost_price: number | null;
  image_url: string | null;
  low_stock_threshold: number;
  is_service: boolean;
  is_active: boolean;
  quantity_on_hand: number;
  stock_status: string;
  created_at: string;
  updated_at: string;
}

export interface Supplier {
  supplier_id: number;
  supplier_name: string;
  contact_person: string | null;
  email: string | null;
  phone: string | null;
  address: string | null;
  city: string | null;
  state: string | null;
  postal_code: string | null;
  country: string | null;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface SupplierDetail extends Supplier {
  contacts: SupplierContact[];
}

export interface SupplierContact {
  contact_id: number;
  supplier_id: number;
  contact_name: string;
  contact_type: string | null;
  email: string | null;
  phone: string | null;
  is_primary: boolean;
  is_active: boolean;
}

export interface SupplierHistory {
  history_id: number;
  supplier_id: number;
  product_id: number;
  product_name: string;
  quantity: number;
  unit_cost: number;
  total_cost: number;
  reference_number: string | null;
  notes: string | null;
  created_at: string;
}

export interface Inventory {
  inventory_id: number;
  product_id: number;
  product_name: string;
  sku: string;
  quantity_on_hand: number;
  quantity_reserved: number;
  available_quantity: number;
  reorder_level: number | null;
  low_stock_threshold: number | null;
  stock_status: string;
  last_restocked_at: string | null;
  last_sold_at: string | null;
  updated_at: string;
}

export interface InventoryMovement {
  transaction_id: number;
  product_id: number;
  product_name: string;
  sku: string;
  movement_type: string;
  quantity: number;
  quantity_before: number;
  quantity_after: number;
  unit_cost: number | null;
  reference_type: string | null;
  reference_id: string | null;
  reason: string | null;
  username: string | null;
  created_at: string;
}

export interface LowStockAlert {
  alert_id: number;
  product_id: number;
  product_name: string;
  sku: string;
  quantity_on_hand: number;
  low_stock_threshold: number;
  status: string;
  raised_at: string;
  resolved_at: string | null;
}

export interface Sale {
  sale_id: number;
  receipt_number: string;
  sale_type: string;
  status: string;
  user_id: number;
  cashier_name: string;
  customer_id: number | null;
  customer_name: string | null;
  subtotal: number;
  tax_amount: number;
  discount_amount: number;
  total_amount: number;
  amount_received: number;
  change_amount: number;
  notes: string | null;
  created_at: string;
  items: SaleItem[];
  payments: Payment[];
}

export interface SaleItem {
  sale_item_id: number;
  sale_id: number;
  product_id: number;
  product_name: string;
  sku: string;
  quantity: number;
  unit_price: number;
  cost_price: number;
  discount_rate: number;
  tax_amount: number;
  line_total: number;
  is_returned: boolean;
  returned_qty: number;
}

export interface Payment {
  payment_id: number;
  sale_id: number;
  payment_method_id: number;
  method_name: string;
  method_code: string;
  amount: number;
  reference_number: string | null;
  status: string;
  created_at: string;
}

export interface PaymentMethod {
  payment_method_id: number;
  method_code: string;
  method_name: string;
  is_cash: boolean;
  is_active: boolean;
  sort_order: number;
}

export interface Customer {
  customer_id: number;
  customer_name: string;
  email: string | null;
  phone: string | null;
  address: string | null;
  credit_limit: number;
  current_balance: number;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface CreditSale {
  credit_sale_id: number;
  sale_id: number;
  receipt_number: string;
  customer_id: number;
  customer_name: string;
  total_amount: number;
  amount_paid: number;
  outstanding_balance: number;
  due_date: string;
  status: string;
  days_overdue: number;
  created_at: string;
  updated_at: string;
}

export interface CreditPayment {
  credit_payment_id: number;
  credit_sale_id: number;
  payment_id: number;
  amount: number;
  payment_method: string;
  notes: string | null;
  created_at: string;
}

export interface Return {
  return_id: number;
  sale_id: number;
  receipt_number: string;
  return_reason_id: number;
  return_reason: string;
  status: string;
  total_refund_amount: number;
  notes: string | null;
  user_id: number;
  user_name: string;
  created_at: string;
  items: ReturnItem[];
}

export interface ReturnItem {
  return_item_id: number;
  return_id: number;
  sale_item_id: number;
  product_id: number;
  product_name: string;
  quantity: number;
  unit_price: number;
  refund_amount: number;
}

export interface ReturnReason {
  return_reason_id: number;
  reason_name: string;
  description: string | null;
  is_active: boolean;
}

export interface Notification {
  notification_id: number;
  user_id: number;
  type_code: string;
  type_name: string;
  title: string;
  message: string;
  severity: string;
  is_read: boolean;
  is_dismissed: boolean;
  entity_type: string | null;
  entity_id: number | null;
  created_at: string;
}

export interface NotificationType {
  notification_type_id: number;
  type_code: string;
  type_name: string;
  description: string | null;
  default_severity: string;
  is_active: boolean;
}

export interface AuditLog {
  log_id: number;
  user_id: number;
  username: string;
  action_type: string;
  resource_type: string;
  resource_id: number | null;
  old_value: string | null;
  new_value: string | null;
  ip_address: string | null;
  user_agent: string | null;
  created_at: string;
}

export interface ActivityLog {
  activity_id: number;
  user_id: number;
  username: string;
  action: string;
  description: string | null;
  ip_address: string | null;
  created_at: string;
}

export interface SecurityLog {
  security_log_id: number;
  user_id: number | null;
  username: string | null;
  event_type: string;
  description: string;
  ip_address: string | null;
  user_agent: string | null;
  created_at: string;
}

export interface ErrorLog {
  error_log_id: number;
  user_id: number | null;
  username: string | null;
  error_type: string;
  message: string;
  stack_trace: string | null;
  ip_address: string | null;
  created_at: string;
}

export interface BusinessInfo {
  business_info_id: number;
  business_name: string;
  legal_name: string | null;
  tax_id: string | null;
  address_line1: string | null;
  address_line2: string | null;
  city: string | null;
  state: string | null;
  postal_code: string | null;
  country: string | null;
  phone: string | null;
  email: string | null;
  website: string | null;
  currency_code: string;
  timezone: string;
  is_active: boolean;
  updated_at: string;
}

export interface Currency {
  currency_id: number;
  currency_code: string;
  currency_name: string;
  symbol: string;
  decimal_places: number;
  is_base: boolean;
  is_active: boolean;
}

export interface TaxRate {
  tax_rate_id: number;
  tax_name: string;
  tax_code: string;
  rate_percent: number;
  is_default: boolean;
  is_active: boolean;
}

export type TaxRateRead = TaxRate;

export interface TaxRateCreate {
  tax_name: string;
  tax_code: string;
  rate_percent: number;
  is_default?: boolean;
}

export type TaxRateUpdate = Partial<TaxRateCreate> & {
  is_active?: boolean;
};

export type SettingDataType = "string" | "int" | "decimal" | "bool" | "json";

export type SettingCategory =
  | "general"
  | "tax"
  | "notifications"
  | "receipt"
  | "system";

export interface Setting {
  setting_id: number;
  setting_key: string;
  setting_value: string;
  data_type: string;
  category: string;
  description: string | null;
  is_active: boolean;
  updated_at: string;
}

export interface SettingRead {
  setting_id: number;
  setting_key: string;
  setting_value: string | null;
  data_type: string;
  category: string;
  description: string | null;
  is_active: boolean;
  updated_at: string;
}

export interface SettingCreate {
  setting_key: string;
  setting_value?: string | null;
  data_type?: SettingDataType;
  category?: SettingCategory;
  description?: string | null;
}

export type SettingUpdate = Partial<SettingCreate> & {
  is_active?: boolean;
};

export interface BusinessInfoUpdate {
  business_name?: string;
  legal_name?: string | null;
  tax_id?: string | null;
  address_line1?: string | null;
  address_line2?: string | null;
  city?: string | null;
  state?: string | null;
  postal_code?: string | null;
  country?: string | null;
  phone?: string | null;
  email?: string | null;
  website?: string | null;
  currency_code?: string;
  timezone?: string;
}

export interface ReportRequest {
  report_type: string;
  date_from: string;
  date_to: string;
  category_id?: number;
  supplier_id?: number;
  product_id?: number;
  cashier_id?: number;
  customer_id?: number;
  payment_method_id?: number;
}

export interface ReportResponse {
  report_type: string;
  period: { date_from: string; date_to: string };
  rows: Record<string, unknown>[];
  summary: Record<string, unknown>;
}

export interface DashboardKPIs {
  today_sales_total: number;
  today_sales_count: number;
  today_returns_total: number;
  today_refunds: number;
  low_stock_count: number;
  out_of_stock_count: number;
  pending_credit_balance: number;
  active_users_count: number;
  total_products_active: number;
}

export interface DashboardSalesTrendItem {
  date: string;
  weekday: string;
  total_sales: number;
  sale_count: number;
}

export interface DashboardTopProduct {
  product_id: number;
  product_name: string;
  sku: string;
  qty_sold: number;
  revenue: number;
  share_pct: number;
}

export interface Receipt {
  receipt_id: number;
  sale_id: number;
  receipt_number: string;
  business_name: string;
  business_address: string | null;
  business_phone: string | null;
  business_email: string | null;
  cashier_name: string;
  sale_date: string;
  receipt_footer: string;
  items: SaleItem[];
  subtotal: number;
  tax_amount: number;
  discount_amount: number;
  total_amount: number;
  amount_received: number;
  change_amount: number;
  payments: Payment[];
  sale: Sale;
}
