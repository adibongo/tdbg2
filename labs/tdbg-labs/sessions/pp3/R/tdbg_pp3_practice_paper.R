# =============================================================================
# TDBG · Practice Paper 3 · Module 3 Practice Paper — PRACTICE PAPER (R)
# Reproduces the Section B outputs in the Practice Paper 3 deck.
# Notes: R's ets()/HoltWinters() and its random split differ slightly from Python's,
# so B1 and B3 numbers can differ a little; B2 matches exactly.
# (Question B4 uses Fig S5.3-F02, reproduced by sessions/5-3/R/tdbg_5_3_figures.R.)
# =============================================================================
suppressPackageStartupMessages({ library(dplyr); library(readr); library(tidyr); library(forecast) })

# ---- B1 · Forecast backtest: SME monthly sales -------------------------------------------------
d <- read_csv("data/sme_monthly_sales.csv", show_col_types = FALSE)
y <- ts(d$sales_m_naira, start = c(2019, 1), frequency = 12)
tr <- window(y, end = c(2024, 12)); te <- window(y, start = c(2025, 1), end = c(2025, 12))
mape <- function(a, p) { a <- as.numeric(a); p <- as.numeric(p); mean(abs(a - p) / a) * 100 }
hw <- HoltWinters(tr, seasonal = "multiplicative")
cat("MAPE, 2025 test year\n")
cat(sprintf("  Naive (last month)   %5.1f%%\n", mape(te, rep(tail(tr, 1), 12))))
cat(sprintf("  Seasonal naive       %5.1f%%\n", mape(te, tail(tr, 12))))
cat(sprintf("  Holt-Winters         %5.1f%%\n", mape(te, predict(hw, 12))))
full <- HoltWinters(window(y, end = c(2025, 12)), seasonal = "multiplicative")
print(forecast(full, h = 3, level = 80))

# ---- B2 · Association rules: supermarket baskets -----------------------------------------------
b <- read_csv("data/supermarket_baskets.csv", show_col_types = FALSE)
B <- as.data.frame.matrix(table(b$txn_id, b$item) > 0); sup <- colMeans(B)
cat(nrow(B), "baskets\n")
for (r in list(c("Tea", "Sugar"), c("Sugar", "Tea"), c("Diapers", "Beer"), c("Rice", "Detergent"))) {
  s <- mean(B[[r[1]]] & B[[r[2]]]); conf <- s / sup[[r[1]]]
  cat(sprintf("%-24s support %.3f  confidence %.3f  lift %.2f\n", paste(r[1], "->", r[2]), s, conf, conf / sup[[r[2]]]))
}

# ---- B3 · Fraud alerts: confusion matrix at threshold 0.10 ---------------------------------------
m <- read_csv("data/mobile_money_txns.csv", show_col_types = FALSE) |>
  mutate(night = as.integer(hour <= 4 | hour >= 23), log_amount = log(amount_naira))
set.seed(19)
idx <- unlist(lapply(split(seq_len(nrow(m)), m$is_fraud), function(i) sample(i, round(0.7 * length(i)))))
tr_m <- m[idx, ]; te_m <- m[-idx, ]
fit <- glm(is_fraud ~ log_amount + night + new_device + new_payee + txns_last_hour + distance_from_home_km, data = tr_m, family = binomial)
p <- predict(fit, te_m, type = "response")
cat("Test transfers:", nrow(te_m), "\n")
print(table(flagged = p >= 0.10, fraud = te_m$is_fraud))
