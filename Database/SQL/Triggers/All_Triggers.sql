/* ==========================================================================
   SmartPOS Database - ALL TRIGGERS
   --------------------------------------------------------------------------
   File:    All_Triggers.sql
   Scope:   Production-ready DML triggers for the SmartPOS OLTP schema.
   Version: 1.0
   --------------------------------------------------------------------------

   ==========================================================================
   OVERALL TRIGGER STRATEGY
   --------------------------------------------------------------------------
   1. AUDIT (TRG_products_audit, TRG_categories_audit, TRG_suppliers_audit,
      TRG_users_audit, TRG_settings_audit)
      - AFTER INSERT/UPDATE/DELETE on every mutable reference/master table.
      - Every change is written as a row in dbo.audit_logs with:
          resource_type = friendly entity name ('Product', 'Category', ...)
          resource_id   = the row's primary key, cast to NVARCHAR
          old_values    = JSON snapshot of the pre-change row (DELETED)
          new_values    = JSON snapshot of the post-change row (INSERTED)
      - Snapshots are produced with
          (SELECT <cols> FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
        evaluated per-row (set-based, multi-row safe). No cursor loops.
      - user_id is ALWAYS left NULL. The application backend writes explicit
        audit rows (with actor) where the actor is known. Triggers are the
        fallback guarantee that a change is NEVER unlogged.
      - Soft deletes (is_deleted 0 -> 1) are audited as 'SOFT_DELETE'.
      - Pure hard deletes are audited as 'DELETE' (old_values only).

   2. LOW STOCK (TRG_inventory_low_stock)
      - AFTER UPDATE on dbo.inventory.
      - Raises an OPEN dbo.low_stock_alerts row when quantity_on_hand drops to
        at/below the product's dbo.products.low_stock_threshold from a higher
        value, only when no OPEN alert already exists for that product.
      - Notifies every ADMIN and MANAGER role user once per new alert via
        dbo.notifications (type_code = 'LOW_STOCK', severity = 'WARNING',
        entity_type = 'Product', entity_id = product_id).
      - Auto-resolves OPEN alerts (status = 'RESOLVED', resolved_at) when the
        quantity recovers back above the threshold.
      - Both directions (drop and recovery) are handled in the SAME trigger by
        joining INSERTED and DELETED on product_id.

   3. RETENTION (TRG_password_history_retention)
      - AFTER INSERT on dbo.password_history.
      - Enforces a maximum of 5 recent history rows per user; surplus oldest
        rows are pruned set-based with ROW_NUMBER() PARTITION BY user_id.

   ==========================================================================
   RECURSION SAFETY
   --------------------------------------------------------------------------
   - No trigger exists on dbo.audit_logs, dbo.low_stock_alerts,
     dbo.notifications, or dbo.password_history (other than this file's
     TRG_password_history_retention), so the writes performed by these
     triggers can never re-fire an upstream trigger -> no infinite loops.
   - TRG_inventory_low_stock writes to dbo.low_stock_alerts and
     dbo.notifications; neither table has a trigger that updates inventory,
     and this trigger only fires on dbo.inventory UPDATE.
   - TRG_password_history_retention only fires on INSERT into
     dbo.password_history; its DELETE against the same table is an AFTER
     trigger with no DELETE trigger on that table, so it cannot recurse.
   - Audit triggers write to dbo.audit_logs, which has no trigger.

   ==========================================================================
   INVENTORY DECREMENT DECISION (IMPORTANT)
   --------------------------------------------------------------------------
   Stock decrement on sale is implemented ONLY inside SP_CreateSale
   (dbo.inventory.quantity_on_hand -= quantity, logged in
   dbo.inventory_transactions with movement_type = 'SALE').

   There is deliberately NO AFTER INSERT trigger on dbo.sale_items that
   decrements inventory. Reasoning:
     - SP_CreateSale already writes the inventory change and the matching
       inventory_transactions row inside ONE transaction. Adding a trigger on
       sale_items would double-count the decrement and break the audit trail
       (two movements for one sale).
     - Keeping the movement inside the stored procedure gives full control
       over atomicity, reference_id wiring (sale_id), and the signed-quantity
       convention required by inventory_transactions.
   The same principle applies to restocking (SP_RestockProduct) and returns
   (SP_ProcessReturn) - all inventory mutations flow through explicit stored
   procedures. TRG_inventory_low_stock observes the RESULTS of those mutations
   (quantity_on_hand transitions) and never mutates inventory itself.

   ==========================================================================
   BUILD ORDER
   --------------------------------------------------------------------------
   Module 01 Authentication (roles) ...................... Standalone
   Module 02 Users ....................................... After 01
   Module 03 Business .................................... After 02
   Module 04 Categories .................................. After 02
   Module 05 Products .................................... After 02, 04, 06
   Module 06 Suppliers ................................... After 02
   Module 07 Inventory ................................... After 05, 02
   Module 08 Sales ....................................... After 05, 02, 03
   Module 11 Returns ..................................... After 08, 05, 02
   Module 12 Notifications ............................... After 02
   Module 15 Settings .................................... After 02
   Module 16 Audit ....................................... After 02
   --------------------------------------------------------------------------
   TRIGGERS (this file) must be deployed AFTER modules 01, 02, 04, 05, 06,
   07, 12, 15 and 16 have been created, because they reference those tables
   (roles, users, products, categories, suppliers, inventory, settings,
   notification_types, notifications, low_stock_alerts, audit_logs,
   password_history). Deploy with sqlcmd or SSMS after the full schema.

   ==========================================================================
   CONVENTIONS
   --------------------------------------------------------------------------
   - Trigger naming : TRG_<table>_<event>  (see NamingStandards.md).
   - Each trigger is idempotent: drops itself if it already exists.
   - SET NOCOUNT ON at the top of every trigger body.
   - All code is valid T-SQL for SQL Server 2016+ (FOR JSON support).
   ========================================================================== */

