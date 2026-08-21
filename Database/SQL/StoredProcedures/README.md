# SmartPOS Database — Stored Procedures

The business logic is implemented as stored procedures, one file per module
under `SQL/<module>/`. Each file contains real, complete implementations with
structured `TRY...CATCH` and transaction handling.

## Module → Procedure Map

| Module | Procedures |
|--------|-----------|
| 01 Authentication | `SP_GetRoles`, `SP_GetRole`, `SP_CreateRole`, `SP_UpdateRole`, `SP_DeleteRole`, `SP_GetPermissions`, `SP_Login`, `SP_Logout`, `SP_ValidateSession` |
| 02 Users | `SP_GetUsers`, `SP_GetUser`, `SP_CreateUser`, `SP_UpdateUser`, `SP_DeactivateUser`, `SP_ResetPassword`, `SP_ChangePassword`, `SP_RequestPasswordReset`, `SP_CompletePasswordReset` |
| 03 Business | `SP_GetBusinessInformation`, `SP_UpsertBusinessInformation`, `SP_GetCurrencies`, `SP_CreateCurrency`, `SP_UpdateCurrency`, `SP_SetBaseCurrency`, `SP_GetTaxRates`, `SP_CreateTaxRate`, `SP_UpdateTaxRate`, `SP_DeactivateTaxRate` |
| 04 Categories | `SP_GetCategories`, `SP_GetCategoryTree`, `SP_CreateCategory`, `SP_UpdateCategory`, `SP_DeleteCategory`, `SP_GetCategory` |
| 05 Products | `SP_GetProducts`, `SP_GetProduct`, `SP_CreateProduct`, `SP_UpdateProduct`, `SP_DeleteProduct`, `SP_RestoreProduct`, `SP_GetProductByBarcode`, `SP_GetProductBySKU`, `SP_SearchProducts`, `SP_GetProductImages`, `SP_AddProductImage`, `SP_DeleteProductImage` |
| 06 Suppliers | `SP_GetSuppliers`, `SP_GetSupplier`, `SP_CreateSupplier`, `SP_UpdateSupplier`, `SP_DeleteSupplier`, `SP_GetSupplierContacts`, `SP_AddSupplierContact`, `SP_UpdateSupplierContact`, `SP_DeleteSupplierContact`, `SP_LogSupplierHistory` |
| 07 Inventory | `SP_GetStockLevel`, `SP_RestockProduct`, `SP_AdjustStock` |
| 08 Sales | `SP_CreateSale` |
| 09 Payments | `SP_GetPaymentMethods`, `SP_CreatePaymentMethod`, `SP_UpdatePaymentMethod`, `SP_GetSalePayments`, `SP_GetPayment`, `SP_RecordPayment`, `SP_GetReceipt`, `SP_GetReceiptBySale`, `SP_GenerateReceipt` |
| 11 Returns | `SP_ProcessReturn` |
| 12 Notifications | `SP_GetNotifications`, `SP_GetUnreadCount`, `SP_MarkNotificationRead`, `SP_DismissNotification`, `SP_CreateNotification`, `SP_GetNotificationTypes`, `SP_ResetNotifications` |
| 13 Reports | `SP_SalesReport`, `SP_InventoryReport`, `SP_InventoryMovementsReport`, `SP_SupplierReport`, `SP_CreditReport`, `SP_ReturnsReport`, `SP_ProfitReport`, `SP_TaxReport`, `SP_PaymentMethodsReport`, `SP_ProductSalesReport`, `SP_ExportReport` |
| 14 Dashboard | `SP_GetDashboardMetrics`, `SP_GetDashboardData`, `SP_GetSalesByCategory`, `SP_GetTopProducts`, `SP_GetSalesTrend` |
| 15 Settings | `SP_GetSettings`, `SP_GetSetting`, `SP_UpsertSetting`, `SP_DeleteSetting`, `SP_GetUserSettings`, `SP_UpsertUserSetting` |
| 16 Audit | `SP_GetAuditLogs`, `SP_GetSecurityLogs`, `SP_GetErrorLogs`, `SP_ArchiveAuditLogs` |

## Conventions

- Every procedure is prefixed `SP_`.
- Multi-table writes run inside a transaction with `TRY...CATCH`; errors are
  logged to `dbo.error_logs` before re-throwing.
- Passwords and tokens are always received already-hashed; procedures never
  generate or store plaintext secrets.
- Pagination uses `OFFSET/FETCH` and returns a `TotalCount`.
- Procedures are idempotent (each drops and recreates itself).