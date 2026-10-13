# =============================================================================
# TDBG · Session 5.2 · Customer & Financial Analytics: CLV, Churn, Credit & Fraud
# Replication script — regenerates every chart in the Session 5.2 deck (R)
# Data: data/customer_orders.csv and data/mobile_money_txns.csv
# The fraud split uses R's random numbers, so test-set figures differ slightly from Python.
# =============================================================================
source("R/theme_tdbg.R")
suppressPackageStartupMessages({ library(dplyr); library(readr); library(tidyr); library(lubridate); library(gbm); library(pROC); library(patchwork) })

# ============================ PART A · RFM and CLV ============================================
o <- read_csv("data/customer_orders.csv", show_col_types = FALSE)
snap <- max(o$order_date) + 1
rfm <- o |> group_by(customer_id) |>
  summarise(R = as.numeric(snap - max(order_date)), F = n(), M = sum(order_value_naira), .groups = "drop") |>
  mutate(r = 6 - ntile(R, 5), f = ntile(F, 5), m = ntile(M, 5),
         segment = case_when(r >= 4 & f >= 4 ~ "Champions", r >= 3 & f >= 3 ~ "Loyal", r >= 4 & f <= 2 ~ "New / promising",
                             r <= 2 & f >= 3 ~ "At risk", r <= 2 & f <= 2 ~ "Lost", TRUE ~ "Need attention"))
ORDER <- c("Champions", "Loyal", "New / promising", "Need attention", "At risk", "Lost")

# --- F01 · The three RFM ingredients -------------------------------------------------------------
h <- function(v, col, ttl, xl) ggplot(rfm, aes(.data[[v]])) + geom_histogram(bins = 30, fill = col) + labs(title = ttl, x = xl, y = "customers") + theme_tdbg(11)
p1 <- h("R", tdbg[["teal"]], "Recency: days since last order", "days") + h("F", tdbg[["gold"]], "Frequency: number of orders", "orders") +
  (ggplot(rfm, aes(M / 1000)) + geom_histogram(bins = 30, fill = tdbg[["navy"]]) + labs(title = "Monetary: total spend", x = "₦ thousand", y = "customers") + theme_tdbg(11)) +
  plot_annotation(title = "RFM: three simple numbers describe every customer — all heavily skewed", theme = theme_tdbg())
save_fig(p1, "5-2", "f01", width = 12, height = 4.2)

# --- F02 · RFM segments: customers vs revenue ----------------------------------------------------
seg <- rfm |> group_by(segment) |> summarise(customers = n(), revenue = sum(M)) |>
  mutate(`% of customers` = 100 * customers / sum(customers), `% of revenue` = 100 * revenue / sum(revenue), segment = factor(segment, ORDER))
print(seg)
p2 <- seg |> pivot_longer(starts_with("%")) |> ggplot(aes(segment, value, fill = name)) + geom_col(position = position_dodge(0.8), width = 0.75) +
  geom_text(aes(label = sprintf("%.0f%%", value)), position = position_dodge(0.8), vjust = -0.4, size = 3.4) +
  scale_fill_manual(values = c(tdbg[["slate"]], tdbg[["teal"]]), name = NULL) +
  labs(title = "RFM segments: Champions and Loyal customers bring in most of the revenue", x = NULL, y = "% of total") + theme_tdbg()
save_fig(p2, "5-2", "f02")

# --- F03 · Pareto: how concentrated is revenue? --------------------------------------------------
par <- rfm |> arrange(desc(M)) |> mutate(cc = 100 * row_number() / n(), cr = 100 * cumsum(M) / sum(M))
top20 <- par$cr[round(0.2 * nrow(par))]
p3 <- ggplot(par, aes(cc, cr)) + geom_line(colour = tdbg[["teal"]], linewidth = 1.5) +
  geom_abline(linetype = 3, colour = tdbg[["slate"]]) + geom_vline(xintercept = 20, linetype = 2, colour = tdbg[["gold"]]) +
  geom_hline(yintercept = top20, linetype = 2, colour = tdbg[["gold"]]) +
  annotate("text", x = 22, y = top20 - 7, hjust = 0, label = sprintf("top 20%% of customers = %.0f%% of revenue", top20), colour = tdbg[["gold"]], fontface = "bold") +
  labs(title = "Revenue concentration: a minority of customers carries the business", x = "% of customers (biggest spenders first)", y = "% of revenue (cumulative)") + theme_tdbg()
