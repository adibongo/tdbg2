-- silver.marketing_spend: typed weekly spend by channel (from the marketing platform's JSON export).
CREATE OR REPLACE TABLE silver.marketing_spend AS
SELECT CAST(week_starting AS DATE) AS week_starting, trim(channel) AS channel,
       CAST(spend_ngn AS DOUBLE) AS spend_ngn, CAST(conversions AS INTEGER) AS conversions
FROM bronze.marketing_spend;

-- silver.macro_inflation: Nigeria's annual consumer-price inflation from the World Bank API.
-- Years with no value yet are dropped; the source is named on every row.
CREATE OR REPLACE TABLE silver.macro_inflation AS
SELECT CAST(date AS INTEGER) AS year, CAST(value AS DOUBLE) AS inflation_pct,
       'World Bank WDI FP.CPI.TOTL.ZG' AS source
FROM bronze.wb_inflation_nga
WHERE value IS NOT NULL AND value <> '';
