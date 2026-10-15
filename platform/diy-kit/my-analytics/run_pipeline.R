# =============================================================================
# run_pipeline.R: one command from raw data to a published warehouse
#
#   Rscript run_pipeline.R                 full run: bronze -> silver -> gold -> tests -> gate -> publish
#   Rscript run_pipeline.R --to=bronze     stop after a stage (bronze | silver | gold | test)
#
# Partial runs write data/db/dev.duckdb for you to inspect; the live warehouse is untouched.
# A full run builds a fresh copy, tests it, and swaps it in ONLY if the gate passes.
# Every run rewrites ai_context.md, the file you attach to your prompts.
# =============================================================================
source("R/platform.R")
args  <- commandArgs(trailingOnly = TRUE)
to_arg <- grep("^--to=", args, value = TRUE)
to    <- if (length(to_arg)) sub("^--to=", "", to_arg[1]) else "publish"
stages <- c("bronze", "silver", "gold", "test", "publish")
if (!to %in% stages) stop("--to must be one of: ", paste(stages, collapse = ", "))
upto  <- function(s) match(s, stages) <= match(to, stages)

cfg     <- kit_config()
sources <- read_yaml_or(cfg$sources)
live    <- file.path(cfg$db_dir, "warehouse.duckdb")
build   <- file.path(cfg$db_dir, "warehouse.building.duckdb")
lock    <- file.path(cfg$db_dir, ".lock")

# ---- one run at a time ---------------------------------------------------------
if (file.exists(lock) && difftime(Sys.time(), file.mtime(lock), units = "hours") < 2)
  stop("Another run is in progress (", lock, "). Delete the file if you are sure it is not.")
writeLines(as.character(Sys.getpid()), lock)          # removed at the end of the run

.run$id <- format(Sys.time(), "%Y%m%d-%H%M%S")
t_start <- Sys.time()
message(sprintf("Run %s  (stages up to: %s)", .run$id, to))
unlink(c(build, paste0(build, ".wal")))
con <- connect(build)

status <- "ok"; ok <- TRUE; res <- NULL
step <- function(name, expr) {
  if (!upto(name)) return(invisible())
  message("== ", toupper(name))
  tryCatch(expr, error = function(e) { status <<- paste(name, "failed:", conditionMessage(e)); ok <<- FALSE })
}
step("bronze", { ingest_files(con, cfg, sources); ingest_sources(con, cfg, sources) })
if (ok) step("silver", run_sql_dir(con, "sql/silver", "silver"))
if (ok) step("gold",   run_sql_dir(con, "sql/gold", "gold"))
if (ok) step("test", {
  tests <- read_yaml_or(cfg$tests, list())
  res <- run_tests(con, tests, cfg)
  if (nrow(res)) message(paste(sprintf("  %-5s %-72s %s failing", res$status, substr(res$test, 1, 72),
                                        ifelse(is.na(res$failures), "?", format(res$failures, big.mark = ","))), collapse = "\n"))
  else message("  (no tests yet)")
  if (!gate(res)) { ok <- FALSE; status <- sprintf("gate closed: %d test(s) failed", sum(res$status %in% c("FAIL", "ERROR"))) }
})
write_ai_context(con, cfg)
disconnect(con)

# ---- swap, publish, record ---------------------------------------------------------
secs <- round(as.numeric(difftime(Sys.time(), t_start, units = "secs")), 1)
if (to != "publish") {
  dev <- file.path(cfg$db_dir, "dev.duckdb"); unlink(dev); file.rename(build, dev)
  message(sprintf("Partial run finished in %ss: %s. Inspect %s (the live warehouse was not touched).", secs, status, dev))
} else if (ok) {
  unlink(c(live, paste0(live, ".wal"))); file.rename(build, live)        # the atomic swap
  n <- publish_sqlite(live, file.path(cfg$serve_dir, "mart.sqlite"))
  message(sprintf("PUBLISHED in %ss: %s is live; %d gold objects copied to %s/mart.sqlite", secs, live, n, cfg$serve_dir))
} else {
  failed <- file.path(cfg$db_dir, "warehouse.failed.duckdb"); unlink(failed); file.rename(build, failed)
  alert(cfg, sprintf("%s: %s. Yesterday's warehouse stays live. Inspect %s.", cfg$project, status, failed))
}
hist <- file.path(cfg$log_dir, "run_history.csv")
utils::write.table(data.frame(run_id = .run$id, finished_at = format(Sys.time()), stages = to,
                              published = (to == "publish" && ok), seconds = secs, status = status),
                   hist, sep = ",", row.names = FALSE, append = file.exists(hist), col.names = !file.exists(hist))
unlink(lock)
if (!ok) quit(status = 1)