-- ==========================================================================
-- SECTION 1: TRG_products_audit
-- --------------------------------------------------------------------------
-- Audits every INSERT / UPDATE / DELETE on dbo.products.
--   action_type = 'INSERT' | 'UPDATE' | 'DELETE' | 'SOFT_DELETE'
-- resource_type = 'Product', resource_id = product_id.
-- Set-based: INSERTED + DELETED are joined on product_id; JSON snapshots are
-- produced with correlated scalar FOR JSON subqueries (no cursors).
-- ==========================================================================
IF OBJECT_ID(N'dbo.TRG_products_audit', N'TR') IS NOT NULL
    DROP TRIGGER dbo.TRG_products_audit;
GO

CREATE TRIGGER dbo.TRG_products_audit
ON dbo.products
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF (ROWCOUNT_BIG() = 0)
        RETURN;

    DECLARE @Now DATETIME2(0) = SYSUTCDATETIME();

    -- INSERT / UPDATE / SOFT_DELETE  (rows present in INSERTED)
    INSERT INTO dbo.audit_logs
        (user_id, action_type, resource_type, resource_id, old_values, new_values, created_at)
    SELECT
        NULL,
        CASE
            WHEN d.product_id IS NULL                 THEN 'INSERT'
            WHEN d.is_deleted = 0 AND i.is_deleted = 1 THEN 'SOFT_DELETE'
            ELSE                                            'UPDATE'
        END,
        'Product',
        CAST(i.product_id AS NVARCHAR(100)),
        CASE
            WHEN d.product_id IS NULL THEN NULL
            ELSE (
                SELECT d.product_id          AS product_id,
                       d.sku                 AS sku,
                       d.barcode             AS barcode,
                       d.product_name        AS product_name,
                       d.[description]       AS [description],
                       d.category_id         AS category_id,
                       d.supplier_id         AS supplier_id,
                       d.unit                AS unit,
                       d.unit_price          AS unit_price,
                       d.cost_price          AS cost_price,
                       d.low_stock_threshold AS low_stock_threshold,
                       d.is_service          AS is_service,
                       d.is_active           AS is_active,
                       d.is_deleted          AS is_deleted,
                       d.deleted_at          AS deleted_at,
                       d.deleted_by          AS deleted_by,
                       d.created_at          AS created_at,
                       d.updated_at          AS updated_at,
                       d.created_by          AS created_by,
                       d.updated_by          AS updated_by
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            )
        END,
        (
            SELECT i.product_id          AS product_id,
                   i.sku                 AS sku,
                   i.barcode             AS barcode,
                   i.product_name        AS product_name,
                   i.[description]       AS [description],
                   i.category_id         AS category_id,
                   i.supplier_id         AS supplier_id,
                   i.unit                AS unit,
                   i.unit_price          AS unit_price,
                   i.cost_price          AS cost_price,
                   i.low_stock_threshold AS low_stock_threshold,
                   i.is_service          AS is_service,
                   i.is_active           AS is_active,
                   i.is_deleted          AS is_deleted,
                   i.deleted_at          AS deleted_at,
                   i.deleted_by          AS deleted_by,
                   i.created_at          AS created_at,
                   i.updated_at          AS updated_at,
                   i.created_by          AS created_by,
                   i.updated_by          AS updated_by
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ),
        @Now
    FROM INSERTED i
    LEFT JOIN DELETED d ON d.product_id = i.product_id;

    -- Pure DELETE  (rows present only in DELETED)
    INSERT INTO dbo.audit_logs
        (user_id, action_type, resource_type, resource_id, old_values, new_values, created_at)
    SELECT
        NULL,
        'DELETE',
        'Product',
        CAST(d.product_id AS NVARCHAR(100)),
        (
            SELECT d.product_id          AS product_id,
                   d.sku                 AS sku,
                   d.barcode             AS barcode,
                   d.product_name        AS product_name,
                   d.[description]       AS [description],
                   d.category_id         AS category_id,
                   d.supplier_id         AS supplier_id,
                   d.unit                AS unit,
                   d.unit_price          AS unit_price,
                   d.cost_price          AS cost_price,
                   d.low_stock_threshold AS low_stock_threshold,
                   d.is_service          AS is_service,
                   d.is_active           AS is_active,
                   d.is_deleted          AS is_deleted,
                   d.deleted_at          AS deleted_at,
                   d.deleted_by          AS deleted_by,
                   d.created_at          AS created_at,
                   d.updated_at          AS updated_at,
                   d.created_by          AS created_by,
                   d.updated_by          AS updated_by
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ),
        NULL,
        @Now
    FROM DELETED d
    WHERE NOT EXISTS (SELECT 1 FROM INSERTED i WHERE i.product_id = d.product_id);
