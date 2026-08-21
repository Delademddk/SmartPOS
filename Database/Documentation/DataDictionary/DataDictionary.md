# SmartPOS Database — Data Dictionary

**Version:** 1.0  
**Source of truth:** `Database/SQL/**/tables.sql`  

This data dictionary documents every table and column in the SmartPOS SQL Server database. It is generated from the authoritative schema definitions.

## Table Inventory

| # | Table | Module | Columns |
|---|-------|--------|---------|
| 1 | `permissions` | 01 Authentication | 10 |
| 2 | `role_permissions` | 01 Authentication | 5 |
| 3 | `roles` | 01 Authentication | 9 |
| 4 | `password_history` | 02 Users | 5 |
| 5 | `password_resets` | 02 Users | 7 |
| 6 | `user_sessions` | 02 Users | 10 |
| 7 | `users` | 02 Users | 20 |
| 8 | `business_information` | 03 Business | 19 |
| 9 | `currencies` | 03 Business | 9 |
| 10 | `tax_rates` | 03 Business | 8 |
| 11 | `categories` | 04 Categories | 12 |
| 12 | `product_images` | 05 Products | 7 |
| 13 | `products` | 05 Products | 19 |
| 14 | `supplier_contacts` | 06 Suppliers | 10 |
| 15 | `supplier_history` | 06 Suppliers | 5 |
| 16 | `suppliers` | 06 Suppliers | 19 |
| 17 | `inventory` | 07 Inventory | 8 |
| 18 | `inventory_transactions` | 07 Inventory | 11 |
| 19 | `low_stock_alerts` | 07 Inventory | 7 |
| 20 | `stock_reconciliations` | 07 Inventory | 9 |
| 21 | `sale_items` | 08 Sales | 11 |
| 22 | `sales` | 08 Sales | 14 |
| 23 | `payment_methods` | 09 Payments | 8 |
| 24 | `payments` | 09 Payments | 9 |
| 25 | `receipts` | 09 Payments | 11 |
| 26 | `credit_payments` | 10 Credit Sales | 7 |
| 27 | `credit_sales` | 10 Credit Sales | 9 |
| 28 | `customers` | 10 Credit Sales | 14 |
| 29 | `return_items` | 11 Returns | 8 |
| 30 | `return_reasons` | 11 Returns | 5 |
| 31 | `returns` | 11 Returns | 9 |
| 32 | `notification_history` | 12 Notifications | 6 |
| 33 | `notification_types` | 12 Notifications | 4 |
| 34 | `notifications` | 12 Notifications | 11 |
| 35 | `settings` | 15 Settings | 10 |
| 36 | `user_settings` | 15 Settings | 6 |
| 37 | `activity_logs` | 16 Audit | 9 |
| 38 | `audit_logs` | 16 Audit | 11 |
| 39 | `audit_logs_archive` | 16 Audit | 13 |
| 40 | `error_logs` | 16 Audit | 7 |
| 41 | `security_logs` | 16 Audit | 7 |

---

## `permissions`

**Module:** 01 Authentication  
**Description:** See Module Guide and `SQL/` schema.  

| Column | Data Type | PK | FK | Nullable |
|--------|-----------|----|----|----------|
| `permission_id` | `INT` |  | Y | Y |
| `permission_code` | `NVARCHAR(100)` |  |  | Y |
| `permission_name` | `NVARCHAR(150)` |  |  | Y |
| `module_name` | `NVARCHAR(100)` |  |  | Y |
| `is_system` | `BIT` |  |  | Y |
| `is_active` | `BIT` |  |  | Y |
| `created_at` | `DATETIME2(0)` |  |  | Y |
| `updated_at` | `DATETIME2(0)` |  |  | Y |
| `created_by` | `INT` |  |  | Y |
| `updated_by` | `INT` |  |  | Y |

## `role_permissions`

**Module:** 01 Authentication  
**Description:** See Module Guide and `SQL/` schema.  

| Column | Data Type | PK | FK | Nullable |
|--------|-----------|----|----|----------|
| `role_permission_id` | `INT` |  | Y | Y |
| `role_id` | `INT` |  | Y | Y |
| `permission_id` | `INT` |  | Y | Y |
| `granted_by` | `INT` |  |  | Y |
| `granted_at` | `DATETIME2(0)` |  |  | Y |

## `roles`

**Module:** 01 Authentication  
**Description:** See Module Guide and `SQL/` schema.  

