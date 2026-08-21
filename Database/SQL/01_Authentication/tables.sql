/* ==========================================================================
   SmartPOS Database - MODULE 01: AUTHENTICATION
   --------------------------------------------------------------------------
   Role-Based Access Control (RBAC) foundation.
   Objects: roles, permissions, role_permissions
   Establishes the permission model used across the whole application.

   Build order: STANDALONE (no FK dependencies other than itself).
   All statements are idempotent.
   ========================================================================== */

-- --------------------------------------------------------------------------
-- ROLES
-- --------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.roles', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.roles
    (
        role_id        INT          NOT NULL IDENTITY(1,1) CONSTRAINT PK_roles PRIMARY KEY,
        role_code      NVARCHAR(50)  NOT NULL,
        role_name      NVARCHAR(100) NOT NULL,
        [description]  NVARCHAR(255) NULL,
        is_system      BIT           NOT NULL CONSTRAINT DF_roles_is_system DEFAULT (0),
        is_active      BIT           NOT NULL CONSTRAINT DF_roles_is_active DEFAULT (1),
        created_at     DATETIME2(0)  NOT NULL CONSTRAINT DF_roles_created_at DEFAULT (SYSUTCDATETIME()),
        updated_at     DATETIME2(0)  NOT NULL CONSTRAINT DF_roles_updated_at DEFAULT (SYSUTCDATETIME()),
        created_by     INT           NULL,
        updated_by     INT           NULL
    );

    -- Role codes are stable identifiers (used as a soft enum).
    ALTER TABLE dbo.roles ADD CONSTRAINT UQ_roles_role_code UNIQUE (role_code);
    ALTER TABLE dbo.roles ADD CONSTRAINT CK_roles_role_code_format
        CHECK (role_code = UPPER(LTRIM(RTRIM(role_code))));
END
GO

-- --------------------------------------------------------------------------
-- PERMISSIONS
-- --------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.permissions', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.permissions
    (
        permission_id   INT           NOT NULL IDENTITY(1,1) CONSTRAINT PK_permissions PRIMARY KEY,
        permission_code NVARCHAR(100) NOT NULL,           -- stable machine key, e.g. 'product.create'
        permission_name NVARCHAR(150) NOT NULL,           -- human-readable
        [description]   NVARCHAR(255) NULL,
        module_name     NVARCHAR(100) NOT NULL,           -- grouping, e.g. 'products'
        is_system       BIT           NOT NULL CONSTRAINT DF_permissions_is_system DEFAULT (0),
        is_active       BIT           NOT NULL CONSTRAINT DF_permissions_is_active DEFAULT (1),
        created_at      DATETIME2(0)  NOT NULL CONSTRAINT DF_permissions_created_at DEFAULT (SYSUTCDATETIME()),
        updated_at      DATETIME2(0)  NOT NULL CONSTRAINT DF_permissions_updated_at DEFAULT (SYSUTCDATETIME()),
        created_by      INT           NULL,
        updated_by      INT           NULL
    );

    ALTER TABLE dbo.permissions ADD CONSTRAINT UQ_permissions_code UNIQUE (permission_code);
    ALTER TABLE dbo.permissions ADD CONSTRAINT CK_permissions_code_upper
        CHECK (permission_code = LOWER(LTRIM(RTRIM(permission_code))));
END

-- --------------------------------------------------------------------------
-- ROLE PERMISSIONS
-- --------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.role_permissions', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.role_permissions
    (
        role_permission_id INT          NOT NULL IDENTITY(1,1) CONSTRAINT PK_role_permissions PRIMARY KEY,
        role_id            INT          NOT NULL,
        permission_id      INT          NOT NULL,
        granted_by         INT          NULL,
        granted_at         DATETIME2(0) NOT NULL CONSTRAINT DF_role_permissions_granted_at DEFAULT (SYSUTCDATETIME())
    );

    ALTER TABLE dbo.role_permissions ADD CONSTRAINT UQ_role_permissions_role_permission
        UNIQUE (role_id, permission_id);

    ALTER TABLE dbo.role_permissions ADD CONSTRAINT FK_role_permissions_roles
        FOREIGN KEY (role_id) REFERENCES dbo.roles (role_id);

    ALTER TABLE dbo.role_permissions ADD CONSTRAINT FK_role_permissions_permissions
        FOREIGN KEY (permission_id) REFERENCES dbo.permissions (permission_id);
END
GO

-- ----------------------------------------------------------------------------
-- INDEXES (FK support)
-- ----------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_role_permissions_permission_id')
    CREATE NONCLUSTERED INDEX IX_role_permissions_permission_id
        ON dbo.role_permissions (permission_id);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_permissions_module_name')
    CREATE NONCLUSTERED INDEX IX_permissions_module_name
        ON dbo.permissions (module_name) INCLUDE (permission_code, permission_name);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_roles_is_active')
    CREATE NONCLUSTERED INDEX IX_roles_is_active
        ON dbo.roles (is_active) INCLUDE (role_code, role_name);
GO

/* ============================================================================
   FUNCTIONS / VIEWS / PROCEDURES for authentication live in:
     SQL/Functions/00_resource_lookup.sql
     SQL/Views/VW_UserPermissions.sql
     SQL/StoredProcedures/SP_Auth*.sql
     SQL/Triggers (audit triggers integrate this module)
   ========================================================================== */