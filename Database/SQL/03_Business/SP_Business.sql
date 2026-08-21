/* ==========================================================================
   SmartPOS Database - MODULE 03: BUSINESS INFORMATION, CURRENCY & TAX
   --------------------------------------------------------------------------
   SP_GetBusinessInformation  - single-row company profile
   SP_UpsertBusinessInformation- insert or update the single profile row
   SP_GetCurrencies           - list currencies
   SP_CreateCurrency          - add a currency
   SP_UpdateCurrency          - update a currency
   SP_SetBaseCurrency         - set one currency as base
   SP_GetTaxRates             - list tax rates
   SP_CreateTaxRate           - add a tax rate
   SP_UpdateTaxRate           - update a tax rate
   SP_DeactivateTaxRate       - deactivate a tax rate

   Depends on: dbo.business_information, dbo.currencies, dbo.tax_rates,
               dbo.error_logs.
   Conventions: SP_<Purpose>, snake_case, transactional writes,
               structured TRY...CATCH + THROW.
   ========================================================================== */

/* ---------------------------------------------------------------------------
   SP_GetBusinessInformation
   Returns the single business profile row (the most recently created).
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_GetBusinessInformation', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_GetBusinessInformation;
GO
CREATE PROCEDURE dbo.SP_GetBusinessInformation
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (1)
        business_info_id,
        business_name,
        legal_name,
        tax_id,
        address_line1,
        address_line2,
        city,
        [state],
        postal_code,
        country,
        phone,
        email,
        website,
        currency_code,
        timezone,
        is_active,
        created_at,
        updated_at,
        created_by,
        updated_by
    FROM dbo.business_information
    ORDER BY business_info_id;
END
GO

/* ---------------------------------------------------------------------------
   SP_UpsertBusinessInformation
   Inserts a new single profile row if none exists, otherwise updates the
   existing one. A business code matching check + validation included.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_UpsertBusinessInformation', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_UpsertBusinessInformation;
GO
CREATE PROCEDURE dbo.SP_UpsertBusinessInformation
    @BusinessName NVARCHAR(150),
    @LegalName    NVARCHAR(150) = NULL,
    @TaxId        NVARCHAR(50)  = NULL,
    @AddressLine1 NVARCHAR(255) = NULL,
    @AddressLine2 NVARCHAR(255) = NULL,
    @City         NVARCHAR(100) = NULL,
    @State        NVARCHAR(100) = NULL,
    @PostalCode   NVARCHAR(20)  = NULL,
    @Country      NVARCHAR(100) = NULL,
    @Phone        NVARCHAR(30)  = NULL,
    @Email        NVARCHAR(255) = NULL,
    @Website      NVARCHAR(255) = NULL,
    @CurrencyCode NVARCHAR(3)   = N'USD',
    @Timezone     NVARCHAR(100) = N'UTC',
    @UpdatedByID  INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Now DATETIME2(0) = SYSUTCDATETIME();
    DECLARE @ExistingId INT;

    BEGIN TRY
        IF NULLIF(LTRIM(RTRIM(@BusinessName)), N'') IS NULL
            THROW 53001, N'A business name is required.', 1;

        IF LEN(@CurrencyCode) <> 3
            THROW 53002, N'Currency code must be exactly 3 characters.', 1;

        SELECT @ExistingId = business_info_id
        FROM dbo.business_information
        ORDER BY business_info_id;

        BEGIN TRANSACTION;

        IF @ExistingId IS NULL
        BEGIN
            INSERT INTO dbo.business_information
                (business_name, legal_name, tax_id, address_line1, address_line2,
                 city, [state], postal_code, country, phone, email, website,
                 currency_code, timezone, is_active, created_at, updated_at,
                 created_by, updated_by)
            VALUES
                (@BusinessName, @LegalName, @TaxId, @AddressLine1, @AddressLine2,
                 @City, @State, @PostalCode, @Country, @Phone, @Email, @Website,
                 @CurrencyCode, @Timezone, 1, @Now, @Now, @UpdatedByID, @UpdatedByID);

            SET @ExistingId = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            UPDATE dbo.business_information
            SET business_name = LTRIM(RTRIM(@BusinessName)),
                legal_name    = @LegalName,
                tax_id        = @TaxId,
                address_line1 = @AddressLine1,
                address_line2 = @AddressLine2,
                city          = @City,
                [state]       = @State,
                postal_code   = @PostalCode,
                country       = @Country,
                phone         = @Phone,
                email         = @Email,
                website       = @Website,
                currency_code = @CurrencyCode,
                timezone      = @Timezone,
                updated_at    = @Now,
                updated_by    = @UpdatedByID
            WHERE business_info_id = @ExistingId;
        END

        COMMIT TRANSACTION;

        SELECT @ExistingId AS BusinessInfoId;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        INSERT INTO dbo.error_logs (user_id, error_code, message, stack_trace, source)
        VALUES (@UpdatedByID, N'SP_UpsertBusinessInformation', ERROR_MESSAGE(),
                ERROR_PROCEDURE(), N'SP_UpsertBusinessInformation');
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------------
   SP_GetCurrencies
   Returns all currencies.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_GetCurrencies', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_GetCurrencies;
GO
CREATE PROCEDURE dbo.SP_GetCurrencies
    @IncludeInactive BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        currency_id,
        currency_code,
        currency_name,
        symbol,
        decimal_places,
        is_base,
        is_active,
        created_at,
        updated_at
    FROM dbo.currencies
    WHERE @IncludeInactive = 1 OR is_active = 1
    ORDER BY is_base DESC, currency_code;
END
GO

/* ---------------------------------------------------------------------------
   SP_CreateCurrency
   Adds a new currency. Rejects duplicate codes and mis-sized symbols.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_CreateCurrency', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_CreateCurrency;
GO
CREATE PROCEDURE dbo.SP_CreateCurrency
    @CurrencyCode  NVARCHAR(3),
    @CurrencyName  NVARCHAR(100),
    @Symbol        NVARCHAR(10),
    @DecimalPlaces TINYINT = 2,
    @SetAsBase     BIT = 0,
    @CurrencyID    INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Now DATETIME2(0) = SYSUTCDATETIME();

    BEGIN TRY
        IF LEN(LTRIM(RTRIM(ISNULL(@CurrencyCode, N'')))) <> 3
            THROW 53010, N'Currency code must be exactly 3 characters.', 1;

        IF LEN(ISNULL(@Symbol, N'')) = 0
            THROW 53011, N'A currency symbol is required.', 1;

        IF @DecimalPlaces > 4 OR @DecimalPlaces < 0
            THROW 53012, N'Decimal places must be between 0 and 4.', 1;

        IF EXISTS (SELECT 1 FROM dbo.currencies WHERE currency_code = @CurrencyCode)
            THROW 53013, N'Currency code already exists.', 1;

        BEGIN TRANSACTION;

        IF @SetAsBase = 1
            UPDATE dbo.currencies SET is_base = 0;

        INSERT INTO dbo.currencies
            (currency_code, currency_name, symbol, decimal_places, is_base,
             is_active, created_at, updated_at)
        VALUES
            (@CurrencyCode, @CurrencyName, @Symbol, @DecimalPlaces, @SetAsBase,
             1, @Now, @Now);

        SET @CurrencyID = SCOPE_IDENTITY();

        COMMIT TRANSACTION;

        SELECT @CurrencyID AS CurrencyID;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        INSERT INTO dbo.error_logs (user_id, error_code, message, stack_trace, source)
        VALUES (NULL, N'SP_CreateCurrency', ERROR_MESSAGE(), ERROR_PROCEDURE(), N'SP_CreateCurrency');
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------------
   SP_UpdateCurrency
   Updates name / symbol / decimal places of an existing currency.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_UpdateCurrency', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_UpdateCurrency;
GO
CREATE PROCEDURE dbo.SP_UpdateCurrency
    @CurrencyID   INT,
    @CurrencyName NVARCHAR(100),
    @Symbol       NVARCHAR(10),
    @DecimalPlaces TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Now DATETIME2(0) = SYSUTCDATETIME();

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.currencies WHERE currency_id = @CurrencyID)
            THROW 50900, N'Currency not found.', 1;

        IF @DecimalPlaces IS NOT NULL AND (@DecimalPlaces < 0 OR @DecimalPlaces > 4)
            THROW 53012, N'Decimal places must be between 0 and 4.', 1;

        UPDATE dbo.currencies
        SET currency_name   = ISNULL(@CurrencyName, currency_name),
            symbol          = ISNULL(@Symbol, symbol),
            decimal_places  = ISNULL(@DecimalPlaces, decimal_places),
            updated_at      = @Now
        WHERE currency_id = @CurrencyID;

        SELECT @CurrencyID AS CurrencyId;
    END TRY
    BEGIN CATCH
        INSERT INTO dbo.error_logs (user_id, error_code, message, stack_trace, source)
        VALUES (NULL, N'SP_UpdateCurrency', ERROR_MESSAGE(), ERROR_PROCEDURE(), N'SP_UpdateCurrency');
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------------
   SP_SetBaseCurrency
   Marks one currency as base (is_base = 1) and clears the flag on all others,
   atomically, inside a single transaction.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_SetBaseCurrency', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_SetBaseCurrency;
GO
CREATE PROCEDURE dbo.SP_SetBaseCurrency
    @CurrencyID INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Now DATETIME2(0) = SYSUTCDATETIME();

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.currencies WHERE currency_id = @CurrencyID)
            THROW 50020, N'Currency not found.', 1;

        BEGIN TRANSACTION;

        UPDATE dbo.currencies
        SET is_base = CASE WHEN currency_id = @CurrencyID THEN 1 ELSE 0 END,
            updated_at = @Now;

        COMMIT TRANSACTION;

        SELECT @CurrencyID AS CurrencyId;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        INSERT INTO dbo.error_logs (user_id, error_code, message, stack_trace, source)
        VALUES (NULL, N'SP_SetBaseCurrency', ERROR_MESSAGE(), ERROR_PROCEDURE(), N'SP_SetBaseCurrency');
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------------
   SP_GetTaxRates
   Returns tax rates, optionally only active ones.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_GetTaxRates', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_GetTaxRates;
GO
CREATE PROCEDURE dbo.SP_GetTaxRates
    @IncludeInactive BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        tax_rate_id,
        tax_name,
        tax_code,
        rate_percent,
        is_default,
        is_active,
        created_at,
        updated_at
    FROM dbo.tax_rates
    WHERE @IncludeInactive = 1 OR is_active = 1
    ORDER BY is_default DESC, tax_code;
END
GO

/* ---------------------------------------------------------------------------
   SP_CreateTaxRate
   Creates a tax rate, validating code and percentage bounds.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_CreateTaxRate', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_CreateTaxRate;
GO
CREATE PROCEDURE dbo.SP_CreateTaxRate
    @TaxName     NVARCHAR(100),
    @TaxCode     NVARCHAR(20),
    @RatePercent DECIMAL(7,4),
    @IsDefault   BIT = 0,
    @TaxRateID   INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Now DATETIME2(0) = SYSUTCDATETIME();

    BEGIN TRY
        IF NULLIF(LTRIM(RTRIM(@TaxCode)), N'') IS NULL
            THROW 50030, N'A tax code is required.', 1;

        IF @RatePercent < 0 OR @RatePercent > 100
            THROW 50031, N'Rate must be between 0 and 100.', 1;

        IF EXISTS (SELECT 1 FROM dbo.tax_rates WHERE tax_code = @TaxCode)
            THROW 50032, N'Tax code already exists.', 1;

        BEGIN TRANSACTION;

        IF @IsDefault = 1
            UPDATE dbo.tax_rates SET is_default = 0;

        INSERT INTO dbo.tax_rates
            (tax_name, tax_code, rate_percent, is_default, is_active,
             created_at, updated_at)
        VALUES
            (@TaxName, @TaxCode, @RatePercent, @IsDefault, 1, @Now, @Now);

        SET @TaxRateID = SCOPE_IDENTITY();

        COMMIT TRANSACTION;

        SELECT @TaxRateID AS TaxRateId;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        INSERT INTO dbo.error_logs (user_id, error_code, message, stack_trace, source)
        VALUES (NULL, N'SP_CreateTaxRate', ERROR_MESSAGE(), ERROR_PROCEDURE(), N'SP_CreateTaxRate');
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------------
   SP_UpdateTaxRate
   Updates an existing tax rate.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_UpdateTaxRate', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_UpdateTaxRate;
GO
CREATE PROCEDURE dbo.SP_UpdateTaxRate
    @TaxRateID   INT,
    @TaxName     NVARCHAR(100),
    @RatePercent DECIMAL(7,4) = NULL,
    @IsDefault   BIT = NULL,
    @IsActive    BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Now DATETIME2(0) = SYSUTCDATETIME();

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.tax_rates WHERE tax_rate_id = @TaxRateID)
            THROW 50033, N'Tax rate not found.', 1;

        IF @RatePercent IS NOT NULL AND (@RatePercent < 0 OR @RatePercent > 100)
            THROW 50031, N'Rate must be between 0 and 100.', 1;

        BEGIN TRANSACTION;

        IF @IsDefault = 1
            UPDATE dbo.tax_rates SET is_default = 0 WHERE tax_rate_id <> @TaxRateID;

        UPDATE dbo.tax_rates
        SET tax_name     = ISNULL(@TaxName, tax_name),
            rate_percent = ISNULL(@RatePercent, rate_percent),
            is_default   = ISNULL(@IsDefault, is_default),
            is_active    = ISNULL(@IsActive, is_active),
            updated_at   = @Now
        WHERE tax_rate_id = @TaxRateID;

        COMMIT TRANSACTION;

        SELECT @TaxRateID AS TaxRateId;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        INSERT INTO dbo.error_logs (user_id, error_code, message, stack_trace, source)
        VALUES (NULL, N'SP_UpdateTaxRate', ERROR_MESSAGE(), ERROR_PROCEDURE(), N'SP_UpdateTaxRate');
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------------
   SP_DeactivateTaxRate
   Soft-deactivates a tax rate (is_active = 0).
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_DeactivateTaxRate', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_DeactivateTaxRate;
GO
CREATE PROCEDURE dbo.SP_DeactivateTaxRate
    @TaxRateID INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Now DATETIME2(0) = SYSUTCDATETIME();

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.tax_rates WHERE tax_rate_id = @TaxRateID)
            THROW 50033, N'Tax rate not found.', 1;

        IF EXISTS (SELECT 1 FROM dbo.tax_rates WHERE tax_rate_id = @TaxRateID AND is_default = 1)
            THROW 50034, N'The default tax rate cannot be deactivated.', 1;

        UPDATE dbo.tax_rates
        SET is_active = 0, updated_at = @Now
        WHERE tax_rate_id = @TaxRateID;

        SELECT @TaxRateID AS TaxRateId;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        INSERT INTO dbo.error_logs (user_id, error_code, message, stack_trace, source)
        VALUES (NULL, N'SP_DeactivateTaxRate', ERROR_MESSAGE(), ERROR_PROCEDURE(), N'SP_DeactivateTaxRate');
        THROW;
    END CATCH
END
GO