-- The one wide view the dashboard and the semantic layer read: the star, pre-joined.
CREATE OR REPLACE VIEW gold.v_dashboard AS
SELECT f.week_starting, d.region, d.depot_name, p.category, p.product_name,
       f.units_sold, f.revenue_ngn, f.gross_profit_ngn, f.on_promotion, f.discount_pct, f.stockout_flag
FROM gold.fct_sales f
JOIN gold.dim_depot   d USING (depot_code)
JOIN gold.dim_product p USING (sku);
