/* ==========================================================================
   SmartPOS Database - MODULE 15: SETTINGS
   --------------------------------------------------------------------------
   SP_GetSettings       - list settings, optional category filter + search
   SP_GetSetting        - single setting value with its data type
   SP_UpsertSetting     - insert or update an application setting
   SP_DeleteSetting     - soft-deactivate a setting
   SP_GetUserSettings   - list a user's preferences
   SP_UpsertUserSetting - insert or update a per-user preference

   Depends on: dbo.settings, dbo.user_settings, dbo.error_logs.
   Conventions: SP_<Purpose>, snake_case, structured TRY...CATCH + THROW.
   ========================================================================== */

/* ---------------------------------------------------------------------------
   SP_GetSettings
   Returns application settings, filterable by category and keyword search.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_GetSettings', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_GetSettings;
GO
CREATE PROCEDURE dbo.SP_GetSettings
    @Category NVARCHAR(50) = NULL,
    @Search   NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @Search = NULLIF(LTRIM(RTRIM(@Search)), N'');
    IF @Search IS NOT NULL SET @Search = N'%' + @Search + N'%';

    SELECT
        setting_id,
        setting_key,
        setting_value,
        data_type,
        category,
        [description],
        is_active,
        created_at,
        updated_at
    FROM dbo.settings
    WHERE (@Category IS NULL OR category = @Category)
      AND (@Search IS NULL
           OR setting_key LIKE @Search
           OR [description] LIKE @Search)
      AND is_active = 1
    ORDER BY category, setting_key;
END
GO

/* ---------------------------------------------------------------------------
   SP_GetSetting
   Returns a single setting by key, including its data type.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_GetSetting', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_GetSetting;
GO
CREATE PROCEDURE dbo.SP_GetSetting
    @Key NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        setting_id,
        setting_key,
        setting_value,
        data_type,
        category,
        [description],
        is_active,
        updated_at
    FROM dbo.settings
    WHERE setting_key = @Key AND is_active = 1;
END
GO

/* ---------------------------------------------------------------------------
   SP_UpsertSetting
   Inserts a new setting or updates an existing one (by key).
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_UpsertSetting', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_UpsertSetting;
GO
CREATE PROCEDURE dbo.SP_UpsertSetting
    @Key          NVARCHAR(100),
    @Value        NVARCHAR(MAX) = NULL,
    @DataType     NVARCHAR(20)  = N'string',
    @Category     NVARCHAR(50)  = N'general',
    @Description  NVARCHAR(255) = NULL,
    @UpdatedByID  INT = NULL,
    @SettingID    INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Now DATETIME2(0) = SYSUTCDATETIME();

    BEGIN TRY
        IF NULLIF(LTRIM(RTRIM(@Key)), N'') IS NULL
            THROW 54001, N'A settings key is required.', 1;

        IF @DataType NOT IN (N'string', N'int', N'decimal', N'bool', N'json')
            THROW 54002, N'Invalid data type.', 1;

        SET @Key = LTRIM(RTRIM(@Key));

        IF EXISTS (SELECT 1 FROM dbo.settings WHERE setting_key = @Key)
        BEGIN
            UPDATE dbo.settings
            SET setting_value = @Value,
                data_type     = @DataType,
                category      = @Category,
                [description] = @Description,
                is_active     = 1,
                updated_at    = @Now,
                updated_by    = @UpdatedByID
            WHERE setting_key = @Key;

            SELECT @SettingID = setting_id
            FROM dbo.settings WHERE setting_key = @Key;
        END
        ELSE
        BEGIN
            INSERT INTO dbo.settings
                (setting_key, setting_value, data_type, category, [description],
                 is_active, created_at, updated_at, created_by, updated_by)
            VALUES
                (@Key, @Value, @DataType, @Category, @Description,
                 1, @Now, @Now, @UpdatedByID, @UpdatedByID);

            SET @SettingID = SCOPE_IDENTITY();
        END

        SELECT @SettingID AS SettingID, @Key AS SettingKey;
    END TRY
    BEGIN CATCH
        INSERT INTO dbo.error_logs (user_id, error_code, message, stack_trace, source)
        VALUES (@UpdatedByID, N'SP_UpsertSetting', ERROR_MESSAGE(), ERROR_PROCEDURE(), N'SP_UpsertSetting');
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------------
   SP_DeleteSetting
   Soft-deletes a setting by flipping its is_active flag to 0.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_DeleteSetting', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_DeleteSetting;
GO
CREATE PROCEDURE dbo.SP_DeleteSetting
    @Key NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.settings
    SET is_active = 0,
        updated_at = SYSUTCDATETIME()
    WHERE setting_key = @Key;

    SELECT @@ROWCOUNT AS RowsAffected;
END
GO

/* ---------------------------------------------------------------------------
   SP_GetUserSettings
   Returns all preference rows for a user.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_GetUserSettings', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_GetUserSettings;
GO
CREATE PROCEDURE dbo.SP_GetUserSettings
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        user_setting_id,
        user_id,
        setting_key,
        setting_value,
        created_at,
        updated_at
    FROM dbo.user_settings
    WHERE user_id = @UserID
    ORDER BY setting_key;
END
GO

/* ---------------------------------------------------------------------------
   SP_UpsertUserSetting
   Inserts or updates a per-user preference (unique on user_id + setting_key).
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_UpsertUserSetting', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_UpsertUserSetting;
GO
CREATE PROCEDURE dbo.SP_UpsertUserSetting
    @UserID        INT,
    @Key           NVARCHAR(100),
    @Value         NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Now DATETIME2(0) = SYSUTCDATETIME();

    BEGIN TRY
        IF @UserID IS NULL OR NULLIF(@Key, N'') IS NULL
            THROW 54010, N'A user ID and settings key are required.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.users WHERE user_id = @UserID)
            THROW 54011, N'User not found.', 1;

        IF EXISTS (SELECT 1 FROM dbo.user_settings WHERE user_id = @UserID AND setting_key = @Key)
        BEGIN
            UPDATE dbo.user_settings
            SET setting_value = @Value,
                updated_at    = @Now
            WHERE user_id = @UserID AND setting_key = @Key;
        END
        ELSE
        BEGIN
            INSERT INTO dbo.user_settings (user_id, setting_key, setting_value, created_at, updated_at)
            VALUES (@UserID, @Key, @Value, @Now, @Now);
        END

        SELECT @UserID AS UserID, @Key AS SettingKey;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        INSERT INTO dbo.error_logs (user_id, error_code, message, stack_trace, source)
        VALUES (@UserID, N'SP_UpsertUserSetting', ERROR_MESSAGE(), ERROR_PROCEDURE(), N'SP_UpsertUserSetting');
        THROW;
    END CATCH
END
GO