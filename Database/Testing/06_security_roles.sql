/* ==========================================================================
   SmartPOS Database - TEST SUITE 06: SECURITY + RBAC
   --------------------------------------------------------------------------
   Verifies the role/permission grant matrix and security logging:
     - seed role grants: ADMIN 50 / MANAGER 34 / CASHIER 11 (95 total)
     - FN_HasPermission grant/deny matrix across roles
     - LOGIN_SUCCESS + LOGIN_FAILED captured in dbo.security_logs
     - account-disabled (40102) and account-locked (40103) login denials
     - role lifecycle via SPs (create -> grant -> update -> delete)
     - system-role protection (50037 / 50030)

   HARNESS
     - Phase A runs in AUTOCOMMIT (SP_Login rolls back the caller's
       transaction on failure via XACT_ABORT, so failed-login rows must be
       observed outside a transaction) and performs its own cleanup.
     - Phase B runs inside ONE transaction and rolls back at the end.
     - Success  -> PRINT N'Test PASSED: <name>'
     - Failure  -> THROW <code>, N'Test FAILED: <name>: <detail>', 1
   ========================================================================== */

SET NOCOUNT ON;

DECLARE @AdminID  INT = (SELECT TOP (1) user_id FROM dbo.users WHERE username = N'admin');
DECLARE @MgrID    INT = (SELECT TOP (1) user_id FROM dbo.users WHERE username = N'manager');
DECLARE @CashID   INT = (SELECT TOP (1) user_id FROM dbo.users WHERE username = N'cashier');
DECLARE @RoleCash INT = (SELECT TOP (1) role_id FROM dbo.roles WHERE role_code = N'CASHIER');
DECLARE @RoleAdmin INT = (SELECT TOP (1) role_id FROM dbo.roles WHERE role_code = N'ADMIN');

/* ===========================================================================
   PHASE A - SECURITY LOGGING (autocommit + self-cleaning)
   =========================================================================== */

DECLARE @BL_USERS   INT = (SELECT COUNT(*) FROM dbo.users);
DECLARE @BL_FAILED  INT = (SELECT COUNT(*) FROM dbo.security_logs WHERE event_type = N'LOGIN_FAILED');
DECLARE @BL_AUDIT   INT = (SELECT COUNT(*) FROM dbo.audit_logs);
DECLARE @SecUID     INT;
DECLARE @Lid        INT, @Sid INT;

-- A dedicated throwaway account so the seeded users are never touched.
INSERT INTO dbo.users (username, email, password_hash, full_name, role_id, must_change_password, is_active, is_locked)
VALUES (N'seclog', N'seclog@test.local', N'HASH_A', N'Sec Log User', @RoleCash, 0, 1, 0);
SET @SecUID = SCOPE_IDENTITY();
INSERT INTO dbo.password_history (user_id, password_hash, changed_at, changed_by)
VALUES (@SecUID, N'HASH_A', SYSUTCDATETIME(), @SecUID);

/* ---------------------------------------------------------------------------
   06.01 - Wrong password -> 40101 + LOGIN_FAILED row + attempt counter
--------------------------------------------------------------------------- */
BEGIN TRY
    EXEC dbo.SP_Login @UsernameOrEmail = N'seclog', @PasswordHash = N'WRONG';
    THROW 66001, N'Wrong password login did not fail.', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (40101, 35100) THROW;
END CATCH;

IF (SELECT COUNT(*) FROM dbo.security_logs WHERE event_type = N'LOGIN_FAILED') <> @BL_FAILED + 1
    THROW 66001, N'LOGIN_FAILED row was not written for a bad password.', 1;
IF (SELECT COUNT(*) FROM dbo.security_logs WHERE user_id = @SecUID AND event_type = N'LOGIN_FAILED') <> 1
    THROW 66001, N'LOGIN_FAILED row not attributed to the correct user.', 1;
IF (SELECT failed_login_attempts FROM dbo.users WHERE user_id = @SecUID) <> 1
    THROW 66001, N'failed_login_attempts was not incremented.', 1;

