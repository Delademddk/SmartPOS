/* ==========================================================================
   SmartPOS Database - MODULE 16: AUDIT
   --------------------------------------------------------------------------
   Objects: audit_logs, activity_logs, error_logs, security_logs, audit_logs_archive
   Depends on: 02 Users (users.user_id)

   Design:
     - audit_logs     : change history of business records (who/what/when/old/new).
     - activity_logs  : high-level user activity (login, actions, exports).
     - error_logs     : application / stored procedure errors.
     - security_logs  : authentication and authorization events.
     - audit_logs_archive : partitioned storage for rotated audit rows.
   ========================================================================== */

-- --------------------------------------------------------------------------
-- AUDIT LOGS
-- --------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.audit_logs', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.audit_logs
    (
        log_id        INT            NOT NULL IDENTITY(1,1) CONSTRAINT PK_audit_logs PRIMARY KEY,
        user_id       INT            NULL,                   -- acting user (NULL = system)
        action_type   NVARCHAR(50)   NOT NULL,               -- INSERT / UPDATE / DELETE / LOGIN / EXPORT ...
        resource_type NVARCHAR(100)  NOT NULL,               -- 'Product', 'Sale', 'User' ...
        resource_id   NVARCHAR(100)  NULL,                   -- string id of the row affected
        old_values    NVARCHAR(MAX)  NULL,                   -- JSON snapshot before change
        new_values    NVARCHAR(MAX)  NULL,                   -- JSON snapshot after change
        ip_address    NVARCHAR(45)   NULL,
        user_agent    NVARCHAR(255)  NULL,
        details       NVARCHAR(MAX)  NULL,
        created_at    DATETIME2(0)   NOT NULL CONSTRAINT DF_audit_logs_created_at DEFAULT (SYSUTCDATETIME())
    );

    ALTER TABLE dbo.audit_logs ADD CONSTRAINT FK_audit_logs_users
        FOREIGN KEY (user_id) REFERENCES dbo.users (user_id);
    ALTER TABLE dbo.audit_logs ADD CONSTRAINT CK_audit_logs_action_type_not_empty
        CHECK (LEN(LTRIM(RTRIM(action_type))) > 0);
END
GO

-- --------------------------------------------------------------------------
-- ACTIVITY LOGS
-- --------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.activity_logs', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.activity_logs
    (
        activity_id   INT            NOT NULL IDENTITY(1,1) CONSTRAINT PK_activity_logs PRIMARY KEY,
        user_id       INT            NULL,
        activity_type NVARCHAR(100)  NOT NULL,
        activity_desc NVARCHAR(255)  NULL,
        entity_type   NVARCHAR(100)  NULL,
        entity_id     NVARCHAR(100)  NULL,
        [metadata]    NVARCHAR(MAX)  NULL,                   -- JSON details
        ip_address    NVARCHAR(45)   NULL,
        user_agent    NVARCHAR(255)  NULL,
        created_at    DATETIME2(0)   NOT NULL CONSTRAINT DF_activity_logs_created_at DEFAULT (SYSUTCDATETIME())
    );

    ALTER TABLE dbo.activity_logs ADD CONSTRAINT FK_activity_logs_users
        FOREIGN KEY (user_id) REFERENCES dbo.users (user_id);
END
GO

-- --------------------------------------------------------------------------
-- ERROR LOGS
-- --------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.error_logs', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.error_logs
    (
        error_id     INT            NOT NULL IDENTITY(1,1) CONSTRAINT PK_error_logs PRIMARY KEY,
        user_id      INT            NULL,
        error_code   NVARCHAR(50)   NULL,
        [message]    NVARCHAR(MAX)  NOT NULL,
        stack_trace  NVARCHAR(MAX)  NULL,
        [source]     NVARCHAR(200)  NULL,                    -- proc / endpoint name
        http_status  INT            NULL,
        ip_address   NVARCHAR(45)   NULL,
        occurred_at  DATETIME2(0)   NOT NULL CONSTRAINT DF_error_logs_occurred_at DEFAULT (SYSUTCDATETIME())
    );

    ALTER TABLE dbo.error_logs ADD CONSTRAINT FK_error_logs_users
        FOREIGN KEY (user_id) REFERENCES dbo.users (user_id);
END
GO

-- --------------------------------------------------------------------------
-- SECURITY LOGS
-- --------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.security_logs', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.security_logs
    (
        security_log_id INT           NOT NULL IDENTITY(1,1) CONSTRAINT PK_security_logs PRIMARY KEY,
        user_id         INT           NULL,
        event_type      NVARCHAR(50)  NOT NULL,   -- LOGIN_SUCCESS / LOGIN_FAILED / LOGOUT / LOCKOUT / RESET ...
        username        NVARCHAR(50)  NULL,       -- captured even if user unknown
        ip_address      NVARCHAR(45)  NULL,
        user_agent      NVARCHAR(255) NULL,
        [message]       NVARCHAR(255) NULL,
        created_at      DATETIME2(0)  NOT NULL CONSTRAINT DF_security_logs_created_at DEFAULT (SYSUTCDATETIME())
    );

    ALTER TABLE dbo.security_logs ADD CONSTRAINT FK_security_logs_users
        FOREIGN KEY (user_id) REFERENCES dbo.users (user_id);
    ALTER TABLE dbo.security_logs ADD CONSTRAINT CK_security_logs_event_type_upper
        CHECK (event_type = UPPER(LTRIM(RTRIM(event_type))));
END
GO

-- --------------------------------------------------------------------------
-- AUDIT LOGS ARCHIVE (rotated old audit rows)
-- --------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.audit_logs_archive', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.audit_logs_archive
    (
        archive_id    INT            NOT NULL IDENTITY(1,1) CONSTRAINT PK_audit_logs_archive PRIMARY KEY,
        log_id        INT            NOT NULL,               -- original log_id
        user_id       INT            NULL,
        action_type   NVARCHAR(50)   NOT NULL,
        resource_type NVARCHAR(100)  NOT NULL,
        resource_id   NVARCHAR(100)  NULL,
        old_values    NVARCHAR(MAX)  NULL,
        new_values    NVARCHAR(MAX)  NULL,
        ip_address    NVARCHAR(45)   NULL,
        user_agent    NVARCHAR(255)  NULL,
        details       NVARCHAR(MAX)  NULL,
        created_at    DATETIME2(0)   NOT NULL,
        archived_at   DATETIME2(0)   NOT NULL CONSTRAINT DF_audit_logs_archive_archived_at DEFAULT (SYSUTCDATETIME())
    );
END
GO

-- ----------------------------------------------------------------------------
-- INDEXES
-- ----------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_audit_logs_resource')
    CREATE NONCLUSTERED INDEX IX_audit_logs_resource ON dbo.audit_logs (resource_type, resource_id) INCLUDE (action_type, created_at);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_audit_logs_created_at')
    CREATE NONCLUSTERED INDEX IX_audit_logs_created_at ON dbo.audit_logs (created_at);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_audit_logs_user_created')
    CREATE NONCLUSTERED INDEX IX_audit_logs_user_created ON dbo.audit_logs (user_id, created_at);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_activity_logs_created_at')
    CREATE NONCLUSTERED INDEX IX_activity_logs_created_at ON dbo.activity_logs (created_at);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_security_logs_created_at')
    CREATE NONCLUSTERED INDEX IX_security_logs_created_at ON dbo.security_logs (created_at);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_error_logs_occurred_at')
    CREATE NONCLUSTERED INDEX IX_error_logs_occurred_at ON dbo.error_logs (occurred_at);
GO