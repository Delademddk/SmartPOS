/* ==========================================================================
   SmartPOS Database - MODULE 04: CATEGORIES PROCEDURES
   --------------------------------------------------------------------------
   SP_GetCategories    - hierarchical flat list with parent name
   SP_GetCategoryTree   - recursive CTE tree (category_id, parent_id, name, depth)
   SP_CreateCategory    - insert with duplicate + parent validation
   SP_UpdateCategory    - update with self/descendant parent guard
   SP_DeleteCategory    - soft delete self + descendants, blocked when has products
   SP_GetCategory       - single category

   Depends on: dbo.categories, dbo.products, dbo.users, dbo.error_logs.
   Conventions: SP_<Purpose>, snake_case, transactional writes,
                structured TRY...CATCH + THROW, soft deletes.
   ========================================================================== */

/* ---------------------------------------------------------------------------
   SP_GetCategories
   Lists categories as a flat, ordered, hierarchical result set. The parent
   name is returned alongside each row. @IncludeDeleted controls whether
   soft-deleted rows are returned.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_GetCategories', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_GetCategories;
GO
CREATE PROCEDURE dbo.SP_GetCategories
    @IncludeDeleted BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        c.category_id,
        c.category_name,
        c.parent_id,
        p.category_name AS parent_name,
        c.[description],
        c.sort_order,
        c.is_active,
        c.is_deleted,
        c.deleted_at,
        c.deleted_by,
        c.created_at,
        c.updated_at,
        c.created_by,
        c.updated_by
    FROM dbo.categories c
    LEFT JOIN dbo.categories p ON p.category_id = c.parent_id
    WHERE (@IncludeDeleted = 1 OR c.is_deleted = 0)
    ORDER BY
        ISNULL(p.sort_order, c.sort_order),
        p.category_name,
        c.sort_order,
        c.category_name;
END
GO

/* ---------------------------------------------------------------------------
   SP_GetCategoryTree
   Produces a recursive CTE over the self-referencing hierarchy. Only non
   deleted nodes are expanded. Adds a depth value starting at 0 for roots and
   a concatenated path for readability.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_GetCategoryTree', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_GetCategoryTree;
GO
CREATE PROCEDURE dbo.SP_GetCategoryTree
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH CategoryCTE AS
    (
        -- Anchor: top-level categories (no parent)
        SELECT
            category_id,
            parent_id,
            category_name,
            0 AS depth,
            CAST(category_name AS NVARCHAR(1000)) AS [path]
        FROM dbo.categories
        WHERE parent_id IS NULL
          AND is_deleted = 0

        UNION ALL

        -- Recursive: children of the previous level
        SELECT
            c.category_id,
            c.parent_id,
            c.category_name,
            cte.depth + 1 AS depth,
            CAST(cte.[path] + N' > ' + c.category_name AS NVARCHAR(1000)) AS [path]
        FROM dbo.categories c
        INNER JOIN CategoryCTE cte ON cte.category_id = c.parent_id
        WHERE c.is_deleted = 0
    )
    SELECT
        category_id,
        parent_id,
        category_name,
        depth,
        [path]
    FROM CategoryCTE
    ORDER BY depth, category_name;
END
GO

/* ---------------------------------------------------------------------------
   SP_CreateCategory
   Creates a category under an optional parent. Enforces that the name is
   unique under the same parent, and that the parent exists and is not
   soft-deleted. Runs in a transaction.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_CreateCategory', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_CreateCategory;
GO
CREATE PROCEDURE dbo.SP_CreateCategory
    @Name        NVARCHAR(100),
    @ParentID    INT = NULL,
    @Description NVARCHAR(255) = NULL,
    @SortOrder   INT = 0,
    @CreatedByID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Now DATETIME2(0) = SYSUTCDATETIME();

    BEGIN TRY
        IF NULLIF(LTRIM(RTRIM(@Name)), N'') IS NULL
            THROW 50020, N'A category name is required.', 1;

        -- Duplicate name under same parent (also catches soft-deleted rows
        -- that still occupy the UNIQUE (parent_id, category_name) slot).
        IF EXISTS (
            SELECT 1
            FROM dbo.categories
            WHERE parent_id = @ParentID
              AND LTRIM(RTRIM(category_name)) = LTRIM(RTRIM(@Name))
        )
            THROW 50021, N'A category with this name already exists under the same parent.', 1;

        -- Parent must exist and not be deleted
        IF @ParentID IS NOT NULL AND NOT EXISTS (
            SELECT 1
            FROM dbo.categories
            WHERE category_id = @ParentID
              AND is_deleted = 0
        )
            THROW 50022, N'The parent category does not exist or is deleted.', 1;

        BEGIN TRANSACTION;

        INSERT INTO dbo.categories
            (category_name, parent_id, [description], sort_order,
             is_active, is_deleted, created_at, updated_at, created_by, updated_by)
        VALUES
            (@Name, @ParentID, @Description, @SortOrder,
             1, 0, @Now, @Now, @CreatedByID, @CreatedByID);

        COMMIT TRANSACTION;

        SELECT CAST(SCOPE_IDENTITY() AS INT) AS CategoryID;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        INSERT INTO dbo.error_logs (user_id, error_code, message, stack_trace, source)
        VALUES (@CreatedByID, N'SP_CreateCategory', ERROR_MESSAGE(), ERROR_PROCEDURE(), N'SP_CreateCategory');
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------------
   SP_UpdateCategory
   Updates an existing category. Guards against setting self as parent
   (@ParentID = @CategoryID) and against moving the category beneath one of its
   own descendants (which would create a cycle). Both security guards raise
   error 50040. Also re-enforces per-parent name uniqueness.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_UpdateCategory', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_UpdateCategory;
GO
CREATE PROCEDURE dbo.SP_UpdateCategory
    @CategoryID   INT,
    @Name         NVARCHAR(100),
    @ParentID     INT = NULL,
    @Description  NVARCHAR(255) = NULL,
    @SortOrder    INT = 0,
    @UpdatedByID  INT NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Now DATETIME2(0) = SYSUTCDATETIME();

    BEGIN TRY
        IF NULLIF(LTRIM(RTRIM(@Name)), N'') IS NULL
            THROW 50024, N'A category name is required.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.categories WHERE category_id = @CategoryID AND is_deleted = 0)
            THROW 50025, N'Category does not exist.', 1;

        -- Guard: cannot be its own parent
        IF @ParentID = @CategoryID
            THROW 50040, N'A category cannot be its own parent.', 1;

        -- Guard: cannot become a child of one of its own descendants (cycle)
        IF @ParentID IS NOT NULL
        BEGIN
            ;WITH DescendantsCTE AS
            (
                SELECT category_id
                FROM dbo.categories
                WHERE parent_id = @CategoryID
                  AND is_deleted = 0
                UNION ALL
                SELECT c.category_id
                FROM dbo.categories c
                INNER JOIN DescendantsCTE d ON c.parent_id = d.category_id
                WHERE c.is_deleted = 0
            )
            IF EXISTS (SELECT 1 FROM DescendantsCTE WHERE category_id = @ParentID)
                THROW 50040, N'Cannot move a category under one of its own descendants.', 1;
        END

        -- Parent must exist and not be deleted
        IF @ParentID IS NOT NULL AND NOT EXISTS (
            SELECT 1
            FROM dbo.categories
            WHERE category_id = @ParentID
              AND is_deleted = 0
        )
            THROW 50026, N'The parent category does not exist or is deleted.', 1;

        -- Duplicate name under the same parent (excluding this row)
        IF EXISTS (
            SELECT 1
            FROM dbo.categories
            WHERE parent_id = @ParentID
              AND LTRIM(RTRIM(category_name)) = LTRIM(RTRIM(@Name))
              AND category_id <> @CategoryID
        )
            THROW 50027, N'A category with this name already exists under the same parent.', 1;

        BEGIN TRANSACTION;

        UPDATE dbo.categories
        SET category_name = @Name,
            parent_id     = @ParentID,
            [description] = @Description,
            sort_order    = @SortOrder,
            updated_at    = @Now,
            updated_by    = @UpdatedByID
        WHERE category_id = @CategoryID;

        COMMIT TRANSACTION;

        SELECT @CategoryID AS CategoryID;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        INSERT INTO dbo.error_logs (user_id, error_code, message, stack_trace, source)
        VALUES (@UpdatedByID, N'SP_UpdateCategory', ERROR_MESSAGE(), ERROR_PROCEDURE(), N'SP_UpdateCategory');
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------------
   SP_DeleteCategory
   Soft-deletes a category and all of its descendants via a recursive CTE.
   The operation is blocked (THROW 50041) while any non-deleted product
   references the category.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_DeleteCategory', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_DeleteCategory;
GO
CREATE PROCEDURE dbo.SP_DeleteCategory
    @CategoryID  INT,
    @DeletedByID INT NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Now DATETIME2(0) = SYSUTCDATETIME();

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.categories WHERE category_id = @CategoryID AND is_deleted = 0)
            THROW 50028, N'Category does not exist or is already deleted.', 1;

        -- Block if non-deleted products reference this category
        IF EXISTS (
            SELECT 1
            FROM dbo.products
            WHERE category_id = @CategoryID
              AND is_deleted = 0
        )
            THROW 50041, N'Cannot delete a category that still contains products.', 1;

        BEGIN TRANSACTION;

        -- Compute the set of self + all descendants
        ;WITH DescendantsCTE AS
        (
            SELECT category_id
            FROM dbo.categories
            WHERE category_id = @CategoryID

            UNION ALL

            SELECT c.category_id
            FROM dbo.categories c
            INNER JOIN DescendantsCTE d ON c.parent_id = d.category_id
        )
        UPDATE c
        SET c.is_deleted = 1,
            c.deleted_at = @Now,
            c.deleted_by = @DeletedByID,
            c.updated_at = @Now,
            c.updated_by = @DeletedByID
        FROM dbo.categories c
        INNER JOIN DescendantsCTE d ON d.category_id = c.category_id;

        COMMIT TRANSACTION;

        SELECT @@ROWCOUNT AS DeletedCount;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        INSERT INTO dbo.error_logs (user_id, error_code, message, stack_trace, source)
        VALUES (@DeletedByID, N'SP_DeleteCategory', ERROR_MESSAGE(), ERROR_PROCEDURE(), N'SP_DeleteCategory');
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------------
   SP_GetCategory
   Returns a single category by primary key.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_GetCategory', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_GetCategory;
GO
CREATE PROCEDURE dbo.SP_GetCategory
    @CategoryID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        c.category_id,
        c.category_name,
        c.parent_id,
        p.category_name AS parent_name,
        c.[description],
        c.sort_order,
        c.is_active,
        c.is_deleted,
        c.deleted_at,
        c.deleted_by,
        c.created_at,
        c.updated_at,
        c.created_by,
        c.updated_by
    FROM dbo.categories c
    LEFT JOIN dbo.categories p ON p.category_id = c.parent_id
    WHERE c.category_id = @CategoryID;
END
GO