/* ---------------------------------------------------------------------------
   06.02 - Disabled account -> 40102
--------------------------------------------------------------------------- */
UPDATE dbo.users SET is_active = 0 WHERE user_id = @SecUID;
BEGIN TRY
    EXEC dbo.SP_Login @UsernameOrEmail = N'seclog', @PasswordHash = N'HASH_A';
    THROW 66002, N'Disabled account login did not fail.', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (40102, 35100) THROW;
END CATCH;
IF (SELECT COUNT(*) FROM dbo.security_logs WHERE user_id = @SecUID AND event_type = N'LOGIN_FAILED') <> 2
    THROW 66002, N'Disabled-account failure was not logged.', 1;

/* ---------------------------------------------------------------------------
   06.03 - Locked account -> 40103
--------------------------------------------------------------------------- */
UPDATE dbo.users SET is_active = 1, is_locked = 1 WHERE user_id = @SecUID;
BEGIN TRY
    EXEC dbo.SP_Login @UsernameOrEmail = N'seclog', @PasswordHash = N'HASH_A';
    THROW 66003, N'Locked account login did not fail.', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (40103, 35100) THROW;
END CATCH;
IF (SELECT COUNT(*) FROM dbo.security_logs WHERE user_id = @SecUID AND event_type = N'LOGIN_FAILED') <> 3
    THROW 66003, N'Locked-account failure was not logged.', 1;

/* ---------------------------------------------------------------------------
   06.04 - Valid login succeeds once unlocked and writes LOGIN_SUCCESS
--------------------------------------------------------------------------- */
UPDATE dbo.users SET is_active = 1, is_locked = 0, failed_login_attempts = 0 WHERE user_id = @SecUID;
DECLARE @Tok NVARCHAR(255) = CONVERT(NVARCHAR(255), NEWID());
DECLARE @BL_SUCCESS INT = (SELECT COUNT(*) FROM dbo.security_logs WHERE event_type = N'LOGIN_SUCCESS');

EXEC dbo.SP_Login
    @UsernameOrEmail = N'seclog', @PasswordHash = N'HASH_A',
    @IPAddress = N'10.1.1.1', @UserAgent = N'test',
    @HashedSessionToken = @Tok, @UserID = @Lid OUTPUT, @SessionID = @Sid OUTPUT;

IF @Lid <> @SecUID
    THROW 66004, N'Login returned the wrong UserID.', 1;
IF @Sid IS NULL
    THROW 66004, N'Login returned no SessionID.', 1;
IF (SELECT COUNT(*) FROM dbo.security_logs WHERE event_type = N'LOGIN_SUCCESS') <> @BL_SUCCESS + 1
    THROW 66004, N'LOGIN_SUCCESS row was not written.', 1;
IF NOT EXISTS (SELECT 1 FROM dbo.security_logs WHERE user_id = @SecUID AND event_type = N'LOGIN_SUCCESS')
    THROW 66004, N'LOGIN_SUCCESS row not attributed to the user.', 1;
IF EXISTS (SELECT 1 FROM dbo.security_logs WHERE [message] LIKE N'%HASH_A%')
    THROW 66004, N'Password hash leaked into security log.', 1;

-- Phase A cleanup: remove every trace of the throwaway account.
DELETE FROM dbo.security_logs WHERE user_id = @SecUID;
DELETE FROM dbo.user_sessions  WHERE user_id = @SecUID;
DELETE FROM dbo.password_history WHERE user_id = @SecUID;
DELETE FROM dbo.audit_logs WHERE resource_type = N'User' AND resource_id = CAST(@SecUID AS NVARCHAR(100));
DELETE FROM dbo.users WHERE user_id = @SecUID;
-- TRG_users_audit fires on the DELETE above and writes a fresh audit row.
DELETE FROM dbo.audit_logs WHERE resource_type = N'User' AND resource_id = CAST(@SecUID AS NVARCHAR(100));

IF (SELECT COUNT(*) FROM dbo.users) <> @BL_USERS
    THROW 66005, N'Phase A cleanup left user rows behind.', 1;
IF (SELECT COUNT(*) FROM dbo.security_logs WHERE event_type = N'LOGIN_FAILED') <> @BL_FAILED
    THROW 66005, N'Phase A cleanup left LOGIN_FAILED rows behind.', 1;
IF (SELECT COUNT(*) FROM dbo.audit_logs) <> @BL_AUDIT
    THROW 66005, N'Phase A cleanup left audit rows behind.', 1;