END
GO

-- ==========================================================================
-- SECTION 2: TRG_categories_audit
-- --------------------------------------------------------------------------
-- Audits every INSERT / UPDATE / DELETE on dbo.categories.
--   action_type = 'INSERT' | 'UPDATE' | 'DELETE' | 'SOFT_DELETE'
-- resource_type = 'Category', resource_id = category_id.
-- ==========================================================================
IF OBJECT_ID(N'dbo.TRG_categories_audit', N'TR') IS NOT NULL
    DROP TRIGGER dbo.TRG_categories_audit;
GO

CREATE TRIGGER dbo.TRG_categories_audit
ON dbo.categories
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF (ROWCOUNT_BIG() = 0)
        RETURN;

    DECLARE @Now DATETIME2(0) = SYSUTCDATETIME();

    -- INSERT / UPDATE / SOFT_DELETE
    INSERT INTO dbo.audit_logs
        (user_id, action_type, resource_type, resource_id, old_values, new_values, created_at)
    SELECT
        NULL,
        CASE
            WHEN d.category_id IS NULL                 THEN 'INSERT'
            WHEN d.is_deleted = 0 AND i.is_deleted = 1 THEN 'SOFT_DELETE'
            ELSE                                             'UPDATE'
        END,
        'Category',
        CAST(i.category_id AS NVARCHAR(100)),
        CASE
            WHEN d.category_id IS NULL THEN NULL
            ELSE (
                SELECT d.category_id   AS category_id,
                       d.category_name AS category_name,
                       d.parent_id     AS parent_id,
                       d.[description] AS [description],
                       d.sort_order    AS sort_order,
                       d.is_active     AS is_active,
                       d.is_deleted    AS is_deleted,
                       d.deleted_at    AS deleted_at,
                       d.deleted_by    AS deleted_by,
                       d.created_at    AS created_at,
                       d.updated_at    AS updated_at,
                       d.created_by    AS created_by,
                       d.updated_by    AS updated_by
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            )
        END,
        (
            SELECT i.category_id   AS category_id,
                   i.category_name AS category_name,
                   i.parent_id     AS parent_id,
                   i.[description] AS [description],
                   i.sort_order    AS sort_order,
                   i.is_active     AS is_active,
                   i.is_deleted    AS is_deleted,
                   i.deleted_at    AS deleted_at,
                   i.deleted_by    AS deleted_by,
                   i.created_at    AS created_at,
                   i.updated_at    AS updated_at,
                   i.created_by    AS created_by,
                   i.updated_by    AS updated_by
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ),
        @Now
    FROM INSERTED i
    LEFT JOIN DELETED d ON d.category_id = i.category_id;

    -- Pure DELETE
    INSERT INTO dbo.audit_logs
        (user_id, action_type, resource_type, resource_id, old_values, new_values, created_at)
    SELECT
        NULL,
        'DELETE',
        'Category',
        CAST(d.category_id AS NVARCHAR(100)),
        (
            SELECT d.category_id   AS category_id,
                   d.category_name AS category_name,
                   d.parent_id     AS parent_id,
                   d.[description] AS [description],
                   d.sort_order    AS sort_order,
                   d.is_active     AS is_active,
                   d.is_deleted    AS is_deleted,
                   d.deleted_at    AS deleted_at,
                   d.deleted_by    AS deleted_by,
                   d.created_at    AS created_at,
                   d.updated_at    AS updated_at,
                   d.created_by    AS created_by,
                   d.updated_by    AS updated_by
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ),
        NULL,
        @Now
    FROM DELETED d
    WHERE NOT EXISTS (SELECT 1 FROM INSERTED i WHERE i.category_id = d.category_id);