| Column | Data Type | PK | FK | Nullable |
|--------|-----------|----|----|----------|
| `role_id` | `INT` |  | Y | Y |
| `role_code` | `NVARCHAR(50)` |  |  | Y |
| `role_name` | `NVARCHAR(100)` |  |  | Y |
| `is_system` | `BIT` |  |  | Y |
| `is_active` | `BIT` |  |  | Y |
| `created_at` | `DATETIME2(0)` |  |  | Y |
| `updated_at` | `DATETIME2(0)` |  |  | Y |
| `created_by` | `INT` |  |  | Y |
| `updated_by` | `INT` |  |  | Y |

## `password_history`

**Module:** 02 Users  
**Description:** See Module Guide and `SQL/` schema.  

| Column | Data Type | PK | FK | Nullable |
|--------|-----------|----|----|----------|
| `history_id` | `INT` |  | Y | Y |
| `user_id` | `INT` |  | Y | Y |
| `password_hash` | `NVARCHAR(255)` |  |  | Y |
| `changed_at` | `DATETIME2(0)` |  |  | Y |
| `changed_by` | `INT` |  |  | Y |

## `password_resets`

**Module:** 02 Users  
**Description:** See Module Guide and `SQL/` schema.  

| Column | Data Type | PK | FK | Nullable |
|--------|-----------|----|----|----------|
| `reset_id` | `INT` |  | Y | Y |
| `user_id` | `INT` |  | Y | Y |
| `reset_token` | `NVARCHAR(255)` |  |  | Y |
| `ip_address` | `NVARCHAR(45)` |  |  | Y |
| `requested_at` | `DATETIME2(0)` |  |  | Y |
| `expires_at` | `DATETIME2(0)` |  |  | Y |
| `used_at` | `DATETIME2(0)` |  |  | Y |

## `user_sessions`

**Module:** 02 Users  
**Description:** See Module Guide and `SQL/` schema.  

| Column | Data Type | PK | FK | Nullable |
|--------|-----------|----|----|----------|
| `session_id` | `INT` |  | Y | Y |
| `user_id` | `INT` |  | Y | Y |
| `session_token` | `NVARCHAR(255)` |  |  | Y |
| `ip_address` | `NVARCHAR(45)` |  |  | Y |
| `user_agent` | `NVARCHAR(255)` |  |  | Y |
| `issued_at` | `DATETIME2(0)` |  |  | Y |
| `expires_at` | `DATETIME2(0)` |  |  | Y |
| `is_revoked` | `BIT` |  |  | Y |
| `revoked_at` | `DATETIME2(0)` |  |  | Y |
| `revoked_by` | `INT` |  |  | Y |

## `users`

**Module:** 02 Users  
**Description:** See Module Guide and `SQL/` schema.  

| Column | Data Type | PK | FK | Nullable |
|--------|-----------|----|----|----------|
| `user_id` | `INT` |  | Y | Y |
| `username` | `NVARCHAR(50)` |  |  | Y |
| `email` | `NVARCHAR(255)` |  |  | Y |
| `password_hash` | `NVARCHAR(255)` |  |  | Y |
| `full_name` | `NVARCHAR(150)` |  |  | Y |
| `phone` | `NVARCHAR(30)` |  |  | Y |
| `role_id` | `INT` |  | Y | Y |
| `is_active` | `BIT` |  |  | Y |
| `is_locked` | `BIT` |  |  | Y |
| `failed_login_attempts` | `TINYINT` |  |  | Y |
| `must_change_password` | `BIT` |  |  | Y |
| `last_login_at` | `DATETIME2(0)` |  |  | Y |
| `last_login_ip` | `NVARCHAR(45)` |  |  | Y |
| `is_deleted` | `BIT` |  |  | Y |
| `deleted_at` | `DATETIME2(0)` |  |  | Y |
| `deleted_by` | `INT` |  |  | Y |
| `created_at` | `DATETIME2(0)` |  |  | Y |
| `updated_at` | `DATETIME2(0)` |  |  | Y |
| `created_by` | `INT` |  |  | Y |
| `updated_by` | `INT` |  |  | Y |

## `business_information`

**Module:** 03 Business  
**Description:** See Module Guide and `SQL/` schema.  

