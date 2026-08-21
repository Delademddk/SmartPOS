/* ==========================================================================
   SmartPOS Database - TEST SUITE 05: SCALAR FUNCTIONS
   --------------------------------------------------------------------------
   Covers the shared helpers in 17_Shared/functions.sql:
     FN_StockStatus, FN_CalculateLineTotal, FN_HashToken,
     FN_SmartPOS_Setting, FN_CurrencySymbol, FN_GetUserDisplayName,
     FN_HasPermission

   HARNESS
     - Pure-function assertions first (no writes); a transaction + rollback
       wraps the one settings-based test.
     - Success  -> PRINT N'Test PASSED: <name>'
     - Failure  -> THROW <code>, N'Test FAILED: <name>: <detail>', 1
   ========================================================================== */

SET NOCOUNT ON;

/* ---------------------------------------------------------------------------
   05.01 FN_StockStatus - classification boundaries
   ---------------------------------------------------------------------------*/
IF dbo.FN_StockStatus(0, 10)       <> N'OUT_OF_STOCK' THROW 65001, N'Test FAILED: 05.01 StockStatus qty=0 -> OUT_OF_STOCK.', 1;
IF dbo.FN_StockStatus(-5, 10)      <> N'OUT_OF_STOCK' THROW 65001, N'Test FAILED: 05.01 StockStatus qty<0 -> OUT_OF_STOCK.', 1;
IF dbo.FN_StockStatus(NULL, 10)    <> N'IN_STOCK'     THROW 65001, N'Test FAILED: 05.01 StockStatus NULL qty -> IN_STOCK (NULL comparisons are UNKNOWN).', 1;
IF dbo.FN_StockStatus(1, 10)       <> N'LOW_STOCK'    THROW 65001, N'Test FAILED: 05.01 StockStatus qty=1 -> LOW_STOCK.', 1;
IF dbo.FN_StockStatus(10, 10)      <> N'LOW_STOCK'    THROW 65001, N'Test FAILED: 05.01 StockStatus qty==threshold -> LOW_STOCK.', 1;
IF dbo.FN_StockStatus(11, 10)      <> N'IN_STOCK'     THROW 65001, N'Test FAILED: 05.01 StockStatus qty>threshold -> IN_STOCK.', 1;
IF dbo.FN_StockStatus(5, NULL)     <> N'IN_STOCK'     THROW 65001, N'Test FAILED: 05.01 StockStatus NULL threshold -> IN_STOCK.', 1;

/* ---------------------------------------------------------------------------
   05.02 FN_CalculateLineTotal - discount clamp, NULLs, rounding
   ---------------------------------------------------------------------------*/
-- 10 x 2 at 10% discount = 18.0000
IF dbo.FN_CalculateLineTotal(10.0000, 2, 0.1000) <> 18.0000
    THROW 65002, N'Test FAILED: 05.02 LineTotal 10*2*(1-0.1) <> 18.', 1;
-- discount clamped to 1.0
IF dbo.FN_CalculateLineTotal(10.0000, 2, 5.0000) <> 0.0000
    THROW 65002, N'Test FAILED: 05.02 LineTotal discount clamp to 1.0 -> 0.', 1;
-- negative discount clamped to 0
IF dbo.FN_CalculateLineTotal(10.0000, 2, -0.5000) <> 20.0000
    THROW 65002, N'Test FAILED: 05.02 LineTotal negative discount -> full price.', 1;
-- NULL-safe
IF dbo.FN_CalculateLineTotal(NULL, 2, NULL) <> 0.0000
    THROW 65002, N'Test FAILED: 05.02 LineTotal NULL price -> 0.', 1;
IF dbo.FN_CalculateLineTotal(7.7777, 3, 0) <> 23.3331
    THROW 65002, N'Test FAILED: 05.02 LineTotal rounding (7.7777*3=23.3331).', 1;
IF dbo.FN_CalculateLineTotal(100.0000, 1, NULL) <> 100.0000
    THROW 65002, N'Test FAILED: 05.02 LineTotal NULL discount -> full price.', 1;

/* ---------------------------------------------------------------------------
   05.03 FN_HashToken - 64-char hex, deterministic, sensitive to input
   ---------------------------------------------------------------------------*/
IF LEN(dbo.FN_HashToken(N'abc')) <> 64
    THROW 65003, N'Test FAILED: 05.03 HashToken must be 64 hex chars.', 1;
IF dbo.FN_HashToken(N'token-a') <> dbo.FN_HashToken(N'token-a')
    THROW 65003, N'Test FAILED: 05.03 HashToken not deterministic.', 1;