END
GO

-- ==========================================================================
-- SECTION 3: TRG_suppliers_audit
-- --------------------------------------------------------------------------
-- Audits every INSERT / UPDATE / DELETE on dbo.suppliers.
--   action_type = 'INSERT' | 'UPDATE' | 'DELETE' | 'SOFT_DELETE'
-- resource_type = 'Supplier', resource_id = supplier_id.
-- ==========================================================================
IF OBJECT_ID(N'dbo.TRG_suppliers_audit', N'TR') IS NOT NULL
    DROP TRIGGER dbo.TRG_suppliers_audit;
GO

CREATE TRIGGER dbo.TRG_suppliers_audit
ON dbo.suppliers
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF (ROWCOUNT_BIG() = 0)
        RETURN;

    DECLARE @Now DATETIME2(0) = SYSUTCDATETIME();

    -- INSERT / UPDATE / SOFT_DELETE
    INSERT INTO dbo.audit_logs
        (user_id, action_type, resource_type, resource_id, old_values, new_values, created_at)
    SELECT
        NULL,
        CASE
            WHEN d.supplier_id IS NULL                 THEN 'INSERT'
            WHEN d.is_deleted = 0 AND i.is_deleted = 1 THEN 'SOFT_DELETE'
            ELSE                                             'UPDATE'
        END,
        'Supplier',
        CAST(i.supplier_id AS NVARCHAR(100)),
        CASE
            WHEN d.supplier_id IS NULL THEN NULL
            ELSE (
                SELECT d.supplier_id    AS supplier_id,
                       d.supplier_code  AS supplier_code,
                       d.supplier_name  AS supplier_name,
                       d.contact_person AS contact_person,
                       d.email          AS email,
                       d.phone          AS phone,
                       d.address_line1  AS address_line1,
                       d.address_line2  AS address_line2,
                       d.city           AS city,
                       d.[state]        AS [state],
                       d.postal_code    AS postal_code,
                       d.country        AS country,
                       d.[notes]        AS [notes],
                       d.is_active      AS is_active,
                       d.is_deleted     AS is_deleted,
                       d.deleted_at     AS deleted_at,
                       d.deleted_by     AS deleted_by,
                       d.created_at     AS created_at,
                       d.updated_at     AS updated_at,
                       d.created_by     AS created_by,
                       d.updated_by     AS updated_by
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            )
        END,
        (
            SELECT i.supplier_id    AS supplier_id,
                   i.supplier_code  AS supplier_code,
                   i.supplier_name  AS supplier_name,
                   i.contact_person AS contact_person,
                   i.email          AS email,
                   i.phone          AS phone,
                   i.address_line1  AS address_line1,
                   i.address_line2  AS address_line2,
                   i.city           AS city,
                   i.[state]        AS [state],
                   i.postal_code    AS postal_code,
                   i.country        AS country,
                   i.[notes]        AS [notes],
                   i.is_active      AS is_active,
                   i.is_deleted     AS is_deleted,
                   i.deleted_at     AS deleted_at,
                   i.deleted_by     AS deleted_by,
                   i.created_at     AS created_at,
                   i.updated_at     AS updated_at,
                   i.created_by     AS created_by,
                   i.updated_by     AS updated_by
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ),
        @Now
    FROM INSERTED i
    LEFT JOIN DELETED d ON d.supplier_id = i.supplier_id;

    -- Pure DELETE
    INSERT INTO dbo.audit_logs
        (user_id, action_type, resource_type, resource_id, old_values, new_values, created_at)
    SELECT
        NULL,
        'DELETE',
        'Supplier',
        CAST(d.supplier_id AS NVARCHAR(100)),
        (
            SELECT d.supplier_id    AS supplier_id,
                   d.supplier_code  AS supplier_code,
                   d.supplier_name  AS supplier_name,
                   d.contact_person AS contact_person,
                   d.email          AS email,
                   d.phone          AS phone,
                   d.address_line1  AS address_line1,
                   d.address_line2  AS address_line2,
                   d.city           AS city,
                   d.[state]        AS [state],
                   d.postal_code    AS postal_code,
                   d.country        AS country,
                   d.[notes]        AS [notes],
                   d.is_active      AS is_active,
                   d.is_deleted     AS is_deleted,
                   d.deleted_at     AS deleted_at,
                   d.deleted_by     AS deleted_by,
                   d.created_at     AS created_at,
                   d.updated_at     AS updated_at,
                   d.created_by     AS created_by,
                   d.updated_by     AS updated_by
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ),
        NULL,
        @Now
    FROM DELETED d
    WHERE NOT EXISTS (SELECT 1 FROM INSERTED i WHERE i.supplier_id = d.supplier_id);
