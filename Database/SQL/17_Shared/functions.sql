/* ==========================================================================
   SmartPOS Database - MODULE 17: SHARED COMPONENTS
   --------------------------------------------------------------------------
   Common, reusable scalar functions + helper utilities consumed throughout
   the schema and stored procedures. These MUST be created before procedures
   and triggers that reference them.

   Dependencies: none (pure functions).
   ========================================================================== */

-- --------------------------------------------------------------------------
-- FN_SmartPOS_Setting: read an application setting with a fallback default.
-- Settings table is created by Module 15 (Settings); this function is safe
-- to call whether or not the table exists yet.
-- --------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.FN_SmartPOS_Setting', N'FN') IS NULL
    EXEC(N'CREATE FUNCTION dbo.FN_SmartPOS_Setting(@key NVARCHAR(100), @default NVARCHAR(MAX))
          RETURNS NVARCHAR(MAX) AS BEGIN RETURN NULL; END;');
GO

ALTER FUNCTION dbo.FN_SmartPOS_Setting(@key NVARCHAR(255), @default NVARCHAR(MAX))
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @value NVARCHAR(MAX);

    IF OBJECT_ID(N'dbo.settings', N'U') IS NOT NULL
    BEGIN
        SELECT @value = setting_value
        FROM dbo.settings
        WHERE setting_key = @key
          AND (is_active = 1 OR is_active IS NULL);
    END

    RETURN COALESCE(NULLIF(@value, N''), @default);
END
GO

-- --------------------------------------------------------------------------
-- FN_StockStatus: classify a product's stock level.
-- Priority: OUT_OF_STOCK (<=0) > LOW_STOCK (<= low_stock_threshold) > IN_STOCK.
-- --------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.FN_StockStatus', N'FN') IS NULL
    EXEC(N'CREATE FUNCTION dbo.FN_StockStatus(@qty INT, @low INT)
          RETURNS NVARCHAR(20) AS BEGIN RETURN N''IN_STOCK''; END;');
GO
ALTER FUNCTION dbo.FN_StockStatus(@qty INT, @low INT)
RETURNS NVARCHAR(20)
AS
BEGIN
    IF @qty <= 0 RETURN N'OUT_OF_STOCK';
    IF @qty <= ISNULL(@low, 0) RETURN N'LOW_STOCK';
    RETURN N'IN_STOCK';
END
GO

-- --------------------------------------------------------------------------
-- FN_HasPermission: safe RBAC check used by SQL-side authorization guards.
-- --------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.FN_HasPermission', N'FN') IS NULL
    EXEC(N'CREATE FUNCTION dbo.FN_HasPermission(@user_id INT, @permission NVARCHAR(100))
    RETURNS BIT AS BEGIN RETURN 0; END;')
GO
ALTER FUNCTION dbo.FN_HasPermission(@user_id INT, @permission NVARCHAR(100))
RETURNS BIT
AS
BEGIN
    IF OBJECT_ID(N'dbo.role_permissions', N'U') IS NULL OR OBJECT_ID(N'dbo.permissions', N'U') IS NULL
        RETURN 0;

    RETURN CASE WHEN EXISTS (
        SELECT 1
        FROM dbo.users u
        JOIN dbo.role_permissions rp ON rp.role_id = u.role_id
        JOIN dbo.permissions p        ON p.permission_id = rp.permission_id
        WHERE u.user_id = @user_id
          AND u.is_active = 1
          AND u.is_deleted = 0
          AND p.permission_code = @permission
          AND p.is_active = 1
    ) THEN 1 ELSE 0 END;
END
GO

-- --------------------------------------------------------------------------
-- FN_HashToken: one-way hash used for session / reset tokens stored at rest.
-- --------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.FN_HashToken', N'FN') IS NULL
    EXEC(N'CREATE FUNCTION dbo.FN_HashToken(@v NVARCHAR(255))
    RETURNS NVARCHAR(64) AS BEGIN RETURN CONVERT(NVARCHAR(64), HASHBYTES(''SHA2_256'', ISNULL(@v, N'''')), 2); END;')
GO
ALTER FUNCTION dbo.FN_HashToken(@v NVARCHAR(255))
RETURNS NVARCHAR(64)
AS
BEGIN
    RETURN CONVERT(NVARCHAR(64), HASHBYTES('SHA2_256', ISNULL(@v, N'')), 2);
END
GO

-- --------------------------------------------------------------------------
-- FN_CalculateLineTotal: compute a sale/return line total with discount.
--   line_total = (unit_price * qty) * (1 - discount_rate)   [discount_rate 0..1]
-- --------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.FN_CalculateLineTotal', N'FN') IS NULL
    EXEC(N'CREATE FUNCTION dbo.FN_CalculateLineTotal(@price DECIMAL(19,4), @qty DECIMAL(12,3), @discount_rate DECIMAL(5,4))
    RETURNS DECIMAL(19,4) AS BEGIN RETURN 0; END;')
GO
ALTER FUNCTION dbo.FN_CalculateLineTotal(@price DECIMAL(19,4), @qty DECIMAL(12,3), @discount_rate DECIMAL(5,4))
RETURNS DECIMAL(19,4)
AS
BEGIN
    DECLARE @rate DECIMAL(5,4) = ISNULL(@discount_rate, 0);
    IF @rate < 0 SET @rate = 0;
    IF @rate > 1 SET @rate = 1;
    RETURN ROUND(ISNULL(@price, 0) * ISNULL(@qty, 0) * (1 - @rate), 4);
END
GO

-- --------------------------------------------------------------------------
-- FN_GetUserDisplayName: displayable name for a user (NULL-safe).
-- --------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.FN_GetUserDisplayName', N'FN') IS NULL
    EXEC(N'CREATE FUNCTION dbo.FN_GetUserDisplayName(@user_id INT)
    RETURNS NVARCHAR(150) AS BEGIN RETURN NULL; END;', N'@user_id INT', N'CREATE FUNCTION dbo.FN_GetUserDisplayName(@user_id INT) RETURNS NVARCHAR(150) AS BEGIN RETURN NULL; END;');
GO
ALTER FUNCTION dbo.FN_GetUserDisplayName(@user_id INT)
RETURNS NVARCHAR(150)
AS
BEGIN
    IF @user_id IS NULL RETURN NULL;
    RETURN (SELECT TOP (1) full_name
            FROM dbo.users
            WHERE user_id = @user_id AND is_deleted = 0);
END
GO

-- --------------------------------------------------------------------------
-- FN_CurrencySymbol: return configured currency symbol (defaults to '$').
-- --------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.FN_CurrencySymbol', N'FN') IS NULL
    EXEC(N'CREATE FUNCTION dbo.FN_CurrencySymbol()
    RETURNS NVARCHAR(10) AS BEGIN RETURN N''$''; END;');
GO
ALTER FUNCTION dbo.FN_CurrencySymbol()
RETURNS NVARCHAR(10)
AS
BEGIN
    RETURN dbo.FN_SmartPOS_Setting(N'currency_symbol', N'$');
END
GO