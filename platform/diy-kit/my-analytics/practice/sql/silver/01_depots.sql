-- silver.depot_history: every version of every depot (slowly changing dimension, type 2).
-- The ERP lists DP04 twice: "Abuja Central" was renamed "Abuja Central (Wuse II)".
-- Business rule (confirmed by Commercial): the rename took effect on 2025-10-01.
CREATE OR REPLACE TABLE silver.depot_history AS
WITH d AS (
  SELECT trim(depot_code) AS depot_code, trim(depot_name) AS depot_name,
         trim(region) AS region, trim(state) AS state, CAST(opened AS DATE) AS opened,
         row_number() OVER (PARTITION BY trim(depot_code) ORDER BY _row) AS version
  FROM bronze.erp_depots
), v AS (
  SELECT *, CASE WHEN version = 1 THEN opened ELSE DATE '2025-10-01' END AS valid_from FROM d
)
SELECT depot_code, version, depot_name, region, state, opened, valid_from,
       lead(valid_from) OVER (PARTITION BY depot_code ORDER BY version) - INTERVAL 1 DAY AS valid_to,
       lead(valid_from) OVER (PARTITION BY depot_code ORDER BY version) IS NULL         AS is_current
FROM v;