END
GO

-- ==========================================================================
-- SECTION 4: TRG_users_audit
-- --------------------------------------------------------------------------
-- Audits every INSERT / UPDATE / DELETE on dbo.users.
--   action_type = 'INSERT' | 'UPDATE' | 'DELETE' | 'SOFT_DELETE'
-- resource_type = 'User', resource_id = user_id.
--
-- SECURITY: password_hash is NEVER written into the JSON snapshots.
-- Only the explicit safe column list below is captured:
--   user_id, username, email, full_name, phone, role_id, is_active,
--   is_locked, must_change_password, last_login_at, is_deleted.
-- ==========================================================================
IF OBJECT_ID(N'dbo.TRG_users_audit', N'TR') IS NOT NULL
    DROP TRIGGER dbo.TRG_users_audit;
GO

CREATE TRIGGER dbo.TRG_users_audit
ON dbo.users
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF (ROWCOUNT_BIG() = 0)
        RETURN;

    DECLARE @Now DATETIME2(0) = SYSUTCDATETIME();

    -- INSERT / UPDATE / SOFT_DELETE
    INSERT INTO dbo.audit_logs
        (user_id, action_type, resource_type, resource_id, old_values, new_values, created_at)
    SELECT
        NULL,
        CASE
            WHEN d.user_id IS NULL                 THEN 'INSERT'
            WHEN d.is_deleted = 0 AND i.is_deleted = 1 THEN 'SOFT_DELETE'
            ELSE                                          'UPDATE'
        END,
        'User',
        CAST(i.user_id AS NVARCHAR(100)),
        CASE
            WHEN d.user_id IS NULL THEN NULL
            ELSE (
                SELECT d.user_id               AS user_id,
                       d.username              AS username,
                       d.email                 AS email,
                       d.full_name             AS full_name,
                       d.phone                 AS phone,
                       d.role_id               AS role_id,
                       d.is_active             AS is_active,
                       d.is_locked             AS is_locked,
                       d.must_change_password  AS must_change_password,
                       d.last_login_at         AS last_login_at,
                       d.is_deleted            AS is_deleted
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            )
        END,
        (
            SELECT i.user_id               AS user_id,
                   i.username              AS username,
                   i.email                 AS email,
                   i.full_name             AS full_name,
                   i.phone                 AS phone,
                   i.role_id               AS role_id,
                   i.is_active             AS is_active,
                   i.is_locked             AS is_locked,
                   i.must_change_password  AS must_change_password,
                   i.last_login_at         AS last_login_at,
                   i.is_deleted            AS is_deleted
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ),
        @Now
    FROM INSERTED i
    LEFT JOIN DELETED d ON d.user_id = i.user_id;

    -- Pure DELETE
    INSERT INTO dbo.audit_logs
        (user_id, action_type, resource_type, resource_id, old_values, new_values, created_at)
    SELECT
        NULL,
        'DELETE',
        'User',
        CAST(d.user_id AS NVARCHAR(100)),
        (
            SELECT d.user_id               AS user_id,
                   d.username              AS username,
                   d.email                 AS email,
                   d.full_name             AS full_name,
                   d.phone                 AS phone,
                   d.role_id               AS role_id,
                   d.is_active             AS is_active,
                   d.is_locked             AS is_locked,
                   d.must_change_password  AS must_change_password,
                   d.last_login_at         AS last_login_at,
                   d.is_deleted            AS is_deleted
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ),
        NULL,
        @Now
    FROM DELETED d
    WHERE NOT EXISTS (SELECT 1 FROM INSERTED i WHERE i.user_id = d.user_id);
