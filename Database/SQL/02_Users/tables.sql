/* ==========================================================================
   SmartPOS Database - MODULE 02: USERS
   --------------------------------------------------------------------------
   Objects: users, user_sessions, password_history, password_resets
   Depends on: 01 Authentication (roles.role_id)

   Security: passwords stored as hashes ONLY (bcrypt/Argon2 hash of the
   password, never plaintext).
   ========================================================================== */

-- --------------------------------------------------------------------------
-- USERS
-- --------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.users', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.users
    (
        user_id                INT           NOT NULL IDENTITY(1,1) CONSTRAINT PK_users PRIMARY KEY,
        username               NVARCHAR(50)  NOT NULL,
        email                  NVARCHAR(255) NOT NULL,
        password_hash          NVARCHAR(255) NOT NULL,       -- bcrypt/Argon2 hash
        full_name              NVARCHAR(150) NOT NULL,
        phone                  NVARCHAR(30)  NULL,
        role_id                INT           NOT NULL,
        is_active              BIT           NOT NULL CONSTRAINT DF_users_is_active DEFAULT (1),
        is_locked              BIT           NOT NULL CONSTRAINT DF_users_is_locked DEFAULT (0),
        failed_login_attempts  TINYINT       NOT NULL CONSTRAINT DF_users_failed_login DEFAULT (0),
        must_change_password   BIT           NOT NULL CONSTRAINT DF_users_must_change_password DEFAULT (0),
        last_login_at          DATETIME2(0)  NULL,
        last_login_ip          NVARCHAR(45)  NULL,
        is_deleted             BIT           NOT NULL CONSTRAINT DF_users_is_deleted DEFAULT (0),
        deleted_at             DATETIME2(0)  NULL,
        deleted_by             INT           NULL,
        created_at             DATETIME2(0)  NOT NULL CONSTRAINT DF_users_created_at DEFAULT (SYSUTCDATETIME()),
        updated_at             DATETIME2(0)  NOT NULL CONSTRAINT DF_users_updated_at DEFAULT (SYSUTCDATETIME()),
        created_by             INT           NULL,
        updated_by             INT           NULL
    );

    ALTER TABLE dbo.users ADD CONSTRAINT UQ_users_username UNIQUE (username);
    ALTER TABLE dbo.users ADD CONSTRAINT UQ_users_email UNIQUE (email);
    ALTER TABLE dbo.users ADD CONSTRAINT FK_users_roles
        FOREIGN KEY (role_id) REFERENCES dbo.roles (role_id);
    ALTER TABLE dbo.users ADD CONSTRAINT CK_users_email_format
        CHECK (email LIKE '%_@_%._%');
    ALTER TABLE dbo.users ADD CONSTRAINT CK_users_username_min_length
        CHECK (LEN(username) >= 3);
END
GO

-- --------------------------------------------------------------------------
-- USER SESSIONS (revocable JWT refresh sessions)
-- --------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.user_sessions', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.user_sessions
    (
        session_id      INT           NOT NULL IDENTITY(1,1) CONSTRAINT PK_user_sessions PRIMARY KEY,
        user_id         INT           NOT NULL,
        session_token   NVARCHAR(255) NOT NULL,              -- hashed token
        ip_address      NVARCHAR(45)  NULL,
        user_agent      NVARCHAR(255) NULL,
        issued_at       DATETIME2(0)  NOT NULL CONSTRAINT DF_user_sessions_issued_at DEFAULT (SYSUTCDATETIME()),
        expires_at      DATETIME2(0)  NOT NULL,
        is_revoked      BIT           NOT NULL CONSTRAINT DF_user_sessions_is_revoked DEFAULT (0),
        revoked_at      DATETIME2(0)  NULL,
        revoked_by      INT           NULL
    );

    ALTER TABLE dbo.user_sessions ADD CONSTRAINT UQ_user_sessions_token UNIQUE (session_token);
    ALTER TABLE dbo.user_sessions ADD CONSTRAINT FK_user_sessions_users
        FOREIGN KEY (user_id) REFERENCES dbo.users (user_id);
    ALTER TABLE dbo.user_sessions ADD CONSTRAINT CK_user_sessions_expiry_after_issue
        CHECK (expires_at > issued_at);
END
GO

-- --------------------------------------------------------------------------
-- PASSWORD HISTORY (reuse prevention)
-- --------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.password_history', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.password_history
    (
        history_id     INT           NOT NULL IDENTITY(1,1) CONSTRAINT PK_password_history PRIMARY KEY,
        user_id        INT           NOT NULL,
        password_hash  NVARCHAR(255) NOT NULL,
        changed_at     DATETIME2(0)  NOT NULL CONSTRAINT DF_password_history_changed_at DEFAULT (SYSUTCDATETIME()),
        changed_by     INT           NULL
    );

    ALTER TABLE dbo.password_history ADD CONSTRAINT FK_password_history_users
        FOREIGN KEY (user_id) REFERENCES dbo.users (user_id);
END
GO

-- --------------------------------------------------------------------------
-- PASSWORD RESETS (one-time tokens)
-- --------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.password_resets', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.password_resets
    (
        reset_id     INT           NOT NULL IDENTITY(1,1) CONSTRAINT PK_password_resets PRIMARY KEY,
        user_id      INT           NOT NULL,
        reset_token  NVARCHAR(255) NOT NULL,                 -- hashed token
        ip_address   NVARCHAR(45)  NULL,
        requested_at DATETIME2(0)  NOT NULL CONSTRAINT DF_password_resets_requested_at DEFAULT (SYSUTCDATETIME()),
        expires_at   DATETIME2(0)  NOT NULL,
        used_at      DATETIME2(0)  NULL
    );

    ALTER TABLE dbo.password_resets ADD CONSTRAINT UQ_password_resets_token UNIQUE (reset_token);
    ALTER TABLE dbo.password_resets ADD CONSTRAINT FK_password_resets_users
        FOREIGN KEY (user_id) REFERENCES dbo.users (user_id);
    ALTER TABLE dbo.password_resets ADD CONSTRAINT CK_password_resets_expiry_after_issue
        CHECK (expires_at > requested_at);
END
GO

-- ----------------------------------------------------------------------------
-- INDEXES (FK + operational lookups)
-- ----------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_users_role_id')
    CREATE NONCLUSTERED INDEX IX_users_role_id ON dbo.users (role_id);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_users_is_active')
    CREATE NONCLUSTERED INDEX IX_users_is_active ON dbo.users (is_active) INCLUDE (full_name, role_id);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_user_sessions_user_id')
    CREATE NONCLUSTERED INDEX IX_user_sessions_user_id ON dbo.user_sessions (user_id);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_password_history_user_id')
    CREATE NONCLUSTERED INDEX IX_password_history_user_id ON dbo.password_history (user_id);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_password_resets_user_id')
    CREATE NONCLUSTERED INDEX IX_password_resets_user_id ON dbo.password_resets (user_id);
GO