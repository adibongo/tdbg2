# Export compact, aggregated data from the DuckDB warehouse for the static dashboard.
# Run from the lab root after rendering 01-build-data-layer.qmd:  Rscript static-dashboard/export_data.R
# The static page aggregates these "cubes" in the browser, so it needs no server.
source("R/helpers.R"); library(jsonlite)
out <- "static-dashboard/data"; dir.create(out, showWarnings = FALSE)
q <- function(con, sql) dbGetQuery(con, sql)
with_duck(function(con) {
  write.csv(q(con, "SELECT CAST(week_starting AS VARCHAR) AS wk, region, depot_name AS depot, category, on_promotion AS promo,
                       round(SUM(revenue_ngn)) AS rev, round(SUM(gross_profit_ngn)) AS gp, SUM(units_sold) AS units,
                       COUNT(*) AS n, SUM(stockout_flag) AS so,
                       round(SUM(CASE WHEN on_promotion = 1 THEN discount_pct ELSE 0 END), 3) AS disc
                FROM v_sales GROUP BY ALL"), file.path(out, "cube_week.csv"), row.names = FALSE)
  write.csv(q(con, "SELECT strftime(week_starting, '%Y-%m') AS mon, region, category, product_name AS product, on_promotion AS promo,
                       round(SUM(revenue_ngn)) AS rev, round(SUM(gross_profit_ngn)) AS gp, SUM(units_sold) AS units,
                       COUNT(*) AS n, SUM(stockout_flag) AS so
                FROM v_sales GROUP BY ALL"), file.path(out, "cube_product.csv"), row.names = FALSE)
  write_json(q(con, "SELECT review_id AS id, CAST(received_date AS VARCHAR) AS dt, channel, star_rating AS stars, theme,
                            sentiment, language AS lang, review_text AS txt FROM review_docs"), file.path(out, "reviews.json"))
  write.csv(q(con, "SELECT CAST(week_starting AS VARCHAR) AS wk, channel, spend_ngn, conversions FROM marketing_spend"),
            file.path(out, "marketing.csv"), row.names = FALSE)
  write.csv(q(con, "SELECT CAST(month AS VARCHAR) AS mon, headline_inflation_yoy_pct AS headline, food_inflation_yoy_pct AS food,
                            usd_ngn_official AS usdngn, mpr_pct AS mpr FROM ng_macro_monthly"), file.path(out, "macro.csv"), row.names = FALSE)
  write.csv(q(con, "SELECT * FROM dv_gdp"), file.path(out, "gdp.csv"), row.names = FALSE)
  write_json(q(con, "SELECT test, status, severity, detail FROM data_tests"), file.path(out, "tests.json"))
  write.csv(q(con, "SELECT depot_name AS depot, round(gap_pct, 3) AS gap_pct FROM recon_regional"), file.path(out, "recon.csv"), row.names = FALSE)
  write_json(q(con, "SELECT CAST(built_at AS VARCHAR) AS built_at, fact_rows, landing_tables FROM build_log"),
             file.path(out, "build.json"), auto_unbox = TRUE)
})
write_json(read_semantic(), file.path(out, "metrics.json"), auto_unbox = TRUE, pretty = TRUE)
cat("Exported to", out, "\n")

# "Same question, every source": all-time revenue and rows from each source the live app supports
src <- do.call(rbind, lapply(names(SOURCES), function(n) {
  s <- SOURCES[[n]]
  if (!source_available(s)) return(data.frame(source = n, status = "not configured", rows = NA, revenue_bn = NA))
  d <- get_sales(s); data.frame(source = n, status = "live", rows = nrow(d), revenue_bn = round(sum(d$revenue_ngn) / 1e9, 3))
}))
write_json(src, file.path(out, "sources.json"))
print(src)

# Official statistics (World Bank WDI, IMF WEO, UN Comtrade) from the warehouse
with_duck(function(con) if ("open_macro" %in% dbListTables(con))
  write.csv(dbGetQuery(con, "SELECT source, indicator, indicator_name, iso3, country, year, round(value, 3) AS value FROM open_macro"),
            file.path(out, "open_macro.csv"), row.names = FALSE))