END
GO

-- ==========================================================================
-- SECTION 5: TRG_settings_audit
-- --------------------------------------------------------------------------
-- Audits every INSERT / UPDATE / DELETE on dbo.settings.
--   action_type = 'INSERT' | 'UPDATE' | 'DELETE'
-- resource_type = 'Setting', resource_id = setting_id.
-- Note: settings uses soft config toggles (is_active) but NOT is_deleted;
--       therefore only INSERT / UPDATE / DELETE apply here.
-- ==========================================================================
IF OBJECT_ID(N'dbo.TRG_settings_audit', N'TR') IS NOT NULL
    DROP TRIGGER dbo.TRG_settings_audit;
GO

CREATE TRIGGER dbo.TRG_settings_audit
ON dbo.settings
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF (ROWCOUNT_BIG() = 0)
        RETURN;

    DECLARE @Now DATETIME2(0) = SYSUTCDATETIME();

    -- INSERT / UPDATE
    INSERT INTO dbo.audit_logs
        (user_id, action_type, resource_type, resource_id, old_values, new_values, created_at)
    SELECT
        NULL,
        CASE WHEN d.setting_id IS NULL THEN 'INSERT' ELSE 'UPDATE' END,
        'Setting',
        CAST(i.setting_id AS NVARCHAR(100)),
        CASE
            WHEN d.setting_id IS NULL THEN NULL
            ELSE (
                SELECT d.setting_id    AS setting_id,
                       d.setting_key   AS setting_key,
                       d.setting_value AS setting_value,
                       d.data_type     AS data_type,
                       d.category      AS category,
                       d.[description] AS [description],
                       d.is_active     AS is_active,
                       d.created_at    AS created_at,
                       d.updated_at    AS updated_at,
                       d.created_by    AS created_by,
                       d.updated_by    AS updated_by
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            )
        END,
        (
            SELECT i.setting_id    AS setting_id,
                   i.setting_key   AS setting_key,
                   i.setting_value AS setting_value,
                   i.data_type     AS data_type,
                   i.category      AS category,
                   i.[description] AS [description],
                   i.is_active     AS is_active,
                   i.created_at    AS created_at,
                   i.updated_at    AS updated_at,
                   i.created_by    AS created_by,
                   i.updated_by    AS updated_by
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ),
        @Now
    FROM INSERTED i
    LEFT JOIN DELETED d ON d.setting_id = i.setting_id;

    -- Pure DELETE
    INSERT INTO dbo.audit_logs
        (user_id, action_type, resource_type, resource_id, old_values, new_values, created_at)
    SELECT
        NULL,
        'DELETE',
        'Setting',
        CAST(d.setting_id AS NVARCHAR(100)),
        (
            SELECT d.setting_id    AS setting_id,
                   d.setting_key   AS setting_key,
                   d.setting_value AS setting_value,
                   d.data_type     AS data_type,
                   d.category      AS category,
                   d.[description] AS [description],
                   d.is_active     AS is_active,
                   d.created_at    AS created_at,
                   d.updated_at    AS updated_at,
                   d.created_by    AS created_by,
                   d.updated_by    AS updated_by
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ),
        NULL,
        @Now
    FROM DELETED d
    WHERE NOT EXISTS (SELECT 1 FROM INSERTED i WHERE i.setting_id = d.setting_id);