| Column | Data Type | PK | FK | Nullable |
|--------|-----------|----|----|----------|
| `business_info_id` | `INT` |  | Y | Y |
| `business_name` | `NVARCHAR(150)` |  |  | Y |
| `legal_name` | `NVARCHAR(150)` |  |  | Y |
| `tax_id` | `NVARCHAR(50)` |  | Y | Y |
| `address_line1` | `NVARCHAR(255)` |  |  | Y |
| `address_line2` | `NVARCHAR(255)` |  |  | Y |
| `city` | `NVARCHAR(100)` |  |  | Y |
| `postal_code` | `NVARCHAR(20)` |  |  | Y |
| `country` | `NVARCHAR(100)` |  |  | Y |
| `phone` | `NVARCHAR(30)` |  |  | Y |
| `email` | `NVARCHAR(255)` |  |  | Y |
| `website` | `NVARCHAR(255)` |  |  | Y |
| `currency_code` | `NVARCHAR(3)` |  |  | Y |
| `timezone` | `NVARCHAR(100)` |  |  | Y |
| `is_active` | `BIT` |  |  | Y |
| `created_at` | `DATETIME2(0)` |  |  | Y |
| `updated_at` | `DATETIME2(0)` |  |  | Y |
| `created_by` | `INT` |  |  | Y |
| `updated_by` | `INT` |  |  | Y |

## `currencies`

**Module:** 03 Business  
**Description:** See Module Guide and `SQL/` schema.  

| Column | Data Type | PK | FK | Nullable |
|--------|-----------|----|----|----------|
| `currency_id` | `INT` |  | Y | Y |
| `currency_code` | `NVARCHAR(3)` |  |  | Y |
| `currency_name` | `NVARCHAR(100)` |  |  | Y |
| `symbol` | `NVARCHAR(10)` |  |  | Y |
| `decimal_places` | `TINYINT` |  |  | Y |
| `is_base` | `BIT` |  |  | Y |
| `is_active` | `BIT` |  |  | Y |
| `created_at` | `DATETIME2(0)` |  |  | Y |
| `updated_at` | `DATETIME2(0)` |  |  | Y |

## `tax_rates`

**Module:** 03 Business  
**Description:** See Module Guide and `SQL/` schema.  

| Column | Data Type | PK | FK | Nullable |
|--------|-----------|----|----|----------|
| `tax_rate_id` | `INT` |  | Y | Y |
| `tax_name` | `NVARCHAR(100)` |  |  | Y |
| `tax_code` | `NVARCHAR(20)` |  |  | Y |
| `rate_percent` | `DECIMAL(7,4)` |  |  | Y |
| `is_default` | `BIT` |  |  | Y |
| `is_active` | `BIT` |  |  | Y |
| `created_at` | `DATETIME2(0)` |  |  | Y |
| `updated_at` | `DATETIME2(0)` |  |  | Y |

## `categories`

**Module:** 04 Categories  
**Description:** See Module Guide and `SQL/` schema.  

| Column | Data Type | PK | FK | Nullable |
|--------|-----------|----|----|----------|
| `category_id` | `INT` |  | Y | Y |
| `category_name` | `NVARCHAR(100)` |  |  | Y |
| `parent_id` | `INT` |  | Y | Y |
| `sort_order` | `INT` |  |  | Y |
| `is_active` | `BIT` |  |  | Y |
| `is_deleted` | `BIT` |  |  | Y |
| `deleted_at` | `DATETIME2(0)` |  |  | Y |
| `deleted_by` | `INT` |  |  | Y |
| `created_at` | `DATETIME2(0)` |  |  | Y |
| `updated_at` | `DATETIME2(0)` |  |  | Y |
| `created_by` | `INT` |  |  | Y |
| `updated_by` | `INT` |  |  | Y |

## `product_images`

**Module:** 05 Products  
**Description:** See Module Guide and `SQL/` schema.  

| Column | Data Type | PK | FK | Nullable |
|--------|-----------|----|----|----------|
| `image_id` | `INT` |  | Y | Y |
| `product_id` | `INT` |  | Y | Y |
| `image_url` | `NVARCHAR(500)` |  |  | Y |
| `image_alt` | `NVARCHAR(200)` |  |  | Y |
| `is_primary` | `BIT` |  |  | Y |
| `sort_order` | `INT` |  |  | Y |
| `created_at` | `DATETIME2(0)` |  |  | Y |

## `products`

**Module:** 05 Products  
**Description:** See Module Guide and `SQL/` schema.  

| Column | Data Type | PK | FK | Nullable |
|--------|-----------|----|----|----------|
| `product_id` | `INT` |  | Y | Y |
| `sku` | `NVARCHAR(50)` |  |  | Y |
| `barcode` | `NVARCHAR(50)` |  |  | Y |
| `product_name` | `NVARCHAR(200)` |  |  | Y |
| `category_id` | `INT` |  | Y | Y |
| `supplier_id` | `INT` |  | Y | Y |
| `unit` | `NVARCHAR(20)` |  |  | Y |
| `unit_price` | `DECIMAL(19,4)` |  |  | Y |
| `cost_price` | `DECIMAL(19,4)` |  |  | Y |
| `image_url` | `NVARCHAR(500)` |  |  | Y |
| `low_stock_threshold` | `INT` |  |  | Y |
| `is_service` | `BIT` |  |  | Y |
| `is_active` | `BIT` |  |  | Y |
| `is_deleted` | `BIT` |  |  | Y |
| `deleted_at` | `DATETIME2(0)` |  |  | Y |
| `deleted_by` | `INT` |  |  | Y |
| `created_at` | `DATETIME2(0)` |  |  | Y |
| `updated_at` | `DATETIME2(0)` |  |  | Y |
| `created_by` | `INT` |  |  | Y |
| `updated_by` | `INT` |  |  | Y |