save_fig(p3, "5-2", "f03")

# --- F04 · Customer lifetime value and retention -------------------------------------------------
c24 <- unique(o$customer_id[year(o$order_date) == 2024]); c25 <- unique(o$customer_id[year(o$order_date) == 2025])
retention <- length(intersect(c24, c25)) / length(c24)
annual_spend <- o |> filter(year(order_date) == 2025) |> group_by(customer_id) |> summarise(s = sum(order_value_naira)) |> pull(s) |> mean()
margin <- 0.25 * annual_spend; d <- 0.20
clv <- function(r) margin * (1 + d) / (1 + d - r)
cat(sprintf("retention %.2f; annual spend %.0f; CLV now %.0f; at +10 pts %.0f\n", retention, annual_spend, clv(retention), clv(retention + 0.1)))
pts <- tibble(r = c(retention, retention + 0.1), lab = c("today", "+10 points")) |> mutate(v = clv(r))
p4 <- ggplot(tibble(r = seq(0.3, 0.9, length.out = 100)), aes(100 * r, clv(r) / 1000)) + geom_line(colour = tdbg[["teal"]], linewidth = 1.5) +
  geom_point(data = pts, aes(100 * r, v / 1000, colour = lab), size = 4) +
  geom_text(data = pts, aes(100 * r - 2, v / 1000 + 7, colour = lab, label = sprintf("%s: %.0f%% retention\nCLV ≈ %s", lab, 100 * r, naira(v))), hjust = 1, fontface = "bold", size = 3.6) +
  scale_colour_manual(values = c(today = tdbg[["rust"]], `+10 points` = tdbg[["gold"]]), guide = "none") +
  labs(title = "Customer lifetime value rises steeply with retention", x = "Annual retention rate (%)", y = "CLV per customer (₦ thousand)") + theme_tdbg()
save_fig(p4, "5-2", "f04")

# ============================ PART B · Fraud ===================================================
m <- read_csv("data/mobile_money_txns.csv", show_col_types = FALSE) |>
  mutate(night = as.integer(hour <= 4 | hour >= 23), log_amount = log(amount_naira))

# --- F05 · Fraud rate by red flag ----------------------------------------------------------------
flags <- list(`New device` = m$new_device == 1, `New payee` = m$new_payee == 1, `Night (11pm–5am)` = m$night == 1,
              `4+ transfers in last hour` = m$txns_last_hour >= 4, `Over 50 km from home` = m$distance_from_home_km > 50)
fr <- bind_rows(lapply(names(flags), function(k) tibble(flag = k, `flag present` = 100 * mean(m$is_fraud[flags[[k]]]), `flag absent` = 100 * mean(m$is_fraud[!flags[[k]]]))))
p5 <- fr |> pivot_longer(-flag) |> ggplot(aes(value, reorder(flag, value), fill = name)) + geom_col(position = position_dodge(0.8), width = 0.75) +
  geom_vline(xintercept = 100 * mean(m$is_fraud), linetype = 2, colour = tdbg[["gold"]]) +
  scale_fill_manual(values = c(`flag present` = tdbg[["rust"]], `flag absent` = tdbg[["slate"]]), name = NULL) +
  labs(title = sprintf("Fraud is rare (%.1f%%) — but much more common when red flags appear", 100 * mean(m$is_fraud)), x = "% of transfers that are fraud", y = NULL) + theme_tdbg()
save_fig(p5, "5-2", "f05")

