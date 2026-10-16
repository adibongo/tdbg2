# ===========================================================================
# R/open_data.R — official and open statistics as warehouse sources
#
# PROMPT that generated this file:
#   "Write R functions that pull official statistics into tidy long tables with the
#    same columns (source, dataset, indicator, indicator_name, iso3, country, year,
#    value): World Bank WDI via api.worldbank.org, IMF World Economic Outlook via the
#    DataMapper API, UN Comtrade (public preview endpoint) and UNCTADstat (needs a
#    registered client id and secret). Cache every pull as CSV in data/open/ and fall
#    back to the cache when the network or the API is unavailable, so dashboards and
#    lessons still run offline. Use httr2 and jsonlite only."
# ===========================================================================
OPEN_DIR <- "data/open"
OPEN_COLS <- c("source", "dataset", "indicator", "indicator_name", "iso3", "country", "year", "value")

with_cache <- function(name, fetch) {
  dir.create(OPEN_DIR, showWarnings = FALSE, recursive = TRUE)
  path <- file.path(OPEN_DIR, paste0(name, ".csv"))
  out <- tryCatch(fetch(), error = function(e) { message("[", name, "] live pull failed: ", conditionMessage(e)); NULL })
  if (!is.null(out) && nrow(out)) { utils::write.csv(out, path, row.names = FALSE); return(out) }
  if (file.exists(path)) { message("[", name, "] using cached copy from ", format(file.mtime(path), "%d %b %Y")); return(utils::read.csv(path)) }
  stop("No live data and no cache for ", name)
}

# ---- World Bank: World Development Indicators (no key needed) ---------------------
wb_wdi <- function(indicators, countries = c("NGA", "GHA", "KEN", "ZAF", "EGY", "CIV"), years = 2000:2025) {
  with_cache("world_bank_wdi", function() {
    do.call(rbind, lapply(indicators, function(ind) {
      url <- sprintf("https://api.worldbank.org/v2/country/%s/indicator/%s?format=json&date=%d:%d&per_page=20000",
                     paste(countries, collapse = ";"), ind, min(years), max(years))
      js <- httr2::request(url) |> httr2::req_timeout(30) |> httr2::req_perform() |> httr2::resp_body_json(simplifyVector = TRUE)
      d <- js[[2]]
      data.frame(source = "World Bank", dataset = "WDI", indicator = ind, indicator_name = d$indicator$value,
                 iso3 = d$countryiso3code, country = d$country$value, year = as.integer(d$date), value = d$value)
    })) |> subset(!is.na(value))
  })
}

# ---- IMF: World Economic Outlook via DataMapper (no key; includes projections) -------
imf_weo <- function(indicators = c("NGDP_RPCH", "PCPIPCH"), countries = c("NGA", "GHA", "KEN", "ZAF", "EGY", "CIV")) {
  with_cache("imf_weo", function() {
    names_url <- "https://www.imf.org/external/datamapper/api/v1/indicators"
    labels <- httr2::request(names_url) |> httr2::req_timeout(30) |> httr2::req_perform() |> httr2::resp_body_json()
    do.call(rbind, lapply(indicators, function(ind) {
      url <- sprintf("https://www.imf.org/external/datamapper/api/v1/%s/%s", ind, paste(countries, collapse = "/"))
      v <- (httr2::request(url) |> httr2::req_timeout(30) |> httr2::req_perform() |> httr2::resp_body_json())$values[[ind]]
      do.call(rbind, lapply(names(v), function(iso) data.frame(
        source = "IMF", dataset = "WEO", indicator = ind, indicator_name = labels$indicators[[ind]]$label %||% ind,
        iso3 = iso, country = iso, year = as.integer(names(v[[iso]])), value = as.numeric(unlist(v[[iso]])))))
    })) |> subset(iso3 %in% countries)      # the API can return every country; keep the ones asked for
  })
}

# ---- UN Comtrade: goods trade by partner (public preview, no key; max 500 rows) -------
comtrade_partners <- function(reporter = 566, year = 2023, flow = "X") {   # 566 = Nigeria (M49)
  with_cache(sprintf("comtrade_%s_%s_%s", reporter, year, flow), function() {
    url <- sprintf("https://comtradeapi.un.org/public/v1/preview/C/A/HS?reporterCode=%s&period=%s&flowCode=%s&cmdCode=TOTAL&includeDesc=true",
                   reporter, year, flow)
    d <- (httr2::request(url) |> httr2::req_timeout(30) |> httr2::req_perform() |> httr2::resp_body_json(simplifyVector = TRUE))$data
    data.frame(source = "UN Comtrade", dataset = "HS annual", indicator = paste0("trade_", flow), indicator_name = ifelse(flow == "X", "Exports, US$", "Imports, US$"),
               iso3 = d$partnerISO, country = d$partnerDesc, year = as.integer(d$refYear), value = d$primaryValue) |>
      subset(country != "World")
  })
}

# ---- UNCTADstat (registered API: set UNCTAD_CLIENT_ID and UNCTAD_CLIENT_SECRET) -------
unctad_available <- function() all(nzchar(Sys.getenv(c("UNCTAD_CLIENT_ID", "UNCTAD_CLIENT_SECRET"))))
unctad_get <- function(dataset = "US.FdiFlowsStock", filter = "Economy/Code in ('566')") {
  with_cache(paste0("unctad_", gsub("[^A-Za-z]", "", dataset)), function() {
    if (!unctad_available()) stop("UNCTADstat credentials not set (register at unctadstat.unctad.org, then add them to .Renviron)")
    httr2::request(sprintf("https://unctadstat-user-api.unctad.org/%s/cur/Facts", dataset)) |>
      httr2::req_headers(ClientId = Sys.getenv("UNCTAD_CLIENT_ID"), ClientSecret = Sys.getenv("UNCTAD_CLIENT_SECRET")) |>
      httr2::req_url_query(`$filter` = filter, `$format` = "csv") |>
      httr2::req_method("POST") |> httr2::req_timeout(60) |> httr2::req_perform() |>
      httr2::resp_body_string() |> textConnection() |> utils::read.csv()
  })
}

# Bind everything into one tidy table for the warehouse
open_macro <- function() {
  parts <- list(
    wb_wdi(c("NY.GDP.MKTP.KD.ZG", "FP.CPI.TOTL.ZG", "NY.GDP.PCAP.CD", "SL.UEM.TOTL.ZS", "BX.TRF.PWKR.DT.GD.ZS")),
    imf_weo(c("NGDP_RPCH", "PCPIPCH", "GGXWDG_NGDP")),
    comtrade_partners())
  if (unctad_available()) parts <- c(parts, list(tryCatch(unctad_get(), error = function(e) NULL)))
  do.call(rbind, lapply(parts, function(p) p[, OPEN_COLS]))
}
