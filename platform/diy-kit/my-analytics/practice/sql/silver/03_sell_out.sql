-- silver.sell_out: typed weekly sell-out, one row per week x depot x SKU.
-- Rule (board pack Notes sheet): a blank units_sold means a stockout week -> 0, and we keep the evidence flag.
-- Rule: re-sent rows for the same key collapse to the first one loaded (214 duplicate keys in the source).
CREATE OR REPLACE TABLE silver.sell_out AS
SELECT CAST(week_starting AS DATE)                  AS week_starting,
       trim(depot_code)                             AS depot_code,
       trim(sku)                                    AS sku,
       COALESCE(TRY_CAST(units_sold  AS DOUBLE), 0) AS units_sold,
       TRY_CAST(unit_price_ngn AS DOUBLE)           AS unit_price_ngn,
       CAST(on_promotion  AS INTEGER)               AS on_promotion,
       CAST(discount_pct  AS DOUBLE)                AS discount_pct,
       CAST(stockout_flag AS INTEGER)               AS stockout_flag,
       COALESCE(TRY_CAST(revenue_ngn AS DOUBLE), 0) AS revenue_ngn,
       units_sold IS NULL                           AS units_was_blank
FROM bronze.fmcg_sell_out
QUALIFY row_number() OVER (PARTITION BY week_starting, depot_code, sku ORDER BY _row) = 1;