# --- F06 · Precision–recall ------------------------------------------------------------------------
set.seed(19)
idx <- unlist(lapply(split(seq_len(nrow(m)), m$is_fraud), function(i) sample(i, round(0.7 * length(i)))))
tr <- m[idx, ]; te <- m[-idx, ]
fml <- is_fraud ~ log_amount + night + new_device + new_payee + txns_last_hour + distance_from_home_km
lg <- glm(fml, data = tr, family = binomial); p_lg <- predict(lg, te, type = "response")
gb <- gbm(fml, data = tr, distribution = "bernoulli", n.trees = 300, interaction.depth = 3, shrinkage = 0.05, verbose = FALSE)
p_gb <- predict(gb, te, n.trees = 300, type = "response")
prc <- function(p, y, name) { o <- order(-p); tp <- cumsum(y[o]); tibble(recall = 100 * tp / sum(y), precision = 100 * tp / seq_along(o), model = name) }
avgp <- function(p, y) { o <- order(-p); tp <- cumsum(y[o]); sum((tp / seq_along(o))[y[o] == 1]) / sum(y) }
cat(sprintf("never-fraud accuracy %.4f | AUC lg %.3f gb %.3f\n", 1 - mean(te$is_fraud), auc(te$is_fraud, p_lg, quiet = TRUE), auc(te$is_fraud, p_gb, quiet = TRUE)))
pr <- bind_rows(prc(p_lg, te$is_fraud, sprintf("Logistic regression (avg precision %.2f)", avgp(p_lg, te$is_fraud))),
                prc(p_gb, te$is_fraud, sprintf("Gradient boosting (avg precision %.2f)", avgp(p_gb, te$is_fraud))))
p6 <- ggplot(pr, aes(recall, precision, colour = model)) + geom_step(linewidth = 1.1) +
  geom_hline(yintercept = 100 * mean(te$is_fraud), linetype = 3) + scale_colour_manual(values = c(tdbg[["gold"]], tdbg[["teal"]]), name = NULL) +
  coord_cartesian(ylim = c(0, 100)) + theme_tdbg() + theme(legend.position = c(0.65, 0.85)) +
  labs(title = "Precision vs recall: catching more fraud means more false alarms", x = "Recall: % of fraud caught", y = "Precision: % of alerts that are fraud")
save_fig(p6, "5-2", "f06")

# --- F07 · Choosing the alert threshold by cost ---------------------------------------------------
REVIEW <- 1500
th <- seq(0.001, 0.5, length.out = 300)
ct <- tibble(th, alerts = sapply(th, function(t) sum(p_lg >= t)),
             cost = sapply(th, function(t) sum(p_lg >= t) * REVIEW + sum(te$amount_naira[p_lg < t & te$is_fraud == 1])))
none <- sum(te$amount_naira[te$is_fraud == 1]); b <- which.min(ct$cost)
cat(sprintf("best threshold %.3f: %d alerts, cost %.0f vs no model %.0f\n", ct$th[b], ct$alerts[b], ct$cost[b], none))
p7 <- ggplot(ct, aes(th, cost / 1e6)) + geom_line(colour = tdbg[["teal"]], linewidth = 1.4) +
  geom_hline(yintercept = none / 1e6, linetype = 3, colour = tdbg[["rust"]]) +
  annotate("text", x = 0.3, y = none / 1e6 * 1.05, label = paste("no screening:", naira(none), "lost"), colour = tdbg[["rust"]]) +
  annotate("point", x = ct$th[b], y = ct$cost[b] / 1e6, size = 4, colour = tdbg[["gold"]]) +
  annotate("text", x = ct$th[b] + 0.02, y = ct$cost[b] / 1e6 * 0.6, hjust = 0, colour = tdbg[["gold"]], fontface = "bold",
           label = sprintf("best threshold ≈ %.2f\n%d alerts to review\ntotal cost %s", ct$th[b], ct$alerts[b], naira(ct$cost[b]))) +
  coord_cartesian(ylim = c(0, none / 1e6 * 1.7)) +
  labs(title = "Pick the threshold that minimises review cost + fraud losses", subtitle = "6,000 test transfers; ₦1,500 to review each alert",
       x = "Alert threshold (flag if predicted fraud probability ≥ threshold)", y = "Total cost (₦ million)") + theme_tdbg()
save_fig(p7, "5-2", "f07")
message("Session 5.2 figures saved.")