## `supplier_contacts`

**Module:** 06 Suppliers  
**Description:** See Module Guide and `SQL/` schema.  

| Column | Data Type | PK | FK | Nullable |
|--------|-----------|----|----|----------|
| `contact_id` | `INT` |  | Y | Y |
| `supplier_id` | `INT` |  | Y | Y |
| `full_name` | `NVARCHAR(150)` |  |  | Y |
| `job_title` | `NVARCHAR(100)` |  |  | Y |
| `email` | `NVARCHAR(255)` |  |  | Y |
| `phone` | `NVARCHAR(30)` |  |  | Y |
| `is_primary` | `BIT` |  |  | Y |
| `is_active` | `BIT` |  |  | Y |
| `created_at` | `DATETIME2(0)` |  |  | Y |
| `updated_at` | `DATETIME2(0)` |  |  | Y |

## `supplier_history`

**Module:** 06 Suppliers  
**Description:** See Module Guide and `SQL/` schema.  

| Column | Data Type | PK | FK | Nullable |
|--------|-----------|----|----|----------|
| `history_id` | `INT` |  | Y | Y |
| `supplier_id` | `INT` |  | Y | Y |
| `history_type` | `NVARCHAR(50)` |  |  | Y |
| `changed_by` | `INT` |  |  | Y |
| `changed_at` | `DATETIME2(0)` |  |  | Y |

## `suppliers`

**Module:** 06 Suppliers  
**Description:** See Module Guide and `SQL/` schema.  

| Column | Data Type | PK | FK | Nullable |
|--------|-----------|----|----|----------|
| `supplier_id` | `INT` |  | Y | Y |
| `supplier_code` | `NVARCHAR(30)` |  |  | Y |
| `supplier_name` | `NVARCHAR(150)` |  |  | Y |
| `contact_person` | `NVARCHAR(150)` |  |  | Y |
| `email` | `NVARCHAR(255)` |  |  | Y |
| `phone` | `NVARCHAR(30)` |  |  | Y |
| `address_line1` | `NVARCHAR(255)` |  |  | Y |
| `address_line2` | `NVARCHAR(255)` |  |  | Y |
| `city` | `NVARCHAR(100)` |  |  | Y |
| `postal_code` | `NVARCHAR(20)` |  |  | Y |
| `country` | `NVARCHAR(100)` |  |  | Y |
| `is_active` | `BIT` |  |  | Y |
| `is_deleted` | `BIT` |  |  | Y |
| `deleted_at` | `DATETIME2(0)` |  |  | Y |
| `deleted_by` | `INT` |  |  | Y |
| `created_at` | `DATETIME2(0)` |  |  | Y |
| `updated_at` | `DATETIME2(0)` |  |  | Y |
| `created_by` | `INT` |  |  | Y |
| `updated_by` | `INT` |  |  | Y |

## `inventory`

**Module:** 07 Inventory  
**Description:** See Module Guide and `SQL/` schema.  

| Column | Data Type | PK | FK | Nullable |
|--------|-----------|----|----|----------|
| `inventory_id` | `INT` |  | Y | Y |
| `product_id` | `INT` |  | Y | Y |
| `quantity_on_hand` | `INT` |  |  | Y |
| `quantity_reserved` | `INT` |  |  | Y |
| `reorder_level` | `INT` |  |  | Y |
| `last_restocked_at` | `DATETIME2(0)` |  |  | Y |
| `last_sold_at` | `DATETIME2(0)` |  |  | Y |
| `updated_at` | `DATETIME2(0)` |  |  | Y |

## `inventory_transactions`

**Module:** 07 Inventory  
**Description:** See Module Guide and `SQL/` schema.  

| Column | Data Type | PK | FK | Nullable |
|--------|-----------|----|----|----------|
| `transaction_id` | `INT` |  | Y | Y |
| `product_id` | `INT` |  | Y | Y |
| `movement_type` | `NVARCHAR(30)` |  |  | Y |
| `quantity` | `INT` |  |  | Y |
| `quantity_before` | `INT` |  |  | Y |
| `quantity_after` | `INT` |  |  | Y |
| `unit_cost` | `DECIMAL(19,4)` |  |  | Y |
| `reference_type` | `NVARCHAR(50)` |  |  | Y |
| `reference_id` | `NVARCHAR(100)` |  | Y | Y |
| `user_id` | `INT` |  | Y | Y |
| `created_at` | `DATETIME2(0)` |  |  | Y |

