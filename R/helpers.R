# ===========================================================================
# R/helpers.R — shared plumbing for the notebook (01) and the dashboard (02)
#
# PROMPT that generated this file:
#   "Write an R helper file for a Quarto Shiny dashboard that can read the same
#    sales data from CSV, Excel, Parquet, SQLite, DuckDB and PostgreSQL. Read
#    every path from config.yml with the config package. Give me: (1) one
#    function get_sales(source, filters) that returns the same columns whatever
#    the source, pushing filters down to the database when there is one;
#    (2) short-lived read-only DuckDB connections so a rebuild can replace the
#    file while the dashboard is running; (3) a compiler that turns metric
#    names from semantic/metrics.yml into SQL; (4) a tiny TF-IDF embedder for
#    semantic search; (5) safe execution of user SQL (SELECT only). Comment it
#    for MBA students."
# ===========================================================================

suppressPackageStartupMessages({
  library(DBI)
  library(duckdb)
  library(RSQLite)
  library(dplyr)
  library(readr)
  library(readxl)
  library(yaml)
})

`%||%` <- function(a, b) if (is.null(a)) b else a   # built into R >= 4.4

# ---- 1. Configuration ------------------------------------------------------
PROJECT_DIR <- normalizePath(getwd())
cfg <- config::get(file = file.path(PROJECT_DIR, "config.yml"))

# Resolve a path from config.yml: "~/..." and "/..." are absolute,
# everything else is relative to the project folder.
proj_path <- function(p) {
  if (grepl("^(~|/|[A-Za-z]:)", p)) path.expand(p) else file.path(PROJECT_DIR, p)
}

# ---- 2. Connections --------------------------------------------------------
# DuckDB allows one writer OR many readers. The dashboard therefore opens a
# read-only connection for each query and closes it straight after, so the
# nightly rebuild (refresh.R) can swap in a fresh warehouse file at any time.
with_duck <- function(fun, path = proj_path(cfg$duckdb_path)) {
  con <- dbConnect(duckdb::duckdb(), dbdir = path, read_only = TRUE)
  on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)
  fun(con)
}

with_sqlite <- function(fun, path = proj_path(cfg$sqlite_path)) {
  con <- dbConnect(RSQLite::SQLite(), path, flags = RSQLite::SQLITE_RO)
  on.exit(dbDisconnect(con), add = TRUE)
  fun(con)
}

pg_available <- function() nzchar(Sys.getenv(cfg$postgres$enabled_if_env))

with_postgres <- function(fun) {
  con <- dbConnect(
    RPostgres::Postgres(),
    host = Sys.getenv("PGHOST"), port = as.integer(Sys.getenv("PGPORT", "5432")),
    dbname = Sys.getenv("PGDATABASE"), user = Sys.getenv("PGUSER"),
    password = Sys.getenv("PGPASSWORD")
  )
  on.exit(dbDisconnect(con), add = TRUE)
  fun(con)
}

# ---- 3. One fact table, many sources ---------------------------------------
# Every source must return exactly these columns, so the dashboard code below
# never needs to know where the data came from.
SALES_COLS <- c("week_starting", "depot_code", "depot_name", "region", "state",
                "sku", "product_name", "category", "pack_size",
                "units_sold", "revenue_ngn", "gross_profit_ngn",
                "on_promotion", "discount_pct", "stockout_flag")

# Cleaning rules, written once (see notebook Step 4 for why each exists):
#   - exact duplicate rows are dropped
#   - a stockout week is recorded as blank, so blank units/revenue -> 0
#   - a dimension key that appears twice (DP04 was renamed and re-added)
#     keeps its first, original row
#   - gross profit = revenue - units x standard unit cost
clean_sales <- function(sell_out, products, depots) {
  products <- distinct(products, sku, .keep_all = TRUE)
  depots   <- distinct(depots, depot_code, .keep_all = TRUE)
  sell_out |>
    distinct() |>
    distinct(week_starting, depot_code, sku, .keep_all = TRUE) |>
    mutate(units_sold  = coalesce(units_sold, 0),
           revenue_ngn = coalesce(revenue_ngn, 0)) |>
    inner_join(products, by = "sku") |>
    inner_join(depots,   by = "depot_code") |>
    mutate(week_starting    = as.Date(week_starting),
           gross_profit_ngn = revenue_ngn - units_sold * unit_cost_ngn) |>
    select(all_of(SALES_COLS))
}

