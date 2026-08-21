/* ==========================================================================
   SmartPOS Database - MODULE 01: AUTHENTICATION - ROLE MANAGEMENT
   --------------------------------------------------------------------------
   SP_GetRoles       - list roles with granted permission counts
   SP_GetRole        - single role with comma-delimited permission codes
   SP_CreateRole     - create role + optional permission grants from a CSV
   SP_UpdateRole     - update role name/description + replace permission set
   SP_DeleteRole     - delete a role (system roles are protected)
   SP_GetPermissions - list permissions, optionally filtered by module

   Depends on: dbo.roles, dbo.permissions, dbo.role_permissions,
               dbo.error_logs.
   Conventions: SP_<Purpose> naming, snake_case columns, structured
               TRY...CATCH, THROW, multi-table writes in transactions.
   ========================================================================== */

/* ---------------------------------------------------------------------------
   SP_GetRoles
   Returns every role with its description, activation state and the number
   of permissions currently granted to it.
---------------------------------------------------------------------------*/
IF OBJECT_ID(N'dbo.SP_GetRoles', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_GetRoles;
GO
CREATE PROCEDURE dbo.SP_GetRoles
    @IncludeInactive BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        r.role_id,
        r.role_code,
        r.role_name,
        r.[description],
        r.is_system,
        r.is_active,
        r.created_at,
        r.updated_at,
        r.created_by,
        r.updated_by,
        COUNT(rp.role_permission_id) AS permission_count
    FROM dbo.roles r
    LEFT JOIN dbo.role_permissions rp ON rp.role_id = r.role_id
    WHERE @IncludeInactive = 1 OR r.is_active = 1
    GROUP BY
        r.role_id, r.role_code, r.role_name, r.[description],
        r.is_system, r.is_active, r.created_at, r.updated_at,
        r.created_by, r.updated_by
    ORDER BY r.role_name;
END
GO

/* ---------------------------------------------------------------------------
   SP_GetRole
   Returns the role header row plus a comma-delimited string of the
   permission codes granted to it.
---------------------------------------------------------------------------*/
IF OBJECT_ID(N'dbo.SP_GetRole', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_GetRole;
GO
CREATE PROCEDURE dbo.SP_GetRole
    @RoleID INT
AS
BEGIN
    SET NOCOUNT ON;

    IF @RoleID IS NULL
        THROW 50030, N'A role ID is required.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.roles WHERE role_id = @RoleID)
        THROW 50031, N'Role not found.', 1;

    SELECT
        r.role_id,
        r.role_code,
        r.role_name,
        r.[description],
        r.is_system,
        r.is_active,
        r.created_at,
        r.updated_at,
        r.created_by,
        r.updated_by,
        STUFF((
            SELECT N',' + p.permission_code
            FROM dbo.role_permissions rp
            JOIN dbo.permissions p ON p.permission_id = rp.permission_id
            WHERE rp.role_id = r.role_id
            ORDER BY p.permission_code
            FOR XML PATH(N''), TYPE
        ).value(N'.', N'NVARCHAR(MAX)'), 1, 1, N'') AS permission_codes
    FROM dbo.roles r
    WHERE r.role_id = @RoleID;
END
GO

/* ---------------------------------------------------------------------------
   SP_CreateRole
   Creates a new role. @PermissionCodesCSV is an optional comma-separated
   list of permission codes (e.g. 'product.create,product.read'). When
   supplied, only existing + active permission codes are granted. Role code
   is uppercased, trimmed, and validated unique.
---------------------------------------------------------------------------*/
IF OBJECT_ID(N'dbo.SP_CreateRole', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_CreateRole;
GO
CREATE PROCEDURE dbo.SP_CreateRole
    @RoleCode          NVARCHAR(50),
    @RoleName          NVARCHAR(100),
    @Description       NVARCHAR(255) = NULL,
    @PermissionCodesCSV NVARCHAR(MAX) = NULL,
    @CreatedBy         INT = NULL,
    @RoleID            INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Now DATETIME2(0) = SYSUTCDATETIME();
    DECLARE @Code NVARCHAR(50);

    BEGIN TRY
        -- ----------------------------------------------------------------
        -- Validation
        -- ----------------------------------------------------------------
        SET @Code = UPPER(LTRIM(RTRIM(ISNULL(@RoleCode, N''))));

        IF @Code = N''
            THROW 50032, N'A role code is required.', 1;

        IF LEN(@RoleName) = 0
            THROW 50033, N'A role name is required.', 1;

        IF @Code <> UPPER(@Code) OR @Code <> LTRIM(RTRIM(@Code))
            THROW 50034, N'Role code must be uppercase and trimmed.', 1;

        IF EXISTS (SELECT 1 FROM dbo.roles WHERE role_code = @Code)
            THROW 50035, N'A role with this code already exists.', 1;

        BEGIN TRANSACTION;

        INSERT INTO dbo.roles
            (role_code, role_name, [description], is_system, is_active,
             created_at, updated_at, created_by)
        VALUES
            (@Code, LTRIM(RTRIM(@RoleName)), @Description, 0, 1, @Now, @Now, @CreatedBy);

        SET @RoleID = SCOPE_IDENTITY();

        -- ----------------------------------------------------------------
        -- Grant permissions parsed from the CSV (if any)
        -- ----------------------------------------------------------------
        IF NULLIF(LTRIM(RTRIM(@PermissionCodesCSV)), N'') IS NOT NULL
        BEGIN
            INSERT INTO dbo.role_permissions (role_id, permission_id, granted_by, granted_at)
            SELECT @RoleID, p.permission_id, @CreatedBy, @Now
            FROM STRING_SPLIT(@PermissionCodesCSV, N',') AS s
            JOIN dbo.permissions p
                ON p.permission_code = LOWER(LTRIM(RTRIM(s.[value])))
               AND p.is_active = 1;

            -- Reject unknown permission codes so typos do not silently drop grants
            IF EXISTS (
                SELECT 1
                FROM STRING_SPLIT(@PermissionCodesCSV, N',') AS s
                LEFT JOIN dbo.permissions p
                    ON p.permission_code = LOWER(LTRIM(RTRIM(s.[value])))
                WHERE p.permission_id IS NULL
                  AND LTRIM(RTRIM(s.[value])) <> N''
            )
            BEGIN
                THROW 50036, N'One or more permission codes do not exist.', 1;
            END
        END

        COMMIT TRANSACTION;

        SELECT @RoleID AS RoleID;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        INSERT INTO dbo.error_logs (user_id, error_code, message, stack_trace, source)
        VALUES (@CreatedBy, N'SP_CreateRole', ERROR_MESSAGE(), ERROR_PROCEDURE(), N'SP_CreateRole');
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------------
   SP_UpdateRole
   Updates role name / description and replaces the entire permission set
   (delete-all then re-insert) inside a single transaction.
---------------------------------------------------------------------------*/
IF OBJECT_ID(N'dbo.SP_UpdateRole', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_UpdateRole;
GO
CREATE PROCEDURE dbo.SP_UpdateRole
    @RoleID            INT,
    @RoleName          NVARCHAR(100),
    @Description       NVARCHAR(255) = NULL,
    @PermissionCodesCSV NVARCHAR(MAX) = NULL,
    @UpdatedBy         INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Now DATETIME2(0) = SYSUTCDATETIME();

    BEGIN TRY
        IF @RoleID IS NULL
            THROW 50030, N'A role ID is required.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.roles WHERE role_id = @RoleID)
            THROW 50031, N'Role not found.', 1;

        IF LEN(LTRIM(RTRIM(ISNULL(@RoleName, N'')))) = 0
            THROW 50033, N'A role name is required.', 1;

        -- System roles keep their permission set: bulk replacement is not allowed
        IF EXISTS (SELECT 1 FROM dbo.roles WHERE role_id = @RoleID AND is_system = 1)
           AND NULLIF(LTRIM(RTRIM(@PermissionCodesCSV)), N'') IS NOT NULL
        BEGIN
            DECLARE @SystemMsg NVARCHAR(200) =
                N'System roles cannot have their permission set replaced.';
            THROW 50037, @SystemMsg, 1;
        END

        BEGIN TRANSACTION;

        UPDATE dbo.roles
        SET role_name     = LTRIM(RTRIM(@RoleName)),
            [description] = @Description,
            updated_at    = @Now,
            updated_by    = @UpdatedBy
        WHERE role_id = @RoleID;

        -- Replace the permission set (only for non-system roles)
        IF NOT EXISTS (SELECT 1 FROM dbo.roles WHERE role_id = @RoleID AND is_system = 1)
        BEGIN
            DELETE FROM dbo.role_permissions WHERE role_id = @RoleID;

            IF NULLIF(LTRIM(RTRIM(@PermissionCodesCSV)), N'') IS NOT NULL
            BEGIN
                IF EXISTS (
                    SELECT 1
                    FROM STRING_SPLIT(@PermissionCodesCSV, N',') AS s
                    LEFT JOIN dbo.permissions p
                        ON p.permission_code = LOWER(LTRIM(RTRIM(s.[value])))
                       AND p.is_active = 1
                    WHERE p.permission_id IS NULL
                      AND LTRIM(RTRIM(s.[value])) <> N''
                )
                BEGIN
                    THROW 50036, N'One or more permission codes do not exist.', 1;
                END

                INSERT INTO dbo.role_permissions (role_id, permission_id, granted_by, granted_at)
                SELECT @RoleID, p.permission_id, @UpdatedBy, @Now
                FROM STRING_SPLIT(@PermissionCodesCSV, N',') AS s
                JOIN dbo.permissions p
                    ON p.permission_code = LOWER(LTRIM(RTRIM(s.[value])))
                   AND p.is_active = 1;
            END
        END

        COMMIT TRANSACTION;

        SELECT @RoleID AS RoleID;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        INSERT INTO dbo.error_logs (user_id, error_code, message, stack_trace, source)
        VALUES (@UpdatedBy, N'SP_UpdateRole', ERROR_MESSAGE(), ERROR_PROCEDURE(), N'SP_UpdateRole');
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------------
   SP_DeleteRole
   Deletes a role and its permission grants. System roles (is_system = 1)
   cannot be deleted.
---------------------------------------------------------------------------*/
IF OBJECT_ID(N'dbo.SP_DeleteRole', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_DeleteRole;
GO
CREATE PROCEDURE dbo.SP_DeleteRole
    @RoleID INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF @RoleID IS NULL
            THROW 50022, N'A role ID is required.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.roles WHERE role_id = @RoleID)
            THROW 50023, N'Role not found.', 1;

        IF EXISTS (SELECT 1 FROM dbo.roles WHERE role_id = @RoleID AND is_system = 1)
            THROW 50030, N'System roles cannot be deleted.', 1;

        -- Roles still assigned to users cannot be removed
        IF EXISTS (SELECT 1 FROM dbo.users WHERE role_id = @RoleID AND is_deleted = 0)
            THROW 50039, N'Role is assigned to one or more users.', 1;

        BEGIN TRANSACTION;

        DELETE FROM dbo.role_permissions WHERE role_id = @RoleID;
        DELETE FROM dbo.roles WHERE role_id = @RoleID;

        COMMIT TRANSACTION;

        SELECT @RoleID AS RoleID;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        INSERT INTO dbo.error_logs (user_id, error_code, message, stack_trace, source)
        VALUES (NULL, N'SP_DeleteRole', ERROR_MESSAGE(), ERROR_PROCEDURE(), N'SP_DeleteRole');
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------------
   SP_GetPermissions
   Returns all permissions, optionally filtered by module name.
---------------------------------------------------------------------------*/
IF OBJECT_ID(N'dbo.SP_GetPermissions', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_GetPermissions;
GO
CREATE PROCEDURE dbo.SP_GetPermissions
    @ModuleName NVARCHAR(100) = NULL,
    @IncludeInactive BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        permission_id,
        permission_code,
        permission_name,
        [description],
        module_name,
        is_system,
        is_active,
        created_at,
        updated_at
    FROM dbo.permissions
    WHERE (@ModuleName IS NULL OR module_name = @ModuleName)
      AND (@IncludeInactive = 1 OR is_active = 1)
    ORDER BY module_name, permission_code;
END
GO