## `low_stock_alerts`

**Module:** 07 Inventory  
**Description:** See Module Guide and `SQL/` schema.  

| Column | Data Type | PK | FK | Nullable |
|--------|-----------|----|----|----------|
| `alert_id` | `INT` |  | Y | Y |
| `product_id` | `INT` |  | Y | Y |
| `quantity_on_hand` | `INT` |  |  | Y |
| `low_stock_threshold` | `INT` |  |  | Y |
| `status` | `NVARCHAR(20)` |  |  | Y |
| `raised_at` | `DATETIME2(0)` |  |  | Y |
| `resolved_at` | `DATETIME2(0)` |  |  | Y |

## `stock_reconciliations`

**Module:** 07 Inventory  
**Description:** See Module Guide and `SQL/` schema.  

| Column | Data Type | PK | FK | Nullable |
|--------|-----------|----|----|----------|
| `reconciliation_id` | `INT` |  | Y | Y |
| `product_id` | `INT` |  | Y | Y |
| `system_quantity` | `INT` |  |  | Y |
| `counted_quantity` | `INT` |  |  | Y |
| `difference` | `INT` |  |  | Y |
| `adjustment_type` | `NVARCHAR(30)` |  |  | Y |
| `user_id` | `INT` |  | Y | Y |
| `transaction_id` | `INT` |  | Y | Y |
| `reconciled_at` | `DATETIME2(0)` |  |  | Y |

## `sale_items`

**Module:** 08 Sales  
**Description:** See Module Guide and `SQL/` schema.  

| Column | Data Type | PK | FK | Nullable |
|--------|-----------|----|----|----------|
| `sale_item_id` | `INT` |  | Y | Y |
| `sale_id` | `INT` |  | Y | Y |
| `product_id` | `INT` |  | Y | Y |
| `quantity` | `DECIMAL(12,3)` |  |  | Y |
| `unit_price` | `DECIMAL(19,4)` |  |  | Y |
| `discount_rate` | `DECIMAL(5,4)` |  |  | Y |
| `tax_amount` | `DECIMAL(19,4)` |  |  | Y |
| `line_total` | `DECIMAL(19,4)` |  |  | Y |
| `is_returned` | `BIT` |  |  | Y |
| `returned_qty` | `DECIMAL(12,3)` |  |  | Y |
| `created_at` | `DATETIME2(0)` |  |  | Y |

## `sales`

**Module:** 08 Sales  
**Description:** See Module Guide and `SQL/` schema.  

| Column | Data Type | PK | FK | Nullable |
|--------|-----------|----|----|----------|
| `sale_id` | `INT` |  | Y | Y |
| `receipt_number` | `NVARCHAR(50)` |  |  | Y |
| `sale_date` | `DATETIME2(0)` |  |  | Y |
| `user_id` | `INT` |  | Y | Y |
| `customer_id` | `INT` |  | Y | Y |
| `tax_rate_id` | `INT` |  | Y | Y |
| `sale_type` | `NVARCHAR(20)` |  |  | Y |
| `subtotal` | `DECIMAL(19,4)` |  |  | Y |
| `discount_amount` | `DECIMAL(19,4)` |  |  | Y |
| `tax_amount` | `DECIMAL(19,4)` |  |  | Y |
| `total_amount` | `DECIMAL(19,4)` |  |  | Y |
| `amount_received` | `DECIMAL(19,4)` |  |  | Y |
| `created_at` | `DATETIME2(0)` |  |  | Y |
| `updated_at` | `DATETIME2(0)` |  |  | Y |

## `payment_methods`

**Module:** 09 Payments  
**Description:** See Module Guide and `SQL/` schema.  

| Column | Data Type | PK | FK | Nullable |
|--------|-----------|----|----|----------|
| `payment_method_id` | `INT` |  | Y | Y |
| `method_code` | `NVARCHAR(30)` |  |  | Y |
| `method_name` | `NVARCHAR(100)` |  |  | Y |
| `is_cash` | `BIT` |  |  | Y |
| `is_active` | `BIT` |  |  | Y |
| `sort_order` | `INT` |  |  | Y |
| `created_at` | `DATETIME2(0)` |  |  | Y |
| `updated_at` | `DATETIME2(0)` |  |  | Y |

## `payments`

