# =============================================================================
# 00_setup.R: run once, from this folder:   Rscript 00_setup.R
# Installs the R packages, creates the folders and checks your tools.
# =============================================================================
pkgs <- c("DBI", "duckdb", "RSQLite", "yaml", "config", "readxl", "jsonlite", "httr2",
          "shiny", "bslib", "bsicons", "plotly", "DT", "rsconnect")
optional <- c("RPostgres", "odbc")        # only if you pull from PostgreSQL / SQL Server / Oracle
missing <- setdiff(pkgs, rownames(installed.packages()))
if (length(missing)) {
  message("Installing: ", paste(missing, collapse = ", "))
  install.packages(missing, repos = c(CRAN = "https://cloud.r-project.org"))
}
for (d in c("data/raw", "data/db", "data/serve", "logs", "sql/silver", "sql/gold", "tests", "semantic"))
  dir.create(d, showWarnings = FALSE, recursive = TRUE)
if (!file.exists(".Renviron") && file.exists(".Renviron.example")) {
  file.copy(".Renviron.example", ".Renviron"); message("Created .Renviron from the example. Put your secrets there.")
}
check <- function(what, ok, fix) message(sprintf("%-28s %s", what, if (ok) "OK" else paste("MISSING:", fix)))
message("\n--- checks ---")
check(sprintf("R %s", getRversion()), getRversion() >= "4.3", "install R 4.3 or newer from cran.r-project.org")
check("R packages", all(pkgs %in% rownames(installed.packages())), "re-run this script and read the errors")
q <- Sys.which("quarto"); check("Quarto", nzchar(q), "install from quarto.org")
g <- Sys.which("git");    check("Git (recommended)", nzchar(g), "install from git-scm.com")
check("optional database drivers", all(optional %in% rownames(installed.packages())),
      paste("install.packages(c('", paste(optional, collapse = "', '"), "')) if you need them", sep = ""))
message("\nNext: put files in data/raw, then run:  Rscript run_pipeline.R --to=bronze")