PRINT N'Test PASSED: 06.01-06.05 security_logging';

/* ===========================================================================
   PHASE B - RBAC MATRIX + ROLE LIFECYCLE (transactional, rolled back)
   =========================================================================== */

CREATE TABLE #roles (
    role_id INT, role_code NVARCHAR(50), role_name NVARCHAR(100), [description] NVARCHAR(255),
    is_system BIT, is_active BIT, created_at DATETIME2(0), updated_at DATETIME2(0),
    created_by INT, updated_by INT, permission_count INT
);

BEGIN TRANSACTION;

BEGIN TRY

    /* ------------------------------------------------------------------ */
    /* 06.06 - Seed grant matrix: ADMIN 50 / MANAGER 34 / CASHIER 11       */
    /* ------------------------------------------------------------------ */
    INSERT INTO #roles EXEC dbo.SP_GetRoles;

    IF (SELECT permission_count FROM #roles WHERE role_code = N'ADMIN') <> 50
        THROW 66006, N'ADMIN permission_count <> 50.', 1;
    IF (SELECT permission_count FROM #roles WHERE role_code = N'MANAGER') <> 34
        THROW 66006, N'MANAGER permission_count <> 34.', 1;
    IF (SELECT permission_count FROM #roles WHERE role_code = N'CASHIER') <> 11
        THROW 66006, N'CASHIER permission_count <> 11.', 1;

    IF (SELECT COUNT(*) FROM dbo.role_permissions) <> 95
        THROW 66006, N'Total role_permissions <> 95.', 1;

    -- Cross-check with the operational view.
    IF (SELECT COUNT(*) FROM dbo.VW_UserPermissions WHERE user_id = @AdminID) <> 50
        THROW 66006, N'VW_UserPermissions admin row count <> 50.', 1;
    IF (SELECT COUNT(*) FROM dbo.VW_UserPermissions WHERE user_id = @MgrID) <> 34
        THROW 66006, N'VW_UserPermissions manager row count <> 34.', 1;
    IF (SELECT COUNT(*) FROM dbo.VW_UserPermissions WHERE user_id = @CashID) <> 11
        THROW 66006, N'VW_UserPermissions cashier row count <> 11.', 1;

    /* ------------------------------------------------------------------ */
    /* 06.07 - FN_HasPermission grant/deny matrix                          */
    /* ------------------------------------------------------------------ */
    -- Admin has everything.
    IF dbo.FN_HasPermission(@AdminID, N'users.delete') <> 1 OR dbo.FN_HasPermission(@AdminID, N'audit.view') <> 1
        THROW 66007, N'Admin missing expected grants.', 1;
    -- Manager: operational modules yes, administration modules no.
    IF dbo.FN_HasPermission(@MgrID, N'products.create') <> 1 OR dbo.FN_HasPermission(@MgrID, N'sales.view') <> 1
        THROW 66007, N'Manager missing operational grants.', 1;
    IF dbo.FN_HasPermission(@MgrID, N'users.view') <> 0 OR dbo.FN_HasPermission(@MgrID, N'settings.view') <> 0
        THROW 66007, N'Manager has administration grants it must not have.', 1;
    IF dbo.FN_HasPermission(@MgrID, N'credit_sales.view') <> 0
        THROW 66007, N'Manager must not see credit_sales.view.', 1;
    -- Cashier: POS duties only.
    IF dbo.FN_HasPermission(@CashID, N'sales.create') <> 1 OR dbo.FN_HasPermission(@CashID, N'products.view') <> 1
        THROW 66007, N'Cashier missing POS grants.', 1;
    IF dbo.FN_HasPermission(@CashID, N'users.view') <> 0 OR dbo.FN_HasPermission(@CashID, N'payments.create') <> 0
        THROW 66007, N'Cashier has grants beyond its scope.', 1;

    /* ------------------------------------------------------------------ */
    /* 06.08 - Role lifecycle: create -> grant -> update -> delete         */
    /* ------------------------------------------------------------------ */
    DECLARE @RoleX INT, @RoleU INT, @UX INT;
    DECLARE @CX1 NVARCHAR(MAX) = N'products.view,sales.view,users.view';

    EXEC dbo.SP_CreateRole @RoleCode = N'SUPPLIER_OPS', @RoleName = N'Supplier Ops',
         @PermissionCodesCSV = @CX1, @CreatedBy = @AdminID, @RoleID = @RoleX OUTPUT;
    IF @RoleX IS NULL
        THROW 66008, N'SP_CreateRole returned no RoleID.', 1;

    INSERT INTO dbo.users (username, email, password_hash, full_name, role_id, must_change_password, is_active, is_locked)
    VALUES (N'rbackuser', N'rbackuser@test.local', N'HASH_B', N'RBAC User', @RoleX, 0, 1, 0);
    SET @RoleU = SCOPE_IDENTITY();

    IF dbo.FN_HasPermission(@RoleU, N'products.view') <> 1 OR dbo.FN_HasPermission(@RoleU, N'users.view') <> 1
        THROW 66008, N'Role grant not visible via FN_HasPermission.', 1;
    IF dbo.FN_HasPermission(@RoleU, N'audit.view') <> 0
        THROW 66008, N'Ungranted permission unexpectedly visible.', 1;

    -- Replace the permission set: drop products.view and users.view.
    EXEC dbo.SP_UpdateRole @RoleID = @RoleX, @RoleName = N'Supplier Ops v2',
         @PermissionCodesCSV = N'sales.view', @UpdatedBy = @AdminID;

    IF dbo.FN_HasPermission(@RoleU, N'products.view') <> 0 OR dbo.FN_HasPermission(@RoleU, N'users.view') <> 0
        THROW 66008, N'SP_UpdateRole did not replace the permission set.', 1;
    IF dbo.FN_HasPermission(@RoleU, N'sales.view') <> 1
        THROW 66008, N'SP_UpdateRole dropped a retained grant.', 1;

    -- A role still assigned to an active user cannot be deleted (50039).
    BEGIN TRY
        EXEC dbo.SP_DeleteRole @RoleID = @RoleX;
        THROW 66008, N'Deleting an assigned role did not fail.', 1;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() NOT IN (50039, 35100) THROW;
    END CATCH;

    -- Soft-delete the user, then the role deletes cleanly.
    UPDATE dbo.users SET is_deleted = 1 WHERE user_id = @RoleU;
    EXEC dbo.SP_DeleteRole @RoleID = @RoleX;
    IF EXISTS (SELECT 1 FROM dbo.roles WHERE role_id = @RoleX)
        THROW 66008, N'Role was not deleted.', 1;
    IF EXISTS (SELECT 1 FROM dbo.role_permissions WHERE role_id = @RoleX)
        THROW 66008, N'Role permission grants were not removed.', 1;

    /* ------------------------------------------------------------------ */
    /* 06.09 - System-role protection                                       */
    /* ------------------------------------------------------------------ */
    -- Permission-set replacement on ADMIN is blocked (50037).
    BEGIN TRY
        EXEC dbo.SP_UpdateRole @RoleID = @RoleAdmin, @RoleName = N'Administrator', @PermissionCodesCSV = N'products.view', @UpdatedBy = @AdminID;
        THROW 66009, N'System-role permission replacement did not fail.', 1;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() NOT IN (50037, 35100) THROW;
    END CATCH;

    -- Deleting a system role is blocked (50030).
    BEGIN TRY
        EXEC dbo.SP_DeleteRole @RoleID = @RoleAdmin;
        THROW 66009, N'System-role deletion did not fail.', 1;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() NOT IN (50030, 35100) THROW;
    END CATCH;

    -- The protected role is untouched.
    IF (SELECT permission_count FROM #roles WHERE role_code = N'ADMIN') <> 50
        THROW 66009, N'ADMIN grant set was modified.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.roles WHERE role_id = @RoleAdmin AND role_code = N'ADMIN')
        THROW 66009, N'ADMIN role was removed.', 1;

END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW 66099, N'Test FAILED: 06_security_roles - ' + ERROR_MESSAGE(), 1;
END CATCH;

/* ---------------------------------------------------------------------------
   FILE CLEANUP: roll back the entire Phase B run
--------------------------------------------------------------------------- */
IF XACT_STATE() <> 0
    ROLLBACK TRANSACTION;

PRINT N'Test PASSED: 06_security_roles_all';