**Module:** 09 Payments  
**Description:** See Module Guide and `SQL/` schema.  

| Column | Data Type | PK | FK | Nullable |
|--------|-----------|----|----|----------|
| `payment_id` | `INT` |  | Y | Y |
| `sale_id` | `INT` |  | Y | Y |
| `payment_method_id` | `INT` |  | Y | Y |
| `amount` | `DECIMAL(19,4)` |  |  | Y |
| `reference_number` | `NVARCHAR(100)` |  |  | Y |
| `received_at` | `DATETIME2(0)` |  |  | Y |
| `received_by` | `INT` |  |  | Y |
| `pay_status` | `NVARCHAR(20)` |  |  | Y |
| `created_at` | `DATETIME2(0)` |  |  | Y |

## `receipts`

**Module:** 09 Payments  
**Description:** See Module Guide and `SQL/` schema.  

| Column | Data Type | PK | FK | Nullable |
|--------|-----------|----|----|----------|
| `receipt_id` | `INT` |  | Y | Y |
| `receipt_number` | `NVARCHAR(50)` |  |  | Y |
| `sale_id` | `INT` |  | Y | Y |
| `gross_total` | `DECIMAL(19,4)` |  |  | Y |
| `discount_amount` | `DECIMAL(19,4)` |  |  | Y |
| `tax_amount` | `DECIMAL(19,4)` |  |  | Y |
| `net_total` | `DECIMAL(19,4)` |  |  | Y |
| `amount_paid` | `DECIMAL(19,4)` |  |  | Y |
| `change_due` | `DECIMAL(19,4)` |  |  | Y |
| `generated_by` | `INT` |  |  | Y |
| `generated_at` | `DATETIME2(0)` |  |  | Y |

## `credit_payments`

**Module:** 10 Credit Sales  
**Description:** See Module Guide and `SQL/` schema.  

| Column | Data Type | PK | FK | Nullable |
|--------|-----------|----|----|----------|
| `credit_payment_id` | `INT` |  | Y | Y |
| `credit_sale_id` | `INT` |  | Y | Y |
| `payment_id` | `INT` |  | Y | Y |
| `amount` | `DECIMAL(19,4)` |  |  | Y |
| `payment_date` | `DATETIME2(0)` |  |  | Y |
| `received_by` | `INT` |  |  | Y |
| `created_at` | `DATETIME2(0)` |  |  | Y |

## `credit_sales`

**Module:** 10 Credit Sales  
**Description:** See Module Guide and `SQL/` schema.  

| Column | Data Type | PK | FK | Nullable |
|--------|-----------|----|----|----------|
| `credit_sale_id` | `INT` |  | Y | Y |
| `sale_id` | `INT` |  | Y | Y |
| `customer_id` | `INT` |  | Y | Y |
| `total_amount` | `DECIMAL(19,4)` |  |  | Y |
| `amount_paid` | `DECIMAL(19,4)` |  |  | Y |
| `outstanding_balance` | `DECIMAL(19,4)` |  |  | Y |
| `due_date` | `DATE` |  |  | Y |
| `created_at` | `DATETIME2(0)` |  |  | Y |
| `updated_at` | `DATETIME2(0)` |  |  | Y |

## `customers`

**Module:** 10 Credit Sales  
**Description:** See Module Guide and `SQL/` schema.  

| Column | Data Type | PK | FK | Nullable |
|--------|-----------|----|----|----------|
| `customer_id` | `INT` |  | Y | Y |
| `customer_code` | `NVARCHAR(30)` |  |  | Y |
| `full_name` | `NVARCHAR(150)` |  |  | Y |
| `phone` | `NVARCHAR(30)` |  |  | Y |
| `email` | `NVARCHAR(255)` |  |  | Y |
| `address` | `NVARCHAR(255)` |  |  | Y |
| `credit_limit` | `DECIMAL(19,4)` |  |  | Y |
| `is_active` | `BIT` |  |  | Y |
| `is_deleted` | `BIT` |  |  | Y |
| `deleted_at` | `DATETIME2(0)` |  |  | Y |
| `created_at` | `DATETIME2(0)` |  |  | Y |
| `updated_at` | `DATETIME2(0)` |  |  | Y |
| `created_by` | `INT` |  |  | Y |
| `updated_by` | `INT` |  |  | Y |

## `return_items`

**Module:** 11 Returns  
**Description:** See Module Guide and `SQL/` schema.  

