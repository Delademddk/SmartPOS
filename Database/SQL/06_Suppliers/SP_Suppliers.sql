/* ==========================================================================
   SmartPOS Database - MODULE 06: SUPPLIERS PROCEDURES
   --------------------------------------------------------------------------
   SP_GetSuppliers          - paginated supplier list with product counts
   SP_GetSupplier           - single supplier + contacts + history
   SP_CreateSupplier        - insert with unique code/name + email validation
   SP_UpdateSupplier        - update supplier fields
   SP_DeleteSupplier        - soft delete
   SP_GetSupplierContacts   - contacts for a supplier
   SP_AddSupplierContact    - add contact (optional primary)
   SP_UpdateSupplierContact - update contact
   SP_DeleteSupplierContact - deactivate contact
   SP_LogSupplierHistory    - append a history entry

   Depends on: dbo.suppliers, dbo.supplier_contacts, dbo.supplier_history,
               dbo.products, dbo.users, dbo.error_logs.
   Conventions: SP_<Purpose>, snake_case, transactions, TRY...CATCH + THROW,
                soft deletes, pagination with TotalCount.
   ========================================================================== */

/* ---------------------------------------------------------------------------
   SP_GetSuppliers
   Paginated supplier list with search and a product count per supplier.
   @IncludeDeleted controls visibility of soft-deleted rows.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_GetSuppliers', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_GetSuppliers;
GO
CREATE PROCEDURE dbo.SP_GetSuppliers
    @Page           INT = 1,
    @PageSize       INT = 50,
    @Search         NVARCHAR(150) = NULL,
    @IncludeDeleted BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Offset INT;
    DECLARE @Total  INT;

    IF @Page < 1 SET @Page = 1;
    IF @PageSize < 1 SET @PageSize = 50;
    IF @PageSize > 500 SET @PageSize = 500;
    SET @Offset = (@Page - 1) * @PageSize;

    SELECT @Total = COUNT(*)
    FROM dbo.suppliers s
    WHERE (@IncludeDeleted = 1 OR s.is_deleted = 0)
      AND (@Search IS NULL OR
           s.supplier_name LIKE N'%' + @Search + N'%' OR
           s.supplier_code LIKE N'%' + @Search + N'%' OR
           s.contact_person LIKE N'%' + @Search + N'%');

    SELECT
        s.supplier_id,
        s.supplier_code,
        s.supplier_name,
        s.contact_person,
        s.email,
        s.phone,
        s.city,
        s.country,
        s.is_active,
        s.is_deleted,
        s.deleted_at,
        s.deleted_by,
        s.created_at,
        s.updated_at,
        (SELECT COUNT(*) FROM dbo.products p WHERE p.supplier_id = s.supplier_id AND p.is_deleted = 0) AS product_count,
        @Total AS total_count
    FROM dbo.suppliers s
    WHERE (@IncludeDeleted = 1 OR s.is_deleted = 0)
      AND (@Search IS NULL OR
           s.supplier_name LIKE N'%' + @Search + N'%' OR
           s.supplier_code LIKE N'%' + @Search + N'%' OR
           s.contact_person LIKE N'%' + @Search + N'%')
    ORDER BY s.supplier_name
    OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

/* ---------------------------------------------------------------------------
   SP_GetSupplier
   Returns one supplier row, its contacts, and its history as three result
   sets. Contacts exclude inactive entries; history is newest first.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_GetSupplier', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_GetSupplier;
GO
CREATE PROCEDURE dbo.SP_GetSupplier
    @SupplierID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        s.supplier_id,
        s.supplier_code,
        s.supplier_name,
        s.contact_person,
        s.email,
        s.phone,
        s.address_line1,
        s.address_line2,
        s.city,
        s.[state],
        s.postal_code,
        s.country,
        s.[notes],
        s.is_active,
        s.is_deleted,
        s.deleted_at,
        s.deleted_by,
        s.created_at,
        s.updated_at,
        s.created_by,
        s.updated_by,
        (SELECT COUNT(*) FROM dbo.products p WHERE p.supplier_id = s.supplier_id AND p.is_deleted = 0) AS product_count
    FROM dbo.suppliers s
    WHERE s.supplier_id = @SupplierID;

    SELECT
        contact_id,
        supplier_id,
        full_name,
        job_title,
        email,
        phone,
        is_primary,
        is_active,
        created_at,
        updated_at
    FROM dbo.supplier_contacts
    WHERE supplier_id = @SupplierID
      AND is_active = 1
    ORDER BY is_primary DESC, contact_id;

    SELECT
        history_id,
        supplier_id,
        history_type,
        [description],
        changed_by,
        changed_at
    FROM dbo.supplier_history
    WHERE supplier_id = @SupplierID
    ORDER BY changed_at DESC;
END
GO

/* ---------------------------------------------------------------------------
   SP_CreateSupplier
   Creates a supplier with a unique code and name, a basic email format check,
   and a CREATED history entry. Returns the new SupplierID.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_CreateSupplier', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_CreateSupplier;
GO
CREATE PROCEDURE dbo.SP_CreateSupplier
    @Code           NVARCHAR(30),
    @Name           NVARCHAR(150),
    @ContactPerson  NVARCHAR(150) = NULL,
    @Email          NVARCHAR(255) = NULL,
    @Phone          NVARCHAR(30)  = NULL,
    @AddressLine1   NVARCHAR(255) = NULL,
    @AddressLine2   NVARCHAR(255) = NULL,
    @City           NVARCHAR(100) = NULL,
    @State          NVARCHAR(100) = NULL,
    @PostalCode     NVARCHAR(20)  = NULL,
    @Country        NVARCHAR(100) = NULL,
    @Notes          NVARCHAR(MAX) = NULL,
    @CreatedByID    INT = NULL,
    @SupplierID     INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Now DATETIME2(0) = SYSUTCDATETIME();

    BEGIN TRY
        IF NULLIF(LTRIM(RTRIM(@Code)), N'') IS NULL
            THROW 52001, N'A supplier code is required.', 1;
        IF NULLIF(LTRIM(RTRIM(@Name)), N'') IS NULL
            THROW 52002, N'A supplier name is required.', 1;

        IF EXISTS (SELECT 1 FROM dbo.suppliers WHERE supplier_code = @Code)
            THROW 52003, N'This supplier code is already in use.', 1;
        IF EXISTS (SELECT 1 FROM dbo.suppliers WHERE supplier_name = @Name)
            THROW 52004, N'This supplier name is already in use.', 1;

        -- Basic email format check (only when a value was supplied)
        IF @Email IS NOT NULL AND NULLIF(LTRIM(RTRIM(@Email)), N'') IS NOT NULL
           AND @Email NOT LIKE N'%_@_%_.__%'
            THROW 52005, N'Please provide a valid email address.', 1;

        BEGIN TRANSACTION;

        INSERT INTO dbo.suppliers
            (supplier_code, supplier_name, contact_person, email, phone,
             address_line1, address_line2, city, [state], postal_code, country,
             [notes], is_active, is_deleted, created_at, updated_at,
             created_by, updated_by)
        VALUES
            (@Code, @Name, @ContactPerson, @Email, @Phone,
             @AddressLine1, @AddressLine2, @City, @State, @PostalCode, @Country,
             @Notes, 1, 0, @Now, @Now, @CreatedByID, @CreatedByID);

        SET @SupplierID = SCOPE_IDENTITY();

        INSERT INTO dbo.supplier_history (supplier_id, history_type, [description], changed_by, changed_at)
        VALUES (@SupplierID, N'CREATED', N'Supplier created.', @CreatedByID, @Now);

        COMMIT TRANSACTION;

        SELECT @SupplierID AS SupplierID;
        RETURN @SupplierID;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        INSERT INTO dbo.error_logs (user_id, error_code, message, stack_trace, source)
        VALUES (@CreatedByID, N'SP_CreateSupplier', ERROR_MESSAGE(), ERROR_PROCEDURE(), N'SP_CreateSupplier');
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------------
   SP_UpdateSupplier
   Updates supplier fields, re-validating uniqueness and email format, and
   appends an UPDATED history entry.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_UpdateSupplier', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_UpdateSupplier;
GO
CREATE PROCEDURE dbo.SP_UpdateSupplier
    @SupplierID     INT,
    @Code           NVARCHAR(30),
    @Name           NVARCHAR(150),
    @ContactPerson  NVARCHAR(150) = NULL,
    @Email          NVARCHAR(255) = NULL,
    @Phone          NVARCHAR(30)  = NULL,
    @AddressLine1   NVARCHAR(255) = NULL,
    @AddressLine2   NVARCHAR(255) = NULL,
    @City           NVARCHAR(100) = NULL,
    @State          NVARCHAR(100) = NULL,
    @PostalCode     NVARCHAR(20)  = NULL,
    @Country        NVARCHAR(100) = NULL,
    @Notes          NVARCHAR(MAX) = NULL,
    @UpdatedByID    INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Now DATETIME2(0) = SYSUTCDATETIME();

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.suppliers WHERE supplier_id = @SupplierID AND is_deleted = 0)
            THROW 52006, N'Supplier does not exist or is deleted.', 1;
        IF NULLIF(LTRIM(RTRIM(@Code)), N'') IS NULL
            THROW 52001, N'A supplier code is required.', 1;
        IF NULLIF(LTRIM(RTRIM(@Name)), N'') IS NULL
            THROW 52002, N'A supplier name is required.', 1;

        IF EXISTS (SELECT 1 FROM dbo.suppliers WHERE supplier_code = @Code AND supplier_id <> @SupplierID)
            THROW 52003, N'This supplier code is already in use.', 1;
        IF EXISTS (SELECT 1 FROM dbo.suppliers WHERE supplier_name = @Name AND supplier_id <> @SupplierID)
            THROW 52004, N'This supplier name is already in use.', 1;

        IF @Email IS NOT NULL AND NULLIF(LTRIM(RTRIM(@Email)), N'') IS NOT NULL
           AND @Email NOT LIKE N'%_@_%_.__%'
            THROW 52005, N'Please provide a valid email address.', 1;

        BEGIN TRANSACTION;

        UPDATE dbo.suppliers
        SET supplier_code  = @Code,
            supplier_name  = @Name,
            contact_person = @ContactPerson,
            email          = @Email,
            phone          = @Phone,
            address_line1  = @AddressLine1,
            address_line2  = @AddressLine2,
            city           = @City,
            [state]        = @State,
            postal_code    = @PostalCode,
            country        = @Country,
            [notes]        = @Notes,
            updated_at     = @Now,
            updated_by     = @UpdatedByID
        WHERE supplier_id = @SupplierID;

        INSERT INTO dbo.supplier_history (supplier_id, history_type, [description], changed_by, changed_at)
        VALUES (@SupplierID, N'UPDATED', N'Supplier details updated.', @UpdatedByID, @Now);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        INSERT INTO dbo.error_logs (user_id, error_code, message, stack_trace, source)
        VALUES (@UpdatedByID, N'SP_UpdateSupplier', ERROR_MESSAGE(), ERROR_PROCEDURE(), N'SP_UpdateSupplier');
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------------
   SP_DeleteSupplier
   Soft deletes a supplier and records a DELETED history entry.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_DeleteSupplier', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_DeleteSupplier;
GO
CREATE PROCEDURE dbo.SP_DeleteSupplier
    @SupplierID   INT,
    @DeletedByID  INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Now DATETIME2(0) = SYSUTCDATETIME();

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.suppliers WHERE supplier_id = @SupplierID AND is_deleted = 0)
            THROW 52007, N'Supplier does not exist or is already deleted.', 1;

        BEGIN TRANSACTION;

        UPDATE dbo.suppliers
        SET is_deleted = 1,
            is_active  = 0,
            deleted_at = @Now,
            deleted_by = @DeletedByID,
            updated_at = @Now,
            updated_by = @DeletedByID
        WHERE supplier_id = @SupplierID;

        INSERT INTO dbo.supplier_history (supplier_id, history_type, [description], changed_by, changed_at)
        VALUES (@SupplierID, N'DELETED', N'Supplier soft-deleted.', @DeletedByID, @Now);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        INSERT INTO dbo.error_logs (user_id, error_code, message, stack_trace, source)
        VALUES (@DeletedByID, N'SP_DeleteSupplier', ERROR_MESSAGE(), ERROR_PROCEDURE(), N'SP_DeleteSupplier');
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------------
   SP_GetSupplierContacts
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_GetSupplierContacts', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_GetSupplierContacts;
GO
CREATE PROCEDURE dbo.SP_GetSupplierContacts
    @SupplierID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        contact_id,
        supplier_id,
        full_name,
        job_title,
        email,
        phone,
        is_primary,
        is_active,
        created_at,
        updated_at
    FROM dbo.supplier_contacts
    WHERE supplier_id = @SupplierID
    ORDER BY is_primary DESC, is_active DESC, contact_id;
END
GO

/* ---------------------------------------------------------------------------
   SP_AddSupplierContact
   Adds a contact; if @IsPrimary = 1 all other contacts of the supplier are
   demoted so exactly one primary remains. Appends a CONTACT_CHANGED history
   entry.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_AddSupplierContact', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_AddSupplierContact;
GO
CREATE PROCEDURE dbo.SP_AddSupplierContact
    @SupplierID INT,
    @FullName   NVARCHAR(150),
    @JobTitle   NVARCHAR(100) = NULL,
    @Email      NVARCHAR(255) = NULL,
    @Phone      NVARCHAR(30)  = NULL,
    @IsPrimary  BIT = 0,
    @ContactID  INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Now DATETIME2(0) = SYSUTCDATETIME();

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.suppliers WHERE supplier_id = @SupplierID AND is_deleted = 0)
            THROW 52008, N'Supplier does not exist.', 1;
        IF NULLIF(LTRIM(RTRIM(@FullName)), N'') IS NULL
            THROW 52009, N'A contact full name is required.', 1;

        IF @Email IS NOT NULL AND NULLIF(LTRIM(RTRIM(@Email)), N'') IS NOT NULL
           AND @Email NOT LIKE N'%_@_%_.__%'
            THROW 52005, N'Please provide a valid email address.', 1;

        BEGIN TRANSACTION;

        IF ISNULL(@IsPrimary, 0) = 1
            UPDATE dbo.supplier_contacts SET is_primary = 0 WHERE supplier_id = @SupplierID;

        INSERT INTO dbo.supplier_contacts
            (supplier_id, full_name, job_title, email, phone, is_primary, is_active, created_at, updated_at)
        VALUES
            (@SupplierID, @FullName, @JobTitle, @Email, @Phone, ISNULL(@IsPrimary, 0), 1, @Now, @Now);

        SET @ContactID = SCOPE_IDENTITY();

        INSERT INTO dbo.supplier_history (supplier_id, history_type, [description], changed_by, changed_at)
        VALUES (@SupplierID, N'CONTACT_CHANGED', N'Contact ' + @FullName + N' added.', NULL, @Now);

        COMMIT TRANSACTION;

        SELECT @ContactID AS ContactID;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        INSERT INTO dbo.error_logs (user_id, error_code, message, stack_trace, source)
        VALUES (NULL, N'SP_AddSupplierContact', ERROR_MESSAGE(), ERROR_PROCEDURE(), N'SP_AddSupplierContact');
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------------
   SP_UpdateSupplierContact
   Updates contact details and optionally re-assigns primary. Appends a
   CONTACT_CHANGED history entry.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_UpdateSupplierContact', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_UpdateSupplierContact;
GO
CREATE PROCEDURE dbo.SP_UpdateSupplierContact
    @ContactID  INT,
    @FullName   NVARCHAR(150),
    @JobTitle   NVARCHAR(100) = NULL,
    @Email      NVARCHAR(255) = NULL,
    @Phone      NVARCHAR(30)  = NULL,
    @IsPrimary  BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Now DATETIME2(0) = SYSUTCDATETIME();
    DECLARE @SupplierID INT;

    BEGIN TRY
        SELECT @SupplierID = supplier_id
        FROM dbo.supplier_contacts
        WHERE contact_id = @ContactID AND is_active = 1;

        IF @SupplierID IS NULL
            THROW 52010, N'Contact not found.', 1;
        IF NULLIF(LTRIM(RTRIM(@FullName)), N'') IS NULL
            THROW 52009, N'A contact full name is required.', 1;

        IF @Email IS NOT NULL AND NULLIF(LTRIM(RTRIM(@Email)), N'') IS NOT NULL
           AND @Email NOT LIKE N'%_@_%_.__%'
            THROW 52005, N'Please provide a valid email address.', 1;

        BEGIN TRANSACTION;

        IF ISNULL(@IsPrimary, 0) = 1
            UPDATE dbo.supplier_contacts SET is_primary = 0 WHERE supplier_id = @SupplierID;

        UPDATE dbo.supplier_contacts
        SET full_name   = @FullName,
            job_title   = @JobTitle,
            email       = @Email,
            phone       = @Phone,
            is_primary  = ISNULL(@IsPrimary, 0),
            updated_at  = @Now
        WHERE contact_id = @ContactID;

        INSERT INTO dbo.supplier_history (supplier_id, history_type, [description], changed_by, changed_at)
        VALUES (@SupplierID, N'CONTACT_CHANGED', N'Contact ' + @FullName + N' updated.', NULL, @Now);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        INSERT INTO dbo.error_logs (user_id, error_code, message, stack_trace, source)
        VALUES (NULL, N'SP_UpdateSupplierContact', ERROR_MESSAGE(), ERROR_PROCEDURE(), N'SP_UpdateSupplierContact');
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------------
   SP_DeleteSupplierContact
   Soft-deactivates a contact (is_active = 0) and appends a history entry.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_DeleteSupplierContact', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_DeleteSupplierContact;
GO
CREATE PROCEDURE dbo.SP_DeleteSupplierContact
    @ContactID INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Now DATETIME2(0) = SYSUTCDATETIME();
    DECLARE @SupplierID INT;
    DECLARE @FullName   NVARCHAR(150);

    BEGIN TRY
        SELECT @SupplierID = supplier_id, @FullName = full_name
        FROM dbo.supplier_contacts
        WHERE contact_id = @ContactID AND is_active = 1;

        IF @SupplierID IS NULL
            THROW 52010, N'Contact not found.', 1;

        BEGIN TRANSACTION;

        UPDATE dbo.supplier_contacts
        SET is_active = 0, is_primary = 0, updated_at = @Now
        WHERE contact_id = @ContactID;

        INSERT INTO dbo.supplier_history (supplier_id, history_type, [description], changed_by, changed_at)
        VALUES (@SupplierID, N'CONTACT_CHANGED', N'Contact ' + @FullName + N' removed.', NULL, @Now);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        INSERT INTO dbo.error_logs (user_id, error_code, message, stack_trace, source)
        VALUES (NULL, N'SP_DeleteSupplierContact', ERROR_MESSAGE(), ERROR_PROCEDURE(), N'SP_DeleteSupplierContact');
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------------
   SP_LogSupplierHistory
   Low-level helper that appends a free-form history row.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_LogSupplierHistory', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_LogSupplierHistory;
GO
CREATE PROCEDURE dbo.SP_LogSupplierHistory
    @SupplierID  INT,
    @HistoryType NVARCHAR(50),
    @Description NVARCHAR(255) = NULL,
    @ChangedByID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.suppliers WHERE supplier_id = @SupplierID)
            THROW 52011, N'Supplier does not exist.', 1;
        IF NULLIF(LTRIM(RTRIM(@HistoryType)), N'') IS NULL
            THROW 52012, N'A history type is required.', 1;

        INSERT INTO dbo.supplier_history (supplier_id, history_type, [description], changed_by, changed_at)
        VALUES (@SupplierID, UPPER(LTRIM(RTRIM(@HistoryType))), @Description, @ChangedByID, SYSUTCDATETIME());

        SELECT CAST(SCOPE_IDENTITY() AS INT) AS HistoryID;
    END TRY
    BEGIN CATCH
        INSERT INTO dbo.error_logs (user_id, error_code, message, source)
        VALUES (@ChangedByID, N'SP_LogSupplierHistory', ERROR_MESSAGE(), N'SP_LogSupplierHistory');
        THROW;
    END CATCH
END
GO