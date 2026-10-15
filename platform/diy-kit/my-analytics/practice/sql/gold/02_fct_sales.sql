-- Grain: one row per week x depot x SKU (a periodic snapshot fact).
CREATE OR REPLACE TABLE gold.fct_sales AS
SELECT s.week_starting, s.depot_code, s.sku,
       s.units_sold, s.revenue_ngn,
       s.revenue_ngn - s.units_sold * p.unit_cost_ngn AS gross_profit_ngn,
       s.on_promotion, s.discount_pct, s.stockout_flag, s.units_was_blank
FROM silver.sell_out s
JOIN silver.products p USING (sku);
