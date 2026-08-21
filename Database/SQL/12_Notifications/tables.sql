/* ==========================================================================
   SmartPOS Database - MODULE 12: NOTIFICATIONS
   --------------------------------------------------------------------------
   Objects: notification_types, notifications, notification_history.
   Depends on: 02 Users.

   Business rule: low-stock notifications trigger automatically (handled by
   triggers and SP_RestockProduct / SP_CreateSale).
   ========================================================================== */

-- --------------------------------------------------------------------------
-- NOTIFICATION TYPES
-- --------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.notification_types', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.notification_types
    (
        notification_type_id INT           NOT NULL IDENTITY(1,1) CONSTRAINT PK_notification_types PRIMARY KEY,
        type_code            NVARCHAR(50)  NOT NULL,           -- LOW_STOCK / SALE / RETURN / SYSTEM / CREDIT
        type_name            NVARCHAR(100) NOT NULL,
        [description]        NVARCHAR(255) NULL,
        is_active            BIT           NOT NULL CONSTRAINT DF_notification_types_is_active DEFAULT (1)
    );

    ALTER TABLE dbo.notification_types ADD CONSTRAINT UQ_notification_types_code UNIQUE (type_code);
    ALTER TABLE dbo.notification_types ADD CONSTRAINT CK_notification_types_code_upper
        CHECK (type_code = UPPER(LTRIM(RTRIM(type_code))));
END
GO

-- --------------------------------------------------------------------------
-- NOTIFICATIONS
-- --------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.notifications', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.notifications
    (
        notification_id      INT           NOT NULL IDENTITY(1,1) CONSTRAINT PK_notifications PRIMARY KEY,
        user_id              INT           NOT NULL,            -- recipient
        notification_type_id INT           NOT NULL,
        title                NVARCHAR(150) NOT NULL,
        [message]            NVARCHAR(MAX) NOT NULL,
        severity             NVARCHAR(20)  NOT NULL CONSTRAINT DF_notifications_severity DEFAULT (N'INFO'), -- INFO / WARNING / CRITICAL
        entity_type          NVARCHAR(100) NULL,
        entity_id            NVARCHAR(100) NULL,
        is_read              BIT           NOT NULL CONSTRAINT DF_notifications_is_read DEFAULT (0),
        read_at              DATETIME2(0)  NULL,
        is_dismissed         BIT           NOT NULL CONSTRAINT DF_notifications_is_dismissed DEFAULT (0),
        created_at           DATETIME2(0)  NOT NULL CONSTRAINT DF_notifications_created_at DEFAULT (SYSUTCDATETIME())
    );

    ALTER TABLE dbo.notifications ADD CONSTRAINT FK_notifications_users
        FOREIGN KEY (user_id) REFERENCES dbo.users (user_id);
    ALTER TABLE dbo.notifications ADD CONSTRAINT FK_notifications_types
        FOREIGN KEY (notification_type_id) REFERENCES dbo.notification_types (notification_type_id);
    ALTER TABLE dbo.notifications ADD CONSTRAINT CK_notifications_severity
        CHECK (severity IN (N'INFO', N'WARNING', N'CRITICAL'));
END
GO

-- --------------------------------------------------------------------------
-- NOTIFICATION HISTORY (archived / processed notifications)
-- --------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.notification_history', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.notification_history
    (
        history_id           INT IDENTITY(1,1) CONSTRAINT PK_notification_history PRIMARY KEY,
        notification_id      INT           NULL,               -- source notification
        user_id              INT           NOT NULL,
        notification_type_id INT           NOT NULL,
        title                NVARCHAR(200) NOT NULL,
        [message]            NVARCHAR(MAX) NOT NULL,
        delivered_at         DATETIME2(0)  NOT NULL CONSTRAINT DF_notification_history_delivered_at DEFAULT (SYSUTCDATETIME()),
        [status]             NVARCHAR(20)  NOT NULL CONSTRAINT DF_notification_history_status DEFAULT (N'DELIVERED')
    );

    ALTER TABLE dbo.notification_history ADD CONSTRAINT FK_notification_history_users
        FOREIGN KEY (user_id) REFERENCES dbo.users (user_id);
    ALTER TABLE dbo.notification_history ADD CONSTRAINT FK_notification_history_types
        FOREIGN KEY (notification_type_id) REFERENCES dbo.notification_types (notification_type_id);
END
GO

-- ----------------------------------------------------------------------------
-- INDEXES
-- ----------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_notifications_user_read')
    CREATE NONCLUSTERED INDEX IX_notifications_user_read
        ON dbo.notifications (user_id, is_read, created_at) INCLUDE (title, severity);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_notifications_created_at')
    CREATE NONCLUSTERED INDEX IX_notifications_created_at ON dbo.notifications (created_at);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_notification_history_user')
    CREATE NONCLUSTERED INDEX IX_notification_history_user ON dbo.notification_history (user_id);
GO