SOURCES <- c(
  "CSV files"          = "csv",
  "Excel workbook"     = "excel",
  "Parquet file"       = "parquet",
  "SQLite database"    = "sqlite",
  "DuckDB warehouse"   = "duckdb",
  "PostgreSQL server"  = "postgres"
)

source_available <- function(src) {
  switch(src,
    csv      = file.exists(file.path(proj_path(cfg$csv_dir), "fmcg_sell_out.csv")),
    excel    = file.exists(proj_path(cfg$excel_path)),
    parquet  = file.exists(proj_path(cfg$parquet_path)),
    sqlite   = file.exists(proj_path(cfg$sqlite_path)),
    duckdb   = file.exists(proj_path(cfg$duckdb_path)),
    postgres = pg_available(),
    FALSE)
}

# Apply the sidebar filters. Works on an in-memory data frame AND on a lazy
# database table (dbplyr translates it to a SQL WHERE clause).
apply_filters <- function(x, f) {
  if (!is.null(f$dates)) {
    d1 <- as.character(f$dates[1]); d2 <- as.character(f$dates[2])
    x <- x |> filter(week_starting >= d1, week_starting <= d2)
  }
  if (length(f$regions))    x <- x |> filter(region   %in% !!f$regions)
  if (length(f$categories)) x <- x |> filter(category %in% !!f$categories)
  if (identical(f$promo, "promo"))   x <- x |> filter(on_promotion == 1)
  if (identical(f$promo, "nopromo")) x <- x |> filter(on_promotion == 0)
  x
}

# The single entry point the dashboard calls.
get_sales <- function(source = "duckdb", filters = list()) {
  out <- switch(source,
    csv = {
      d <- proj_path(cfg$csv_dir)
      clean_sales(read_csv(file.path(d, "fmcg_sell_out.csv"), show_col_types = FALSE),
                  read_csv(file.path(d, "fmcg_products.csv"), show_col_types = FALSE),
                  read_csv(file.path(d, "fmcg_depots.csv"),   show_col_types = FALSE)) |>
        apply_filters(filters)
    },
    excel = {
      p <- proj_path(cfg$excel_path)
      clean_sales(read_excel(p, "sales"), read_excel(p, "products"), read_excel(p, "depots")) |>
        apply_filters(filters)
    },
    parquet = {
      # Parquet is read through an in-memory DuckDB: no import step at all.
      con <- dbConnect(duckdb::duckdb())
      on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)
      tbl(con, sql(sprintf("SELECT * FROM read_parquet('%s')", proj_path(cfg$parquet_path)))) |>
        mutate(units_sold = coalesce(units_sold, 0), revenue_ngn = coalesce(revenue_ngn, 0),
               gross_profit_ngn = coalesce(gross_profit_ngn, 0)) |>
        select(all_of(SALES_COLS)) |>
        apply_filters(filters) |>
        collect()
    },
    sqlite   = with_sqlite(function(con)   tbl(con, "v_sales") |> apply_filters(filters) |> collect()),
    duckdb   = with_duck(function(con)     tbl(con, "v_sales") |> apply_filters(filters) |> collect()),
    postgres = with_postgres(function(con) tbl(con, "v_sales") |> apply_filters(filters) |> collect()),
    stop("Unknown source: ", source)
  )
  out |> mutate(week_starting = as.Date(week_starting))
}

# ---- 4. Semantic layer -----------------------------------------------------
read_semantic <- function(path = proj_path(cfg$semantic_layer)) yaml::read_yaml(path, fileEncoding = "UTF-8")

