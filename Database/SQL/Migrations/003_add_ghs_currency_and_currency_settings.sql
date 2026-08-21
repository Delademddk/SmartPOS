/* ==========================================================================
   SmartPOS Database - MIGRATION 003
   --------------------------------------------------------------------------
   Global application currency configuration.

   1. Add the Ghana Cedi (GHS) to the currencies catalogue.
   2. Seed the currency_code and currency_locale display settings that mirror
      the authoritative business_information.currency_code value.

   Backward compatible: idempotent (guarded) so it can be re-run safely.
   ========================================================================== */

SET NOCOUNT ON;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.currencies WHERE currency_code = N'GHS')
BEGIN
    INSERT INTO dbo.currencies
        (currency_code, currency_name, symbol, decimal_places, is_base, is_active, created_at, updated_at)
    VALUES
        (N'GHS', N'Ghana Cedi', N'GH₵', 2, 0, 1, SYSUTCDATETIME(), SYSUTCDATETIME());
END
GO

IF NOT EXISTS (SELECT 1 FROM dbo.settings WHERE setting_key = N'currency_code')
BEGIN
    INSERT INTO dbo.settings
        (setting_key, setting_value, data_type, category, [description], is_active, created_at, updated_at)
    VALUES
        (N'currency_code', N'USD', N'string', N'general',
         N'ISO currency code used across the entire application', 1, SYSUTCDATETIME(), SYSUTCDATETIME());
END
GO

IF NOT EXISTS (SELECT 1 FROM dbo.settings WHERE setting_key = N'currency_locale')
BEGIN
    INSERT INTO dbo.settings
        (setting_key, setting_value, data_type, category, [description], is_active, created_at, updated_at)
    VALUES
        (N'currency_locale', N'en-US', N'string', N'general',
         N'Locale used for currency formatting', 1, SYSUTCDATETIME(), SYSUTCDATETIME());
END
GO

/* ==========================================================================
   END OF MIGRATION 003
   ========================================================================== */