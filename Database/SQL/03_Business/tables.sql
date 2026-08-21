/* ==========================================================================
   SmartPOS Database - MODULE 03: BUSINESS
   --------------------------------------------------------------------------
   Objects: business_information, currencies, tax_rates
   Depends on: nothing (self-contained).

   Stores the company profile, locale/currency, and tax configuration used by
   quotes, receipts, and reports.
   ========================================================================== */

-- --------------------------------------------------------------------------
-- BUSINESS INFORMATION (single-row profile)
-- --------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.business_information', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.business_information
    (
        business_info_id INT           NOT NULL IDENTITY(1,1) CONSTRAINT PK_business_information PRIMARY KEY,
        business_name    NVARCHAR(150) NOT NULL,
        legal_name       NVARCHAR(150) NULL,
        tax_id           NVARCHAR(50)  NULL,
        address_line1    NVARCHAR(255) NULL,
        address_line2    NVARCHAR(255) NULL,
        city             NVARCHAR(100) NULL,
        [state]          NVARCHAR(100) NULL,
        postal_code      NVARCHAR(20)  NULL,
        country          NVARCHAR(100) NULL,
        phone            NVARCHAR(30)  NULL,
        email            NVARCHAR(255) NULL,
        website          NVARCHAR(255) NULL,
        currency_code    NVARCHAR(3)   NOT NULL CONSTRAINT DF_business_information_currency_code DEFAULT (N'USD'),
        timezone         NVARCHAR(100) NOT NULL CONSTRAINT DF_business_information_timezone DEFAULT (N'UTC'),
        is_active        BIT           NOT NULL CONSTRAINT DF_business_information_is_active DEFAULT (1),
        created_at       DATETIME2(0)  NOT NULL CONSTRAINT DF_business_information_created_at DEFAULT (SYSUTCDATETIME()),
        updated_at       DATETIME2(0)  NOT NULL CONSTRAINT DF_business_information_updated_at DEFAULT (SYSUTCDATETIME()),
        created_by       INT NULL,
        updated_by       INT NULL
    );
    ALTER TABLE dbo.business_information ADD CONSTRAINT CK_business_information_currency_format
        CHECK (LEN(currency_code) = 3);
END
GO

-- --------------------------------------------------------------------------
-- CURRENCIES
-- --------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.currencies', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.currencies
    (
        currency_id   INT          NOT NULL IDENTITY(1,1) CONSTRAINT PK_currencies PRIMARY KEY,
        currency_code NVARCHAR(3)   NOT NULL,
        currency_name NVARCHAR(100) NOT NULL,
        symbol        NVARCHAR(10)  NOT NULL,
        decimal_places TINYINT      NOT NULL CONSTRAINT DF_currencies_decimal_places DEFAULT (2),
        is_base       BIT           NOT NULL CONSTRAINT DF_currencies_is_base DEFAULT (0),
        is_active     BIT           NOT NULL CONSTRAINT DF_currencies_is_active DEFAULT (1),
        created_at    DATETIME2(0)  NOT NULL CONSTRAINT DF_currencies_created_at DEFAULT (SYSUTCDATETIME()),
        updated_at    DATETIME2(0)  NOT NULL CONSTRAINT DF_currencies_updated_at DEFAULT (SYSUTCDATETIME())
    );
    ALTER TABLE dbo.currencies ADD CONSTRAINT UQ_currencies_code UNIQUE (currency_code);
    ALTER TABLE dbo.currencies ADD CONSTRAINT CK_currencies_code_format CHECK (LEN(currency_code) = 3);
    ALTER TABLE dbo.currencies ADD CONSTRAINT CK_currencies_decimal_places CHECK (decimal_places BETWEEN 0 AND 4);
END
GO

-- --------------------------------------------------------------------------
-- TAX RATES
-- --------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.tax_rates', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.tax_rates
    (
        tax_rate_id  INT             NOT NULL IDENTITY(1,1) CONSTRAINT PK_tax_rates PRIMARY KEY,
        tax_name     NVARCHAR(100)   NOT NULL,
        tax_code     NVARCHAR(20)    NOT NULL,
        rate_percent DECIMAL(7,4)    NOT NULL,                -- e.g. 7.5000 = 7.5%
        is_default   BIT             NOT NULL CONSTRAINT DF_tax_rates_is_default DEFAULT (0),
        is_active    BIT             NOT NULL CONSTRAINT DF_tax_rates_is_active DEFAULT (1),
        created_at   DATETIME2(0)    NOT NULL CONSTRAINT DF_tax_rates_created_at DEFAULT (SYSUTCDATETIME()),
        updated_at   DATETIME2(0)    NOT NULL CONSTRAINT DF_tax_rates_updated_at DEFAULT (SYSUTCDATETIME())
    );

    ALTER TABLE dbo.tax_rates ADD CONSTRAINT UQ_tax_rates_code UNIQUE (tax_code);
    ALTER TABLE dbo.tax_rates ADD CONSTRAINT CK_tax_rates_rate_non_negative CHECK (rate_percent >= 0);
    ALTER TABLE dbo.tax_rates ADD CONSTRAINT CK_tax_rates_rate_max CHECK (rate_percent <= 100);
END
GO

-- ----------------------------------------------------------------------------
-- INDEXES
-- ----------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_currencies_is_active')
    CREATE NONCLUSTERED INDEX IX_currencies_is_active ON dbo.currencies (is_active);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_tax_rates_is_active')
    CREATE NONCLUSTERED INDEX IX_tax_rates_is_active ON dbo.tax_rates (is_active);
GO