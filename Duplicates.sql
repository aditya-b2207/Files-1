USE [SalesOrderProd];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

-- 0 = Preview only
-- 1 = Delete duplicate records
DECLARE @Apply BIT = 0;

DECLARE @BeforeCount INT;
DECLARE @DuplicateCount INT;
DECLARE @DeletedCount INT;
DECLARE @AfterCount INT;

IF @@TRANCOUNT <> 0
    THROW 50001, 'An existing transaction is open.', 1;

BEGIN TRY

    BEGIN TRANSACTION;

    SELECT @BeforeCount = COUNT(*)
    FROM dbo.TB_CustomerLedger WITH (TABLOCKX, HOLDLOCK)
    WHERE CompanyCode = 1054
      AND Posting_Date >= '20261101'
      AND Posting_Date < '20261125';

    -- Identify exact duplicate records
    ;WITH DuplicateRecords AS
    (
        SELECT *,
            ROW_NUMBER() OVER
            (
                PARTITION BY
                    CompanyCode,
                    CustomerCode,
                    Document_Type,
                    Document_Number,
                    Credit_Control_Area,
                    Document_Date,
                    Net_Due_Date,
                    Posting_Date,
                    Credit_Control_Area_Currency,
                    Baseline_Payment_Date,
                    Amount_in_Local_Currency,
                    Clearing_Date,
                    Clearing_Document,
                    Assignment,
                    Reference,
                    [Text],
                    Account,
                    Document_Header_Text,
                    UserCode,
                    Arrears_by_Net_Due_Date,
                    GLAccount,
                    UpdateBy,
                    DC
                ORDER BY (SELECT NULL)
            ) AS RowNum
        FROM dbo.TB_CustomerLedger
        WHERE CompanyCode = 1054
          AND Posting_Date >= '20261101'
          AND Posting_Date < '20261125'
          AND NOT
          (
              ISNULL(Document_Type, '') = 'AB'
              AND ISNULL(Document_Number, '') = '0000000000'
          )
    )
    SELECT @DuplicateCount = COUNT(*)
    FROM DuplicateRecords
    WHERE RowNum > 1;

    -- Preview result
    SELECT
        @BeforeCount AS ExistingRecords,
        @DuplicateCount AS DuplicateRecords,
        @BeforeCount - @DuplicateCount AS ExpectedRecords;

    IF @Apply = 0
    BEGIN
        COMMIT TRANSACTION;
        PRINT 'Preview completed. No records deleted.';
        RETURN;
    END;

    -- Safety validation
    IF @BeforeCount <> 4360
        THROW 50002, 'Existing record count has changed.', 1;

    IF @DuplicateCount <> 1881
        THROW 50003, 'Duplicate count does not match expected count.', 1;

    -- Delete only exact duplicate records
    ;WITH DuplicateRecords AS
    (
        SELECT *,
            ROW_NUMBER() OVER
            (
                PARTITION BY
                    CompanyCode,
                    CustomerCode,
                    Document_Type,
                    Document_Number,
                    Credit_Control_Area,
                    Document_Date,
                    Net_Due_Date,
                    Posting_Date,
                    Credit_Control_Area_Currency,
                    Baseline_Payment_Date,
                    Amount_in_Local_Currency,
                    Clearing_Date,
                    Clearing_Document,
                    Assignment,
                    Reference,
                    [Text],
                    Account,
                    Document_Header_Text,
                    UserCode,
                    Arrears_by_Net_Due_Date,
                    GLAccount,
                    UpdateBy,
                    DC
                ORDER BY (SELECT NULL)
            ) AS RowNum
        FROM dbo.TB_CustomerLedger
        WHERE CompanyCode = 1054
          AND Posting_Date >= '20261101'
          AND Posting_Date < '20261125'
          AND NOT
          (
              ISNULL(Document_Type, '') = 'AB'
              AND ISNULL(Document_Number, '') = '0000000000'
          )
    )
    DELETE FROM DuplicateRecords
    WHERE RowNum > 1;

    SET @DeletedCount = @@ROWCOUNT;

    SELECT @AfterCount = COUNT(*)
    FROM dbo.TB_CustomerLedger
    WHERE CompanyCode = 1054
      AND Posting_Date >= '20261101'
      AND Posting_Date < '20261125';

    -- Final validation
    IF @DeletedCount <> 1881 OR @AfterCount <> 2479
        THROW 50004, 'Final record validation failed.', 1;

    COMMIT TRANSACTION;

    SELECT
        @BeforeCount AS BeforeDeletion,
        @DeletedCount AS DeletedDuplicates,
        @AfterCount AS RemainingRecords,
        'Success' AS Result;

END TRY
BEGIN CATCH

    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;

END CATCH;