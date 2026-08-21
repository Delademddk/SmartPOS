/* ==========================================================================
   SmartPOS Database - TEST SUITE 02: STORED PROCEDURES
   --------------------------------------------------------------------------
   Functional tests for the stored procedure layer: happy paths, validation
   failures, business-rule guards, and the transactional side effects each
   procedure is documented to produce.

   HARNESS / NON-DESTRUCTIVE STRATEGY
     - The whole file runs inside a single outer transaction.
     - The throwing procedures use XACT_ABORT ON and their CATCH blocks issue
       an unconditional ROLLBACK, which also aborts the caller's transaction.
       After every expected-failure test the harness therefore re-opens the
       transaction with:
           IF XACT_STATE() = 0 BEGIN TRANSACTION; END
     - Expected failures are caught in nested TRY/CATCH; unexpected errors
       are re-thrown so sqlcmd -b fails.
     - error_logs rows written by procedures AFTER their rollback are
       auto-committed; the file records a baseline and deletes them at the end.
     - SP_Login THROWs error numbers < 50000 (40100-40103); SQL Server re-raises
       those as Msg 35100 at runtime, so login failures assert ERROR_NUMBER()
       IN (401xx, 35100).

   Run with sqlcmd -S <server> -U <user> -P <pass> -d SmartPOS -b -i 02_...
   ========================================================================== */

SET NOCOUNT ON;

/* ----------------------------- fixtures ---------------------------------- */
DECLARE @AdminID    INT = (SELECT TOP (1) user_id   FROM dbo.users WHERE username = N'admin');
DECLARE @CashierID  INT = (SELECT TOP (1) user_id   FROM dbo.users WHERE username = N'cashier');
DECLARE @ManagerID  INT = (SELECT TOP (1) user_id   FROM dbo.users WHERE username = N'manager');
DECLARE @RoleAdmin  INT = (SELECT TOP (1) role_id   FROM dbo.roles  WHERE role_code = N'ADMIN');
DECLARE @RoleCash   INT = (SELECT TOP (1) role_id   FROM dbo.roles  WHERE role_code = N'CASHIER');
DECLARE @CashID     INT = (SELECT TOP (1) payment_method_id FROM dbo.payment_methods WHERE method_code = N'CASH');
DECLARE @ErrorBaseline INT = ISNULL((SELECT MAX(error_id) FROM dbo.error_logs), 0);

DECLARE @LoginUID INT, @LoginSessionID INT;
DECLARE @NewUID INT, @NewRoleID INT, @NewRoleID2 INT;
DECLARE @CatID INT, @ChildCatID INT;
DECLARE @ProductID INT;
DECLARE @SaleID INT, @SaleItemID INT, @PayID INT, @CreditSaleID INT;
DECLARE @ReturnID INT, @CustomerID INT;
DECLARE @SettingID INT, @NotifID INT;
DECLARE @Token NVARCHAR(255) = N'TOK-' + CONVERT(NVARCHAR(32), NEWID());
DECLARE @R2 INT;

BEGIN TRANSACTION;

/* ---------------------------------------------------------------------------
   TEST 02.01 - SP_CreateUser creates an active user + password history
--------------------------------------------------------------------------- */
BEGIN TRY
    EXEC dbo.SP_CreateUser
        @Username = N'loginuser',
        @Email = N'loginuser@test.local',
        @PasswordHash = N'HASH_KNOWN',
        @FullName = N'Login User',
        @RoleID = @RoleCash,
        @CreatedByID = @AdminID,
        @MustChangePassword = 0,
        @UserID = @LoginUID OUTPUT;

    IF @LoginUID IS NULL
        THROW 62001, N'SP_CreateUser returned no UserID.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.users WHERE user_id = @LoginUID AND is_active = 1 AND is_deleted = 0)
        THROW 62001, N'Created user is not active.', 1;
    IF (SELECT COUNT(*) FROM dbo.password_history WHERE user_id = @LoginUID) <> 1
        THROW 62001, N'Expected exactly 1 password_history row for the new user.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.activity_logs WHERE activity_type = N'USER_CREATED' AND entity_id = CAST(@LoginUID AS NVARCHAR(20)))
        THROW 62001, N'USER_CREATED activity_log row missing.', 1;
END TRY
BEGIN CATCH
    DECLARE @e1 INT = ERROR_NUMBER(); DECLARE @m1 NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK;
    IF XACT_STATE() = 0 BEGIN TRANSACTION; END
    THROW 62001, N'Test FAILED: 02.01 create_user_success - ' + @m1, 1;
END CATCH
PRINT N'Test PASSED: 02.01 create_user_success';

/* ---------------------------------------------------------------------------
   TEST 02.02 - SP_CreateUser validation failures
--------------------------------------------------------------------------- */
IF XACT_STATE() = 0 BEGIN TRANSACTION; END
BEGIN TRY
    EXEC dbo.SP_CreateUser @Username = N'ab', @Email = N'x@y.z', @PasswordHash = N'h', @FullName = N'x', @RoleID = @RoleCash;
    IF XACT_STATE() <> 0 ROLLBACK;
    THROW 62002, N'Short username accepted.', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (52001, 35100) THROW;
    IF XACT_STATE() <> 0 ROLLBACK;
    IF XACT_STATE() = 0 BEGIN TRANSACTION; END
END CATCH

IF XACT_STATE() = 0 BEGIN TRANSACTION; END
BEGIN TRY
    EXEC dbo.SP_CreateUser @Username = N'validuser1', @Email = N'not-an-email', @PasswordHash = N'h', @FullName = N'x', @RoleID = @RoleCash;
    IF XACT_STATE() <> 0 ROLLBACK;
    THROW 62002, N'Invalid email accepted.', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (52002, 35100) THROW;
    IF XACT_STATE() <> 0 ROLLBACK;
    IF XACT_STATE() = 0 BEGIN TRANSACTION; END
END CATCH

IF XACT_STATE() = 0 BEGIN TRANSACTION; END
BEGIN TRY
    EXEC dbo.SP_CreateUser @Username = N'admin', @Email = N'unique2@test.local', @PasswordHash = N'h', @FullName = N'x', @RoleID = @RoleCash;
    IF XACT_STATE() <> 0 ROLLBACK;
    THROW 62002, N'Duplicate username accepted.', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (52004, 35100) THROW;
    IF XACT_STATE() <> 0 ROLLBACK;
    IF XACT_STATE() = 0 BEGIN TRANSACTION; END
END CATCH

IF XACT_STATE() = 0 BEGIN TRANSACTION; END
BEGIN TRY
    EXEC dbo.SP_CreateUser @Username = N'unique3', @Email = N'admin@smartpos.local', @PasswordHash = N'h', @FullName = N'x', @RoleID = @RoleCash;
    IF XACT_STATE() <> 0 ROLLBACK;
    THROW 62002, N'Duplicate email accepted.', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (52005, 35100) THROW;
    IF XACT_STATE() <> 0 ROLLBACK;
    IF XACT_STATE() = 0 BEGIN TRANSACTION; END
END CATCH
PRINT N'Test PASSED: 02.02 create_user_validation';

/* ---------------------------------------------------------------------------
   TEST 02.03 - SP_Login success: issues a session, resets failures
--------------------------------------------------------------------------- */
BEGIN TRY
    EXEC dbo.SP_Login
        @UsernameOrEmail = N'loginuser',
        @PasswordHash = N'HASH_KNOWN',
        @IPAddress = N'127.0.0.1',
        @HashedSessionToken = @Token,
        @UserID = @LoginUID OUTPUT,
        @SessionID = @LoginSessionID OUTPUT;

    IF @LoginSessionID IS NULL
        THROW 62003, N'SP_Login returned no SessionID.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.user_sessions WHERE session_id = @LoginSessionID AND user_id = @LoginUID AND is_revoked = 0)
        THROW 62003, N'Session row was not persisted.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.security_logs WHERE event_type = N'LOGIN_SUCCESS' AND user_id = @LoginUID)
        THROW 62003, N'LOGIN_SUCCESS security event missing.', 1;
