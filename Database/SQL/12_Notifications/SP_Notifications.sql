/* ==========================================================================
   SmartPOS Database - MODULE 12: NOTIFICATIONS
   --------------------------------------------------------------------------
   SP_GetNotifications     - paginated list for a user (optional unread-only)
   SP_GetUnreadCount       - count of unread notifications for a user
   SP_MarkNotificationRead - mark one (or all) notifications as read
   SP_DismissNotification  - dimiss one notification
   SP_CreateNotification   - resolve type_code -> id and insert
   SP_GetNotificationTypes - list active notification types
   SP_ResetNotifications   - clear read/dismissed flags for a user

   Depends on: dbo.notifications, dbo.notification_types, dbo.error_logs.
   Conventions: SP_<Purpose>, snake_case, structured TRY...CATCH + THROW.
   ========================================================================== */

/* ---------------------------------------------------------------------------
   SP_GetNotifications
   Paginated list of a user's notifications, optionally unread-only.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_GetNotifications', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_GetNotifications;
GO
CREATE PROCEDURE dbo.SP_GetNotifications
    @UserID     INT,
    @Page       INT = 1,
    @PageSize   INT = 20,
    @UnreadOnly BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Offset INT;
    DECLARE @Total INT;

    IF @Page < 1 SET @Page = 1;
    IF @PageSize < 1 SET @PageSize = 20;
    IF @PageSize > 200 SET @PageSize = 200;
    SET @Offset = (@Page - 1) * @PageSize;

    SELECT @Total = COUNT(*)
    FROM dbo.notifications
    WHERE user_id = @UserID
      AND (@UnreadOnly = 0 OR is_read = 0);

    SELECT
        n.notification_id,
        n.user_id,
        n.notification_type_id,
        nt.type_code,
        nt.type_name,
        n.title,
        n.[message],
        n.severity,
        n.entity_type,
        n.entity_id,
        n.is_read,
        n.read_at,
        n.is_dismissed,
        n.created_at,
        @Total AS total_count
    FROM dbo.notifications n
    JOIN dbo.notification_types nt ON nt.notification_type_id = n.notification_type_id
    WHERE n.user_id = @UserID
      AND (@UnreadOnly = 0 OR n.is_read = 0)
    ORDER BY n.created_at DESC
    OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

/* ---------------------------------------------------------------------------
   SP_GetUnreadCount
   Returns the number of unread notifications for a user.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_GetUnreadCount', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_GetUnreadCount;
GO
CREATE PROCEDURE dbo.SP_GetUnreadCount
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Count INT;

    SELECT @Count = COUNT(*)
    FROM dbo.notifications
    WHERE user_id = @UserID AND is_read = 0;

    SELECT ISNULL(@Count, 0) AS UnreadCount;
END
GO

/* ---------------------------------------------------------------------------
   SP_MarkNotificationRead
   Marks a single notification as read for the user, or all notifications when
   @NotificationID is NULL.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_MarkNotificationRead', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_MarkNotificationRead;
GO
CREATE PROCEDURE dbo.SP_MarkNotificationRead
    @UserID          INT,
    @NotificationID  INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Now DATETIME2(0) = SYSUTCDATETIME();

    BEGIN TRY
        IF @NotificationID IS NULL
        BEGIN
            UPDATE dbo.notifications
            SET is_read = 1, read_at = @Now
            WHERE user_id = @UserID AND is_read = 0;
        END
        ELSE
        BEGIN
            -- Ownership enforced: only the recipient can mark its own.
            IF NOT EXISTS (
                SELECT 1 FROM dbo.notifications
                WHERE notification_id = @NotificationID AND user_id = @UserID
            )
                THROW 55001, N'Notification not found for this user.', 1;

            UPDATE dbo.notifications
            SET is_read = 1, read_at = @Now
            WHERE notification_id = @NotificationID AND user_id = @UserID;
        END

        SELECT @@ROWCOUNT AS RowsAffected;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        INSERT INTO dbo.error_logs (user_id, error_code, message, stack_trace, source)
        VALUES (@UserID, N'SP_MarkNotificationRead', ERROR_MESSAGE(), ERROR_PROCEDURE(), N'SP_MarkNotificationRead');
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------------
   SP_DismissNotification
   Marks a single notification as dismissed for the user.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_DismissNotification', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_DismissNotification;
GO
CREATE PROCEDURE dbo.SP_DismissNotification
    @UserID          INT,
    @NotificationID  INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Now DATETIME2(0) = SYSUTCDATETIME();

    BEGIN TRY
        IF NOT EXISTS (
            SELECT 1 FROM dbo.notifications
            WHERE notification_id = @NotificationID AND user_id = @UserID
        )
            THROW 55001, N'Notification not found for this user.', 1;

        UPDATE dbo.notifications
        SET is_dismissed = 1,
            is_read = 1,
            read_at = @Now
        WHERE notification_id = @NotificationID AND user_id = @UserID;

        SELECT @@ROWCOUNT AS RowsAffected;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        INSERT INTO dbo.error_logs (user_id, error_code, message, stack_trace, source)
        VALUES (@UserID, N'SP_DismissNotification', ERROR_MESSAGE(), ERROR_PROCEDURE(), N'SP_DismissNotification');
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------------
   SP_CreateNotification
   Resolves a notification type code to its id and inserts a notification.
   Returns the new notification id.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_CreateNotification', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_CreateNotification;
GO
CREATE PROCEDURE dbo.SP_CreateNotification
    @UserID       INT,
    @TypeCode     NVARCHAR(50),
    @Title        NVARCHAR(150),
    @Message      NVARCHAR(MAX),
    @Severity     NVARCHAR(20) = N'INFO',
    @EntityType   NVARCHAR(100) = NULL,
    @EntityID     NVARCHAR(100) = NULL,
    @NotificationID INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @TypeID INT;
    DECLARE @Now DATETIME2(0) = SYSUTCDATETIME();

    BEGIN TRY
        IF @UserID IS NULL OR NULLIF(@Title, N'') IS NULL
            THROW 55010, N'A user ID and title are required.', 1;

        IF @Severity NOT IN (N'INFO', N'WARNING', N'CRITICAL')
            THROW 55011, N'Invalid severity.', 1;

        SELECT @TypeID = notification_type_id
        FROM dbo.notification_types
        WHERE type_code = UPPER(LTRIM(RTRIM(@TypeCode))) AND is_active = 1;

        IF @TypeID IS NULL
            THROW 55012, N'Notification type not found.', 1;

        INSERT INTO dbo.notifications
            (user_id, notification_type_id, title, [message], severity,
             entity_type, entity_id, is_read, is_dismissed, created_at)
        VALUES
            (@UserID, @TypeID, @Title, @Message, @Severity, @EntityType,
             @EntityID, 0, 0, @Now);

        SET @NotificationID = SCOPE_IDENTITY();

        SELECT @NotificationID AS NotificationID;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        INSERT INTO dbo.error_logs (user_id, error_code, message, stack_trace, source)
        VALUES (@UserID, N'SP_CreateNotification', ERROR_MESSAGE(), ERROR_PROCEDURE(), N'SP_CreateNotification');
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------------
   SP_GetNotificationTypes
   Returns all notification types.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_GetNotificationTypes', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_GetNotificationTypes;
GO
CREATE PROCEDURE dbo.SP_GetNotificationTypes
    @IncludeInactive BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        notification_type_id,
        type_code,
        type_name,
        [description],
        is_active
    FROM dbo.notification_types
    WHERE @IncludeInactive = 1 OR is_active = 1
    ORDER BY type_code;
END
GO

/* ---------------------------------------------------------------------------
   SP_ResetNotifications
   Clears the read / dismissed flags for a user's notifications (making them
   appear as new again) optionally only for one type.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_ResetNotifications', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_ResetNotifications;
GO
CREATE PROCEDURE dbo.SP_ResetNotifications
    @UserID         INT,
    @TypeCode       NVARCHAR(50) = NULL,
    @EntityType     NVARCHAR(100) = NULL,
    @EntityID       NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE n
    SET is_read = 0,
        read_at = NULL,
        is_dismissed = 0
    FROM dbo.notifications n
    LEFT JOIN dbo.notification_types nt ON nt.notification_type_id = n.notification_type_id
    WHERE n.user_id = @UserID
      AND (@TypeCode   IS NULL OR nt.type_code  = @TypeCode)
      AND (@EntityType IS NULL OR n.entity_type = @EntityType)
      AND (@EntityID   IS NULL OR n.entity_id   = @EntityID);

    SELECT @@ROWCOUNT AS RowsAffected;
END
GO