IF dbo.FN_HashToken(N'token-a') = dbo.FN_HashToken(N'token-b')
    THROW 65003, N'Test FAILED: 05.03 HashToken collision on different inputs.', 1;
IF dbo.FN_HashToken(NULL) <> dbo.FN_HashToken(N'')
    THROW 65003, N'Test FAILED: 05.03 HashToken NULL should hash empty string.', 1;
-- HashToken hashes NVARCHAR input (UTF-16LE bytes).
-- Known SHA2_256 of N'abc' = 13e228567e8249fce53337f25d7970de3bd68ab2653424c7b8f9fd05e33caedf
IF UPPER(dbo.FN_HashToken(N'abc')) <> N'13E228567E8249FCE53337F25D7970DE3BD68AB2653424C7B8F9FD05E33CAEDF'
    THROW 65003, N'Test FAILED: 05.03 HashToken does not match SHA-256 (UTF-16LE) reference.', 1;

/* ---------------------------------------------------------------------------
   05.04 FN_GetUserDisplayName - live user, unknown id, NULL
   ---------------------------------------------------------------------------*/
DECLARE @AdminID INT = (SELECT TOP (1) user_id FROM dbo.users WHERE username = N'admin');
IF dbo.FN_GetUserDisplayName(@AdminID) <> (SELECT full_name FROM dbo.users WHERE user_id = @AdminID)
    THROW 65004, N'Test FAILED: 05.04 GetUserDisplayName mismatch.', 1;
IF dbo.FN_GetUserDisplayName(-999999) IS NOT NULL
    THROW 65004, N'Test FAILED: 05.04 GetUserDisplayName unknown id should be NULL.', 1;
IF dbo.FN_GetUserDisplayName(NULL) IS NOT NULL
    THROW 65004, N'Test FAILED: 05.04 GetUserDisplayName NULL should be NULL.', 1;

/* ---------------------------------------------------------------------------
   05.05 FN_HasPermission - RBAC grant matrix
   ---------------------------------------------------------------------------*/
DECLARE @CashierID INT = (SELECT TOP (1) user_id FROM dbo.users WHERE username = N'cashier');
IF dbo.FN_HasPermission(@AdminID, N'products.view') <> 1
    THROW 65005, N'Test FAILED: 05.05 HasPermission admin/products.view -> 1.', 1;
IF dbo.FN_HasPermission(@AdminID, N'not.a.real.permission') <> 0
    THROW 65005, N'Test FAILED: 05.05 HasPermission admin/unknown code -> 0.', 1;
IF dbo.FN_HasPermission(@CashierID, N'users.manage') <> 0
    THROW 65005, N'Test FAILED: 05.05 HasPermission cashier/users.manage -> 0.', 1;
IF dbo.FN_HasPermission(NULL, N'products.view') <> 0
    THROW 65005, N'Test FAILED: 05.05 HasPermission NULL user -> 0.', 1;

/* ---------------------------------------------------------------------------
   05.06 FN_SmartPOS_Setting + FN_CurrencySymbol - default + override
   ---------------------------------------------------------------------------*/
-- Missing key returns the default.
IF dbo.FN_SmartPOS_Setting(N'no.such.key.xyz', N'fallback') <> N'fallback'
    THROW 65006, N'Test FAILED: 05.06 SmartPOS_Setting default fallback.', 1;
-- Default currency symbol is $.
IF dbo.FN_CurrencySymbol() <> N'$'
    THROW 65006, N'Test FAILED: 05.06 CurrencySymbol default should be $.', 1;

BEGIN TRANSACTION;
BEGIN TRY
    -- The key already exists in seed data; override its value inside the
    -- transaction so both functions must observe the new value.
    UPDATE dbo.settings SET setting_value = N'GHS' WHERE setting_key = N'currency_symbol';

    IF dbo.FN_SmartPOS_Setting(N'currency_symbol', N'$') <> N'GHS'
        THROW 65006, N'Test FAILED: 05.06 SmartPOS_Setting override not read.', 1;
    IF dbo.FN_CurrencySymbol() <> N'GHS'
        THROW 65006, N'Test FAILED: 05.06 CurrencySymbol override not applied.', 1;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW 65099, N'Test FAILED: 05_functions (05.06) - ' + ERROR_MESSAGE(), 1;
END CATCH;

IF XACT_STATE() <> 0
    ROLLBACK TRANSACTION;

PRINT N'Test PASSED: 05_functions_all';
