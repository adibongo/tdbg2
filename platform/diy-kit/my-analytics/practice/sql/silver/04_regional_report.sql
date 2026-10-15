-- silver.regional_report: Finance's printed FY2025 Excel report made tidy, for reconciliation.
-- Fill the merged region cells down, drop the "All depots" total and the footnote, unpivot the
-- twelve month columns, and turn "₦149,023,348" into a number.
CREATE OR REPLACE TABLE silver.regional_report AS
WITH filled AS (
  SELECT last_value(region IGNORE NULLS) OVER (ORDER BY _row) AS region, depot,
         Jan, Feb, Mar, Apr, May, Jun, Jul, Aug, Sep, Oct, Nov, Dec
  FROM bronze.regional_report
  WHERE depot IS NOT NULL AND depot <> 'All depots'
), long AS (
  UNPIVOT filled ON Jan, Feb, Mar, Apr, May, Jun, Jul, Aug, Sep, Oct, Nov, Dec INTO NAME mon VALUE revenue_txt
)
SELECT region, depot AS depot_name,
       strptime('2025 ' || mon || ' 01', '%Y %b %d')::DATE            AS month,
       CAST(regexp_replace(revenue_txt, '[^0-9.]', '', 'g') AS DOUBLE) AS revenue_ngn
FROM long;
