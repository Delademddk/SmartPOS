/* ==========================================================================
   SmartPOS Database - MODULE 16: AUDIT & LOGGING
   --------------------------------------------------------------------------
   SP_GetAuditLogs    - paginated audit log query with filters
   SP_GetSecurityLogs - paginated security event query
   SP_GetErrorLogs    - paginated error log query
   SP_ArchiveAuditLogs- rotate old audit rows into the archive table

   Depends on: dbo.audit_logs, dbo.security_logs, dbo.error_logs,
               dbo.audit_logs_archive, dbo.error_logs.
   Conventions: SP_<Purpose>, snake_case, transactional multi-table writes,
               structured TRY...CATCH + THROW.
   ========================================================================== */

/* ---------------------------------------------------------------------------
   SP_GetAuditLogs
   Paginated, filterable query over dbo.audit_logs. Filters: resource type,
   resource id, acting user and created-at date range.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_GetAuditLogs', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_GetAuditLogs;
GO
CREATE PROCEDURE dbo.SP_GetAuditLogs
    @Page         INT = 1,
    @PageSize     INT = 50,
    @ResourceType NVARCHAR(100) = NULL,
    @ResourceID   NVARCHAR(100) = NULL,
    @UserID       INT = NULL,
    @From         DATETIME2(0) = NULL,
    @To           DATETIME2(0) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Offset INT;
    DECLARE @Total INT;

    IF @Page < 1 SET @Page = 1;
    IF @PageSize < 1 SET @PageSize = 50;
    IF @PageSize > 500 SET @PageSize = 500;
    SET @Offset = (@Page - 1) * @PageSize;

    SELECT @Total = COUNT(*)
    FROM dbo.audit_logs
    WHERE (@ResourceType IS NULL OR resource_type = @ResourceType)
      AND (@ResourceID   IS NULL OR resource_id   = @ResourceID)
      AND (@UserID       IS NULL OR user_id       = @UserID)
      AND (@From         IS NULL OR created_at   >= @From)
      AND (@To           IS NULL OR created_at   <= @To);

    SELECT
        log_id,
        user_id,
        action_type,
        resource_type,
        resource_id,
        old_values,
        new_values,
        ip_address,
        user_agent,
        details,
        created_at,
        @Total AS total_count
    FROM dbo.audit_logs
    WHERE (@ResourceType IS NULL OR resource_type = @ResourceType)
      AND (@ResourceID   IS NULL OR resource_id   = @ResourceID)
      AND (@UserID       IS NULL OR user_id       = @UserID)
      AND (@From         IS NULL OR created_at   >= @From)
      AND (@To           IS NULL OR created_at   <= @To)
    ORDER BY created_at DESC
    OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

/* ---------------------------------------------------------------------------
   SP_GetSecurityLogs
   Paginated query over dbo.security_logs with event type and date filters.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_GetSecurityLogs', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_GetSecurityLogs;
GO
CREATE PROCEDURE dbo.SP_GetSecurityLogs
    @Page      INT = 1,
    @PageSize  INT = 50,
    @EventType NVARCHAR(50) = NULL,
    @From      DATETIME2(0) = NULL,
    @To        DATETIME2(0) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Offset INT;
    DECLARE @Total INT;

    IF @Page < 1 SET @Page = 1;
    IF @PageSize < 1 SET @PageSize = 50;
    IF @PageSize > 500 SET @PageSize = 500;
    SET @Offset = (@Page - 1) * @PageSize;

    SELECT @Total = COUNT(*)
    FROM dbo.security_logs
    WHERE (@EventType IS NULL OR event_type = @EventType)
      AND (@From      IS NULL OR created_at >= @From)
      AND (@To        IS NULL OR created_at <= @To);

    SELECT
        security_log_id,
        user_id,
        event_type,
        username,
        ip_address,
        user_agent,
        [message],
        created_at,
        @Total AS total_count
    FROM dbo.security_logs
    WHERE (@EventType IS NULL OR event_type = @EventType)
      AND (@From      IS NULL OR created_at >= @From)
      AND (@To        IS NULL OR created_at <= @To)
    ORDER BY created_at DESC
    OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

/* ---------------------------------------------------------------------------
   SP_GetErrorLogs
   Paginated query over dbo.error_logs with source and date filters.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_GetErrorLogs', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_GetErrorLogs;
GO
CREATE PROCEDURE dbo.SP_GetErrorLogs
    @Page     INT = 1,
    @PageSize INT = 50,
    @Source   NVARCHAR(200) = NULL,
    @From     DATETIME2(0) = NULL,
    @To       DATETIME2(0) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Offset INT;
    DECLARE @Total INT;

    IF @Page < 1 SET @Page = 1;
    IF @PageSize < 1 SET @PageSize = 50;
    IF @PageSize > 500 SET @PageSize = 500;
    SET @Offset = (@Page - 1) * @PageSize;

    SELECT @Total = COUNT(*)
    FROM dbo.error_logs
    WHERE (@Source IS NULL OR [source] = @Source)
      AND (@From   IS NULL OR occurred_at >= @From)
      AND (@To     IS NULL OR occurred_at <= @To);

    SELECT
        error_id,
        user_id,
        error_code,
        [message],
        stack_trace,
        [source],
        http_status,
        ip_address,
        occurred_at,
        @Total AS total_count
    FROM dbo.error_logs
    WHERE (@Source IS NULL OR [source] = @Source)
      AND (@From   IS NULL OR occurred_at >= @From)
      AND (@To     IS NULL OR occurred_at <= @To)
    ORDER BY occurred_at DESC
    OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

/* ---------------------------------------------------------------------------
   SP_ArchiveAuditLogs
   Moves audit_logs rows older than @OlderThanDays days into
   dbo.audit_logs_archive (preserving the original log_id) and deletes the
   originals, all within a single transaction.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_ArchiveAuditLogs', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_ArchiveAuditLogs;
GO
CREATE PROCEDURE dbo.SP_ArchiveAuditLogs
    @OlderThanDays INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Cutoff DATETIME2(0);
    DECLARE @Archived INT = 0;

    BEGIN TRY
        IF @OlderThanDays IS NULL OR @OlderThanDays < 0
            THROW 56001, N'A non-negative number of days is required.', 1;

        SET @Cutoff = DATEADD(day, -@OlderThanDays, SYSUTCDATETIME());

        BEGIN TRANSACTION;

        INSERT INTO dbo.audit_logs_archive
            (log_id, user_id, action_type, resource_type, resource_id,
             old_values, new_values, ip_address, user_agent, details,
             created_at, archived_at)
        SELECT
            log_id, user_id, action_type, resource_type, resource_id,
            old_values, new_values, ip_address, user_agent, details,
            created_at, SYSUTCDATETIME()
        FROM dbo.audit_logs
        WHERE created_at < @Cutoff;

        SET @Archived = @@ROWCOUNT;

        DELETE FROM dbo.audit_logs WHERE created_at < @Cutoff;

        COMMIT TRANSACTION;

        SELECT @Archived AS RowsArchived, @Cutoff AS CutoffDate;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        INSERT INTO dbo.error_logs (user_id, error_code, message, stack_trace, source)
        VALUES (NULL, N'SP_ArchiveAuditLogs', ERROR_MESSAGE(), ERROR_PROCEDURE(), N'SP_ArchiveAuditLogs');
        THROW;
    END CATCH
END
GO