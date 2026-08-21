/* ==========================================================================
   SmartPOS Database - MODULE 01/02: LOGIN / SESSION MANAGEMENT
   --------------------------------------------------------------------------
   SP_Login           - authenticate a user and persist a revocable session
   SP_Logout          - revoke a session and log the LOGOUT event
   SP_ValidateSession - return the user + session validity

   Depends on: dbo.users, dbo.user_sessions, dbo.security_logs,
               dbo.roles, dbo.error_logs.
   Conventions: SP_<Purpose> naming, snake_case columns, structured
               TRY...CATCH, THROW, multi-table writes in transactions.
   ========================================================================== */

/* ---------------------------------------------------------------------------
   SP_Login
   Authenticates a username-or-email against the stored password hash and
   issues a single revocable session row. The caller passes the already-hashed
   password and an already-hashed session token; this procedure never generates
   a hash.

   On success:
     - resets failed_login_attempts, records last_login_at / last_login_ip
     - inserts a row into dbo.user_sessions
     - returns user profile + roles in a single result set
   Security events are written to dbo.security_logs in every outcome.
---------------------------------------------------------------------------*/
IF OBJECT_ID(N'dbo.SP_Login', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_Login;
GO
CREATE PROCEDURE dbo.SP_Login
    @UsernameOrEmail    NVARCHAR(255),
    @PasswordHash       NVARCHAR(255),
    @IPAddress          NVARCHAR(45) = NULL,
    @UserAgent          NVARCHAR(255) = NULL,
    @HashedSessionToken NVARCHAR(255) = NULL,
    @UserID             INT = NULL OUTPUT,
    @SessionID          INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Now DATETIME2(0) = SYSUTCDATETIME();
    DECLARE @UserId INT;
    DECLARE @StoredHash NVARCHAR(255);
    DECLARE @RoleID INT;
    DECLARE @IsActive BIT;
    DECLARE @IsLocked BIT;
    DECLARE @IsDeleted BIT;
    DECLARE @FailCount TINYINT;
    DECLARE @Username NVARCHAR(50);
    DECLARE @SessionExpires DATETIME2(0) = DATEADD(hour, 30, @Now);

    BEGIN TRY
        IF NULLIF(LTRIM(RTRIM(@UsernameOrEmail)), N'') IS NULL
            OR NULLIF(LTRIM(RTRIM(@PasswordHash)), N'') IS NULL
        BEGIN
            INSERT INTO dbo.security_logs
                (user_id, event_type, username, ip_address, user_agent, message, created_at)
            VALUES (NULL, N'LOGIN_FAILED', @UsernameOrEmail, @IPAddress, @UserAgent,
                    N'Missing credentials.', @Now);
            THROW 40100, N'Invalid credentials.', 1;
        END

        -- ----------------------------------------------------------------
        -- Look up the account by username or email
        -- ----------------------------------------------------------------
        SELECT TOP (1)
            @UserId      = user_id,
            @StoredHash  = password_hash,
            @RoleID      = role_id,
            @IsActive    = is_active,
            @IsLocked    = is_locked,
            @IsDeleted   = is_deleted,
            @FailCount   = failed_login_attempts,
            @Username    = username
        FROM dbo.users
        WHERE username = @UsernameOrEmail OR email = @UsernameOrEmail;

        IF @UserId IS NULL OR @IsDeleted = 1
        BEGIN
            INSERT INTO dbo.security_logs
                (user_id, event_type, username, ip_address, user_agent, message, created_at)
            VALUES (NULL, N'LOGIN_FAILED', @UsernameOrEmail, @IPAddress, @UserAgent,
                    N'Unknown account.', @Now);
            THROW 40101, N'Invalid credentials.', 1;
        END

        -- ----------------------------------------------------------------
        -- Account state checks
        -- ----------------------------------------------------------------
        IF @IsActive = 0
        BEGIN
            INSERT INTO dbo.security_logs
                (user_id, event_type, username, ip_address, user_agent, message, created_at)
            VALUES (@UserId, N'LOGIN_FAILED', @Username, @IPAddress, @UserAgent,
                    N'Account disabled.', @Now);
            THROW 40102, N'Account disabled.', 1;
        END

        IF @IsLocked = 1
        BEGIN
            INSERT INTO dbo.security_logs
                (user_id, event_type, username, ip_address, user_agent, message, created_at)
            VALUES (@UserId, N'LOGIN_FAILED', @Username, @IPAddress, @UserAgent,
                    N'Account locked.', @Now);
            THROW 40103, N'Account locked.', 1;
        END

        -- ----------------------------------------------------------------
        -- Verify the caller-supplied password hash against the store
        -- ----------------------------------------------------------------
        IF @StoredHash <> @PasswordHash
        BEGIN
            SET @FailCount = ISNULL(@FailCount, 0) + 1;
            IF @FailCount > 255 SET @FailCount = 255;

            -- Optionally escalate to lock-out after repeated failures
            UPDATE dbo.users
            SET failed_login_attempts = @FailCount,
                updated_at = @Now
            WHERE user_id = @UserId;

            INSERT INTO dbo.security_logs
                (user_id, event_type, username, ip_address, user_agent, message, created_at)
            VALUES (@UserId, N'LOGIN_FAILED', @Username, @IPAddress, @UserAgent,
                    N'Invalid password.', @Now);

            THROW 40101, N'Invalid credentials.', 1;
        END

        BEGIN TRANSACTION;

        -- All checks passed: reset failure counter and record login
        UPDATE dbo.users
        SET failed_login_attempts = 0,
            last_login_at = @Now,
            last_login_ip = @IPAddress,
            updated_at    = @Now
        WHERE user_id = @UserId;

        -- Issue the session
        INSERT INTO dbo.user_sessions
            (user_id, session_token, ip_address, user_agent, issued_at,
             expires_at, is_revoked)
        VALUES
            (@UserId, @HashedSessionToken, @IPAddress, @UserAgent,
             @Now, @SessionExpires, 0);

        SET @SessionID = SCOPE_IDENTITY();

        INSERT INTO dbo.security_logs
            (user_id, event_type, username, ip_address, user_agent, message, created_at)
        VALUES
            (@UserId, N'LOGIN_SUCCESS', @Username, @IPAddress, @UserAgent,
             N'Login successful.', @Now);

        COMMIT TRANSACTION;

        SET @UserID = @UserId;

        -- ----------------------------------------------------------------
        -- Single result set: user profile + role
        -- ----------------------------------------------------------------
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
            u.must_change_password,
            u.last_login_at,
            u.last_login_ip,
            s.session_id,
            s.expires_at AS session_expires_at
        FROM dbo.users u
        JOIN dbo.roles r         ON r.role_id = u.role_id
        JOIN dbo.user_sessions s ON s.session_id = @SessionID
        WHERE u.user_id = @UserId;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        INSERT INTO dbo.error_logs (user_id, error_code, message, stack_trace, source)
        VALUES (@UserId, N'SP_Login', ERROR_MESSAGE(), ERROR_PROCEDURE(), N'SP_Login');
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------------
   SP_Logout
   Revokes the session matching a hashed token and writes a LOGOUT security
   event. Idempotent: a missing or already-revoked token is not an error.
---------------------------------------------------------------------------*/
IF OBJECT_ID(N'dbo.SP_Logout', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_Logout;
GO
CREATE PROCEDURE dbo.SP_Logout
    @SessionTokenHash NVARCHAR(255),
    @IPAddress NVARCHAR(45) = NULL,
    @UserAgent NVARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Now DATETIME2(0) = SYSUTCDATETIME();
    DECLARE @UserId INT;
    DECLARE @Username NVARCHAR(50);

    BEGIN TRY
        IF NULLIF(LTRIM(RTRIM(@SessionTokenHash)), N'') IS NULL
            THROW 51010, N'A session token is required.', 1;

        SELECT TOP (1)
            @UserId   = s.user_id,
            @Username = u.username
        FROM dbo.user_sessions s
        LEFT JOIN dbo.users u ON u.user_id = s.user_id
        WHERE s.session_token = @SessionTokenHash
          AND s.is_revoked = 0;

        IF @UserId IS NOT NULL
        BEGIN
            BEGIN TRANSACTION;

            UPDATE dbo.user_sessions
            SET is_revoked = 1,
                revoked_at = @Now,
                revoked_by = @UserId
            WHERE session_token = @SessionTokenHash AND is_revoked = 0;

            INSERT INTO dbo.security_logs
                (user_id, event_type, username, ip_address, user_agent, message, created_at)
            VALUES
                (@UserId, N'LOGOUT', @Username, @IPAddress, @UserAgent,
                 N'Session revoked.', @Now);

            COMMIT TRANSACTION;
        END

        SELECT @UserId AS UserID;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        INSERT INTO dbo.error_logs (user_id, error_code, message, stack_trace, source)
        VALUES (@UserId, N'SP_Logout', ERROR_MESSAGE(), ERROR_PROCEDURE(), N'SP_Logout');
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------------
   SP_ValidateSession
   Validates a hashed session token against revocation, expiry and user
   state. Returns the user profile and a validity flag (and message).
---------------------------------------------------------------------------*/
IF OBJECT_ID(N'dbo.SP_ValidateSession', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_ValidateSession;
GO
CREATE PROCEDURE dbo.SP_ValidateSession
    @SessionTokenHash NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Now DATETIME2(0) = SYSUTCDATETIME();
    DECLARE @Valid BIT = 0;

    IF NULLIF(LTRIM(RTRIM(@SessionTokenHash)), N'') IS NULL
    BEGIN
        SELECT CAST(0 AS BIT) AS is_valid,
               CAST(NULL AS INT) AS user_id,
               N'Missing token' AS message;
        RETURN;
    END

    SELECT @Valid = CASE
        WHEN s.is_revoked = 0
         AND s.expires_at > @Now
         AND u.is_active = 1
         AND u.is_deleted = 0
         AND u.is_locked = 0
        THEN 1 ELSE 0 END
    FROM dbo.user_sessions s
    LEFT JOIN dbo.users u ON u.user_id = s.user_id
    WHERE s.session_token = @SessionTokenHash;

    IF @Valid = 1
    BEGIN
        SELECT
            CAST(1 AS BIT) AS is_valid,
            u.user_id,
            u.username,
            u.email,
            u.full_name,
            u.role_id,
            r.role_code,
            r.role_name,
            u.must_change_password,
            s.session_id,
            s.expires_at AS session_expires_at,
            N'Session is valid.' AS message
        FROM dbo.user_sessions s
        JOIN dbo.users u   ON u.user_id = s.user_id
        JOIN dbo.roles r   ON r.role_id = u.role_id
        WHERE s.session_token = @SessionTokenHash;
    END
    ELSE
    BEGIN
        SELECT
            CAST(0 AS BIT) AS is_valid,
            u.user_id,
            N'Session is invalid, expired, or the account is inactive.' AS message
        FROM dbo.user_sessions s
        LEFT JOIN dbo.users u ON u.user_id = s.user_id
        WHERE s.session_token = @SessionTokenHash;
    END
END
GO