END
GO

-- ==========================================================================
-- SECTION 6: TRG_inventory_low_stock
-- --------------------------------------------------------------------------
-- AFTER UPDATE on dbo.inventory. Handles BOTH directions in one trigger by
-- joining INSERTED and DELETED on product_id:
--
--   1. DROP direction: quantity_on_hand goes from a value ABOVE the product's
--      low_stock_threshold to a value AT OR BELOW it.
--         -> insert dbo.low_stock_alerts (status = 'OPEN') unless an OPEN
--            alert for that product already exists.
--         -> notify ADMIN + MANAGER users (via dbo.roles.role_code IN
--            ('ADMIN','MANAGER'), dbo.notification_types.type_code =
--            'LOW_STOCK') once per newly raised alert: severity 'WARNING',
--            entity_type 'Product', entity_id product_id.
--
--   2. RECOVERY direction: quantity_on_hand goes from AT OR BELOW the
--      threshold to a value ABOVE it.
--         -> resolve OPEN alerts: status = 'RESOLVED', resolved_at = now.
--
--   The threshold is read from dbo.products.low_stock_threshold (the current
--   per-product value). dbo.inventory itself carries no threshold column.
--
--   Recursion safety: this trigger writes ONLY to dbo.low_stock_alerts and
--   dbo.notifications, neither of which has a trigger that modifies
--   dbo.inventory, so it can never re-fire itself.
-- ==========================================================================
IF OBJECT_ID(N'dbo.TRG_inventory_low_stock', N'TR') IS NOT NULL
    DROP TRIGGER dbo.TRG_inventory_low_stock;
GO