# Turn metric + dimension names into SQL. Students read the SQL the dashboard
# shows them; nobody hand-writes "revenue" twice.
compile_metric_sql <- function(layer, metrics, dims = character(), grain = NULL,
                               where = NULL, limit = NULL) {
  stopifnot(all(metrics %in% names(layer$metrics)), all(dims %in% names(layer$dimensions)))
  sel <- character(); grp <- character()
  if (!is.null(grain) && grain != "none") {
    sel <- c(sel, sprintf("date_trunc('%s', %s) AS period", grain, layer$time_dimension))
    grp <- c(grp, "period")
  }
  for (d in dims) {
    sel <- c(sel, sprintf("%s AS %s", layer$dimensions[[d]]$column, d)); grp <- c(grp, d)
  }
  for (m in metrics) sel <- c(sel, sprintf("%s AS %s", layer$metrics[[m]]$sql, m))
  sql <- paste0("SELECT\n  ", paste(sel, collapse = ",\n  "), "\nFROM ", layer$table)
  if (length(where) && any(nzchar(where))) sql <- paste0(sql, "\nWHERE ", paste(where[nzchar(where)], collapse = " AND "))
  if (length(grp)) sql <- paste0(sql, "\nGROUP BY ", paste(grp, collapse = ", "),
                                 "\nORDER BY ", if ("period" %in% grp) "period" else paste(metrics[1], "DESC"))
  if (!is.null(limit)) sql <- paste0(sql, "\nLIMIT ", limit)
  sql
}

# Run semantic-layer SQL against ANY data frame: register it in a throw-away
# in-memory DuckDB as "v_sales". This is how CSV, Excel and Parquet data get
# exactly the same metric definitions as the databases.
query_frame <- function(df, sql) {
  con <- dbConnect(duckdb::duckdb())
  on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)
  duckdb::duckdb_register(con, "v_sales", df)
  dbGetQuery(con, sql)
}
semantic_frame <- function(df, metrics, dims = character(), grain = NULL, limit = NULL,
                           layer = read_semantic()) {
  query_frame(df, compile_metric_sql(layer, metrics, dims, grain, limit = limit))
}

fmt_metric <- function(x, format = "number") {
  if (length(x) == 0 || is.na(x)) return("—")
  switch(format,
    naira = if (abs(x) >= 1e9) sprintf("₦%.2fbn", x / 1e9) else if (abs(x) >= 1e6) sprintf("₦%.1fm", x / 1e6) else paste0("₦", formatC(x, format = "f", digits = 0, big.mark = ",")),
    pct   = sprintf("%.1f%%", x),
    formatC(x, format = "f", digits = 0, big.mark = ","))
}

# ---- 5. Semantic (vector) search -------------------------------------------
# A transparent, offline "embedding": TF-IDF over the review vocabulary.
# Swap embed_text() for a real sentence-embedding model later (notebook Step 12)
# and nothing else in the dashboard changes.
tokenize <- function(x) {
  x <- tolower(gsub("[^A-Za-z0-9 ]", " ", x))
  lapply(strsplit(x, "\\s+"), function(w) w[nchar(w) > 2])
}

embed_text <- function(texts, vocab) {
  toks <- tokenize(texts)
  t(vapply(toks, function(w) {
    v <- tabulate(match(w, vocab$term), nbins = nrow(vocab)) * vocab$idf
    n <- sqrt(sum(v^2)); if (n > 0) v / n else v
  }, numeric(nrow(vocab))))
}

semantic_search <- function(query, k = 15) {
  with_duck(function(con) {
    vocab <- dbGetQuery(con, "SELECT term, idf FROM review_vocab ORDER BY idx")
    q <- embed_text(query, vocab)[1, ]
    if (all(q == 0)) return(NULL)
    dbGetQuery(con, sprintf(
      "SELECT review_id, received_date, channel, star_rating, theme, sentiment,
              round(list_cosine_similarity(vec, %s::DOUBLE[]), 3) AS similarity, review_text
       FROM review_docs
       WHERE list_cosine_similarity(vec, %s::DOUBLE[]) > 0
       ORDER BY similarity DESC LIMIT %d",
      vec_literal(q), vec_literal(q), as.integer(k)))
  })
}
vec_literal <- function(v) paste0("[", paste(sprintf("%.6f", v), collapse = ","), "]")

# ---- 6. Safe user SQL ------------------------------------------------------
# Read-only connection + SELECT/WITH only + a row cap = students can't break it.
run_safe_sql <- function(sql, max_rows = 5000) {
  s <- trimws(gsub(";\\s*$", "", sql))
  if (!grepl("^(select|with)\\b", tolower(s))) stop("Only SELECT / WITH queries are allowed.")
  if (grepl(";", s)) stop("One statement at a time, please.")
  with_duck(function(con) dbGetQuery(con, sprintf("SELECT * FROM (%s) LIMIT %d", s, max_rows)))
}

