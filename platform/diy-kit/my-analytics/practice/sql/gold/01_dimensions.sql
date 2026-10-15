-- Dimensions: the things we slice by. One row per depot (current version) and per product.
CREATE OR REPLACE TABLE gold.dim_depot AS
SELECT depot_code, depot_name, region, state, opened
FROM silver.depot_history WHERE is_current;

CREATE OR REPLACE TABLE gold.dim_product AS
SELECT sku, product_name, category, pack_size, unit_cost_ngn, list_price_ngn,
       round(1 - unit_cost_ngn / list_price_ngn, 3) AS list_margin
FROM silver.products;
