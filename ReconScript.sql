-- The preceding statement MUST be terminated with a semicolon for CTEs to work.
;WITH AllRefPrices AS (
    -- CTE 1: Combine all reference prices into one list

    -- Bond Prices
    SELECT
        -- Fix 1: Convert TEXT DATETIME to DATE
        CAST(CAST([DATETIME] AS NVARCHAR(50)) AS DATE) AS Price_Date,
        -- Fix 2: Convert TEXT ISIN to NVARCHAR(100) for comparison
        CAST(ISIN AS NVARCHAR(100)) AS Instrument_ID,
        'BOND' AS Instrument_Type,
        PRICE
    FROM bond_prices
    
    UNION ALL
    
    -- Equity Prices
    SELECT
        -- Fix 1: Convert TEXT DATETIME to DATE
        CAST(CAST([DATETIME] AS NVARCHAR(50)) AS DATE) AS Price_Date,
        -- Fix 2: Convert TEXT SYMBOL to NVARCHAR(100) for comparison
        CAST(SYMBOL AS NVARCHAR(100)) AS Instrument_ID,
        'EQUITY' AS Instrument_Type,
        PRICE
    FROM equity_prices
),
LastAvailablePrices AS (
    -- CTE 2: Find the Last Available Price (LAP) for each fund position
    SELECT
        fp.Fund_Name,
        fp.EOM_Date,
        fp.Instrument_ID,
        fp.Instrument_Type,
        fp.Fund_Price,
        ap.PRICE AS Ref_Price,
        ap.Price_Date AS Ref_Price_Date,
        -- Rank the reference prices: Rank 1 is the most recent price <= EOM_Date.
        ROW_NUMBER() OVER (
            PARTITION BY fp.Fund_Name, fp.EOM_Date, fp.Instrument_ID
            ORDER BY ap.Price_Date DESC
        ) as rn
    FROM dbo.fund_positions fp
    -- The join comparison now works because ap.Instrument_ID is converted to NVARCHAR(100)
    LEFT JOIN AllRefPrices ap
        ON fp.Instrument_ID = ap.Instrument_ID
        AND fp.Instrument_Type = ap.Instrument_Type
        AND ap.Price_Date <= fp.EOM_Date
    WHERE fp.Instrument_Type IN ('BOND', 'EQUITY')
)
-- Final SELECT statement
SELECT
    Fund_Name,
    EOM_Date,
    Instrument_ID,
    Instrument_Type,
    Fund_Price,
    Ref_Price,
    Ref_Price_Date,
    CAST((Fund_Price - Ref_Price) AS DECIMAL(18, 4)) AS Price_Difference,
    CASE
        WHEN Ref_Price IS NULL THEN 'NO REFERENCE PRICE FOUND'
        WHEN Ref_Price_Date < EOM_Date THEN 'BREAK (LAST AVAILABLE PRICE USED)'
        ELSE 'OK (EOM PRICE MATCH)'
    END AS Status
FROM LastAvailablePrices
WHERE rn = 1 OR Ref_Price IS NULL
ORDER BY EOM_Date, Fund_Name, Instrument_ID;
GO