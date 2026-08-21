/* ==========================================================================
   SmartPOS Database - MODULE 06: SUPPLIERS
   --------------------------------------------------------------------------
   Objects: suppliers, supplier_contacts, supplier_history.
   Depends on: 02 Users.
   ========================================================================== */

-- --------------------------------------------------------------------------
-- SUPPLIERS
-- --------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.suppliers', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.suppliers
    (
        supplier_id    INT           NOT NULL IDENTITY(1,1) CONSTRAINT PK_suppliers PRIMARY KEY,
        supplier_code  NVARCHAR(30)  NOT NULL,
        supplier_name  NVARCHAR(150) NOT NULL,
        contact_person NVARCHAR(150) NULL,
        email          NVARCHAR(255) NULL,
        phone          NVARCHAR(30)  NULL,
        address_line1  NVARCHAR(255) NULL,
        address_line2  NVARCHAR(255) NULL,
        city           NVARCHAR(100) NULL,
        [state]        NVARCHAR(100) NULL,
        postal_code    NVARCHAR(20)  NULL,
        country        NVARCHAR(100) NULL,
        [notes]        NVARCHAR(MAX) NULL,
        is_active      BIT           NOT NULL CONSTRAINT DF_suppliers_is_active DEFAULT (1),
        is_deleted     BIT           NOT NULL CONSTRAINT DF_suppliers_is_deleted DEFAULT (0),
        deleted_at     DATETIME2(0)  NULL,
        deleted_by     INT NULL,
        created_at     DATETIME2(0)  NOT NULL CONSTRAINT DF_suppliers_created_at DEFAULT (SYSUTCDATETIME()),
        updated_at     DATETIME2(0)  NOT NULL CONSTRAINT DF_suppliers_updated_at DEFAULT (SYSUTCDATETIME()),
        created_by     INT NULL,
        updated_by     INT NULL
    );

    ALTER TABLE dbo.suppliers ADD CONSTRAINT UQ_suppliers_code UNIQUE (supplier_code);
    ALTER TABLE dbo.suppliers ADD CONSTRAINT UQ_suppliers_name UNIQUE (supplier_name);
    ALTER TABLE dbo.suppliers ADD CONSTRAINT FK_suppliers_created_by
        FOREIGN KEY (created_by) REFERENCES dbo.users (user_id);
    ALTER TABLE dbo.suppliers ADD CONSTRAINT FK_suppliers_deleted_by
        FOREIGN KEY (deleted_by) REFERENCES dbo.users (user_id);
END
GO

-- --------------------------------------------------------------------------
-- SUPPLIER CONTACTS (multiple contacts per supplier)
-- --------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.supplier_contacts', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.supplier_contacts
    (
        contact_id   INT           NOT NULL IDENTITY(1,1) CONSTRAINT PK_supplier_contacts PRIMARY KEY,
        supplier_id  INT           NOT NULL,
        full_name    NVARCHAR(150) NOT NULL,
        job_title    NVARCHAR(100) NULL,
        email        NVARCHAR(255) NULL,
        phone        NVARCHAR(30)  NULL,
        is_primary   BIT           NOT NULL CONSTRAINT DF_supplier_contacts_is_primary DEFAULT (0),
        is_active    BIT           NOT NULL CONSTRAINT DF_supplier_contacts_is_active DEFAULT (1),
        created_at   DATETIME2(0)  NOT NULL CONSTRAINT DF_supplier_contacts_created_at DEFAULT (SYSUTCDATETIME()),
        updated_at   DATETIME2(0)  NOT NULL CONSTRAINT DF_supplier_contacts_updated_at DEFAULT (SYSUTCDATETIME())
    );

    ALTER TABLE dbo.supplier_contacts ADD CONSTRAINT FK_supplier_contacts_suppliers
        FOREIGN KEY (supplier_id) REFERENCES dbo.suppliers (supplier_id);
END
GO

-- --------------------------------------------------------------------------
-- SUPPLIER HISTORY (record of changes / interactions)
-- --------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.supplier_history', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.supplier_history
    (
        history_id   INT           NOT NULL IDENTITY(1,1) CONSTRAINT PK_supplier_history PRIMARY KEY,
        supplier_id  INT           NOT NULL,
        history_type NVARCHAR(50)  NOT NULL,                 -- CREATED / UPDATED / CONTACT_CHANGED / NOTE
        [description] NVARCHAR(255) NULL,
        changed_by   INT           NULL,
        changed_at   DATETIME2(0)  NOT NULL CONSTRAINT DF_supplier_history_changed_at DEFAULT (SYSUTCDATETIME())
    );

    ALTER TABLE dbo.supplier_history ADD CONSTRAINT FK_supplier_history_suppliers
        FOREIGN KEY (supplier_id) REFERENCES dbo.suppliers (supplier_id);
    ALTER TABLE dbo.supplier_history ADD CONSTRAINT FK_supplier_history_users
        FOREIGN KEY (changed_by) REFERENCES dbo.users (user_id);
END
GO

-- ----------------------------------------------------------------------------
-- INDEXES
-- ----------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_suppliers_is_active')
    CREATE NONCLUSTERED INDEX IX_suppliers_is_active ON dbo.suppliers (is_active) INCLUDE (supplier_code, supplier_name);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_supplier_contacts_supplier_id')
    CREATE NONCLUSTERED INDEX IX_supplier_contacts_supplier_id ON dbo.supplier_contacts (supplier_id) INCLUDE (full_name, is_primary);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_supplier_history_supplier_id')
    CREATE NONCLUSTERED INDEX IX_supplier_history_supplier_id ON dbo.supplier_history (supplier_id, changed_at);
GO