CREATE TRIGGER dbo.TRG_inventory_low_stock
ON dbo.inventory
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF (ROWCOUNT_BIG() = 0)
        RETURN;

    -- Nothing meaningful changes unless quantity_on_hand was a target column.
    IF NOT UPDATE(quantity_on_hand)
        RETURN;

    DECLARE @Now DATETIME2(0) = SYSUTCDATETIME();

    -- ------------------------------------------------------------------
    -- 1a. RAISE alerts: stock dropped to/below the threshold.
    --     Only when NO OPEN alert exists for that product (no duplicates).
    -- ------------------------------------------------------------------
    INSERT INTO dbo.low_stock_alerts
        (product_id, quantity_on_hand, low_stock_threshold, status, raised_at)
    SELECT
        i.product_id,
        i.quantity_on_hand,
        p.low_stock_threshold,
        'OPEN',
        @Now
    FROM INSERTED i
    INNER JOIN DELETED d    ON d.product_id = i.product_id
    INNER JOIN dbo.products p ON p.product_id = i.product_id
    WHERE d.quantity_on_hand > p.low_stock_threshold
      AND i.quantity_on_hand <= p.low_stock_threshold
      AND NOT EXISTS
          (
              SELECT 1
              FROM dbo.low_stock_alerts la
              WHERE la.product_id = i.product_id
                AND la.status = 'OPEN'
          );

    -- ------------------------------------------------------------------
    -- 1b. NOTIFY ADMIN + MANAGER users about each newly raised alert.
    --     Same filter as 1a guarantees one notification wave per new alert.
    -- ------------------------------------------------------------------
    INSERT INTO dbo.notifications
        (user_id, notification_type_id, title, [message], severity,
         entity_type, entity_id, is_read, is_dismissed, created_at)
    SELECT
        u.user_id,
        nt.notification_type_id,
        N'Low stock alert: ' + p.product_name,
        N'Product "' + p.product_name + N'" (ID ' + CAST(i.product_id AS NVARCHAR(10))
        + N') has ' + CAST(i.quantity_on_hand AS NVARCHAR(10))
        + N' unit(s) on hand, which is at or below the restock threshold of '
        + CAST(p.low_stock_threshold AS NVARCHAR(10)) + N'. Please restock soon.',
        'WARNING',
        'Product',
        CAST(i.product_id AS NVARCHAR(100)),
        0,
        0,
        @Now
    FROM INSERTED i
    INNER JOIN DELETED d    ON d.product_id = i.product_id
    INNER JOIN dbo.products p ON p.product_id = i.product_id
    INNER JOIN dbo.roles r    ON r.role_code IN (N'ADMIN', N'MANAGER')
    INNER JOIN dbo.users u    ON u.role_id = r.role_id
    INNER JOIN dbo.notification_types nt ON nt.type_code = N'LOW_STOCK'
    WHERE d.quantity_on_hand > p.low_stock_threshold
      AND i.quantity_on_hand <= p.low_stock_threshold
      AND u.is_active = 1
      AND NOT EXISTS
          (
              SELECT 1
              FROM dbo.low_stock_alerts la
              WHERE la.product_id = i.product_id
                AND la.status = 'OPEN'
          );

    -- ------------------------------------------------------------------
    -- 2. RESOLVE alerts: stock recovered above the threshold.
    -- ------------------------------------------------------------------
    UPDATE la
    SET la.status = 'RESOLVED',
        la.resolved_at = @Now
    FROM dbo.low_stock_alerts la
    INNER JOIN INSERTED i    ON i.product_id = la.product_id
    INNER JOIN DELETED d     ON d.product_id = i.product_id
    INNER JOIN dbo.products p ON p.product_id = i.product_id
    WHERE la.status = 'OPEN'
      AND d.quantity_on_hand <= p.low_stock_threshold
      AND i.quantity_on_hand > p.low_stock_threshold;
END
GO

-- ==========================================================================
-- SECTION 7: TRG_password_history_retention
-- --------------------------------------------------------------------------
-- AFTER INSERT on dbo.password_history.
-- Enforces a maximum of 5 recent history rows per user. After every insert,
-- the oldest rows beyond the 5 most recent for that user are deleted.
-- "Most recent" is determined by history_id (identity, monotonic with insert
-- order). Set-based: ROW_NUMBER() PARTITION BY user_id ORDER BY history_id
-- DESC, delete every row ranked > 5.
--
-- Recursion safety: this is an AFTER INSERT trigger; its DELETE against the
-- same table cannot re-fire it because there is no AFTER DELETE trigger on
-- dbo.password_history.
-- ==========================================================================
IF OBJECT_ID(N'dbo.TRG_password_history_retention', N'TR') IS NOT NULL
    DROP TRIGGER dbo.TRG_password_history_retention;
GO

CREATE TRIGGER dbo.TRG_password_history_retention
ON dbo.password_history
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    IF (ROWCOUNT_BIG() = 0)
        RETURN;

    DELETE ph
    FROM dbo.password_history ph
    INNER JOIN
    (
        SELECT
            ph2.history_id,
            ROW_NUMBER() OVER (PARTITION BY ph2.user_id ORDER BY ph2.history_id DESC) AS rn
        FROM dbo.password_history ph2
        WHERE ph2.user_id IN (SELECT DISTINCT user_id FROM INSERTED)
    ) ranked ON ranked.history_id = ph.history_id
    WHERE ranked.rn > 5;
END
GO

-- ==========================================================================
-- END OF FILE
-- ==========================================================================