| Column | Data Type | PK | FK | Nullable |
|--------|-----------|----|----|----------|
| `return_item_id` | `INT` |  | Y | Y |
| `return_id` | `INT` |  | Y | Y |
| `sale_item_id` | `INT` |  | Y | Y |
| `product_id` | `INT` |  | Y | Y |
| `quantity` | `DECIMAL(12,3)` |  |  | Y |
| `unit_price` | `DECIMAL(19,4)` |  |  | Y |
| `refund_amount` | `DECIMAL(19,4)` |  |  | Y |
| `created_at` | `DATETIME2(0)` |  |  | Y |

## `return_reasons`

**Module:** 11 Returns  
**Description:** See Module Guide and `SQL/` schema.  

| Column | Data Type | PK | FK | Nullable |
|--------|-----------|----|----|----------|
| `return_reason_id` | `INT` |  | Y | Y |
| `reason_code` | `NVARCHAR(30)` |  |  | Y |
| `reason_name` | `NVARCHAR(100)` |  |  | Y |
| `is_active` | `BIT` |  |  | Y |
| `created_at` | `DATETIME2(0)` |  |  | Y |

## `returns`

**Module:** 11 Returns  
**Description:** See Module Guide and `SQL/` schema.  

| Column | Data Type | PK | FK | Nullable |
|--------|-----------|----|----|----------|
| `return_id` | `INT` |  | Y | Y |
| `return_number` | `NVARCHAR(50)` |  |  | Y |
| `sale_id` | `INT` |  | Y | Y |
| `customer_id` | `INT` |  | Y | Y |
| `user_id` | `INT` |  | Y | Y |
| `return_reason_id` | `INT` |  | Y | Y |
| `total_refund_amount` | `DECIMAL(19,4)` |  |  | Y |
| `created_at` | `DATETIME2(0)` |  |  | Y |
| `updated_at` | `DATETIME2(0)` |  |  | Y |

## `notification_history`

**Module:** 12 Notifications  
**Description:** See Module Guide and `SQL/` schema.  

| Column | Data Type | PK | FK | Nullable |
|--------|-----------|----|----|----------|
| `history_id` | `INT IDENTITY(1,1)` | Y |  | N |
| `notification_id` | `INT` |  | Y | Y |
| `user_id` | `INT` |  | Y | Y |
| `notification_type_id` | `INT` |  | Y | Y |
| `title` | `NVARCHAR(200)` |  |  | Y |
| `delivered_at` | `DATETIME2(0)` |  |  | Y |

## `notification_types`

**Module:** 12 Notifications  
**Description:** See Module Guide and `SQL/` schema.  

| Column | Data Type | PK | FK | Nullable |
|--------|-----------|----|----|----------|
| `notification_type_id` | `INT` |  | Y | Y |
| `type_code` | `NVARCHAR(50)` |  |  | Y |
| `type_name` | `NVARCHAR(100)` |  |  | Y |
| `is_active` | `BIT` |  |  | Y |

## `notifications`

**Module:** 12 Notifications  
**Description:** See Module Guide and `SQL/` schema.  

| Column | Data Type | PK | FK | Nullable |
|--------|-----------|----|----|----------|
| `notification_id` | `INT` |  | Y | Y |
| `user_id` | `INT` |  | Y | Y |
| `notification_type_id` | `INT` |  | Y | Y |
| `title` | `NVARCHAR(150)` |  |  | Y |
| `severity` | `NVARCHAR(20)` |  |  | Y |
| `entity_type` | `NVARCHAR(100)` |  |  | Y |
| `entity_id` | `NVARCHAR(100)` |  | Y | Y |
| `is_read` | `BIT` |  |  | Y |
| `read_at` | `DATETIME2(0)` |  |  | Y |
| `is_dismissed` | `BIT` |  |  | Y |
| `created_at` | `DATETIME2(0)` |  |  | Y |

## `settings`

**Module:** 15 Settings  
**Description:** See Module Guide and `SQL/` schema.  

| Column | Data Type | PK | FK | Nullable |
|--------|-----------|----|----|----------|
| `setting_id` | `INT` |  | Y | Y |
| `setting_key` | `NVARCHAR(100)` |  |  | Y |
| `setting_value` | `NVARCHAR(MAX)` |  |  | Y |
| `data_type` | `NVARCHAR(20)` |  |  | Y |
| `category` | `NVARCHAR(50)` |  |  | Y |
| `is_active` | `BIT` |  |  | Y |
| `created_at` | `DATETIME2(0)` |  |  | Y |
| `updated_at` | `DATETIME2(0)` |  |  | Y |
| `created_by` | `INT` |  |  | Y |
| `updated_by` | `INT` |  |  | Y |

## `user_settings`

**Module:** 15 Settings  
**Description:** See Module Guide and `SQL/` schema.  

