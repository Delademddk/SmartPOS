/* ==========================================================================
   SmartPOS Database - MODULE 04: CATEGORIES
   --------------------------------------------------------------------------
   Objects: categories (self-referencing hierarchy).
   Depends on: 02 Users (created_by/updated_by), itself (parent_id).
   ========================================================================== */

IF OBJECT_ID(N'dbo.categories', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.categories
    (
        category_id    INT           NOT NULL IDENTITY(1,1) CONSTRAINT PK_categories PRIMARY KEY,
        category_name  NVARCHAR(100) NOT NULL,
        parent_id      INT           NULL,                   -- self-referencing
        [description]  NVARCHAR(255) NULL,
        sort_order     INT           NOT NULL CONSTRAINT DF_categories_sort_order DEFAULT (0),
        is_active      BIT           NOT NULL CONSTRAINT DF_categories_is_active DEFAULT (1),
        is_deleted     BIT           NOT NULL CONSTRAINT DF_categories_is_deleted DEFAULT (0),
        deleted_at     DATETIME2(0)  NULL,
        deleted_by     INT NULL,
        created_at     DATETIME2(0)  NOT NULL CONSTRAINT DF_categories_created_at DEFAULT (SYSUTCDATETIME()),
        updated_at     DATETIME2(0)  NOT NULL CONSTRAINT DF_categories_updated_at DEFAULT (SYSUTCDATETIME()),
        created_by     INT NULL,
        updated_by     INT NULL
    );

    ALTER TABLE dbo.categories ADD CONSTRAINT FK_categories_parent
        FOREIGN KEY (parent_id) REFERENCES dbo.categories (category_id);
    ALTER TABLE dbo.categories ADD CONSTRAINT FK_categories_created_by
        FOREIGN KEY (created_by) REFERENCES dbo.users (user_id);
    ALTER TABLE dbo.categories ADD CONSTRAINT FK_categories_deleted_by
        FOREIGN KEY (deleted_by) REFERENCES dbo.users (user_id);
    ALTER TABLE dbo.categories ADD CONSTRAINT CK_categories_not_self_parent
        CHECK (parent_id <> category_id);
    -- Unique name within the same parent (only among active, non-deleted)
    ALTER TABLE dbo.categories ADD CONSTRAINT UQ_categories_parent_name
        UNIQUE (parent_id, category_name);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_categories_parent_id')
    CREATE NONCLUSTERED INDEX IX_categories_parent_id ON dbo.categories (parent_id);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_categories_is_deleted_active')
    CREATE NONCLUSTERED INDEX IX_categories_is_deleted_active
        ON dbo.categories (is_deleted, is_active) INCLUDE (category_name, parent_id, sort_order);
GO