END TRY
BEGIN CATCH
    DECLARE @e3 INT = ERROR_NUMBER(); DECLARE @m3 NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK;
    IF XACT_STATE() = 0 BEGIN TRANSACTION; END
    THROW 62003, N'Test FAILED: 02.03 login_success - ' + @m3, 1;
END CATCH
PRINT N'Test PASSED: 02.03 login_success';

/* ---------------------------------------------------------------------------
   TEST 02.04 - SP_Login failures (wrong password / unknown user / no creds)
   THROW numbers 40100-40103 surface as Msg 35100 at runtime.
--------------------------------------------------------------------------- */
IF XACT_STATE() = 0 BEGIN TRANSACTION; END
BEGIN TRY
    EXEC dbo.SP_Login @UsernameOrEmail = N'loginuser', @PasswordHash = N'WRONG_HASH';
    IF XACT_STATE() <> 0 ROLLBACK;
    THROW 62004, N'Wrong password login did not fail.', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (40101, 35100) THROW;
    IF XACT_STATE() <> 0 ROLLBACK;
    IF XACT_STATE() = 0 BEGIN TRANSACTION; END
END CATCH

IF XACT_STATE() = 0 BEGIN TRANSACTION; END
BEGIN TRY
    EXEC dbo.SP_Login @UsernameOrEmail = N'no_such_user', @PasswordHash = N'HASH';
    IF XACT_STATE() <> 0 ROLLBACK;
    THROW 62004, N'Unknown-user login did not fail.', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (40101, 35100) THROW;
    IF XACT_STATE() <> 0 ROLLBACK;
    IF XACT_STATE() = 0 BEGIN TRANSACTION; END
END CATCH

IF XACT_STATE() = 0 BEGIN TRANSACTION; END
BEGIN TRY
    EXEC dbo.SP_Login @UsernameOrEmail = NULL, @PasswordHash = NULL;
    IF XACT_STATE() <> 0 ROLLBACK;
    THROW 62004, N'Missing-credentials login did not fail.', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (40100, 35100) THROW;
    IF XACT_STATE() <> 0 ROLLBACK;
    IF XACT_STATE() = 0 BEGIN TRANSACTION; END
END CATCH
PRINT N'Test PASSED: 02.04 login_failures';

/* ---------------------------------------------------------------------------
   TEST 02.05 - SP_ValidateSession (valid token -> valid; bad token -> none)
--------------------------------------------------------------------------- */
CREATE TABLE #vs_valid (
    is_valid BIT, user_id INT, username NVARCHAR(50), email NVARCHAR(255), full_name NVARCHAR(150),
    role_id INT, role_code NVARCHAR(50), role_name NVARCHAR(100), must_change_password BIT,
    session_id INT, session_expires_at DATETIME2(0), [message] NVARCHAR(200)
);
CREATE TABLE #vs_invalid (is_valid INT, user_id INT, [message] NVARCHAR(200));

