-- Marts: small, pre-aggregated tables for Excel and Power BI users (published to data/serve/mart.sqlite).
CREATE OR REPLACE TABLE gold.mart_depot_month AS
SELECT CAST(date_trunc('month', week_starting) AS DATE) AS month, region, depot_name,
       SUM(revenue_ngn) AS revenue_ngn, SUM(gross_profit_ngn) AS gross_profit_ngn,
       SUM(units_sold) AS units, AVG(stockout_flag) AS stockout_rate
FROM gold.v_dashboard GROUP BY ALL;

CREATE OR REPLACE TABLE gold.mart_marketing_week AS
SELECT week_starting, channel, SUM(spend_ngn) AS spend_ngn, SUM(conversions) AS conversions,
       SUM(spend_ngn) / NULLIF(SUM(conversions), 0) AS cost_per_conversion_ngn
FROM silver.marketing_spend GROUP BY ALL;

CREATE OR REPLACE TABLE gold.ref_inflation AS SELECT * FROM silver.macro_inflation;