# ---- 7. Optional LLM: natural language -> SQL over the semantic layer -------
llm_available <- function() {
  if (cfg$llm$provider == "anthropic") nzchar(Sys.getenv("ANTHROPIC_API_KEY")) else TRUE
}

llm_system_prompt <- function(layer = read_semantic()) {
  schema <- with_duck(function(con) dbGetQuery(con,
    "SELECT table_name, string_agg(column_name || ' ' || data_type, ', ') AS cols
       FROM information_schema.columns
      WHERE table_schema = 'main' AND table_name IN ('v_sales','marketing_spend','ng_macro_monthly','review_docs','dv_gdp')
      GROUP BY table_name"))
  metrics <- paste(sprintf("- %s = %s  -- %s", names(layer$metrics),
                           vapply(layer$metrics, `[[`, "", "sql"),
                           vapply(layer$metrics, `[[`, "", "description")), collapse = "\n")
  paste0(
    "You are a careful analytics engineer. Write ONE DuckDB SQL SELECT query that answers the user's question.\n",
    "Tables:\n", paste(sprintf("- %s(%s)", schema$table_name, schema$cols), collapse = "\n"),
    "\n\nAlways use these governed metric definitions when relevant:\n", metrics,
    "\n\nRules: SELECT only; no DDL/DML; at most 200 rows; readable aliases; revenue in NGN. ",
    "Return only the SQL inside a ```sql code block.")
}

ask_llm_for_sql <- function(question) {
  sys <- llm_system_prompt()
  if (cfg$llm$provider == "anthropic") {
    resp <- httr2::request("https://api.anthropic.com/v1/messages") |>
      httr2::req_headers(`x-api-key` = Sys.getenv("ANTHROPIC_API_KEY"),
                         `anthropic-version` = "2023-06-01") |>
      httr2::req_body_json(list(model = cfg$llm$anthropic_model, max_tokens = 800, system = sys,
                                messages = list(list(role = "user", content = question)))) |>
      httr2::req_perform() |> httr2::resp_body_json()
    txt <- resp$content[[1]]$text
  } else {
    resp <- httr2::request(paste0(cfg$llm$ollama_url, "/api/chat")) |>
      httr2::req_body_json(list(model = cfg$llm$ollama_model, stream = FALSE,
                                messages = list(list(role = "system", content = sys),
                                                list(role = "user", content = question)))) |>
      httr2::req_perform() |> httr2::resp_body_json()
    txt <- resp$message$content
  }
  m <- regmatches(txt, regexpr("(?s)```sql\\s*(.*?)```", txt, perl = TRUE))
  trimws(if (length(m)) gsub("(?s)```sql|```", "", m, perl = TRUE) else txt)
}

# ---- 8. Microsoft Dataverse (Web API / OData) ------------------------------
msdv_available <- function() all(nzchar(Sys.getenv(c("DATAVERSE_URL", "AZURE_TENANT_ID", "AZURE_CLIENT_ID", "AZURE_CLIENT_SECRET"))))

msdv_request <- function(path) {
  base <- sub("/$", "", Sys.getenv("DATAVERSE_URL"))
  client <- httr2::oauth_client(
    id = Sys.getenv("AZURE_CLIENT_ID"), secret = Sys.getenv("AZURE_CLIENT_SECRET"),
    token_url = sprintf("https://login.microsoftonline.com/%s/oauth2/v2.0/token", Sys.getenv("AZURE_TENANT_ID")))
  httr2::request(sprintf("%s/api/data/%s/%s", base, cfg$ms_dataverse$api_version, path)) |>
    httr2::req_oauth_client_credentials(client, scope = paste0(base, "/.default")) |>
    httr2::req_headers(Accept = "application/json", `OData-MaxVersion` = "4.0", `OData-Version` = "4.0")
}

msdv_read <- function(entity_set, select = NULL, top = 5000) {
  q <- paste0(entity_set, "?$top=", top, if (!is.null(select)) paste0("&$select=", paste(select, collapse = ",")))
  body <- msdv_request(q) |> httr2::req_perform() |> httr2::resp_body_json(simplifyVector = TRUE)
  tibble::as_tibble(body$value)
}
