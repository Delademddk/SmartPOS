/* ==========================================================================
   SmartPOS Database - MODULE 09: PAYMENTS PROCEDURES
   --------------------------------------------------------------------------
   SP_GetPaymentMethods     - list payment methods (optional inactive)
   SP_CreatePaymentMethod   - create with unique uppercase code
   SP_UpdatePaymentMethod   - update; guards last active cash method
   SP_GetSalePayments       - payments for a sale
   SP_GetPayment            - single payment
   SP_RecordPayment         - record a payment; updates credit balances
   SP_GetReceipt            - single receipt by id
   SP_GetReceiptBySale      - latest receipt for a sale
   SP_GenerateReceipt       - compute totals and create a receipt

   Depends on: dbo.payment_methods, dbo.payments, dbo.receipts, dbo.sales,
               dbo.sale_items, dbo.credit_sales, dbo.credit_payments,
               dbo.users, dbo.error_logs.
   Conventions: SP_<Purpose>, snake_case, transactions, TRY...CATCH + THROW.
   ========================================================================== */

/* ---------------------------------------------------------------------------
   SP_GetPaymentMethods
   Lists payment methods ordered by sort_order/sort_order + name. @IncludeInactive
   controls whether inactive methods are returned.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_GetPaymentMethods', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_GetPaymentMethods;
GO
CREATE PROCEDURE dbo.SP_GetPaymentMethods
    @IncludeInactive BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        payment_method_id,
        method_code,
        method_name,
        is_cash,
        is_active,
        sort_order,
        created_at,
        updated_at
    FROM dbo.payment_methods
    WHERE (is_active = 1 OR @IncludeInactive = 1)
    ORDER BY sort_order, method_name;
END
GO

/* ---------------------------------------------------------------------------
   SP_CreatePaymentMethod
   Creates a payment method. The code is normalised to uppercase and must be
   unique (enforced by the UQ_payment_methods_code constraint).
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_CreatePaymentMethod', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_CreatePaymentMethod;
GO
CREATE PROCEDURE dbo.SP_CreatePaymentMethod
    @Code      NVARCHAR(30),
    @Name      NVARCHAR(100),
    @IsCash    BIT = 0,
    @SortOrder INT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Now DATETIME2(0) = SYSUTCDATETIME();
    DECLARE @NormCode NVARCHAR(30);

    BEGIN TRY
        SET @NormCode = UPPER(LTRIM(RTRIM(@Code)));

        IF NULLIF(@NormCode, N'') IS NULL
            THROW 54001, N'A payment method code is required.', 1;
        IF NULLIF(LTRIM(RTRIM(@Name)), N'') IS NULL
            THROW 54002, N'A payment method name is required.', 1;

        IF EXISTS (SELECT 1 FROM dbo.payment_methods WHERE method_code = @NormCode)
            THROW 54003, N'This payment method code already exists.', 1;

        INSERT INTO dbo.payment_methods
            (method_code, method_name, is_cash, is_active, sort_order, created_at, updated_at)
        VALUES
            (@NormCode, @Name, ISNULL(@IsCash, 0), 1, ISNULL(@SortOrder, 0), @Now, @Now);
    END TRY
    BEGIN CATCH
        INSERT INTO dbo.error_logs (user_id, error_code, message, stack_trace, source)
        VALUES (NULL, N'SP_CreatePaymentMethod', ERROR_MESSAGE(), ERROR_PROCEDURE(), N'SP_CreatePaymentMethod');
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------------
   SP_UpdatePaymentMethod
   Updates name/active/sort order. Prevents deactivating the last active cash
   method so the POS always retains a way to accept cash.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_UpdatePaymentMethod', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_UpdatePaymentMethod;
GO
CREATE PROCEDURE dbo.SP_UpdatePaymentMethod
    @ID          INT,
    @Name        NVARCHAR(100),
    @IsActive    BIT = 1,
    @SortOrder   INT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Now DATETIME2(0) = SYSUTCDATETIME();
    DECLARE @IsCash BIT;

    BEGIN TRY
        SELECT @IsCash = is_cash
        FROM dbo.payment_methods
        WHERE payment_method_id = @ID;

        IF @IsCash IS NULL
            THROW 54004, N'Payment method not found.', 1;

        IF NULLIF(LTRIM(RTRIM(@Name)), N'') IS NULL
            THROW 54002, N'A payment method name is required.', 1;

        -- Guard: cannot deactivate the last remaining active cash method
        IF ISNULL(@IsActive, 1) = 0 AND ISNULL(@IsCash, 0) = 1
           AND (SELECT COUNT(*) FROM dbo.payment_methods WHERE is_cash = 1 AND is_active = 1) <= 1
           AND EXISTS (SELECT 1 FROM dbo.payment_methods WHERE payment_method_id = @ID AND is_active = 1)
            THROW 54005, N'Cannot deactivate the last active cash payment method.', 1;

        UPDATE dbo.payment_methods
        SET method_name = @Name,
            is_active   = ISNULL(@IsActive, 1),
            sort_order  = ISNULL(@SortOrder, 0),
            updated_at  = @Now
        WHERE payment_method_id = @ID;
    END TRY
    BEGIN CATCH
        INSERT INTO dbo.error_logs (user_id, error_code, message, stack_trace, source)
        VALUES (NULL, N'SP_UpdatePaymentMethod', ERROR_MESSAGE(), ERROR_PROCEDURE(), N'SP_UpdatePaymentMethod');
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------------
   SP_GetSalePayments / SP_GetPayment
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_GetSalePayments', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_GetSalePayments;
GO
CREATE PROCEDURE dbo.SP_GetSalePayments
    @SaleID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        pa.payment_id,
        pa.sale_id,
        pa.payment_method_id,
        pm.method_code,
        pm.method_name,
        pm.is_cash,
        pa.amount,
        pa.reference_number,
        pa.received_at,
        pa.received_by,
        pa.pay_status,
        pa.[notes],
        pa.created_at
    FROM dbo.payments pa
    INNER JOIN dbo.payment_methods pm ON pm.payment_method_id = pa.payment_method_id
    WHERE pa.sale_id = @SaleID
    ORDER BY pa.received_at, pa.payment_id;
END
GO

/* ---------------------------------------------------------------------------
   SP_GetPayment
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_GetPayment', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_GetPayment;
GO
CREATE PROCEDURE dbo.SP_GetPayment
    @PaymentID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        pa.payment_id,
        pa.sale_id,
        pa.payment_method_id,
        pm.method_code,
        pm.method_name,
        pm.is_cash,
        pa.amount,
        pa.reference_number,
        pa.received_at,
        pa.received_by,
        pa.pay_status,
        pa.[notes],
        pa.created_at
    FROM dbo.payments pa
    INNER JOIN dbo.payment_methods pm ON pm.payment_method_id = pa.payment_method_id
    WHERE pa.payment_id = @PaymentID;
END
GO

/* ---------------------------------------------------------------------------
   SP_RecordPayment
   Records a payment against a sale. Validates the sale exists and is active
   (not VOIDED/REFUNDED), that the amount is positive, and that the payment
   method is active. For credit sales, reduces the credit balance and inserts
   a credit_payments row.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_RecordPayment', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_RecordPayment;
GO
CREATE PROCEDURE dbo.SP_RecordPayment
    @SaleID          INT,
    @MethodID        INT,
    @Amount          DECIMAL(19,4),
    @ReferenceNumber NVARCHAR(100) = NULL,
    @ReceivedBy      INT = NULL,
    @Notes           NVARCHAR(255) = NULL,
    @PaymentID       INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Now DATETIME2(0) = SYSUTCDATETIME();
    DECLARE @SaleStatus NVARCHAR(20);
    DECLARE @SaleType   NVARCHAR(20);

    BEGIN TRY
        SELECT @SaleStatus = [status], @SaleType = sale_type
        FROM dbo.sales
        WHERE sale_id = @SaleID;

        IF @SaleStatus IS NULL
            THROW 54006, N'Sale does not exist.', 1;
        IF @SaleStatus <> N'COMPLETED'
            THROW 54007, N'Payments can only be recorded against active sales.', 1;
        IF @Amount IS NULL OR @Amount <= 0
            THROW 54008, N'Payment amount must be greater than zero.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.payment_methods WHERE payment_method_id = @MethodID AND is_active = 1)
            THROW 54009, N'Payment method is inactive or does not exist.', 1;

        BEGIN TRANSACTION;

        INSERT INTO dbo.payments
            (sale_id, payment_method_id, amount, reference_number,
             received_at, received_by, pay_status, notes, created_at)
        VALUES
            (@SaleID, @MethodID, @Amount, @ReferenceNumber,
             @Now, @ReceivedBy, N'COMPLETED', @Notes, @Now);

        SET @PaymentID = SCOPE_IDENTITY();

        -- Update the sale's received amount
        UPDATE dbo.sales
        SET amount_received = amount_received + @Amount,
            updated_at      = @Now
        WHERE sale_id = @SaleID;

        -- For credit sales, reduce the outstanding balance and log the credit
        -- payment.
        IF @SaleType IN (N'CREDIT', N'CREDIT_PARTIAL')
        BEGIN
            DECLARE @CreditSaleID INT;
            DECLARE @Balance DECIMAL(19,4);

            SELECT @CreditSaleID = credit_sale_id,
                   @Balance      = outstanding_balance
            FROM dbo.credit_sales
            WHERE sale_id = @SaleID;

            IF @CreditSaleID IS NOT NULL
            BEGIN
                DECLARE @NewBalance DECIMAL(19,4) = @Balance - @Amount;
                IF @NewBalance < 0 SET @NewBalance = 0;

                UPDATE dbo.credit_sales
                SET amount_paid         = amount_paid + @Amount,
                    outstanding_balance = @NewBalance,
                    [status]            = CASE
                                             WHEN @NewBalance <= 0 THEN N'SETTLED'
                                             WHEN amount_paid + @Amount > 0 THEN N'PARTIAL'
                                             ELSE N'OPEN'
                                         END,
                    updated_at          = @Now
                WHERE credit_sale_id = @CreditSaleID;

                INSERT INTO dbo.credit_payments
                    (credit_sale_id, payment_id, amount, payment_date,
                     received_by, [notes], created_at)
                VALUES
                    (@CreditSaleID, @PaymentID, @Amount, @Now,
                     @ReceivedBy, @Notes, @Now);
            END
        END

        COMMIT TRANSACTION;

        SELECT @PaymentID AS PaymentID;
        RETURN @PaymentID;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        INSERT INTO dbo.error_logs (user_id, error_code, message, stack_trace, source)
        VALUES (@ReceivedBy, N'SP_RecordPayment', ERROR_MESSAGE(), ERROR_PROCEDURE(), N'SP_RecordPayment');
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------------
   SP_GetReceipt / SP_GetReceiptBySale
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_GetReceipt', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_GetReceipt;
GO
CREATE PROCEDURE dbo.SP_GetReceipt
    @ReceiptID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        r.receipt_id,
        r.receipt_number,
        r.sale_id,
        r.gross_total,
        r.discount_amount,
        r.tax_amount,
        r.net_total,
        r.amount_paid,
        r.change_due,
        r.generated_by,
        r.generated_at
    FROM dbo.receipts r
    WHERE r.receipt_id = @ReceiptID;
END
GO

IF OBJECT_ID(N'dbo.SP_GetReceiptBySale', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_GetReceiptBySale;
GO
CREATE PROCEDURE dbo.SP_GetReceiptBySale
    @SaleID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (1)
        r.receipt_id,
        r.receipt_number,
        r.sale_id,
        r.gross_total,
        r.discount_amount,
        r.tax_amount,
        r.net_total,
        r.amount_paid,
        r.change_due,
        r.generated_by,
        r.generated_at
    FROM dbo.receipts r
    WHERE r.sale_id = @SaleID
    ORDER BY r.generated_at DESC, r.receipt_id DESC;
END
GO

/* ---------------------------------------------------------------------------
   SP_GenerateReceipt
   Computes receipt totals from the sale header and its items, inserts a
   receipt row with a unique receipt_number, and returns the receipt header
   and line items as two result sets.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_GenerateReceipt', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_GenerateReceipt;
GO
CREATE PROCEDURE dbo.SP_GenerateReceipt
    @SaleID      INT,
    @GeneratedBy INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Now DATETIME2(0) = SYSUTCDATETIME();
    DECLARE @ReceiptID INT;
    DECLARE @ReceiptNumber NVARCHAR(50);
    DECLARE @Sequence INT;
    DECLARE @Gross DECIMAL(19,4);
    DECLARE @Discount DECIMAL(19,4);
    DECLARE @Tax DECIMAL(19,4);
    DECLARE @Net DECIMAL(19,4);
    DECLARE @Paid DECIMAL(19,4);
    DECLARE @Change DECIMAL(19,4);

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.sales WHERE sale_id = @SaleID)
            THROW 54010, N'Sale does not exist.', 1;

        SELECT @Gross   = subtotal + discount_amount,   -- pre-discount value
               @Discount = discount_amount,
               @Tax     = tax_amount,
               @Net     = total_amount,
               @Paid    = amount_received
        FROM dbo.sales
        WHERE sale_id = @SaleID;

        SET @Gross   = ISNULL(@Gross, 0);
        SET @Discount = ISNULL(@Discount, 0);
        SET @Tax     = ISNULL(@Tax, 0);
        SET @Net     = ISNULL(@Net, 0);
        SET @Paid    = ISNULL(@Paid, 0);
        SET @Change  = CASE WHEN @Paid - @Net > 0 THEN @Paid - @Net ELSE 0 END;

        BEGIN TRANSACTION;

        SELECT @Sequence = COUNT(*) + 1 FROM dbo.receipts WHERE sale_id = @SaleID;
        SET @Sequence = ISNULL(@Sequence, 1);
        SET @ReceiptNumber =
            N'RCP-' +
            RIGHT(N'00000' + CAST(@SaleID AS NVARCHAR(10)), 6) +
            N'-' +
            RIGHT(N'00000' + CAST(@Sequence AS NVARCHAR(10)), 4);

        INSERT INTO dbo.receipts
            (receipt_number, sale_id, gross_total, discount_amount, tax_amount,
             net_total, amount_paid, change_due, generated_by, generated_at)
        VALUES
            (@ReceiptNumber, @SaleID, @Gross, @Discount, @Tax,
             @Net, @Paid, @Change, @GeneratedBy, @Now);

        SET @ReceiptID = SCOPE_IDENTITY();

        COMMIT TRANSACTION;

        SELECT
            r.receipt_id,
            r.receipt_number,
            r.sale_id,
            r.gross_total,
            r.discount_amount,
            r.tax_amount,
            r.net_total,
            r.amount_paid,
            r.change_due,
            r.generated_by,
            r.generated_at
        FROM dbo.receipts r
        WHERE r.receipt_id = @ReceiptID;

        SELECT
            @ReceiptID AS receipt_id,
            si.sale_item_id,
            si.product_id,
            p.sku,
            p.product_name,
            si.quantity,
            si.unit_price,
            si.discount_rate,
            si.tax_amount,
            si.line_total
        FROM dbo.sale_items si
        LEFT JOIN dbo.products p ON p.product_id = si.product_id
        WHERE si.sale_id = @SaleID
        ORDER BY si.sale_item_id;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        INSERT INTO dbo.error_logs (user_id, error_code, message, stack_trace, source)
        VALUES (@GeneratedBy, N'SP_GenerateReceipt', ERROR_MESSAGE(), ERROR_PROCEDURE(), N'SP_GenerateReceipt');
        THROW;
    END CATCH
END
GO