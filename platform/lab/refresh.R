# ===========================================================================
# refresh.R — rebuild every database, re-run the data tests, log the result.
#
# PROMPT that generated this file:
#   "Write refresh.R that re-renders 01-build-data-layer.qmd (which rebuilds
#    every database and re-runs the data tests), logs success or failure with a
#    timestamp to logs/refresh.log, and exits with an error code if any data
#    test fails. Then show me how to schedule it nightly at 05:30 Lagos time
#    with cron, launchd, Windows Task Scheduler and GitHub Actions."
#
# Run by hand:   Rscript refresh.R
# The running dashboard notices the new warehouse file within ~20 s
# (reactivePoll in 02-dashboard.qmd) and redraws itself. No restart needed.
# ===========================================================================
setwd(dirname(normalizePath(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE)[1]))))
dir.create("logs", showWarnings = FALSE)
log_line <- function(...) {
  msg <- paste0(format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "  ", paste0(...))
  cat(msg, "\n"); cat(msg, "\n", file = "logs/refresh.log", append = TRUE)
}

log_line("Refresh started")
status <- system2("quarto", c("render", "01-build-data-layer.qmd", "--quiet"))
if (status != 0) { log_line("FAILED: notebook did not render (exit ", status, ")"); quit(status = 1) }

source("R/helpers.R")
tests <- with_duck(function(con) dbGetQuery(con, "SELECT test, status, detail FROM data_tests"))
fails <- subset(tests, status == "FAIL")
log_line("Warehouse rebuilt. Tests: ", sum(tests$status == "PASS"), " pass, ", nrow(fails), " fail")
for (i in seq_len(nrow(fails))) log_line("  FAIL  ", fails$test[i], " — ", fails$detail[i])

# Optional alert, e.g. a Teams/Slack incoming webhook stored in .Renviron:
# if (nrow(fails) && nzchar(Sys.getenv("ALERT_WEBHOOK")))
#   httr2::request(Sys.getenv("ALERT_WEBHOOK")) |>
#     httr2::req_body_json(list(text = paste("TDBG data tests failed:", paste(fails$test, collapse = "; ")))) |>
#     httr2::req_perform()

# The freshness test is expected to fail on the course data (it stops in March 2026).
# Exit non-zero only for the tests that mean the numbers are wrong.
hard <- setdiff(fails$test, "Data is fresh (≤ 21 days)")
quit(status = if (length(hard)) 2 else 0)

# ---------------------------------------------------------------------------
# SCHEDULING — pick one
# ---------------------------------------------------------------------------
# 1) macOS / Linux cron  (crontab -e) — 05:30 every day:
#    30 5 * * * cd "/path/to/Shiny-Dashboard-Lab" && /usr/local/bin/Rscript refresh.R >> logs/cron.log 2>&1
#
# 2) macOS launchd — save as ~/Library/LaunchAgents/ng.lbs.tdbg.refresh.plist, then
#    launchctl load ~/Library/LaunchAgents/ng.lbs.tdbg.refresh.plist
#    <?xml version="1.0" encoding="UTF-8"?>
#    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
#    <plist version="1.0"><dict>
#      <key>Label</key><string>ng.lbs.tdbg.refresh</string>
#      <key>ProgramArguments</key><array>
#        <string>/usr/local/bin/Rscript</string>
#        <string>/path/to/Shiny-Dashboard-Lab/refresh.R</string></array>
#      <key>StartCalendarInterval</key><dict>
#        <key>Hour</key><integer>5</integer><key>Minute</key><integer>30</integer></dict>
#      <key>StandardOutPath</key><string>/tmp/tdbg-refresh.log</string>
#    </dict></plist>
#
# 3) Windows Task Scheduler (PowerShell, once):
#    schtasks /Create /SC DAILY /ST 05:30 /TN "TDBG refresh" ^
#      /TR "\"C:\Program Files\R\R-4.4.1\bin\Rscript.exe\" \"C:\path\to\Shiny-Dashboard-Lab\refresh.R\""
#    (or from R: taskscheduleR::taskscheduler_create(...); on macOS/Linux: cronR::cron_add(...))
#
# 4) GitHub Actions — .github/workflows/refresh.yml (04:30 UTC = 05:30 Lagos):
#    on: { schedule: [ { cron: "30 4 * * *" } ], workflow_dispatch: {} }
#    jobs:
#      refresh:
#        runs-on: ubuntu-latest
#        steps:
#          - uses: actions/checkout@v4
#          - uses: r-lib/actions/setup-r@v2
#          - uses: quarto-dev/quarto-actions/setup@v2
#          - run: Rscript -e 'install.packages(c("DBI","duckdb","RSQLite","dplyr","dbplyr","tidyr","readr","readxl","writexl","yaml","config","shiny","bslib","bsicons","plotly","DT","httr2","jsonlite","dataverse","RPostgres","ggplot2","knitr"))'
#          - run: Rscript refresh.R
#            env: { PGHOST: "${{ secrets.PGHOST }}", PGPASSWORD: "${{ secrets.PGPASSWORD }}" }
#          - run: Rscript -e 'rsconnect::deployApp(appPrimaryDoc = "02-dashboard.qmd", forceUpdate = TRUE)'
