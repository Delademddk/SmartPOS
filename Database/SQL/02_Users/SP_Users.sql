/* ==========================================================================
   SmartPOS Database - MODULE 02: USER MANAGEMENT
   --------------------------------------------------------------------------
   SP_GetUsers                - paginated, filtered user list with role name
   SP_GetUser                 - single user with role name
   SP_CreateUser             - create a user + first password history row
   SP_UpdateUser             - update profile / role / active flag
   SP_DeactivateUser         - deactivate + revoke all sessions
   SP_ResetPassword          - admin resets a password (revokes sessions)
   SP_ChangePassword         - user changes their own password
   SP_RequestPasswordReset   - issue a one-time reset token
   SP_CompletePasswordReset  - consume a token and set a new password

   Depends on: dbo.users, dbo.user_sessions, dbo.password_history,
               dbo.password_resets, dbo.activity_logs, dbo.security_logs,
               dbo.error_logs.
   Conventions: SP_<Purpose>, snake_case, transactional multi-table writes,
               structured TRY...CATCH + THROW.
   ========================================================================== */

/* ---------------------------------------------------------------------------
   SP_GetUsers
   Paginated, filtered list. Supports keyword search across username, email,
   full name and phone, optional role filter, and a stable sort key. Returns a
   total_count for the caller plus the page of rows.
---------------------------------------------------------------------------*/
IF OBJECT_ID(N'dbo.SP_GetUsers', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_GetUsers;
GO
CREATE PROCEDURE dbo.SP_GetUsers
    @Page       INT = 1,
    @PageSize   INT = 20,
    @Search     NVARCHAR(255) = NULL,
    @RoleID     INT = NULL,
    @SortBy     NVARCHAR(50) = N'created_at DESC',
    @IncludeInactive BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Offset INT;
    DECLARE @Total INT;

    IF @Page < 1 SET @Page = 1;
    IF @PageSize < 1 SET @PageSize = 20;
    IF @PageSize > 200 SET @PageSize = 200;
    SET @Offset = (@Page - 1) * @PageSize;

    SET @Search = NULLIF(LTRIM(RTRIM(@Search)), N'');
    IF @Search IS NOT NULL SET @Search = N'%' + @Search + N'%';

    -- Total count
    SELECT @Total = COUNT(*)
    FROM dbo.users u
    WHERE (@Search IS NULL
           OR u.username LIKE @Search
           OR u.email    LIKE @Search
           OR u.full_name LIKE @Search
           OR u.phone    LIKE @Search)
      AND (@RoleID IS NULL OR u.role_id = @RoleID)
      AND (@IncludeInactive = 1 OR u.is_active = 1);

    SELECT
        u.user_id,
        u.username,
        u.email,
        u.full_name,
        u.phone,
        u.role_id,
        r.role_name,
        u.is_active,
        u.is_locked,
        u.must_change_password,
        u.last_login_at,
        u.last_login_ip,
        u.created_at,
        u.updated_at,
        @Total AS total_count
    FROM dbo.users u
    LEFT JOIN dbo.roles r ON r.role_id = u.role_id
    WHERE (@Search IS NULL
           OR u.username  LIKE @Search
           OR u.email     LIKE @Search
           OR u.full_name LIKE @Search
           OR u.phone     LIKE @Search)
      AND (@RoleID IS NULL OR u.role_id = @RoleID)
      AND (@IncludeInactive = 1 OR u.is_active = 1)
    ORDER BY CASE WHEN @SortBy = 'name'      THEN u.full_name END,
             CASE WHEN @SortBy = 'username'  THEN u.username   END,
             CASE WHEN @SortBy = 'email'     THEN u.email      END,
             CASE WHEN @SortBy = 'role'       THEN r.role_name  END,
             u.created_at DESC
    OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

/* ---------------------------------------------------------------------------
   SP_GetUser
   Returns one user with its role name, or an empty set if not found.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_GetUser', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_GetUser;
GO
CREATE PROCEDURE dbo.SP_GetUser
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        u.user_id,
        u.username,
        u.email,
        u.full_name,
        u.phone,
        u.role_id,
        r.role_code,
        r.role_name,
        u.is_active,
        u.is_locked,
        u.failed_login_attempts,
        u.must_change_password,
        u.last_login_at,
        u.last_login_ip,
        u.created_at,
        u.updated_at
    FROM dbo.users u
    LEFT JOIN dbo.roles r ON r.role_id = u.role_id
    WHERE u.user_id = @UserID;
END
GO

/* ---------------------------------------------------------------------------
   SP_CreateUser
   Validates unique username/email and a valid active role, inserts the user,
   and stores the first password history entry.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_CreateUser', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_CreateUser;
GO
CREATE PROCEDURE dbo.SP_CreateUser
    @Username        NVARCHAR(50),
    @Email           NVARCHAR(255),
    @PasswordHash    NVARCHAR(255),
    @FullName        NVARCHAR(150),
    @Phone           NVARCHAR(30) = NULL,
    @RoleID          INT,
    @CreatedByID     INT = NULL,
    @MustChangePassword BIT = 1,
    @UserID          INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Now DATETIME2(0) = SYSUTCDATETIME();

    BEGIN TRY
        -- ----------------------------------------------------------------
        -- Validation
        -- ----------------------------------------------------------------
        SET @Username = LTRIM(RTRIM(ISNULL(@Username, N'')));
        SET @Email    = LTRIM(RTRIM(ISNULL(@Email, N'')));

        IF LEN(@Username) < 3
            THROW 52001, N'Username must be at least 3 characters.', 1;

        IF NULLIF(@Email, N'') IS NULL OR @Email NOT LIKE N'%_@_%._%'
            THROW 52002, N'A valid email is required.', 1;

        IF NULLIF(@PasswordHash, N'') IS NULL
            THROW 52003, N'A password hash is required.', 1;

        IF EXISTS (SELECT 1 FROM dbo.users WHERE username = @Username)
            THROW 52004, N'Username already exists.', 1;

        IF EXISTS (SELECT 1 FROM dbo.users WHERE email = @Email)
            THROW 52005, N'Email already exists.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.roles WHERE role_id = @RoleID AND is_active = 1)
            THROW 52006, N'Role does not exist or is inactive.', 1;

        BEGIN TRANSACTION;

        INSERT INTO dbo.users
            (username, email, password_hash, full_name, phone, role_id,
             is_active, is_locked, failed_login_attempts, must_change_password,
             created_at, updated_at, created_by)
        VALUES
            (@Username, @Email, @PasswordHash, LTRIM(RTRIM(@FullName)), @Phone, @RoleID,
             1, 0, 0, @MustChangePassword, @Now, @Now, @CreatedByID);

        SET @UserID = SCOPE_IDENTITY();

        -- Seed password history (the current hash)
        INSERT INTO dbo.password_history (user_id, password_hash, changed_at, changed_by)
        VALUES (@UserID, @PasswordHash, @Now, @CreatedByID);

        INSERT INTO dbo.activity_logs
            (user_id, activity_type, activity_desc, entity_type, entity_id, metadata, created_at)
        VALUES
            (@CreatedByID, N'USER_CREATED', N'Created user ' + @Username,
             N'User', CAST(@UserID AS NVARCHAR(20)), NULL, @Now);

        COMMIT TRANSACTION;

        SELECT @UserID AS UserID;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        INSERT INTO dbo.error_logs (user_id, error_code, message, stack_trace, source)
        VALUES (@CreatedByID, N'SP_CreateUser', ERROR_MESSAGE(), ERROR_PROCEDURE(), N'SP_CreateUser');
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------------
   SP_UpdateUser
   Updates profile fields and role. Sets the audit trail (updated_by/at).
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_UpdateUser', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_UpdateUser;
GO
CREATE PROCEDURE dbo.SP_UpdateUser
    @UserID       INT,
    @FullName     NVARCHAR(150),
    @Phone        NVARCHAR(30) = NULL,
    @RoleID       INT,
    @IsActive     BIT = NULL,
    @UpdatedByID  INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Now DATETIME2(0) = SYSUTCDATETIME();

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.users WHERE user_id = @UserID)
            THROW 52010, N'User not found.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.roles WHERE role_id = @RoleID AND is_active = 1)
            THROW 52006, N'Role does not exist or is inactive.', 1;

        BEGIN TRANSACTION;

        UPDATE dbo.users
        SET full_name   = LTRIM(RTRIM(ISNULL(@FullName, full_name))),
            phone       = @Phone,
            role_id     = @RoleID,
            is_active   = ISNULL(@IsActive, is_active),
            updated_at  = @Now,
            updated_by  = @UpdatedByID
        WHERE user_id = @UserID;

        INSERT INTO dbo.activity_logs
            (user_id, activity_type, activity_desc, entity_type, entity_id, metadata, created_at)
        VALUES
            (@UpdatedByID, N'USER_UPDATED', N'Updated user ' + CAST(@UserID AS NVARCHAR(20)),
             N'User', CAST(@UserID AS NVARCHAR(20)), NULL, @Now);

        COMMIT TRANSACTION;

        SELECT @UserID AS UserID;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        INSERT INTO dbo.error_logs (user_id, error_code, message, stack_trace, source)
        VALUES (@UpdatedByID, N'SP_UpdateUser', ERROR_MESSAGE(), ERROR_PROCEDURE(), N'SP_UpdateUser');
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------------
   SP_DeactivateUser
   Sets is_active = 0 and revokes every active session. Logs activity.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_DeactivateUser', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_DeactivateUser;
GO
CREATE PROCEDURE dbo.SP_DeactivateUser
    @UserID       INT,
    @UpdatedByID  INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Now DATETIME2(0) = SYSUTCDATETIME();
    DECLARE @Username NVARCHAR(50);

    BEGIN TRY
        IF @UserID IS NULL
            THROW 52011, N'A user ID is required.', 1;

        SELECT @Username = username
        FROM dbo.users WHERE user_id = @UserID;

        IF @Username IS NULL
            THROW 52010, N'User not found.', 1;

        -- A user cannot deactivate themselves
        IF @UserID = @UpdatedByID
            THROW 52012, N'You cannot deactivate your own account.', 1;

        BEGIN TRANSACTION;

        UPDATE dbo.users
        SET is_active = 0,
            updated_at = @Now,
            updated_by = @UpdatedByID
        WHERE user_id = @UserID;

        UPDATE dbo.user_sessions
        SET is_revoked = 1,
            revoked_at = @Now,
            revoked_by = @UpdatedByID
        WHERE user_id = @UserID AND is_revoked = 0;

        INSERT INTO dbo.activity_logs
            (user_id, activity_type, activity_desc, entity_type, entity_id, metadata, created_at)
        VALUES
            (@UpdatedByID, N'USER_DEACTIVATED',
             N'Deactivated user ' + @Username,
             N'User', CAST(@UserID AS NVARCHAR(20)), NULL, @Now);

        COMMIT TRANSACTION;

        SELECT @UserID AS UserID;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        INSERT INTO dbo.error_logs (user_id, error_code, message, stack_trace, source)
        VALUES (@UpdatedByID, N'SP_DeactivateUser', ERROR_MESSAGE(), ERROR_PROCEDURE(), N'SP_DeactivateUser');
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------------
   SP_ResetPassword
   Admin-override password reset: stores the supplied (already-hashed) value,
   clears must_change_password, records history, revokes all sessions and
   closes outstanding reset requests.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_ResetPassword', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_ResetPassword;
GO
CREATE PROCEDURE dbo.SP_ResetPassword
    @UserID         INT,
    @NewPasswordHash NVARCHAR(255),
    @ResetByID      INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Now DATETIME2(0) = SYSUTCDATETIME();
    DECLARE @Username NVARCHAR(50);

    BEGIN TRY
        IF NULLIF(@NewPasswordHash, N'') IS NULL
            THROW 52013, N'A new password hash is required.', 1;

        SELECT @Username = username
        FROM dbo.users WHERE user_id = @UserID;

        IF @Username IS NULL
            THROW 52010, N'User not found.', 1;

        BEGIN TRANSACTION;

        UPDATE dbo.users
        SET password_hash = @NewPasswordHash,
            must_change_password = 0,
            failed_login_attempts = 0,
            updated_at = @Now,
            updated_by = @ResetByID
        WHERE user_id = @UserID;

        INSERT INTO dbo.password_history (user_id, password_hash, changed_at, changed_by)
        VALUES (@UserID, @NewPasswordHash, @Now, @ResetByID);

        -- Revoke all existing sessions
        UPDATE dbo.user_sessions
        SET is_revoked = 1, revoked_at = @Now, revoked_by = @ResetByID
        WHERE user_id = @UserID AND is_revoked = 0;

        -- Purge outstanding reset tokens for this user
        DELETE FROM dbo.password_resets WHERE user_id = @UserID;

        INSERT INTO dbo.activity_logs
            (user_id, activity_type, activity_desc, entity_type, entity_id, metadata, created_at)
        VALUES
            (@ResetByID, N'PASSWORD_RESET',
             N'Password reset for ' + @Username,
             N'User', CAST(@UserID AS NVARCHAR(20)), NULL, @Now);

        COMMIT TRANSACTION;

        SELECT @UserID AS UserID;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        INSERT INTO dbo.error_logs (user_id, error_code, message, stack_trace, source)
        VALUES (@ResetByID, N'SP_ResetPassword', ERROR_MESSAGE(), ERROR_PROCEDURE(), N'SP_ResetPassword');
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------------
   SP_ChangePassword
   Verifies the caller-supplied current hash, then sets the new one, records
   history and revokes every other active session (keeps the current one).
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_ChangePassword', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_ChangePassword;
GO
CREATE PROCEDURE dbo.SP_ChangePassword
    @UserID            INT,
    @CurrentPasswordHash NVARCHAR(255),
    @NewPasswordHash   NVARCHAR(255),
    @CurrentSessionTokenHash NVARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Now DATETIME2(0) = SYSUTCDATETIME();
    DECLARE @Stored NVARCHAR(255);

    BEGIN TRY
        IF NULLIF(@NewPasswordHash, N'') IS NULL
            THROW 52013, N'A new password hash is required.', 1;

        SELECT @Stored = password_hash
        FROM dbo.users WHERE user_id = @UserID;

        IF @Stored IS NULL
            THROW 52010, N'User not found.', 1;

        IF @Stored <> @CurrentPasswordHash
            THROW 52014, N'Current password is incorrect.', 1;

        BEGIN TRANSACTION;

        UPDATE dbo.users
        SET password_hash = @NewPasswordHash,
            must_change_password = 0,
            failed_login_attempts = 0,
            updated_at = @Now
        WHERE user_id = @UserID;

        INSERT INTO dbo.password_history (user_id, password_hash, changed_at, changed_by)
        VALUES (@UserID, @NewPasswordHash, @Now, @UserID);

        -- Revoke all OTHER sessions, preserving the current one when known
        UPDATE dbo.user_sessions
        SET is_revoked = 1, revoked_at = @Now, revoked_by = @UserID
        WHERE user_id = @UserID
          AND is_revoked = 0
          AND (@CurrentSessionTokenHash IS NULL OR session_token <> @CurrentSessionTokenHash);

        INSERT INTO dbo.activity_logs
            (user_id, activity_type, activity_desc, entity_type, entity_id, metadata, created_at)
        VALUES
            (@UserID, N'PASSWORD_CHANGED', N'User changed own password',
             N'User', CAST(@UserID AS NVARCHAR(20)), NULL, @Now);

        COMMIT TRANSACTION;

        SELECT @UserID AS UserID;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        INSERT INTO dbo.error_logs (user_id, error_code, message, stack_trace, source)
        VALUES (@UserID, N'SP_ChangePassword', ERROR_MESSAGE(), ERROR_PROCEDURE(), N'SP_ChangePassword');
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------------
   SP_RequestPasswordReset
   Issues a one-time reset token for the given email. Always logs a security
   event; returns the created reset id (the token is hashed by the caller, so
   this returns the user id only, without leaking the token).
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_RequestPasswordReset', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_RequestPasswordReset;
GO
CREATE PROCEDURE dbo.SP_RequestPasswordReset
    @UserEmail   NVARCHAR(255),
    @HashedToken NVARCHAR(255),
    @IPAddress   NVARCHAR(45) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Now DATETIME2(0) = SYSUTCDATETIME();
    DECLARE @UserId INT;

    BEGIN TRY
        IF NULLIF(@HashedToken, N'') IS NULL
            THROW 52020, N'A reset token is required.', 1;

        SELECT @UserId = user_id
        FROM dbo.users
        WHERE email = @UserEmail AND is_deleted = 0 AND is_active = 1;

        BEGIN TRANSACTION;

        IF @UserId IS NOT NULL
        BEGIN
            INSERT INTO dbo.password_resets
                (user_id, reset_token, ip_address, requested_at, expires_at)
            VALUES
                (@UserId, @HashedToken, @IPAddress, @Now, DATEADD(hour, 1, @Now));
        END

        -- Always log so enumeration is not possible
        INSERT INTO dbo.security_logs
            (user_id, event_type, username, ip_address, user_agent, message, created_at)
        VALUES
            (@UserId, N'RESET', NULL, @IPAddress, NULL,
             N'Password reset requested.', @Now);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        INSERT INTO dbo.error_logs (user_id, error_code, message, stack_trace, source)
        VALUES (@UserId, N'SP_RequestPasswordReset', ERROR_MESSAGE(), ERROR_PROCEDURE(), N'SP_RequestPasswordReset');
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------------
   SP_CompletePasswordReset
   Validates an unused, unexpired token, then applies a new password hash,
   marks the token used, records history, revokes all sessions and deletes
   any other outstanding tokens for that user.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_CompletePasswordReset', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_CompletePasswordReset;
GO
CREATE PROCEDURE dbo.SP_CompletePasswordReset
    @HashedToken     NVARCHAR(255),
    @NewPasswordHash NVARCHAR(255),
    @IPAddress       NVARCHAR(45) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Now DATETIME2(0) = SYSUTCDATETIME();
    DECLARE @ResetID INT;
    DECLARE @UserId INT;

    BEGIN TRY
        IF NULLIF(@HashedToken, N'') IS NULL OR NULLIF(@NewPasswordHash, N'') IS NULL
            THROW 52021, N'A reset token and new password hash are required.', 1;

        SELECT @ResetID = pr.reset_id, @UserId = pr.user_id
        FROM dbo.password_resets pr
        WHERE pr.reset_token = @HashedToken
          AND pr.used_at IS NULL
          AND pr.expires_at > @Now;

        IF @ResetID IS NULL
            THROW 52022, N'Reset token is invalid or expired.', 1;

        IF @UserId IS NULL
            THROW 52010, N'User not found.', 1;

        BEGIN TRANSACTION;

        UPDATE dbo.users
        SET password_hash = @NewPasswordHash,
            must_change_password = 0,
            failed_login_attempts = 0,
            is_locked = 0,
            updated_at = @Now
        WHERE user_id = @UserId;

        INSERT INTO dbo.password_history (user_id, password_hash, changed_at, changed_by)
        VALUES (@UserId, @NewPasswordHash, @Now, @UserId);

        -- Mark THIS token used then delete all other pending tokens
        UPDATE dbo.password_resets
        SET used_at = @Now
        WHERE reset_id = @ResetID;

        DELETE FROM dbo.password_resets
        WHERE user_id = @UserId AND used_at IS NULL;

        -- Revoke all sessions (force re-login)
        UPDATE dbo.user_sessions
        SET is_revoked = 1, revoked_at = @Now, revoked_by = @UserId
        WHERE user_id = @UserId AND is_revoked = 0;

        INSERT INTO dbo.security_logs
            (user_id, event_type, username, ip_address, user_agent, message, created_at)
        VALUES
            (@UserId, 'PASSWORD_RESET', NULL, @IPAddress, NULL,
             N'Password reset completed.', @Now);

        COMMIT TRANSACTION;

        SELECT @UserId AS UserID;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        INSERT INTO dbo.error_logs (user_id, error_code, message, stack_trace, source)
        VALUES (@UserId, N'SP_CompletePasswordReset', ERROR_MESSAGE(), ERROR_PROCEDURE(), N'SP_CompletePasswordReset');
        THROW;
    END CATCH
END
GO