-- silver.products: typed product master, one row per SKU (first listed wins).
CREATE OR REPLACE TABLE silver.products AS
SELECT trim(sku)                      AS sku,
       trim(product_name)             AS product_name,
       trim(category)                 AS category,
       pack_size,
       CAST(unit_cost_ngn  AS DOUBLE) AS unit_cost_ngn,
       CAST(list_price_ngn AS DOUBLE) AS list_price_ngn
FROM bronze.fmcg_products
QUALIFY row_number() OVER (PARTITION BY trim(sku) ORDER BY _row) = 1;