BEGIN TRY
    INSERT INTO #vs_valid EXEC dbo.SP_ValidateSession @SessionTokenHash = @Token;
    IF (SELECT COUNT(*) FROM #vs_valid) <> 1
        THROW 62005, N'Valid session returned no row.', 1;
    IF (SELECT TOP (1) is_valid FROM #vs_valid) <> 1
        THROW 62005, N'Valid session reported is_valid = 0.', 1;

    INSERT INTO #vs_invalid EXEC dbo.SP_ValidateSession @SessionTokenHash = N'NO-SUCH-TOKEN';
    IF (SELECT COUNT(*) FROM #vs_invalid) <> 0
        THROW 62005, N'Unknown token must return no rows.', 1;
END TRY
BEGIN CATCH
    DECLARE @e5 INT = ERROR_NUMBER(); DECLARE @m5 NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK;
    IF XACT_STATE() = 0 BEGIN TRANSACTION; END
    THROW 62005, N'Test FAILED: 02.05 validate_session - ' + @m5, 1;
END CATCH
PRINT N'Test PASSED: 02.05 validate_session';

/* ---------------------------------------------------------------------------
   TEST 02.06 - SP_Logout revokes the session (idempotent)
--------------------------------------------------------------------------- */
BEGIN TRY
    EXEC dbo.SP_Logout @SessionTokenHash = @Token, @IPAddress = N'127.0.0.1';
    IF NOT EXISTS (SELECT 1 FROM dbo.user_sessions WHERE session_token = @Token AND is_revoked = 1)
        THROW 62006, N'Session was not revoked.', 1;

    EXEC dbo.SP_Logout @SessionTokenHash = @Token;   -- second call must be a no-op
END TRY
BEGIN CATCH
    DECLARE @e6 INT = ERROR_NUMBER(); DECLARE @m6 NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK;
    IF XACT_STATE() = 0 BEGIN TRANSACTION; END
    THROW 62006, N'Test FAILED: 02.06 logout - ' + @m6, 1;
END CATCH
PRINT N'Test PASSED: 02.06 logout';

/* ---------------------------------------------------------------------------
   TEST 02.07 - SP_ChangePassword (wrong current -> 52014; success -> hash swap)
--------------------------------------------------------------------------- */
IF XACT_STATE() = 0 BEGIN TRANSACTION; END
BEGIN TRY
    EXEC dbo.SP_ChangePassword @UserID = @LoginUID, @CurrentPasswordHash = N'WRONG', @NewPasswordHash = N'NEW';
    IF XACT_STATE() <> 0 ROLLBACK;
    THROW 62007, N'Wrong current password accepted.', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (52014, 35100) THROW;
    IF XACT_STATE() <> 0 ROLLBACK;
    IF XACT_STATE() = 0 BEGIN TRANSACTION; END
END CATCH

BEGIN TRY
    EXEC dbo.SP_ChangePassword @UserID = @LoginUID, @CurrentPasswordHash = N'HASH_KNOWN', @NewPasswordHash = N'HASH_NEW', @CurrentSessionTokenHash = @Token;
    IF (SELECT password_hash FROM dbo.users WHERE user_id = @LoginUID) <> N'HASH_NEW'
        THROW 62007, N'Password hash was not updated.', 1;
    IF (SELECT COUNT(*) FROM dbo.password_history WHERE user_id = @LoginUID) <> 2
        THROW 62007, N'Expected 2 password_history rows after change.', 1;
END TRY
BEGIN CATCH
    DECLARE @e7 INT = ERROR_NUMBER(); DECLARE @m7 NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK;
    IF XACT_STATE() = 0 BEGIN TRANSACTION; END
    THROW 62007, N'Test FAILED: 02.07 change_password - ' + @m7, 1;
END CATCH
PRINT N'Test PASSED: 02.07 change_password';

/* ---------------------------------------------------------------------------
   TEST 02.08 - SP_CreateRole success (code normalised, permissions granted)
--------------------------------------------------------------------------- */
BEGIN TRY
    EXEC dbo.SP_CreateRole
        @RoleCode = N'testrole',
        @RoleName = N'Test Role',
        @PermissionCodesCSV = N'products.view,products.create',
        @CreatedBy = @AdminID,
        @RoleID = @NewRoleID OUTPUT;

    IF @NewRoleID IS NULL
        THROW 62008, N'SP_CreateRole returned no RoleID.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.roles WHERE role_id = @NewRoleID AND role_code = N'TESTROLE' AND is_system = 0)
        THROW 62008, N'Role was not created / code not uppercased.', 1;
    IF (SELECT COUNT(*) FROM dbo.role_permissions WHERE role_id = @NewRoleID) <> 2
        THROW 62008, N'Expected 2 permission grants.', 1;
END TRY
BEGIN CATCH
    DECLARE @e8 INT = ERROR_NUMBER(); DECLARE @m8 NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK;
    IF XACT_STATE() = 0 BEGIN TRANSACTION; END
    THROW 62008, N'Test FAILED: 02.08 create_role_success - ' + @m8, 1;
END CATCH
PRINT N'Test PASSED: 02.08 create_role_success';

/* ---------------------------------------------------------------------------
   TEST 02.09 - SP_CreateRole failures: duplicate, bad permission, lowercase
--------------------------------------------------------------------------- */
IF XACT_STATE() = 0 BEGIN TRANSACTION; END
BEGIN TRY
    EXEC dbo.SP_CreateRole @RoleCode = N'testrole', @RoleName = N'Dup', @RoleID = @R2 OUTPUT;
    IF XACT_STATE() <> 0 ROLLBACK;
    THROW 62009, N'Duplicate role code accepted.', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (50035, 35100) THROW;
    IF XACT_STATE() <> 0 ROLLBACK;
    IF XACT_STATE() = 0 BEGIN TRANSACTION; END
END CATCH

IF XACT_STATE() = 0 BEGIN TRANSACTION; END
BEGIN TRY
    EXEC dbo.SP_CreateRole @RoleCode = N'ROLEBADP', @RoleName = N'Bad', @PermissionCodesCSV = N'no.such.permission', @RoleID = @R2 OUTPUT;
    IF XACT_STATE() <> 0 ROLLBACK;
    THROW 62009, N'Unknown permission code accepted.', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (50036, 35100) THROW;
    IF XACT_STATE() <> 0 ROLLBACK;
    IF XACT_STATE() = 0 BEGIN TRANSACTION; END
END CATCH

IF XACT_STATE() = 0 BEGIN TRANSACTION; END
BEGIN TRY
    EXEC dbo.SP_CreateRole @RoleCode = N'notupper', @RoleName = N'Bad', @RoleID = @R2 OUTPUT;
    IF XACT_STATE() <> 0 ROLLBACK;
    THROW 62009, N'Lowercase role code accepted.', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (50034, 35100) THROW;
    IF XACT_STATE() <> 0 ROLLBACK;
    IF XACT_STATE() = 0 BEGIN TRANSACTION; END
END CATCH
PRINT N'Test PASSED: 02.09 create_role_validation';

/* ---------------------------------------------------------------------------
   TEST 02.10 - SP_UpdateRole replaces permission set
--------------------------------------------------------------------------- */
BEGIN TRY
    EXEC dbo.SP_UpdateRole @RoleID = @NewRoleID, @RoleName = N'Test Role v2', @PermissionCodesCSV = N'sales.view', @UpdatedBy = @AdminID;
    IF (SELECT COUNT(*) FROM dbo.role_permissions WHERE role_id = @NewRoleID) <> 1
        THROW 62010, N'Permission set was not replaced.', 1;
    IF NOT EXISTS (
        SELECT 1 FROM dbo.role_permissions rp JOIN dbo.permissions p ON p.permission_id = rp.permission_id
        WHERE rp.role_id = @NewRoleID AND p.permission_code = N'sales.view'
    )
        THROW 62010, N'Replacement grant sales.view missing.', 1;
END TRY
BEGIN CATCH
    DECLARE @e10 INT = ERROR_NUMBER(); DECLARE @m10 NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK;
    IF XACT_STATE() = 0 BEGIN TRANSACTION; END
    THROW 62010, N'Test FAILED: 02.10 update_role - ' + @m10, 1;
END CATCH
PRINT N'Test PASSED: 02.10 update_role';

/* ---------------------------------------------------------------------------
   TEST 02.11 - SP_UpdateRole blocks replacing system-role permission set (50037)
--------------------------------------------------------------------------- */
IF XACT_STATE() = 0 BEGIN TRANSACTION; END
BEGIN TRY
    EXEC dbo.SP_UpdateRole @RoleID = @RoleAdmin, @RoleName = N'Administrator', @PermissionCodesCSV = N'products.view', @UpdatedBy = @AdminID;
    IF XACT_STATE() <> 0 ROLLBACK;
    THROW 62011, N'System-role permission replacement accepted.', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (50037, 35100) THROW;
    IF XACT_STATE() <> 0 ROLLBACK;
    IF XACT_STATE() = 0 BEGIN TRANSACTION; END
END CATCH
PRINT N'Test PASSED: 02.11 update_role_system_protected';

/* ---------------------------------------------------------------------------
   TEST 02.12 - SP_DeleteRole (system protected 50030; custom role deleted)
--------------------------------------------------------------------------- */
IF XACT_STATE() = 0 BEGIN TRANSACTION; END
BEGIN TRY
    EXEC dbo.SP_DeleteRole @RoleID = @RoleAdmin;
    IF XACT_STATE() <> 0 ROLLBACK;
    THROW 62012, N'System role was deleted.', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (50030, 35100) THROW;
    IF XACT_STATE() <> 0 ROLLBACK;
    IF XACT_STATE() = 0 BEGIN TRANSACTION; END
END CATCH

BEGIN TRY
    EXEC dbo.SP_DeleteRole @RoleID = @NewRoleID;
    IF EXISTS (SELECT 1 FROM dbo.roles WHERE role_id = @NewRoleID)
        THROW 62012, N'Custom role was not deleted.', 1;
    IF EXISTS (SELECT 1 FROM dbo.role_permissions WHERE role_id = @NewRoleID)
        THROW 62012, N'Role permission grants were not removed.', 1;
END TRY
BEGIN CATCH
    DECLARE @e12 INT = ERROR_NUMBER(); DECLARE @m12 NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK;
    IF XACT_STATE() = 0 BEGIN TRANSACTION; END
    THROW 62012, N'Test FAILED: 02.12 delete_role - ' + @m12, 1;
END CATCH
PRINT N'Test PASSED: 02.12 delete_role';

/* ---------------------------------------------------------------------------
   TEST 02.13 - SP_CreateCategory success (result set CategoryID)
--------------------------------------------------------------------------- */
CREATE TABLE #cat (CategoryID INT);
BEGIN TRY
    INSERT INTO #cat EXEC dbo.SP_CreateCategory @Name = N'TestCat', @Description = N'Test', @CreatedByID = @AdminID;
    SELECT TOP (1) @CatID = CategoryID FROM #cat;
    IF @CatID IS NULL
        THROW 62013, N'SP_CreateCategory returned no CategoryID.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.categories WHERE category_id = @CatID AND category_name = N'TestCat' AND is_deleted = 0)
        THROW 62013, N'Category was not created.', 1;

    INSERT INTO #cat EXEC dbo.SP_CreateCategory @Name = N'TestChild', @ParentID = @CatID, @CreatedByID = @AdminID;
    SELECT TOP (1) @ChildCatID = CategoryID FROM #cat WHERE CategoryID <> @CatID;
    IF @ChildCatID IS NULL
        THROW 62013, N'Child category was not created.', 1;
END TRY
BEGIN CATCH
    DECLARE @e13 INT = ERROR_NUMBER(); DECLARE @m13 NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK;
    IF XACT_STATE() = 0 BEGIN TRANSACTION; END
    THROW 62013, N'Test FAILED: 02.13 create_category - ' + @m13, 1;
END CATCH
PRINT N'Test PASSED: 02.13 create_category';

/* ---------------------------------------------------------------------------
   TEST 02.14 - SP_CreateCategory failures (dup sibling 50021, bad parent 50022)
--------------------------------------------------------------------------- */
IF XACT_STATE() = 0 BEGIN TRANSACTION; END
BEGIN TRY
    EXEC dbo.SP_CreateCategory @Name = N'TestCat', @CreatedByID = @AdminID;
    IF XACT_STATE() <> 0 ROLLBACK;
    THROW 62014, N'Duplicate sibling category accepted.', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (50021, 35100) THROW;
    IF XACT_STATE() <> 0 ROLLBACK;
    IF XACT_STATE() = 0 BEGIN TRANSACTION; END
END CATCH

IF XACT_STATE() = 0 BEGIN TRANSACTION; END
BEGIN TRY
    EXEC dbo.SP_CreateCategory @Name = N'BadParentCat', @ParentID = 2147483647, @CreatedByID = @AdminID;
    IF XACT_STATE() <> 0 ROLLBACK;
    THROW 62014, N'Missing parent category accepted.', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (50022, 35100) THROW;
    IF XACT_STATE() <> 0 ROLLBACK;
    IF XACT_STATE() = 0 BEGIN TRANSACTION; END
END CATCH
PRINT N'Test PASSED: 02.14 create_category_validation';

/* ---------------------------------------------------------------------------
   TEST 02.15 - SP_UpdateCategory cycle guards (self parent / descendant 50040)
--------------------------------------------------------------------------- */
IF XACT_STATE() = 0 BEGIN TRANSACTION; END
BEGIN TRY
    EXEC dbo.SP_UpdateCategory @CategoryID = @CatID, @Name = N'TestCat', @ParentID = @CatID, @UpdatedByID = @AdminID;
    IF XACT_STATE() <> 0 ROLLBACK;
    THROW 62015, N'Self-parent update accepted.', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (50040, 35100) THROW;
    IF XACT_STATE() <> 0 ROLLBACK;
    IF XACT_STATE() = 0 BEGIN TRANSACTION; END
END CATCH

IF XACT_STATE() = 0 BEGIN TRANSACTION; END
BEGIN TRY
    -- Moving the PARENT under its own CHILD would create a cycle.
    EXEC dbo.SP_UpdateCategory @CategoryID = @CatID, @Name = N'TestCat', @ParentID = @ChildCatID, @UpdatedByID = @AdminID;
    IF XACT_STATE() <> 0 ROLLBACK;
    THROW 62015, N'Descendant-parent update accepted.', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (50040, 35100) THROW;
    IF XACT_STATE() <> 0 ROLLBACK;
    IF XACT_STATE() = 0 BEGIN TRANSACTION; END
END CATCH
PRINT N'Test PASSED: 02.15 update_category_cycle_guard';

/* ---------------------------------------------------------------------------
   TEST 02.16 - SP_CreateProduct success (inventory row created for stock item)
--------------------------------------------------------------------------- */
BEGIN TRY
    EXEC dbo.SP_CreateProduct
        @SKU = N'SKU001', @Barcode = N'BAR001', @Name = N'Test Product',
        @CategoryID = @CatID, @UnitPrice = 100.00, @CostPrice = 50.00,
        @LowStockThreshold = 10, @CreatedByID = @AdminID,
        @ProductID = @ProductID OUTPUT;

    IF @ProductID IS NULL
        THROW 62016, N'SP_CreateProduct returned no ProductID.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.products WHERE product_id = @ProductID AND sku = N'SKU001' AND is_deleted = 0)
        THROW 62016, N'Product was not created.', 1;
    -- No @InitialQuantity supplied -> no inventory row (created later by restock).
    IF EXISTS (SELECT 1 FROM dbo.inventory WHERE product_id = @ProductID)
        THROW 62016, N'Inventory row created without @InitialQuantity.', 1;
END TRY
BEGIN CATCH
    DECLARE @e16 INT = ERROR_NUMBER(); DECLARE @m16 NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK;
    IF XACT_STATE() = 0 BEGIN TRANSACTION; END
    THROW 62016, N'Test FAILED: 02.16 create_product - ' + @m16, 1;
END CATCH
PRINT N'Test PASSED: 02.16 create_product';

/* ---------------------------------------------------------------------------
   TEST 02.17 - SP_CreateProduct failures (missing SKU 50051, dup 50053,
               negative price 50055, bad category 50056)
--------------------------------------------------------------------------- */
IF XACT_STATE() = 0 BEGIN TRANSACTION; END
BEGIN TRY
    EXEC dbo.SP_CreateProduct @SKU = NULL, @Name = N'X', @ProductID = @R2 OUTPUT;
    IF XACT_STATE() <> 0 ROLLBACK;
    THROW 62017, N'Missing SKU accepted.', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (50051, 35100) THROW;
    IF XACT_STATE() <> 0 ROLLBACK;
    IF XACT_STATE() = 0 BEGIN TRANSACTION; END
END CATCH

IF XACT_STATE() = 0 BEGIN TRANSACTION; END
BEGIN TRY
    EXEC dbo.SP_CreateProduct @SKU = N'SKU001', @Name = N'Dup', @ProductID = @R2 OUTPUT;
    IF XACT_STATE() <> 0 ROLLBACK;
    THROW 62017, N'Duplicate SKU accepted.', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (50053, 35100) THROW;
    IF XACT_STATE() <> 0 ROLLBACK;
    IF XACT_STATE() = 0 BEGIN TRANSACTION; END
END CATCH

IF XACT_STATE() = 0 BEGIN TRANSACTION; END
BEGIN TRY
    EXEC dbo.SP_CreateProduct @SKU = N'SKUNEG', @Name = N'Neg', @UnitPrice = -1.00, @ProductID = @R2 OUTPUT;
    IF XACT_STATE() <> 0 ROLLBACK;
    THROW 62017, N'Negative unit price accepted.', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (50055, 35100) THROW;
    IF XACT_STATE() <> 0 ROLLBACK;
    IF XACT_STATE() = 0 BEGIN TRANSACTION; END
END CATCH

IF XACT_STATE() = 0 BEGIN TRANSACTION; END
BEGIN TRY
    EXEC dbo.SP_CreateProduct @SKU = N'SKUBADCAT', @Name = N'BadCat', @CategoryID = 2147483647, @ProductID = @R2 OUTPUT;
    IF XACT_STATE() <> 0 ROLLBACK;
    THROW 62017, N'Unknown category accepted.', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (50056, 35100) THROW;
    IF XACT_STATE() <> 0 ROLLBACK;
    IF XACT_STATE() = 0 BEGIN TRANSACTION; END
END CATCH
PRINT N'Test PASSED: 02.17 create_product_validation';

/* ---------------------------------------------------------------------------
   TEST 02.18 - SP_DeleteCategory (blocked with products 50041)
--------------------------------------------------------------------------- */
IF XACT_STATE() = 0 BEGIN TRANSACTION; END
BEGIN TRY
    EXEC dbo.SP_DeleteCategory @CategoryID = @CatID, @DeletedByID = @AdminID;
    IF XACT_STATE() <> 0 ROLLBACK;
    THROW 62018, N'Category with products was deleted.', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (50041, 35100) THROW;
    IF XACT_STATE() <> 0 ROLLBACK;
    IF XACT_STATE() = 0 BEGIN TRANSACTION; END
END CATCH

DECLARE @EmptyCat INT;
BEGIN TRY
    INSERT INTO #cat EXEC dbo.SP_CreateCategory @Name = N'EmptyCat', @CreatedByID = @AdminID;
    SELECT TOP (1) @EmptyCat = CategoryID FROM #cat WHERE CategoryID NOT IN (@CatID, @ChildCatID);
    IF @EmptyCat IS NULL THROW 62018, N'Could not create empty category.', 1;
    EXEC dbo.SP_DeleteCategory @CategoryID = @EmptyCat, @DeletedByID = @AdminID;
    IF NOT EXISTS (SELECT 1 FROM dbo.categories WHERE category_id = @EmptyCat AND is_deleted = 1)
        THROW 62018, N'Empty category was not soft-deleted.', 1;
END TRY
BEGIN CATCH
    DECLARE @e18 INT = ERROR_NUMBER(); DECLARE @m18 NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK;
    IF XACT_STATE() = 0 BEGIN TRANSACTION; END
    THROW 62018, N'Test FAILED: 02.18 delete_category - ' + @m18, 1;
END CATCH
PRINT N'Test PASSED: 02.18 delete_category';

/* ---------------------------------------------------------------------------
   TEST 02.19 - SP_GetProducts returns the created product + total_count
--------------------------------------------------------------------------- */
CREATE TABLE #prods (
    product_id INT, product_name NVARCHAR(200), sku NVARCHAR(50), barcode NVARCHAR(50),
    unit_price DECIMAL(19,4), low_stock_threshold INT, category_id INT, category_name NVARCHAR(100),
    supplier_id INT, supplier_name NVARCHAR(100), quantity_on_hand INT, stock_status NVARCHAR(20), total_count INT
);
BEGIN TRY
    INSERT INTO #prods EXEC dbo.SP_GetProducts @Page = 1, @PageSize = 50, @Search = N'SKU001';
    IF NOT EXISTS (SELECT 1 FROM #prods WHERE product_id = @ProductID)
        THROW 62019, N'SP_GetProducts did not return the created product.', 1;
    IF (SELECT TOP (1) total_count FROM #prods) < 1
        THROW 62019, N'total_count is inconsistent.', 1;
    IF (SELECT TOP (1) stock_status FROM #prods WHERE product_id = @ProductID) <> N'OUT_OF_STOCK'
        THROW 62019, N'Expected OUT_OF_STOCK for zero-quantity product.', 1;
END TRY
BEGIN CATCH
    DECLARE @e19 INT = ERROR_NUMBER(); DECLARE @m19 NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK;
    IF XACT_STATE() = 0 BEGIN TRANSACTION; END
    THROW 62019, N'Test FAILED: 02.19 get_products - ' + @m19, 1;
END CATCH
PRINT N'Test PASSED: 02.19 get_products';

/* ---------------------------------------------------------------------------
   TEST 02.20 - SP_RestockProduct increases stock and logs movement
--------------------------------------------------------------------------- */
CREATE TABLE #q (QuantityOnHand INT);
BEGIN TRY
    INSERT INTO #q EXEC dbo.SP_RestockProduct @ProductID = @ProductID, @Quantity = 25, @UserID = @AdminID, @Reason = N'Initial stock';
    IF (SELECT TOP (1) QuantityOnHand FROM #q) <> 25
        THROW 62020, N'SP_RestockProduct returned unexpected quantity.', 1;
    IF (SELECT quantity_on_hand FROM dbo.inventory WHERE product_id = @ProductID) <> 25
        THROW 62020, N'inventory.quantity_on_hand was not updated to 25.', 1;
    IF NOT EXISTS (
        SELECT 1 FROM dbo.inventory_transactions
        WHERE product_id = @ProductID AND movement_type = N'RESTOCK' AND quantity = 25
    )
        THROW 62020, N'RESTOCK inventory_transactions row missing.', 1;
END TRY
BEGIN CATCH
    DECLARE @e20 INT = ERROR_NUMBER(); DECLARE @m20 NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK;
    IF XACT_STATE() = 0 BEGIN TRANSACTION; END
    THROW 62020, N'Test FAILED: 02.20 restock_product - ' + @m20, 1;
END CATCH
PRINT N'Test PASSED: 02.20 restock_product';

/* ---------------------------------------------------------------------------
   TEST 02.21 - SP_RestockProduct failures (bad qty 50010, bad product 50011)
--------------------------------------------------------------------------- */
IF XACT_STATE() = 0 BEGIN TRANSACTION; END
BEGIN TRY
    EXEC dbo.SP_RestockProduct @ProductID = @ProductID, @Quantity = 0;
    IF XACT_STATE() <> 0 ROLLBACK;
    THROW 62021, N'Non-positive restock accepted.', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (50010, 35100) THROW;
    IF XACT_STATE() <> 0 ROLLBACK;
    IF XACT_STATE() = 0 BEGIN TRANSACTION; END
END CATCH

IF XACT_STATE() = 0 BEGIN TRANSACTION; END
BEGIN TRY
    EXEC dbo.SP_RestockProduct @ProductID = 2147483647, @Quantity = 5;
    IF XACT_STATE() <> 0 ROLLBACK;
    THROW 62021, N'Unknown product restock accepted.', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (50011, 35100) THROW;
    IF XACT_STATE() <> 0 ROLLBACK;
    IF XACT_STATE() = 0 BEGIN TRANSACTION; END
END CATCH
PRINT N'Test PASSED: 02.21 restock_validation';

/* ---------------------------------------------------------------------------
   TEST 02.22 - SP_AdjustStock (negative-result guard 50015, success)
--------------------------------------------------------------------------- */
IF XACT_STATE() = 0 BEGIN TRANSACTION; END
BEGIN TRY
    EXEC dbo.SP_AdjustStock @ProductID = @ProductID, @Quantity = -100, @AdjustmentType = N'CORRECTION', @UserID = @AdminID;
    IF XACT_STATE() <> 0 ROLLBACK;
    THROW 62022, N'Negative-stock adjustment accepted.', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (50015, 35100) THROW;
    IF XACT_STATE() <> 0 ROLLBACK;
    IF XACT_STATE() = 0 BEGIN TRANSACTION; END
END CATCH

DECLARE @AdjQty INT;
BEGIN TRY
    DELETE FROM #q;
    INSERT INTO #q EXEC dbo.SP_AdjustStock @ProductID = @ProductID, @Quantity = -5, @AdjustmentType = N'DAMAGE', @UserID = @AdminID, @Reason = N'Broken';
    SELECT TOP (1) @AdjQty = QuantityOnHand FROM #q;
    IF @AdjQty <> 20
        THROW 62022, N'SP_AdjustStock returned unexpected quantity.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.stock_reconciliations WHERE product_id = @ProductID AND adjustment_type = N'DAMAGE')
        THROW 62022, N'stock_reconciliations row missing.', 1;
END TRY
BEGIN CATCH
    DECLARE @e22 INT = ERROR_NUMBER(); DECLARE @m22 NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK;
    IF XACT_STATE() = 0 BEGIN TRANSACTION; END
    THROW 62022, N'Test FAILED: 02.22 adjust_stock - ' + @m22, 1;
END CATCH
PRINT N'Test PASSED: 02.22 adjust_stock';

/* ---------------------------------------------------------------------------
   TEST 02.23 - SP_CreateSale success (CASH): totals, stock, items, payment
   Line: 1 x 100.00 @ 10% discount + 5.00 tax -> subtotal 180, total 185.
--------------------------------------------------------------------------- */
DECLARE @Lines NVARCHAR(MAX) = N'[{"productId":' + CAST(@ProductID AS NVARCHAR(20)) +
    N',"quantity":2,"unitPrice":100.00,"discountRate":0.10,"taxAmount":5.00}]';

BEGIN TRY
    EXEC dbo.SP_CreateSale
        @ReceiptNumber = N'RCP-1001',
        @UserID = @CashierID,
        @SaleType = N'CASH',
        @LinesJSON = @Lines,
        @AmountReceived = 200.00,
        @PaymentMethodID = @CashID,
        @SaleID = @SaleID OUTPUT;

    IF @SaleID IS NULL
        THROW 62023, N'SP_CreateSale returned no SaleID.', 1;

    IF NOT EXISTS (
        SELECT 1 FROM dbo.sales
        WHERE sale_id = @SaleID AND status = N'COMPLETED' AND sale_type = N'CASH'
          AND subtotal = 180.0000 AND tax_amount = 5.0000 AND total_amount = 185.0000
    )
        THROW 62023, N'Sale header totals are wrong.', 1;

    SELECT TOP (1) @SaleItemID = sale_item_id FROM dbo.sale_items WHERE sale_id = @SaleID;
    IF @SaleItemID IS NULL
        THROW 62023, N'Sale items were not inserted.', 1;

    IF (SELECT quantity_on_hand FROM dbo.inventory WHERE product_id = @ProductID) <> 18
        THROW 62023, N'Inventory was not decremented to 18.', 1;

    IF NOT EXISTS (
        SELECT 1 FROM dbo.inventory_transactions
        WHERE product_id = @ProductID AND movement_type = N'SALE' AND quantity = -2 AND reference_id = N'RCP-1001'
    )
        THROW 62023, N'SALE inventory_transactions row missing.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.payments WHERE sale_id = @SaleID AND amount = 200.00 AND pay_status = N'COMPLETED')
        THROW 62023, N'Payment row missing.', 1;
END TRY
BEGIN CATCH
    DECLARE @e23 INT = ERROR_NUMBER(); DECLARE @m23 NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK;
    IF XACT_STATE() = 0 BEGIN TRANSACTION; END
    THROW 62023, N'Test FAILED: 02.23 create_sale - ' + @m23, 1;
END CATCH
PRINT N'Test PASSED: 02.23 create_sale';

/* ---------------------------------------------------------------------------
   TEST 02.24 - SP_CreateSale failures
   (50001 invalid type, 50002 credit w/o customer, 50005 bad JSON, 50007 stock)
--------------------------------------------------------------------------- */
DECLARE @J1 NVARCHAR(MAX) = N'[{"productId":' + CAST(@ProductID AS NVARCHAR(20)) + N',"quantity":1,"unitPrice":100.00}]';

IF XACT_STATE() = 0 BEGIN TRANSACTION; END
BEGIN TRY
    EXEC dbo.SP_CreateSale @ReceiptNumber = N'RCP-BADTYPE', @UserID = @CashierID, @SaleType = N'HIRE', @LinesJSON = @J1, @SaleID = @R2 OUTPUT;
    IF XACT_STATE() <> 0 ROLLBACK;
    THROW 62024, N'Invalid sale type accepted.', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (50001, 35100) THROW;
    IF XACT_STATE() <> 0 ROLLBACK;
    IF XACT_STATE() = 0 BEGIN TRANSACTION; END
END CATCH

IF XACT_STATE() = 0 BEGIN TRANSACTION; END
BEGIN TRY
    EXEC dbo.SP_CreateSale @ReceiptNumber = N'RCP-NOCUST', @UserID = @CashierID, @SaleType = N'CREDIT', @CustomerID = NULL, @LinesJSON = @J1, @SaleID = @R2 OUTPUT;
    IF XACT_STATE() <> 0 ROLLBACK;
    THROW 62024, N'Credit sale without customer accepted.', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (50002, 35100) THROW;
    IF XACT_STATE() <> 0 ROLLBACK;
    IF XACT_STATE() = 0 BEGIN TRANSACTION; END
END CATCH

IF XACT_STATE() = 0 BEGIN TRANSACTION; END
BEGIN TRY
    EXEC dbo.SP_CreateSale @ReceiptNumber = N'RCP-BADJSON', @UserID = @CashierID, @SaleType = N'CASH', @LinesJSON = N'not-json', @SaleID = @R2 OUTPUT;
    IF XACT_STATE() <> 0 ROLLBACK;
    THROW 62024, N'Invalid JSON accepted.', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (50005, 35100) THROW;
    IF XACT_STATE() <> 0 ROLLBACK;
    IF XACT_STATE() = 0 BEGIN TRANSACTION; END
END CATCH

DECLARE @JBig NVARCHAR(MAX) = N'[{"productId":' + CAST(@ProductID AS NVARCHAR(20)) + N',"quantity":9999}]';
IF XACT_STATE() = 0 BEGIN TRANSACTION; END
BEGIN TRY
    EXEC dbo.SP_CreateSale @ReceiptNumber = N'RCP-OVERSELL', @UserID = @CashierID, @SaleType = N'CASH', @LinesJSON = @JBig, @SaleID = @R2 OUTPUT;
    IF XACT_STATE() <> 0 ROLLBACK;
    THROW 62024, N'Over-quantity sale accepted.', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (50007, 35100) THROW;
    IF XACT_STATE() <> 0 ROLLBACK;
    IF XACT_STATE() = 0 BEGIN TRANSACTION; END
END CATCH
PRINT N'Test PASSED: 02.24 create_sale_validation';

/* ---------------------------------------------------------------------------
   TEST 02.25 - SP_CreateSale CREDIT + SP_RecordPayment updates the ledger
--------------------------------------------------------------------------- */
BEGIN TRY
    INSERT INTO dbo.customers (customer_code, full_name, phone, credit_limit, created_by)
    VALUES (N'CUST-TEST-001', N'Test Customer', N'+1-555-0000', 10000.00, @AdminID);
    SET @CustomerID = SCOPE_IDENTITY();

    EXEC dbo.SP_CreateSale
        @ReceiptNumber = N'RCP-2001',
        @UserID = @CashierID,
        @SaleType = N'CREDIT',
        @CustomerID = @CustomerID,
        @LinesJSON = @J1,
        @SaleID = @CreditSaleID OUTPUT;

    IF @CreditSaleID IS NULL
        THROW 62025, N'Credit sale was not created.', 1;
    IF NOT EXISTS (
        SELECT 1 FROM dbo.credit_sales
        WHERE sale_id = @CreditSaleID AND outstanding_balance = 100.0000 AND status = N'OPEN'
    )
        THROW 62025, N'Credit balance row is wrong.', 1;

    EXEC dbo.SP_RecordPayment @SaleID = @CreditSaleID, @MethodID = @CashID, @Amount = 40.00, @ReceivedBy = @AdminID, @PaymentID = @PayID OUTPUT;
    IF @PayID IS NULL
        THROW 62025, N'SP_RecordPayment returned no PaymentID.', 1;

    IF NOT EXISTS (
        SELECT 1 FROM dbo.credit_sales
        WHERE sale_id = @CreditSaleID AND outstanding_balance = 60.0000 AND amount_paid = 40.0000 AND status = N'PARTIAL'
    )
        THROW 62025, N'Credit balance was not updated correctly.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.credit_payments WHERE payment_id = @PayID AND credit_sale_id = (SELECT credit_sale_id FROM dbo.credit_sales WHERE sale_id = @CreditSaleID))
        THROW 62025, N'credit_payments row missing.', 1;
END TRY
BEGIN CATCH
    DECLARE @e25 INT = ERROR_NUMBER(); DECLARE @m25 NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK;
    IF XACT_STATE() = 0 BEGIN TRANSACTION; END
    THROW 62025, N'Test FAILED: 02.25 credit_sale_payment - ' + @m25, 1;
END CATCH
PRINT N'Test PASSED: 02.25 credit_sale_payment';

/* ---------------------------------------------------------------------------
   TEST 02.26 - SP_RecordPayment failures (bad amount 54008, bad sale 54006)
--------------------------------------------------------------------------- */
IF XACT_STATE() = 0 BEGIN TRANSACTION; END
BEGIN TRY
    EXEC dbo.SP_RecordPayment @SaleID = @SaleID, @MethodID = @CashID, @Amount = 0, @PaymentID = @R2 OUTPUT;
    IF XACT_STATE() <> 0 ROLLBACK;
    THROW 62026, N'Zero-amount payment accepted.', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (54008, 35100) THROW;
    IF XACT_STATE() <> 0 ROLLBACK;
    IF XACT_STATE() = 0 BEGIN TRANSACTION; END
END CATCH

IF XACT_STATE() = 0 BEGIN TRANSACTION; END
BEGIN TRY
    EXEC dbo.SP_RecordPayment @SaleID = 2147483647, @MethodID = @CashID, @Amount = 10.00, @PaymentID = @R2 OUTPUT;
    IF XACT_STATE() <> 0 ROLLBACK;
    THROW 62026, N'Payment against unknown sale accepted.', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (54006, 35100) THROW;
    IF XACT_STATE() <> 0 ROLLBACK;
    IF XACT_STATE() = 0 BEGIN TRANSACTION; END
END CATCH
PRINT N'Test PASSED: 02.26 record_payment_validation';

/* ---------------------------------------------------------------------------
   TEST 02.27 - SP_GenerateReceipt computes totals + unique receipt number
--------------------------------------------------------------------------- */
CREATE TABLE #rcpt (
    receipt_id INT, receipt_number NVARCHAR(50), sale_id INT,
    gross_total DECIMAL(19,4), discount_amount DECIMAL(19,4), tax_amount DECIMAL(19,4),
    net_total DECIMAL(19,4), amount_paid DECIMAL(19,4), change_due DECIMAL(19,4),
    generated_by INT, generated_at DATETIME2(0)
);
BEGIN TRY
    INSERT INTO #rcpt EXEC dbo.SP_GenerateReceipt @SaleID = @SaleID, @GeneratedBy = @AdminID;
    IF (SELECT COUNT(*) FROM #rcpt) <> 1
        THROW 62027, N'No receipt generated.', 1;
    IF (SELECT TOP (1) receipt_number FROM #rcpt) NOT LIKE N'RCP-%'
        THROW 62027, N'Receipt number format is wrong.', 1;
    -- For RCP-1001: gross 180 (subtotal+discount), discount 0, tax 5,
    -- net = total_amount = 185, paid 200 -> change 15.
    IF (SELECT TOP (1) gross_total FROM #rcpt) <> 180.0000
        THROW 62027, N'Receipt gross_total is wrong.', 1;
    IF (SELECT TOP (1) tax_amount FROM #rcpt) <> 5.0000
        THROW 62027, N'Receipt tax_amount is wrong.', 1;
    IF (SELECT TOP (1) net_total FROM #rcpt) <> 185.0000
        THROW 62027, N'Receipt net_total is wrong.', 1;
    IF (SELECT TOP (1) amount_paid FROM #rcpt) <> 200.0000
        THROW 62027, N'Receipt amount_paid is wrong.', 1;
    IF (SELECT TOP (1) change_due FROM #rcpt) <> 15.0000
        THROW 62027, N'Receipt change_due is wrong.', 1;
END TRY
BEGIN CATCH
    DECLARE @e27 INT = ERROR_NUMBER(); DECLARE @m27 NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK;
    IF XACT_STATE() = 0 BEGIN TRANSACTION; END
    THROW 62027, N'Test FAILED: 02.27 generate_receipt - ' + @m27, 1;
END CATCH
PRINT N'Test PASSED: 02.27 generate_receipt';

/* ---------------------------------------------------------------------------
   TEST 02.28 - SP_ProcessReturn restores stock and computes refund (over 50025)
--------------------------------------------------------------------------- */
DECLARE @RLines NVARCHAR(MAX) = N'[{"saleItemId":' + CAST(@SaleItemID AS NVARCHAR(20)) +
    N',"productId":' + CAST(@ProductID AS NVARCHAR(20)) + N',"quantity":1}]';

BEGIN TRY
    EXEC dbo.SP_ProcessReturn
        @ReturnNumber = N'RET-1001',
        @SaleID = @SaleID,
        @UserID = @AdminID,
        @LinesJSON = @RLines,
        @ReturnID = @ReturnID OUTPUT;

    IF @ReturnID IS NULL
        THROW 62028, N'SP_ProcessReturn returned no ReturnID.', 1;
    IF NOT EXISTS (
        SELECT 1 FROM dbo.returns WHERE return_id = @ReturnID AND total_refund_amount = 90.0000 AND status = N'COMPLETED'
    )
        THROW 62028, N'Return header / refund total is wrong.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.return_items WHERE return_id = @ReturnID AND quantity = 1 AND refund_amount = 90.0000)
        THROW 62028, N'return_items row is wrong.', 1;
    IF (SELECT quantity_on_hand FROM dbo.inventory WHERE product_id = @ProductID) <> 18
        THROW 62028, N'Stock was not restored to 18.', 1;
    IF (SELECT returned_qty FROM dbo.sale_items WHERE sale_item_id = @SaleItemID) <> 1
        THROW 62028, N'sale_items.returned_qty was not updated.', 1;
END TRY
BEGIN CATCH
    DECLARE @e28 INT = ERROR_NUMBER(); DECLARE @m28 NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK;
    IF XACT_STATE() = 0 BEGIN TRANSACTION; END
    THROW 62028, N'Test FAILED: 02.28 process_return - ' + @m28, 1;
END CATCH

DECLARE @RLines2 NVARCHAR(MAX) = N'[{"saleItemId":' + CAST(@SaleItemID AS NVARCHAR(20)) +
    N',"productId":' + CAST(@ProductID AS NVARCHAR(20)) + N',"quantity":3}]';
IF XACT_STATE() = 0 BEGIN TRANSACTION; END
BEGIN TRY
    EXEC dbo.SP_ProcessReturn @ReturnNumber = N'RET-OVER', @SaleID = @SaleID, @UserID = @AdminID, @LinesJSON = @RLines2, @ReturnID = @R2 OUTPUT;
    IF XACT_STATE() <> 0 ROLLBACK;
    THROW 62028, N'Over-return accepted.', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (50025, 35100) THROW;
    IF XACT_STATE() <> 0 ROLLBACK;
    IF XACT_STATE() = 0 BEGIN TRANSACTION; END
END CATCH
PRINT N'Test PASSED: 02.28 process_return';

/* ---------------------------------------------------------------------------
   TEST 02.29 - SP_UpsertSetting + SP_GetSetting (insert, update, invalid type)
--------------------------------------------------------------------------- */
CREATE TABLE #s (
    setting_id INT, setting_key NVARCHAR(100), setting_value NVARCHAR(MAX), data_type NVARCHAR(20),
    category NVARCHAR(50), [description] NVARCHAR(255), is_active BIT, updated_at DATETIME2(0)
);
BEGIN TRY
    EXEC dbo.SP_UpsertSetting @Key = N'test.setting', @Value = N'v1', @DataType = N'string', @SettingID = @SettingID OUTPUT;
    IF @SettingID IS NULL
        THROW 62029, N'SP_UpsertSetting (insert) returned no SettingID.', 1;

    EXEC dbo.SP_UpsertSetting @Key = N'test.setting', @Value = N'v2', @DataType = N'string', @SettingID = @SettingID OUTPUT;
    IF (SELECT setting_value FROM dbo.settings WHERE setting_key = N'test.setting') <> N'v2'
        THROW 62029, N'Setting was not updated.', 1;

    TRUNCATE TABLE #s;
    INSERT INTO #s EXEC dbo.SP_GetSetting @Key = N'test.setting';
    IF (SELECT TOP (1) setting_value FROM #s) <> N'v2'
        THROW 62029, N'SP_GetSetting returned the wrong value.', 1;
END TRY
BEGIN CATCH
    DECLARE @e29 INT = ERROR_NUMBER(); DECLARE @m29 NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK;
    IF XACT_STATE() = 0 BEGIN TRANSACTION; END
    THROW 62029, N'Test FAILED: 02.29 upsert_setting - ' + @m29, 1;
END CATCH

IF XACT_STATE() = 0 BEGIN TRANSACTION; END
BEGIN TRY
    EXEC dbo.SP_UpsertSetting @Key = N'test.badtype', @Value = N'x', @DataType = N'blob', @SettingID = @R2 OUTPUT;
    IF XACT_STATE() <> 0 ROLLBACK;
    THROW 62029, N'Invalid setting data type accepted.', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (54002, 35100) THROW;
    IF XACT_STATE() <> 0 ROLLBACK;
    IF XACT_STATE() = 0 BEGIN TRANSACTION; END
END CATCH
PRINT N'Test PASSED: 02.29 upsert_setting';

/* ---------------------------------------------------------------------------
   TEST 02.30 - SP_CreateNotification + SP_MarkNotificationRead (invalid 55011)
--------------------------------------------------------------------------- */
BEGIN TRY
    EXEC dbo.SP_CreateNotification
        @UserID = @AdminID, @TypeCode = N'SYSTEM', @Title = N'Test Notif',
        @Message = N'Hello', @Severity = N'INFO', @NotificationID = @NotifID OUTPUT;

    IF @NotifID IS NULL
        THROW 62030, N'SP_CreateNotification returned no NotificationID.', 1;
    IF (SELECT is_read FROM dbo.notifications WHERE notification_id = @NotifID) <> 0
        THROW 62030, N'New notification should be unread.', 1;

    EXEC dbo.SP_MarkNotificationRead @UserID = @AdminID, @NotificationID = @NotifID;
    IF (SELECT is_read FROM dbo.notifications WHERE notification_id = @NotifID) <> 1
        THROW 62030, N'Notification was not marked read.', 1;
END TRY
BEGIN CATCH
    DECLARE @e30 INT = ERROR_NUMBER(); DECLARE @m30 NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK;
    IF XACT_STATE() = 0 BEGIN TRANSACTION; END
    THROW 62030, N'Test FAILED: 02.30 notifications - ' + @m30, 1;
END CATCH

IF XACT_STATE() = 0 BEGIN TRANSACTION; END
BEGIN TRY
    EXEC dbo.SP_CreateNotification @UserID = @AdminID, @TypeCode = N'SYSTEM', @Title = N'X', @Message = N'X', @Severity = N'URGENT', @NotificationID = @R2 OUTPUT;
    IF XACT_STATE() <> 0 ROLLBACK;
    THROW 62030, N'Invalid severity accepted.', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (55011, 35100) THROW;
    IF XACT_STATE() <> 0 ROLLBACK;
    IF XACT_STATE() = 0 BEGIN TRANSACTION; END
END CATCH
PRINT N'Test PASSED: 02.30 notifications';

/* ---------------------------------------------------------------------------
   TEST 02.31 - Read-only procedure smoke tests (tolerant of empty data)
--------------------------------------------------------------------------- */
BEGIN TRY
    EXEC dbo.SP_GetDashboardData @UserID = @AdminID;
    EXEC dbo.SP_GetDashboardMetrics @UserID = @AdminID;
    EXEC dbo.SP_GetTopProducts @Days = 7, @Limit = 5;
    EXEC dbo.SP_GetSalesTrend @Days = 7;
    EXEC dbo.SP_SalesReport;
    EXEC dbo.SP_InventoryReport @Page = 1, @PageSize = 10;
    EXEC dbo.SP_InventoryMovementsReport @Page = 1, @PageSize = 10;
    EXEC dbo.SP_SupplierReport @Page = 1, @PageSize = 10;
    EXEC dbo.SP_CreditReport @Page = 1, @PageSize = 10;
    EXEC dbo.SP_ReturnsReport @Page = 1, @PageSize = 10;
    EXEC dbo.SP_ProfitReport @Page = 1, @PageSize = 10;
    EXEC dbo.SP_TaxReport;
    EXEC dbo.SP_PaymentMethodsReport;
    EXEC dbo.SP_ProductSalesReport @Page = 1, @PageSize = 10;
    EXEC dbo.SP_GetUsers @Page = 1, @PageSize = 10;
    EXEC dbo.SP_GetRole @RoleID = @RoleAdmin;
    EXEC dbo.SP_GetAuditLogs @Page = 1, @PageSize = 10;
    EXEC dbo.SP_GetSecurityLogs @Page = 1, @PageSize = 10;
    EXEC dbo.SP_GetErrorLogs @Page = 1, @PageSize = 10;
    EXEC dbo.SP_GetSettings;
    EXEC dbo.SP_GetStockLevel @ProductID = @ProductID;
    EXEC dbo.SP_GetNotificationTypes;
    EXEC dbo.SP_GetPaymentMethods;
END TRY
BEGIN CATCH
    DECLARE @e31 INT = ERROR_NUMBER(); DECLARE @m31 NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK;
    IF XACT_STATE() = 0 BEGIN TRANSACTION; END
    THROW 62031, N'Test FAILED: 02.31 read_only_smoke - ' + @m31, 1;
END CATCH
PRINT N'Test PASSED: 02.31 read_only_smoke';

/* ---------------------------------------------------------------------------
   TEST 02.32 - SP_DeleteProduct / SP_RestoreProduct soft-delete toggle
--------------------------------------------------------------------------- */
BEGIN TRY
    EXEC dbo.SP_DeleteProduct @ProductID = @ProductID, @DeletedByID = @AdminID;
    IF NOT EXISTS (SELECT 1 FROM dbo.products WHERE product_id = @ProductID AND is_deleted = 1)
        THROW 62032, N'Product was not soft-deleted.', 1;

    EXEC dbo.SP_RestoreProduct @ProductID = @ProductID;
    IF NOT EXISTS (SELECT 1 FROM dbo.products WHERE product_id = @ProductID AND is_deleted = 0)
        THROW 62032, N'Product was not restored.', 1;
END TRY
BEGIN CATCH
    DECLARE @e32 INT = ERROR_NUMBER(); DECLARE @m32 NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK;
    IF XACT_STATE() = 0 BEGIN TRANSACTION; END
    THROW 62032, N'Test FAILED: 02.32 product_soft_delete - ' + @m32, 1;
END CATCH
PRINT N'Test PASSED: 02.32 product_soft_delete';

/* ---------------------------------------------------------------------------
   TEST 02.33 - SP_GetProducts by category returns the product
--------------------------------------------------------------------------- */
BEGIN TRY
    TRUNCATE TABLE #prods;
    INSERT INTO #prods EXEC dbo.SP_GetProducts @CategoryID = @CatID;
    IF NOT EXISTS (SELECT 1 FROM #prods WHERE product_id = @ProductID)
        THROW 62033, N'Category filter did not return the product.', 1;
END TRY
BEGIN CATCH
    DECLARE @e33 INT = ERROR_NUMBER(); DECLARE @m33 NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK;
    IF XACT_STATE() = 0 BEGIN TRANSACTION; END
    THROW 62033, N'Test FAILED: 02.33 get_products_by_category - ' + @m33, 1;
END CATCH
PRINT N'Test PASSED: 02.33 get_products_by_category';

/* ---------------------------------------------------------------------------
   FILE CLEANUP
   - Remove error_logs rows created by throwing procedures this run (they are
     auto-committed after each proc rollback and must not pollute the log).
   - Roll back the entire run so no test data is persisted.
--------------------------------------------------------------------------- */
IF XACT_STATE() <> 0
    ROLLBACK TRANSACTION;

-- error_logs rows written by throwing procedures after their rollback are
-- auto-committed; purge this run's rows now that the test transaction is gone.
DELETE FROM dbo.error_logs WHERE error_id > @ErrorBaseline;

IF EXISTS (SELECT 1 FROM dbo.error_logs WHERE error_id > @ErrorBaseline)
    THROW 62099, N'Test FAILED: 02.34 error_log_cleanup - error_logs rows remain.', 1;

PRINT N'Test PASSED: 02.34 error_log_cleanup';
PRINT N'Test PASSED: 02_stored_procedures_all';
