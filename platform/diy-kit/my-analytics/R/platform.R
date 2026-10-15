# =============================================================================
# R/platform.R: the engine of the DIY starter kit
# (Appendix F of "The Governed Analytics Platform")
#
# You normally never edit this file. You change what the platform does by
# editing plain files:
#   data/raw/            drop CSV, TSV, Excel, Parquet and JSON files here
#   sources.yml          databases and web APIs to pull from, and per-file read options
#   sql/silver/*.sql     cleaning rules (one file per table, run in name order)
#   sql/gold/*.sql       decision-ready tables (facts, dimensions, marts)
#   tests/tests.yml      the data tests that form the publish gate
#   semantic/metrics.yml the metric definitions the dashboard uses
#
# Layers: bronze (as delivered, with lineage) -> silver (true) -> gold (decide)
#         -> tests -> gate -> publish (warehouse swap + SQLite serving mart)
# =============================================================================
suppressPackageStartupMessages({
  library(DBI); library(duckdb); library(yaml)
})

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a

# ---- configuration -----------------------------------------------------------
kit_config <- function(profile = Sys.getenv("R_CONFIG_ACTIVE", "default")) {
  cfg <- config::get(file = "config.yml", config = profile)
  for (d in c(cfg$raw_dir, cfg$db_dir, cfg$serve_dir, cfg$log_dir))
    dir.create(d, showWarnings = FALSE, recursive = TRUE)
  cfg
}
read_yaml_or <- function(path, default = list()) {
  if (!file.exists(path)) return(default)
  y <- yaml::read_yaml(path, fileEncoding = "UTF-8")
  y %||% default
}

# ---- connections -------------------------------------------------------------
connect <- function(path, read_only = FALSE) {
  con <- suppressMessages(dbConnect(duckdb::duckdb(), dbdir = path, read_only = read_only))
  if (!read_only)
    for (s in c("bronze", "silver", "gold", "ops")) dbExecute(con, sprintf("CREATE SCHEMA IF NOT EXISTS %s", s))
  con
}
disconnect <- function(con) try(dbDisconnect(con, shutdown = TRUE), silent = TRUE)
sq <- function(x) paste0("'", gsub("'", "''", x), "'")          # SQL string literal
clean_name <- function(x) {
  x <- tolower(gsub("[^A-Za-z0-9]+", "_", x)); x <- gsub("^_+|_+$", "", x)
  ifelse(grepl("^[0-9]", x), paste0("t_", x), x)
}

# ---- logging -----------------------------------------------------------------
.run <- new.env()
log_step <- function(con, step, object, rows = NA, seconds = NA, status = "ok", detail = "") {
  dbExecute(con, "CREATE TABLE IF NOT EXISTS ops.run_log (run_id VARCHAR, logged_at TIMESTAMP, step VARCHAR,
                   object VARCHAR, rows BIGINT, seconds DOUBLE, status VARCHAR, detail VARCHAR)")
  dbExecute(con, "INSERT INTO ops.run_log VALUES (?, current_timestamp, ?, ?, ?, ?, ?, ?)",
            params = list(.run$id %||% "manual", step, object, as.numeric(rows), as.numeric(seconds), status, detail))
  message(sprintf("  %-7s %-40s %10s rows  %5.1fs  %s", step, object,
                  ifelse(is.na(rows), "-", format(rows, big.mark = ",")), ifelse(is.na(seconds), 0, seconds), status))
}
alert <- function(cfg, text) {
  cat(format(Sys.time()), text, "\n", file = file.path(cfg$log_dir, "alerts.log"), append = TRUE)
  url <- Sys.getenv(cfg$alert_webhook_env %||% "ALERT_WEBHOOK_URL")
  if (nzchar(url)) try(httr2::req_perform(httr2::req_body_json(httr2::request(url), list(text = text))), silent = TRUE)
  message("ALERT: ", text)
}

