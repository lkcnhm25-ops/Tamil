-- This query uses EOM_Date from fund_positions, which is already correctly typed as DATE.
-- The preceding statement MUST be terminated with a semicolon for CTEs to work.
;WITH MonthlyFundTotals AS (
    SELECT
        Fund_Name,
        EOM_Date,
        -- Fund_MV_end: Sum only for tradable assets (excluding CASH)
        SUM(CASE WHEN Instrument_Type IN ('BOND', 'EQUITY') THEN Market_Value ELSE 0 END) AS Fund_MV_end,
        SUM(CASE WHEN Instrument_Type IN ('BOND', 'EQUITY') THEN Realized_PL ELSE 0 END) AS Monthly_Realized_PL
    FROM dbo.fund_positions
    GROUP BY Fund_Name, EOM_Date
),
WithStartMV AS (
    SELECT
        Fund_Name,
        EOM_Date,
        Fund_MV_end,
        Monthly_Realized_PL,
        -- Fund_MV_start: Get the previous month's Fund MV using LAG()
        LAG(Fund_MV_end, 1, Fund_MV_end) OVER (
            PARTITION BY Fund_Name
            ORDER BY EOM_Date 
        ) AS Fund_MV_start
    FROM MonthlyFundTotals
),
WithRoR AS (
    SELECT
        *,
        -- RoR calculation
        CASE 
            WHEN Fund_MV_start > 0 
            AND EOM_Date > (SELECT MIN(EOM_Date) FROM MonthlyFundTotals)
            THEN (Fund_MV_end - Fund_MV_start + Monthly_Realized_PL) / Fund_MV_start
            ELSE NULL
        END AS Rate_of_Return,
        -- Rank funds by RoR for each month
        RANK() OVER (
            PARTITION BY EOM_Date
            ORDER BY 
                CASE WHEN Fund_MV_start > 0 THEN (Fund_MV_end - Fund_MV_start + Monthly_Realized_PL) / Fund_MV_start ELSE -999999.0 END DESC
        ) AS rank_by_ror
    FROM WithStartMV
)
-- Final SELECT statement
SELECT
    EOM_Date,
    Fund_Name,
    CAST(Rate_of_Return AS DECIMAL(18, 4)) AS Rate_of_Return,
    CAST(Fund_MV_end AS DECIMAL(18, 2)) AS Fund_MV_end,
    CAST(Fund_MV_start AS DECIMAL(18, 2)) AS Fund_MV_start,
    CAST(Monthly_Realized_PL AS DECIMAL(18, 2)) AS Monthly_Realized_PL,
    'BEST PERFORMING FUND' AS Status
FROM WithRoR
WHERE rank_by_ror = 1 AND Rate_of_Return IS NOT NULL
ORDER BY EOM_Date;
GO