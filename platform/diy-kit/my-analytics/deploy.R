# =============================================================================
# deploy.R: publish the dashboard so other people can open it in a browser.
#   Rscript deploy.R connect      Posit Connect or Posit Connect Cloud (needs an account; see the book, Chapter 16)
#   Rscript deploy.R shinyapps    shinyapps.io (free tier available)
#   Rscript deploy.R manifest     just write manifest.json (for Connect Cloud's "deploy from GitHub").
#                                 GitHub deploys need the warehouse file in the repository, so use this
#                                 route ONLY for data you may store in GitHub. Otherwise use connect/shinyapps.
# The warehouse file travels with the app, so run the pipeline first. For live refresh on a server,
# schedule run_pipeline.R ON that server instead (schedule/README.md).
# =============================================================================
target <- commandArgs(trailingOnly = TRUE)[1]
if (is.na(target)) target <- "manifest"
files <- c("dashboard.qmd", "theme.scss", "config.yml", "R/platform.R", "semantic/metrics.yml",
           "data/db/warehouse.duckdb", list.files("logs", full.names = TRUE))
stopifnot("Run the pipeline first: data/db/warehouse.duckdb is missing" = file.exists("data/db/warehouse.duckdb"))
if (target == "manifest") {
  rsconnect::writeManifest(appPrimaryDoc = "dashboard.qmd", appFiles = files, quarto = TRUE)
  message("manifest.json written. Commit it with the files listed in it, then deploy from GitHub in Connect Cloud.")
} else {
  # One-time setup: rsconnect::setAccountInfo(...) for shinyapps.io, or rsconnect::connectApiUser(...) for Connect.
  rsconnect::deployApp(appPrimaryDoc = "dashboard.qmd", appFiles = files, appName = "analytics-cockpit",
                       server = if (target == "shinyapps") "shinyapps.io" else NULL, forceUpdate = TRUE)
}
