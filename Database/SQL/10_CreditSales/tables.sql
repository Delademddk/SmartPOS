/* ==========================================================================
   SmartPOS Database - MODULE 10: CREDIT SALES
   --------------------------------------------------------------------------
   Objects: customers, credit_sales, credit_payments.
   Depends on: 02 Users, 08 Sales, 09 Payments (payment_method_id).

   Business rule: credit sales create customer balances; every credit payment
   reduces the outstanding balance.
   ========================================================================== */

-- --------------------------------------------------------------------------
-- CUSTOMERS (credit customers)
-- --------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.customers', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.customers
    (
        customer_id   INT           NOT NULL IDENTITY(1,1) CONSTRAINT PK_customers PRIMARY KEY,
        customer_code NVARCHAR(30)  NOT NULL,
        full_name     NVARCHAR(150) NOT NULL,
        phone         NVARCHAR(30)  NULL,
        email         NVARCHAR(255) NULL,
        address       NVARCHAR(255) NULL,
        credit_limit  DECIMAL(19,4) NOT NULL CONSTRAINT DF_customers_credit_limit DEFAULT (0),
        is_active     BIT           NOT NULL CONSTRAINT DF_customers_is_active DEFAULT (1),
        is_deleted    BIT           NOT NULL CONSTRAINT DF_customers_is_deleted DEFAULT (0),
        deleted_at    DATETIME2(0)  NULL,
        created_at    DATETIME2(0)  NOT NULL CONSTRAINT DF_customers_created_at DEFAULT (SYSUTCDATETIME()),
        updated_at    DATETIME2(0)  NOT NULL CONSTRAINT DF_customers_updated_at DEFAULT (SYSUTCDATETIME()),
        created_by    INT           NULL,
        updated_by    INT           NULL
    );

    ALTER TABLE dbo.customers ADD CONSTRAINT UQ_customers_code UNIQUE (customer_code);
    ALTER TABLE dbo.customers ADD CONSTRAINT FK_customers_created_by
        FOREIGN KEY (created_by) REFERENCES dbo.users (user_id);
    ALTER TABLE dbo.customers ADD CONSTRAINT CK_customers_credit_limit_non_negative
        CHECK (credit_limit >= 0);
END
GO

-- --------------------------------------------------------------------------
-- CREDIT SALES (balance ledger per credit sale)
-- --------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.credit_sales', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.credit_sales
    (
        credit_sale_id     INT            NOT NULL IDENTITY(1,1) CONSTRAINT PK_credit_sales PRIMARY KEY,
        sale_id            INT            NOT NULL,
        customer_id        INT            NOT NULL,
        total_amount       DECIMAL(19,4)  NOT NULL,
        amount_paid        DECIMAL(19,4)  NOT NULL CONSTRAINT DF_credit_sales_amount_paid DEFAULT (0),
        outstanding_balance DECIMAL(19,4) NOT NULL,
        due_date           DATE           NULL,
        [status]           NVARCHAR(20)   NOT NULL CONSTRAINT DF_credit_sales_status DEFAULT (N'OPEN'), -- OPEN / PARTIAL / SETTLED / OVERDUE / WRITTEN_OFF
        created_at         DATETIME2(0)   NOT NULL CONSTRAINT DF_credit_sales_created_at DEFAULT (SYSUTCDATETIME()),
        updated_at         DATETIME2(0)   NOT NULL CONSTRAINT DF_credit_sales_updated_at DEFAULT (SYSUTCDATETIME())
    );

    ALTER TABLE dbo.credit_sales ADD CONSTRAINT UQ_credit_sales_sale_id UNIQUE (sale_id);
    ALTER TABLE dbo.credit_sales ADD CONSTRAINT FK_credit_sales_sales
        FOREIGN KEY (sale_id) REFERENCES dbo.sales (sale_id);
    ALTER TABLE dbo.credit_sales ADD CONSTRAINT FK_credit_sales_customers
        FOREIGN KEY (customer_id) REFERENCES dbo.customers (customer_id);
    ALTER TABLE dbo.credit_sales ADD CONSTRAINT CK_credit_sales_balance_non_negative
        CHECK (outstanding_balance >= 0);
    ALTER TABLE dbo.credit_sales ADD CONSTRAINT CK_credit_sales_paid_non_negative
        CHECK (amount_paid >= 0);
    ALTER TABLE dbo.credit_sales ADD CONSTRAINT CK_credit_sales_status
        CHECK ([status] IN (N'OPEN', N'PARTIAL', N'SETTLED', N'OVERDUE', N'WRITTEN_OFF'));
END
GO

-- --------------------------------------------------------------------------
-- CREDIT PAYMENTS (payments against credit balances)
-- --------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.credit_payments', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.credit_payments
    (
        credit_payment_id INT            NOT NULL IDENTITY(1,1) CONSTRAINT PK_credit_payments PRIMARY KEY,
        credit_sale_id    INT            NOT NULL,
        payment_id        INT            NULL,                -- optional link to a sales payment
        amount            DECIMAL(19,4)  NOT NULL,
        payment_date      DATETIME2(0)   NOT NULL CONSTRAINT DF_credit_payments_payment_date DEFAULT (SYSUTCDATETIME()),
        received_by       INT            NULL,
        [notes]           NVARCHAR(255)  NULL,
        created_at        DATETIME2(0)   NOT NULL CONSTRAINT DF_credit_payments_created_at DEFAULT (SYSUTCDATETIME())
    );

    ALTER TABLE dbo.credit_payments ADD CONSTRAINT FK_credit_payments_credit_sales
        FOREIGN KEY (credit_sale_id) REFERENCES dbo.credit_sales (credit_sale_id);
    ALTER TABLE dbo.credit_payments ADD CONSTRAINT FK_credit_payments_payments
        FOREIGN KEY (payment_id) REFERENCES dbo.payments (payment_id);
    ALTER TABLE dbo.credit_payments ADD CONSTRAINT FK_credit_payments_users
        FOREIGN KEY (received_by) REFERENCES dbo.users (user_id);
    ALTER TABLE dbo.credit_payments ADD CONSTRAINT CK_credit_payments_amount_positive CHECK (amount > 0);
END
GO

-- ----------------------------------------------------------------------------
-- INDEXES
-- ----------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_credit_sales_customer_id')
    CREATE NONCLUSTERED INDEX IX_credit_sales_customer_id ON dbo.credit_sales (customer_id) INCLUDE (outstanding_balance, status);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_credit_sales_status')
    CREATE NONCLUSTERED INDEX IX_credit_sales_status ON dbo.credit_sales (status) INCLUDE (customer_id, outstanding_balance);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_credit_payments_credit_sale_id')
    CREATE NONCLUSTERED INDEX IX_credit_payments_credit_sale_id ON dbo.credit_payments (credit_sale_id);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_customers_name')
    CREATE NONCLUSTERED INDEX IX_customers_name ON dbo.customers (full_name) INCLUDE (phone);
GO

-- ----------------------------------------------------------------------------
-- FK BACKFILL: sales.customer_id -> customers.customer_id
-- Module 08 (sales) is created before this module, so the FK is applied here
-- once the customers table exists. This preserves referential integrity for
-- credit/customer sales.
-- ----------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_sales_customers')
    ALTER TABLE dbo.sales ADD CONSTRAINT FK_sales_customers
        FOREIGN KEY (customer_id) REFERENCES dbo.customers (customer_id);
GO