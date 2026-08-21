/* ==========================================================================
   SmartPOS Database - TEST SUITE 03: TRIGGERS
   --------------------------------------------------------------------------
   Verifies the trigger layer in All_Triggers.sql:
     - audit triggers write JSON snapshots into dbo.audit_logs
     - TRG_users_audit NEVER captures password_hash
     - TRG_inventory_low_stock raises OPEN alerts + notifies ADMIN/MANAGER and
       resolves alerts on recovery
     - TRG_password_history_retention keeps at most 5 rows per user

   HARNESS
     - The entire file runs inside ONE outer transaction and rolls back at the
       end -> fully non-destructive (audit/alert/notification writes included).
     - Success  -> PRINT N'Test PASSED: <name>'
     - Failure  -> THROW <code>, N'Test FAILED: <name>: <detail>', 1
   ========================================================================== */

SET NOCOUNT ON;

DECLARE @AdminID INT = (SELECT TOP (1) user_id FROM dbo.users WHERE username = N'admin');
DECLARE @RoleCash INT = (SELECT TOP (1) role_id FROM dbo.roles WHERE role_code = N'CASHIER');

DECLARE @CatID INT, @ProdID INT, @UserId INT, @SetID INT;

BEGIN TRANSACTION;

BEGIN TRY

    /* ------------------------------------------------------------------ */
    /* 03.01 - TRG_categories_audit writes an INSERT audit row             */
    /* ------------------------------------------------------------------ */
    INSERT INTO dbo.categories (category_name, is_active, is_deleted, created_by)
    VALUES (N'TRG Test Category', 1, 0, @AdminID);
    SET @CatID = SCOPE_IDENTITY();

    IF NOT EXISTS (
        SELECT 1 FROM dbo.audit_logs
        WHERE resource_type = N'Category' AND resource_id = CAST(@CatID AS NVARCHAR(100)) AND action_type = N'INSERT'
    )
        THROW 63001, N'Test FAILED: 03.01 categories_audit - INSERT audit row missing.', 1;

    /* ------------------------------------------------------------------ */
    /* 03.02 - TRG_categories_audit SOFT_DELETE path                       */
    /* ------------------------------------------------------------------ */
    UPDATE dbo.categories SET is_deleted = 1 WHERE category_id = @CatID;
    IF NOT EXISTS (
        SELECT 1 FROM dbo.audit_logs
        WHERE resource_type = N'Category' AND resource_id = CAST(@CatID AS NVARCHAR(100)) AND action_type = N'SOFT_DELETE'
    )
        THROW 63002, N'Test FAILED: 03.02 categories_audit - SOFT_DELETE audit row missing.', 1;

    /* ------------------------------------------------------------------ */
    /* 03.03 - TRG_products_audit writes JSON INSERT + SOFT_DELETE         */
    /* ------------------------------------------------------------------ */
    INSERT INTO dbo.products (sku, product_name, unit_price, category_id, low_stock_threshold, created_by)
    VALUES (N'TRG-SKU-001', N'TRG Product', 10.0000, @CatID, 5, @AdminID);
    SET @ProdID = SCOPE_IDENTITY();

    IF NOT EXISTS (
        SELECT 1 FROM dbo.audit_logs
        WHERE resource_type = N'Product' AND resource_id = CAST(@ProdID AS NVARCHAR(100)) AND action_type = N'INSERT'
          AND new_values LIKE N'%product_name%'
    )
        THROW 63003, N'Test FAILED: 03.03 products_audit - INSERT audit row missing.', 1;

    UPDATE dbo.products SET is_deleted = 1 WHERE product_id = @ProdID;
    IF NOT EXISTS (
        SELECT 1 FROM dbo.audit_logs
        WHERE resource_type = N'Product' AND resource_id = CAST(@ProdID AS NVARCHAR(100)) AND action_type = N'SOFT_DELETE'
    )
        THROW 63003, N'Test FAILED: 03.03 products_audit - SOFT_DELETE audit row missing.', 1;

    /* ------------------------------------------------------------------ */
    /* 03.04 - TRG_users_audit: password_hash is NEVER written to JSON     */
    /* ------------------------------------------------------------------ */
    INSERT INTO dbo.users (username, email, password_hash, full_name, role_id)
    VALUES (N'trg_user', N'trg_user@test.local', N'SUPER_SECRET_HASH', N'TRG User', @RoleCash);
    SET @UserId = SCOPE_IDENTITY();

    IF EXISTS (
        SELECT 1 FROM dbo.audit_logs
        WHERE resource_type = N'User' AND resource_id = CAST(@UserId AS NVARCHAR(100))
          AND (new_values LIKE N'%password_hash%' OR old_values LIKE N'%password_hash%')
    )
        THROW 63004, N'Test FAILED: 03.04 users_audit - password_hash leaked into audit JSON.', 1;

    IF NOT EXISTS (
        SELECT 1 FROM dbo.audit_logs
        WHERE resource_type = N'User' AND resource_id = CAST(@UserId AS NVARCHAR(100)) AND action_type = N'INSERT'
    )
        THROW 63004, N'Test FAILED: 03.04 users_audit - INSERT audit row missing.', 1;

    /* ------------------------------------------------------------------ */
    /* 03.05 - TRG_settings_audit on INSERT and UPDATE                     */
    /* ------------------------------------------------------------------ */
    INSERT INTO dbo.settings (setting_key, setting_value, data_type, category)
    VALUES (N'trg.test.setting', N'one', N'string', N'general');
    SET @SetID = SCOPE_IDENTITY();

    IF NOT EXISTS (
        SELECT 1 FROM dbo.audit_logs
        WHERE resource_type = N'Setting' AND resource_id = CAST(@SetID AS NVARCHAR(100)) AND action_type = N'INSERT'
    )
        THROW 63005, N'Test FAILED: 03.05 settings_audit - INSERT audit row missing.', 1;

    UPDATE dbo.settings SET setting_value = N'two' WHERE setting_id = @SetID;
    IF NOT EXISTS (
        SELECT 1 FROM dbo.audit_logs
        WHERE resource_type = N'Setting' AND resource_id = CAST(@SetID AS NVARCHAR(100)) AND action_type = N'UPDATE'
    )
        THROW 63005, N'Test FAILED: 03.05 settings_audit - UPDATE audit row missing.', 1;

    /* ------------------------------------------------------------------ */
    /* 03.06 - TRG_inventory_low_stock raises alerts + notifications       */
    /* ------------------------------------------------------------------ */
    INSERT INTO dbo.inventory (product_id, quantity_on_hand, quantity_reserved)
    VALUES (@ProdID, 20, 0);

    -- Drop from 20 (above threshold 5) to 0 -> raise OPEN alert + notify.
    UPDATE dbo.inventory SET quantity_on_hand = 0, updated_at = SYSUTCDATETIME() WHERE product_id = @ProdID;

    IF NOT EXISTS (
        SELECT 1 FROM dbo.low_stock_alerts
        WHERE product_id = @ProdID AND status = N'OPEN'
          AND low_stock_threshold = 5 AND quantity_on_hand = 0
    )
        THROW 63006, N'Test FAILED: 03.06 low_stock - OPEN alert not raised.', 1;

    DECLARE @ExpectedNotifs INT =
        (SELECT COUNT(*) FROM dbo.users u JOIN dbo.roles r ON r.role_id = u.role_id
         WHERE r.role_code IN (N'ADMIN', N'MANAGER') AND u.is_active = 1 AND u.is_deleted = 0);

    IF (SELECT COUNT(*) FROM dbo.notifications
        WHERE entity_type = N'Product' AND entity_id = CAST(@ProdID AS NVARCHAR(100))
          AND notification_type_id = (SELECT notification_type_id FROM dbo.notification_types WHERE type_code = N'LOW_STOCK')
    ) <> @ExpectedNotifs
        THROW 63006, N'Test FAILED: 03.06 low_stock - notification count does not match active ADMIN+MANAGER users.', 1;

    -- Duplicate drop must NOT raise a second OPEN alert.
    UPDATE dbo.inventory SET quantity_on_hand = 3, updated_at = SYSUTCDATETIME() WHERE product_id = @ProdID;
    IF (SELECT COUNT(*) FROM dbo.low_stock_alerts WHERE product_id = @ProdID AND status = N'OPEN') <> 1
        THROW 63006, N'Test FAILED: 03.06 low_stock - duplicate OPEN alert raised.', 1;

    -- Recovery above the threshold resolves the alert.
    UPDATE dbo.inventory SET quantity_on_hand = 8, updated_at = SYSUTCDATETIME() WHERE product_id = @ProdID;
    IF NOT EXISTS (
        SELECT 1 FROM dbo.low_stock_alerts
        WHERE product_id = @ProdID AND status = N'RESOLVED' AND resolved_at IS NOT NULL
    )
        THROW 63006, N'Test FAILED: 03.06 low_stock - alert was not resolved on recovery.', 1;

    /* ------------------------------------------------------------------ */
    /* 03.07 - TRG_password_history_retention caps at 5 rows per user      */
    /* ------------------------------------------------------------------ */
    INSERT INTO dbo.password_history (user_id, password_hash, changed_at, changed_by)
    SELECT @UserId, N'h1', SYSUTCDATETIME(), @UserId;
    INSERT INTO dbo.password_history (user_id, password_hash, changed_at, changed_by)
    SELECT @UserId, N'h2', SYSUTCDATETIME(), @UserId;
    INSERT INTO dbo.password_history (user_id, password_hash, changed_at, changed_by)
    SELECT @UserId, N'h3', SYSUTCDATETIME(), @UserId;
    INSERT INTO dbo.password_history (user_id, password_hash, changed_at, changed_by)
    SELECT @UserId, N'h4', SYSUTCDATETIME(), @UserId;
    INSERT INTO dbo.password_history (user_id, password_hash, changed_at, changed_by)
    SELECT @UserId, N'h5', SYSUTCDATETIME(), @UserId;
    INSERT INTO dbo.password_history (user_id, password_hash, changed_at, changed_by)
    SELECT @UserId, N'h6', SYSUTCDATETIME(), @UserId;

    IF (SELECT COUNT(*) FROM dbo.password_history WHERE user_id = @UserId) <> 5
        THROW 63007, N'Test FAILED: 03.07 password_retention - expected exactly 5 history rows.', 1;

END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    DECLARE @e INT = ERROR_NUMBER(); DECLARE @m NVARCHAR(4000) = ERROR_MESSAGE();
    THROW 63099, N'Test FAILED: 03_triggers - ' + @m, 1;
END CATCH;

/* ---------------------------------------------------------------------------
   FILE CLEANUP: roll back the entire run (non-destructive guarantee)
--------------------------------------------------------------------------- */
IF XACT_STATE() <> 0
    ROLLBACK TRANSACTION;

PRINT N'Test PASSED: 03_triggers_all';
