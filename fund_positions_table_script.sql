CREATE TABLE dbo.fund_positions (
    Fund_Name NVARCHAR(100) NOT NULL,
    EOM_Date DATE NOT NULL,
    Instrument_ID NVARCHAR(100) NOT NULL,
    Instrument_Type NVARCHAR(50) NOT NULL, -- 'BOND', 'EQUITY', 'CASH'
    Position DECIMAL(18, 4),
    Fund_Price DECIMAL(18, 4),
    Market_Value DECIMAL(18, 4),
    Realized_PL DECIMAL(18, 4),
    CONSTRAINT PK_FundPositions PRIMARY KEY (Fund_Name, EOM_Date, Instrument_ID)
);
