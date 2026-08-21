/* ==========================================================================
   SmartPOS Database - MODULE 09: PAYMENTS
   --------------------------------------------------------------------------
   Objects: payment_methods, payments, receipts.
   Depends on: 02 Users, 08 Sales.
   ========================================================================== */

-- --------------------------------------------------------------------------
-- PAYMENT METHODS (cash, card, mobile, bank transfer ...)
-- --------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.payment_methods', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.payment_methods
    (
        payment_method_id  INT           NOT NULL IDENTITY(1,1) CONSTRAINT PK_payment_methods PRIMARY KEY,
        method_code        NVARCHAR(30)  NOT NULL,
        method_name        NVARCHAR(100) NOT NULL,
        is_cash            BIT           NOT NULL CONSTRAINT DF_payment_methods_is_cash DEFAULT (0),
        is_active          BIT           NOT NULL CONSTRAINT DF_payment_methods_is_active DEFAULT (1),
        sort_order         INT           NOT NULL CONSTRAINT DF_payment_methods_sort_order DEFAULT (0),
        created_at         DATETIME2(0)  NOT NULL CONSTRAINT DF_payment_methods_created_at DEFAULT (SYSUTCDATETIME()),
        updated_at         DATETIME2(0)  NOT NULL CONSTRAINT DF_payment_methods_updated_at DEFAULT (SYSUTCDATETIME())
    );

    ALTER TABLE dbo.payment_methods ADD CONSTRAINT UQ_payment_methods_code UNIQUE (method_code);
    ALTER TABLE dbo.payment_methods ADD CONSTRAINT CK_payment_methods_code_upper
        CHECK (method_code = UPPER(LTRIM(RTRIM(method_code))));
END
GO

-- --------------------------------------------------------------------------
-- PAYMENTS (per-sale installment / method)
-- --------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.payments', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.payments
    (
        payment_id        INT            NOT NULL IDENTITY(1,1) CONSTRAINT PK_payments PRIMARY KEY,
        sale_id           INT            NOT NULL,
        payment_method_id INT            NOT NULL,
        amount            DECIMAL(19,4)  NOT NULL,
        reference_number  NVARCHAR(100)  NULL,                 -- external ref / cheque no
        received_at       DATETIME2(0)   NOT NULL CONSTRAINT DF_payments_received_at DEFAULT (SYSUTCDATETIME()),
        received_by       INT            NULL,
        pay_status        NVARCHAR(20)   NOT NULL CONSTRAINT DF_payments_pay_status DEFAULT (N'COMPLETED'), -- COMPLETED / PARTIAL / REFUNDED / FAILED
        [notes]           NVARCHAR(255)  NULL,
        created_at        DATETIME2(0)   NOT NULL CONSTRAINT DF_payments_created_at DEFAULT (SYSUTCDATETIME())
    );

    ALTER TABLE dbo.payments ADD CONSTRAINT FK_payments_sales
        FOREIGN KEY (sale_id) REFERENCES dbo.sales (sale_id);
    ALTER TABLE dbo.payments ADD CONSTRAINT FK_payments_payment_methods
        FOREIGN KEY (payment_method_id) REFERENCES dbo.payment_methods (payment_method_id);
    ALTER TABLE dbo.payments ADD CONSTRAINT FK_payments_users
        FOREIGN KEY (received_by) REFERENCES dbo.users (user_id);
    ALTER TABLE dbo.payments ADD CONSTRAINT CK_payments_amount_positive CHECK (amount > 0);
    ALTER TABLE dbo.payments ADD CONSTRAINT CK_payments_status
        CHECK (pay_status IN (N'COMPLETED', N'PARTIAL', N'REFUNDED'));
END
GO

-- --------------------------------------------------------------------------
-- RECEIPTS
-- --------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.receipts', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.receipts
    (
        receipt_id        INT            NOT NULL IDENTITY(1,1) CONSTRAINT PK_receipts PRIMARY KEY,
        receipt_number    NVARCHAR(50)   NOT NULL,
        sale_id           INT            NOT NULL,
        gross_total       DECIMAL(19,4)  NOT NULL,
        discount_amount   DECIMAL(19,4)  NOT NULL CONSTRAINT DF_receipts_discount_amount DEFAULT (0),
        tax_amount        DECIMAL(19,4)  NOT NULL CONSTRAINT DF_receipts_tax_amount DEFAULT (0),
        net_total         DECIMAL(19,4)  NOT NULL,
        amount_paid       DECIMAL(19,4)  NOT NULL,
        change_due        DECIMAL(19,4)  NOT NULL CONSTRAINT DF_receipts_change_due DEFAULT (0),
        generated_by      INT            NULL,
        generated_at      DATETIME2(0)   NOT NULL CONSTRAINT DF_receipts_generated_at DEFAULT (SYSUTCDATETIME())
    );

    ALTER TABLE dbo.receipts ADD CONSTRAINT UQ_receipts_receipt_number UNIQUE (receipt_number);
    ALTER TABLE dbo.receipts ADD CONSTRAINT FK_receipts_sales
        FOREIGN KEY (sale_id) REFERENCES dbo.sales (sale_id);
    ALTER TABLE dbo.receipts ADD CONSTRAINT FK_receipts_users
        FOREIGN KEY (generated_by) REFERENCES dbo.users (user_id);
END
GO

-- ----------------------------------------------------------------------------
-- INDEXES
-- ----------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_payments_sale_id')
    CREATE NONCLUSTERED INDEX IX_payments_sale_id ON dbo.payments (sale_id);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_payments_method_id')
    CREATE NONCLUSTERED INDEX IX_payments_method_id ON dbo.payments (payment_method_id);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_receipts_sale_id')
    CREATE NONCLUSTERED INDEX IX_receipts_sale_id ON dbo.receipts (sale_id);
GO