| Column | Data Type | PK | FK | Nullable |
|--------|-----------|----|----|----------|
| `user_setting_id` | `INT` |  | Y | Y |
| `user_id` | `INT` |  | Y | Y |
| `setting_key` | `NVARCHAR(100)` |  |  | Y |
| `setting_value` | `NVARCHAR(MAX)` |  |  | Y |
| `created_at` | `DATETIME2(0)` |  |  | Y |
| `updated_at` | `DATETIME2(0)` |  |  | Y |

## `activity_logs`

**Module:** 16 Audit  
**Description:** See Module Guide and `SQL/` schema.  

| Column | Data Type | PK | FK | Nullable |
|--------|-----------|----|----|----------|
| `activity_id` | `INT` |  | Y | Y |
| `user_id` | `INT` |  | Y | Y |
| `activity_type` | `NVARCHAR(100)` |  |  | Y |
| `activity_desc` | `NVARCHAR(255)` |  |  | Y |
| `entity_type` | `NVARCHAR(100)` |  |  | Y |
| `entity_id` | `NVARCHAR(100)` |  | Y | Y |
| `ip_address` | `NVARCHAR(45)` |  |  | Y |
| `user_agent` | `NVARCHAR(255)` |  |  | Y |
| `created_at` | `DATETIME2(0)` |  |  | Y |

## `audit_logs`

**Module:** 16 Audit  
**Description:** See Module Guide and `SQL/` schema.  

| Column | Data Type | PK | FK | Nullable |
|--------|-----------|----|----|----------|
| `log_id` | `INT` |  | Y | Y |
| `user_id` | `INT` |  | Y | Y |
| `action_type` | `NVARCHAR(50)` |  |  | Y |
| `resource_type` | `NVARCHAR(100)` |  |  | Y |
| `resource_id` | `NVARCHAR(100)` |  | Y | Y |
| `old_values` | `NVARCHAR(MAX)` |  |  | Y |
| `new_values` | `NVARCHAR(MAX)` |  |  | Y |
| `ip_address` | `NVARCHAR(45)` |  |  | Y |
| `user_agent` | `NVARCHAR(255)` |  |  | Y |
| `details` | `NVARCHAR(MAX)` |  |  | Y |
| `created_at` | `DATETIME2(0)` |  |  | Y |

## `audit_logs_archive`

**Module:** 16 Audit  
**Description:** See Module Guide and `SQL/` schema.  

| Column | Data Type | PK | FK | Nullable |
|--------|-----------|----|----|----------|
| `archive_id` | `INT` |  | Y | Y |
| `log_id` | `INT` |  | Y | Y |
| `user_id` | `INT` |  | Y | Y |
| `action_type` | `NVARCHAR(50)` |  |  | Y |
| `resource_type` | `NVARCHAR(100)` |  |  | Y |
| `resource_id` | `NVARCHAR(100)` |  | Y | Y |
| `old_values` | `NVARCHAR(MAX)` |  |  | Y |
| `new_values` | `NVARCHAR(MAX)` |  |  | Y |
| `ip_address` | `NVARCHAR(45)` |  |  | Y |
| `user_agent` | `NVARCHAR(255)` |  |  | Y |
| `details` | `NVARCHAR(MAX)` |  |  | Y |
| `created_at` | `DATETIME2(0)` |  |  | Y |
| `archived_at` | `DATETIME2(0)` |  |  | Y |

## `error_logs`

**Module:** 16 Audit  
**Description:** See Module Guide and `SQL/` schema.  

| Column | Data Type | PK | FK | Nullable |
|--------|-----------|----|----|----------|
| `error_id` | `INT` |  | Y | Y |
| `user_id` | `INT` |  | Y | Y |
| `error_code` | `NVARCHAR(50)` |  |  | Y |
| `stack_trace` | `NVARCHAR(MAX)` |  |  | Y |
| `http_status` | `INT` |  |  | Y |
| `ip_address` | `NVARCHAR(45)` |  |  | Y |
| `occurred_at` | `DATETIME2(0)` |  |  | Y |

## `security_logs`

**Module:** 16 Audit  
**Description:** See Module Guide and `SQL/` schema.  

| Column | Data Type | PK | FK | Nullable |
|--------|-----------|----|----|----------|
| `security_log_id` | `INT` |  | Y | Y |
| `user_id` | `INT` |  | Y | Y |
| `event_type` | `NVARCHAR(50)` |  |  | Y |
| `username` | `NVARCHAR(50)` |  |  | Y |
| `ip_address` | `NVARCHAR(45)` |  |  | Y |
| `user_agent` | `NVARCHAR(255)` |  |  | Y |
| `created_at` | `DATETIME2(0)` |  |  | Y |
