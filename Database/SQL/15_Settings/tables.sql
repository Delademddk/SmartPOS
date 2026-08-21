/* ==========================================================================
   SmartPOS Database - MODULE 15: SETTINGS
   --------------------------------------------------------------------------
   Objects: settings (application settings), user_settings.
   Depends on: 02 Users.
   ========================================================================== */

-- --------------------------------------------------------------------------
-- SETTINGS (application/system configuration key-value)
-- --------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.settings', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.settings
    (
        setting_id    INT            NOT NULL IDENTITY(1,1) CONSTRAINT PK_settings PRIMARY KEY,
        setting_key   NVARCHAR(100)  NOT NULL,
        setting_value NVARCHAR(MAX)  NULL,
        data_type     NVARCHAR(20)   NOT NULL CONSTRAINT DF_settings_data_type DEFAULT (N'string'), -- string / int / decimal / bool / json
        category      NVARCHAR(50)   NOT NULL CONSTRAINT DF_settings_category DEFAULT (N'general'),   -- general / tax / receipt / notifications / system
        [description] NVARCHAR(255)  NULL,
        is_active     BIT            NOT NULL CONSTRAINT DF_settings_is_active DEFAULT (1),
        created_at    DATETIME2(0)   NOT NULL CONSTRAINT DF_settings_created_at DEFAULT (SYSUTCDATETIME()),
        updated_at    DATETIME2(0)   NOT NULL CONSTRAINT DF_settings_updated_at DEFAULT (SYSUTCDATETIME()),
        created_by    INT            NULL,
        updated_by    INT            NULL
    );

    ALTER TABLE dbo.settings ADD CONSTRAINT UQ_settings_key UNIQUE (setting_key);
    ALTER TABLE dbo.settings ADD CONSTRAINT CK_settings_data_type
        CHECK (data_type IN (N'string', N'int', N'decimal', N'bool', N'json'));
END
GO

-- --------------------------------------------------------------------------
-- USER SETTINGS (per-user preferences)
-- --------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.user_settings', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.user_settings
    (
        user_setting_id INT           NOT NULL IDENTITY(1,1) CONSTRAINT PK_user_settings PRIMARY KEY,
        user_id         INT           NOT NULL,
        setting_key     NVARCHAR(100) NOT NULL,
        setting_value   NVARCHAR(MAX) NULL,
        created_at      DATETIME2(0)  NOT NULL CONSTRAINT DF_user_settings_created_at DEFAULT (SYSUTCDATETIME()),
        updated_at      DATETIME2(0)  NOT NULL CONSTRAINT DF_user_settings_updated_at DEFAULT (SYSUTCDATETIME())
    );

    ALTER TABLE dbo.user_settings ADD CONSTRAINT UQ_user_settings_user_key
        UNIQUE (user_id, setting_key);
    ALTER TABLE dbo.user_settings ADD CONSTRAINT FK_user_settings_users
        FOREIGN KEY (user_id) REFERENCES dbo.users (user_id);
END
GO

-- ----------------------------------------------------------------------------
-- INDEXES
-- ----------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_settings_category')
    CREATE NONCLUSTERED INDEX IX_settings_category ON dbo.settings (category) INCLUDE (setting_key);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_user_settings_user_id')
    CREATE NONCLUSTERED INDEX IX_user_settings_user_id ON dbo.user_settings (user_id);
GO