# ---- BRONZE: files -------------------------------------------------------------
# Every file in data/raw (and its sub-folders) becomes one bronze table per file
# (one per sheet for Excel). Values are kept as delivered: CSV and Excel as text.
# Lineage columns: _source_file, _row (position in the file), _loaded_at.
file_options <- function(sources, rel) {
  opts <- sources$files %||% list()
  for (pat in names(opts)) if (rel == pat || grepl(glob2rx(pat), rel)) return(opts[[pat]])
  list()
}
add_lineage <- function(df, rel) {
  df[] <- lapply(df, function(x) if (inherits(x, c("Date", "POSIXt"))) format(x) else x)
  df$`_source_file` <- rel; df$`_row` <- seq_len(nrow(df)); df$`_loaded_at` <- Sys.time()
  df
}
write_bronze <- function(con, table, df) {
  dbWriteTable(con, DBI::Id(schema = "bronze", table = table), df, overwrite = TRUE)
  nrow(df)
}
ingest_file <- function(con, path, rel, opts = list()) {
  ext <- tolower(tools::file_ext(path)); base <- opts$table %||% clean_name(tools::file_path_sans_ext(basename(path)))
  t0 <- Sys.time(); out <- list()
  if (ext %in% c("csv", "tsv", "txt")) {
    delim <- opts$delim %||% if (ext == "tsv") "\t" else ","
    sql <- sprintf("CREATE OR REPLACE TABLE bronze.%s AS SELECT *, %s AS _source_file, row_number() OVER () AS _row,
                    current_timestamp AS _loaded_at FROM read_csv(%s, all_varchar = true, header = %s, delim = %s,
                    skip = %d, sample_size = -1, null_padding = true)",
                   base, sq(rel), sq(path), tolower(as.character(opts$header %||% TRUE)), sq(delim), as.integer(opts$skip %||% 0))
    ok <- tryCatch({ dbExecute(con, sql); TRUE }, error = function(e) FALSE)
    if (!ok) {   # e.g. not UTF-8 (Excel "CSV (Comma delimited)"): read with R in the stated encoding
      df <- utils::read.csv(path, colClasses = "character", sep = delim, skip = opts$skip %||% 0,
                            fileEncoding = opts$encoding %||% "latin1", check.names = FALSE, na.strings = "")
      write_bronze(con, base, add_lineage(df, rel))
    }
    out[[base]] <- dbGetQuery(con, sprintf("SELECT COUNT(*) n FROM bronze.%s", base))$n
  } else if (ext %in% c("xlsx", "xls", "xlsm")) {
    sheets <- opts$sheets %||% readxl::excel_sheets(path)
    for (sh in sheets) {
      df <- readxl::read_excel(path, sheet = sh, col_types = "text", skip = opts$skip %||% 0,
                               col_names = opts$header %||% TRUE, .name_repair = "unique_quiet")
      if (!nrow(df)) next
      tbl <- if (length(sheets) > 1 || isTRUE(opts$sheet_suffix)) paste0(base, "__", clean_name(sh)) else base
      out[[tbl]] <- write_bronze(con, tbl, add_lineage(as.data.frame(df), paste0(rel, "#", sh)))
    }
  } else if (ext == "parquet") {
    dbExecute(con, sprintf("CREATE OR REPLACE TABLE bronze.%s AS SELECT *, %s AS _source_file, row_number() OVER () AS _row,
                            current_timestamp AS _loaded_at FROM read_parquet(%s)", base, sq(rel), sq(path)))
    out[[base]] <- dbGetQuery(con, sprintf("SELECT COUNT(*) n FROM bronze.%s", base))$n
  } else if (ext == "json") {
    j <- jsonlite::fromJSON(path, flatten = TRUE)
    if (!is.null(opts$pick)) j <- j[[opts$pick]]
    df <- as.data.frame(j); df[] <- lapply(df, function(x) if (is.list(x)) vapply(x, jsonlite::toJSON, "", auto_unbox = TRUE) else as.character(x))
    names(df) <- gsub("[^A-Za-z0-9_]+", "_", names(df))      # nested JSON fields: a.b -> a_b
    out[[base]] <- write_bronze(con, base, add_lineage(df, rel))
  } else return(invisible(NULL))
  secs <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  for (tbl in names(out)) {
    dbExecute(con, "INSERT INTO ops.load_manifest VALUES (?, ?, ?, ?, ?, current_timestamp)",
              params = list(rel, tbl, unname(tools::md5sum(path)), as.numeric(out[[tbl]]), file.size(path)))
    log_step(con, "bronze", paste0("bronze.", tbl), out[[tbl]], secs / length(out))
  }
}
ingest_files <- function(con, cfg, sources) {
  dbExecute(con, "CREATE TABLE IF NOT EXISTS ops.load_manifest (source VARCHAR, tbl VARCHAR, md5 VARCHAR,
                   rows BIGINT, bytes BIGINT, loaded_at TIMESTAMP)")
  files <- list.files(cfg$raw_dir, recursive = TRUE, full.names = TRUE)
  files <- files[!grepl("(^|/)(~\\$|\\.|_api_cache/)", files) & tolower(tools::file_ext(files)) %in%
                   c("csv", "tsv", "txt", "xlsx", "xls", "xlsm", "parquet", "json")]
  if (!length(files)) message("  (no files in ", cfg$raw_dir, ")")
  seen <- character()
  for (f in files) {
    rel <- sub(paste0("^", normalizePath(cfg$raw_dir), "/?"), "", normalizePath(f))
    opts <- file_options(sources, rel)
    if (isTRUE(opts$skip_file)) next
    stem <- clean_name(tools::file_path_sans_ext(basename(f)))
    if (is.null(opts$table) && stem %in% seen) opts$table <- clean_name(tools::file_path_sans_ext(rel))
    seen <- c(seen, stem)
    tryCatch(ingest_file(con, f, rel, opts),
             error = function(e) log_step(con, "bronze", rel, NA, NA, "ERROR", conditionMessage(e)))
  }
}

# ---- BRONZE: databases and APIs (from sources.yml) ----------------------------
db_connect_source <- function(s) {
  env <- function(k) if (!is.null(s[[k]])) Sys.getenv(s[[k]]) else NULL
  switch(s$driver,
    sqlite   = dbConnect(RSQLite::SQLite(), s$path),
    duckdb   = suppressMessages(dbConnect(duckdb::duckdb(), s$path, read_only = TRUE)),
    postgres = dbConnect(RPostgres::Postgres(), host = s$host %||% env("host_env"), port = s$port %||% 5432,
                         dbname = s$dbname, user = env("user_env"), password = env("password_env")),
    odbc     = if (!is.null(s$dsn)) dbConnect(odbc::odbc(), dsn = s$dsn, uid = env("user_env"), pwd = env("password_env"))
               else dbConnect(odbc::odbc(), .connection_string = Sys.getenv(s$connection_string_env)),
    stop("unknown driver: ", s$driver))
}
ingest_database <- function(con, s) {
  src <- db_connect_source(s); on.exit(try(dbDisconnect(src), silent = TRUE))
  qs <- s$queries %||% list()
  for (t in unlist(s$tables)) qs[[t]] <- sprintf("SELECT * FROM %s", t)
  for (nm in names(qs)) {
    t0 <- Sys.time(); tbl <- clean_name(paste(s$name, nm, sep = "_"))
    df <- dbGetQuery(src, qs[[nm]])
    n <- write_bronze(con, tbl, add_lineage(df, paste0(s$name, ":", nm)))
    dbExecute(con, "INSERT INTO ops.load_manifest VALUES (?, ?, NULL, ?, NULL, current_timestamp)",
              params = list(paste0(s$name, ":", nm), tbl, n))
    log_step(con, "bronze", paste0("bronze.", tbl), n, as.numeric(difftime(Sys.time(), t0, units = "secs")))
  }
}
ingest_api <- function(con, s, cfg) {
  t0 <- Sys.time(); tbl <- clean_name(s$name)
  cache <- file.path(cfg$raw_dir, "_api_cache", paste0(tbl, ".", s$format %||% "json"))
  dir.create(dirname(cache), showWarnings = FALSE, recursive = TRUE)
  status <- "ok"
  got <- tryCatch({
    req <- httr2::request(s$url) |> httr2::req_timeout(60) |> httr2::req_retry(max_tries = 3)
    hdr <- lapply(s$headers %||% list(), Sys.getenv)          # header values come from .Renviron
    if (length(hdr)) req <- httr2::req_headers(req, !!!hdr)
    writeBin(httr2::resp_body_raw(httr2::req_perform(req)), cache); TRUE
  }, error = function(e) FALSE)
  if (!got) { if (!file.exists(cache)) stop("API failed and no cache for ", s$name); status <- "ok (cached copy)" }
  df <- if ((s$format %||% "json") == "csv") utils::read.csv(cache, colClasses = "character", check.names = FALSE) else {
    j <- jsonlite::fromJSON(cache, flatten = TRUE); if (!is.null(s$pick)) j <- j[[s$pick]]; as.data.frame(j) }
  df[] <- lapply(df, function(x) if (is.list(x)) vapply(x, jsonlite::toJSON, "", auto_unbox = TRUE) else as.character(x))
  names(df) <- gsub("[^A-Za-z0-9_]+", "_", names(df))        # nested JSON fields: a.b -> a_b
  n <- write_bronze(con, tbl, add_lineage(df, paste0("api:", s$name)))
  dbExecute(con, "INSERT INTO ops.load_manifest VALUES (?, ?, ?, ?, ?, current_timestamp)",
            params = list(paste0("api:", s$name), tbl, unname(tools::md5sum(cache)), n, file.size(cache)))
  log_step(con, "bronze", paste0("bronze.", tbl), n, as.numeric(difftime(Sys.time(), t0, units = "secs")), status)
}
ingest_sources <- function(con, cfg, sources) {
  for (s in sources$databases %||% list())
    tryCatch(ingest_database(con, s), error = function(e) log_step(con, "bronze", s$name, NA, NA, "ERROR", conditionMessage(e)))
  for (s in sources$apis %||% list())
    tryCatch(ingest_api(con, s, cfg), error = function(e) log_step(con, "bronze", s$name, NA, NA, "ERROR", conditionMessage(e)))
}

# ---- SILVER and GOLD: run every .sql file in a folder, in name order ------------
run_sql_dir <- function(con, dir, layer) {
  files <- sort(list.files(dir, pattern = "\\.sql$", full.names = TRUE))
  if (!length(files)) message("  (no SQL files in ", dir, " yet)")
  for (f in files) {
    t0 <- Sys.time()
    sql <- paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
    before <- dbGetQuery(con, sprintf("SELECT table_name FROM information_schema.tables WHERE table_schema = %s", sq(layer)))$table_name
    res <- tryCatch({ dbExecute(con, sql); "ok" }, error = function(e) paste("ERROR:", conditionMessage(e)))
    made <- setdiff(dbGetQuery(con, sprintf("SELECT table_name FROM information_schema.tables WHERE table_schema = %s", sq(layer)))$table_name, before)
    rows <- if (length(made) == 1) dbGetQuery(con, sprintf("SELECT COUNT(*) n FROM %s.%s", layer, made))$n else NA
    log_step(con, layer, paste0(basename(f), if (length(made)) paste0(" -> ", paste(made, collapse = ", ")) else ""),
             rows, as.numeric(difftime(Sys.time(), t0, units = "secs")), if (res == "ok") "ok" else "ERROR", res)
    if (res != "ok") stop(basename(f), " failed: ", sub("^ERROR: ", "", res), call. = FALSE)
  }
}

# ---- TESTS and the GATE --------------------------------------------------------
# Each test is SQL that returns ONE number: how many rows break the rule (0 = pass).
test_sql <- function(t) {
  w <- function(cond) sprintf("SELECT COUNT(*) FROM %s WHERE %s", t[["table"]], cond)
  switch(t[["type"]],
    unique       = sprintf("SELECT COUNT(*) FROM (SELECT %s FROM %s GROUP BY ALL HAVING COUNT(*) > 1)", paste(t[["columns"]], collapse = ", "), t[["table"]]),
    not_null     = w(sprintf("%s IS NULL", t[["column"]])),
    accepted     = w(sprintf("%s IS NOT NULL AND CAST(%s AS VARCHAR) NOT IN (%s)", t[["column"]], t[["column"]], paste(sq(unlist(t[["values"]])), collapse = ", "))),
    range        = w(paste(c(if (!is.null(t[["min"]])) sprintf("%s < %s", t[["column"]], t[["min"]]), if (!is.null(t[["max"]])) sprintf("%s > %s", t[["column"]], t[["max"]])), collapse = " OR ")),
    relationship = sprintf("SELECT COUNT(*) FROM %s a WHERE a.%s IS NOT NULL AND NOT EXISTS (SELECT 1 FROM %s b WHERE b.%s = a.%s)",
                           t[["table"]], t[["column"]], t[["ref_table"]], t[["ref_column"]] %||% t[["column"]], t[["column"]]),
    fresh        = sprintf("SELECT CASE WHEN MAX(CAST(%s AS DATE)) >= CAST(%s AS DATE) - INTERVAL %d DAY THEN 0 ELSE 1 END FROM %s",
                           t[["column"]], if (!is.null(t[["as_of"]])) sq(t[["as_of"]]) else "current_date", as.integer(t[["max_days"]]), t[["table"]]),
    rowcount     = sprintf("SELECT CASE WHEN COUNT(*) >= %s THEN 0 ELSE 1 END FROM %s", t[["min"]], t[["table"]]),
    custom       = t[["sql"]],
    stop("unknown test type: ", t[["type"]]))
}
test_name <- function(t) t[["name"]] %||% sprintf("%s(%s%s)", t[["type"]], t[["table"]],
  if (!is.null(t[["column"]])) paste0(".", t[["column"]]) else if (!is.null(t[["columns"]])) paste0(": ", paste(t[["columns"]], collapse = "+")) else "")
run_tests <- function(con, tests, cfg) {
  dbExecute(con, "CREATE TABLE IF NOT EXISTS ops.test_log (run_id VARCHAR, run_at TIMESTAMP, test VARCHAR,
                   severity VARCHAR, failures BIGINT, status VARCHAR, detail VARCHAR)")
  res <- do.call(rbind, lapply(tests, function(t) {
    sev <- t$severity %||% "error"
    out <- tryCatch(list(n = as.numeric(dbGetQuery(con, test_sql(t))[[1]]), d = ""),
                    error = function(e) list(n = NA, d = conditionMessage(e)))
    status <- if (is.na(out$n)) "ERROR" else if (out$n == 0) "PASS" else if (sev == "warn") "WARN" else "FAIL"
    data.frame(run_id = .run$id %||% "manual", run_at = Sys.time(), test = test_name(t), severity = sev,
               failures = out$n, status = status, detail = substr(out$d, 1, 300))
  }))
  if (is.null(res)) res <- data.frame(run_id = character(), run_at = as.POSIXct(character()), test = character(),
                                      severity = character(), failures = numeric(), status = character(), detail = character())
  if (nrow(res)) dbWriteTable(con, DBI::Id(schema = "ops", table = "test_log"), res, append = TRUE)
  hist <- file.path(cfg$log_dir, "test_history.csv")
  utils::write.table(res, hist, sep = ",", row.names = FALSE, append = file.exists(hist), col.names = !file.exists(hist))
  res
}
gate <- function(res) !any(res$status %in% c("FAIL", "ERROR"))

# ---- PUBLISH: serving mart -------------------------------------------------------
publish_sqlite <- function(db_path, out) {
  con <- connect(db_path, read_only = TRUE); on.exit(disconnect(con))
  objs <- dbGetQuery(con, "SELECT table_name FROM information_schema.tables WHERE table_schema = 'gold'")$table_name
  tmp <- paste0(out, ".tmp"); unlink(tmp)
  lite <- dbConnect(RSQLite::SQLite(), tmp)
  for (o in objs) {
    df <- dbGetQuery(con, sprintf("SELECT * FROM gold.%s", o))
    df[] <- lapply(df, function(x) if (inherits(x, c("Date", "POSIXt"))) format(x) else x)
    dbWriteTable(lite, o, df, overwrite = TRUE)
  }
  dbDisconnect(lite); file.rename(tmp, out)
  length(objs)
}

# ---- SEMANTIC LAYER: compile governed metric SQL --------------------------------
read_metrics <- function(path = "semantic/metrics.yml") read_yaml_or(path, list(model = list(), metrics = list()))
metric_sql <- function(M, metrics, dims = character(), grain = NULL, where = NULL) {
  time <- M$model$time
  sel <- c(if (!is.null(grain)) sprintf("CAST(date_trunc('%s', CAST(%s AS DATE)) AS DATE) AS period", grain, time),
           dims, sprintf("%s AS %s", vapply(metrics, function(m) M$metrics[[m]]$sql, ""), metrics))
  grp <- c(if (!is.null(grain)) "period", dims)
  sprintf("SELECT %s FROM %s%s%s%s", paste(sel, collapse = ", "), M$model$table,
          if (length(where)) paste0(" WHERE ", paste(where, collapse = " AND ")) else "",
          if (length(grp)) paste0(" GROUP BY ", paste(grp, collapse = ", ")) else "",
          if (length(grp)) paste0(" ORDER BY ", paste(grp, collapse = ", ")) else "")
}

# ---- AI CONTEXT: what you attach to every prompt -----------------------------------
# Writes ai_context.md: your brief, every table with its columns, null %, distinct
# counts, ranges and (optionally) a few example values, plus tests and metrics.
# It contains NO full rows. Set ai_context_samples: false in config.yml if the
# data holds personal information, so not even example values are included.
write_ai_context <- function(con, cfg, out = "ai_context.md") {
  L <- c("# AI context for this project", "",
         "Attach this file to every prompt. It describes the data. It contains no full records.", "")
  if (file.exists("brief.md")) L <- c(L, "## Project brief", "", readLines("brief.md", warn = FALSE), "")
  tabs <- dbGetQuery(con, "SELECT table_schema s, table_name t, table_type ty FROM information_schema.tables
                           WHERE table_schema IN ('bronze','silver','gold') ORDER BY 1, 2")
  for (i in seq_len(nrow(tabs))) {
    full <- paste0(tabs$s[i], ".", tabs$t[i])
    n <- dbGetQuery(con, sprintf("SELECT COUNT(*) n FROM %s", full))$n
    L <- c(L, sprintf("## `%s` (%s, %s rows)", full, tolower(tabs$ty[i]), format(n, big.mark = ",")), "")
    prof <- tryCatch(dbGetQuery(con, sprintf("SUMMARIZE %s", full)), error = function(e) NULL)
    if (is.null(prof)) next
    prof <- utils::head(prof, 60)
    L <- c(L, "| column | type | null % | ≈ distinct | min | max |", "|---|---|---|---|---|---|")
    for (j in seq_len(nrow(prof))) {
      cut <- function(x) { x <- gsub("\\|", "/", substr(as.character(x %||% ""), 1, 40)); ifelse(is.na(x), "", x) }
      L <- c(L, sprintf("| %s | %s | %s | %s | %s | %s |", prof$column_name[j], prof$column_type[j],
                        round(as.numeric(prof$null_percentage[j]), 1), prof$approx_unique[j], cut(prof$min[j]), cut(prof$max[j])))
    }
    if (isTRUE(cfg$ai_context_samples) && tabs$s[i] == "bronze") {
      ex <- tryCatch(dbGetQuery(con, sprintf("SELECT * EXCLUDE (_source_file, _row, _loaded_at) FROM %s USING SAMPLE 3 ROWS", full)),
                     error = function(e) NULL)
      if (!is.null(ex) && nrow(ex)) {
        ex <- utils::head(ex[, seq_len(min(12, ncol(ex))), drop = FALSE], 3)
        L <- c(L, "", "Example values (3 random rows, first 12 columns):", "", "```",
               { op <- options(width = 250); on.exit(options(op)); utils::capture.output(print(ex, row.names = FALSE)) }, "```")
      }
    }
    L <- c(L, "")
  }
  if (nrow(dbGetQuery(con, "SELECT 1 FROM information_schema.tables WHERE table_schema = 'ops' AND table_name = 'test_log'"))) {
    tl <- dbGetQuery(con, "SELECT test, severity, failures, status FROM ops.test_log WHERE run_id = (SELECT MAX(run_id) FROM ops.test_log)")
    if (nrow(tl)) L <- c(L, "## Latest test results", "", "```", utils::capture.output(print(tl, row.names = FALSE)), "```", "")
  }
  if (file.exists("semantic/metrics.yml")) L <- c(L, "## semantic/metrics.yml", "", "```yaml", readLines("semantic/metrics.yml", warn = FALSE), "```", "")
  for (d in c("sql/silver", "sql/gold")) {
    fs <- list.files(d, pattern = "\\.sql$")
    if (length(fs)) L <- c(L, sprintf("## Existing SQL in %s", d), "", paste0("- ", fs), "")
  }
  writeLines(L, out, useBytes = TRUE)
  invisible(out)
}
