# =============================================================================
# TDBG · Session 4.3 · Time Series & Business Forecasting
# Replication script — regenerates every chart in the Session 4.3 deck (R)
# Data: data/sme_monthly_sales.csv. Backtest: train 2019–2024, test 2025.
# Note: F08 is a simulation; R and Python random draws differ slightly.
# =============================================================================
source("R/theme_tdbg.R")
suppressPackageStartupMessages({ library(dplyr); library(readr); library(tidyr); library(forecast); library(patchwork) })
d <- read_csv("data/sme_monthly_sales.csv", show_col_types = FALSE) |> mutate(month = as.Date(month))
y <- ts(d$sales_m_naira, start = c(2019, 1), frequency = 12)
tr <- window(y, end = c(2024, 12)); te <- window(y, start = c(2025, 1))
mape <- function(a, p) mean(abs(a - p) / a) * 100
dates <- d$month

# --- F01 ---------------------------------------------------------------------------------
p1 <- ggplot(d, aes(month, sales_m_naira)) + annotate("rect", xmin = as.Date("2020-04-01"), xmax = as.Date("2020-06-30"), ymin = -Inf, ymax = Inf, fill = tdbg[["rust"]], alpha = .15) +
  geom_line(colour = tdbg[["teal"]], linewidth = 1.2) + geom_point(data = filter(d, format(month, "%m") == "12"), colour = tdbg[["gold"]], size = 3) +
  annotate("text", x = as.Date("2020-07-10"), y = 36, label = "2020 lockdown", colour = tdbg[["rust"]], hjust = 0) +
  labs(title = "Monthly sales: steady growth, a December spike every year, one shock", x = NULL, y = "Sales (₦ million)") + theme_tdbg()
save_fig(p1, "4-3", "f01")

# --- F02 · STL decomposition ---------------------------------------------------------------
st <- stl(log(y), s.window = "periodic", robust = TRUE)
dc <- tibble(month = dates, `Observed (log sales)` = as.numeric(log(y)), Trend = as.numeric(st$time.series[, "trend"]),
             Seasonal = as.numeric(st$time.series[, "seasonal"]), Remainder = as.numeric(st$time.series[, "remainder"])) |>
  pivot_longer(-month) |> mutate(name = factor(name, levels = c("Observed (log sales)", "Trend", "Seasonal", "Remainder")))
p2 <- ggplot(dc, aes(month, value, colour = name)) + geom_line() + facet_wrap(~name, ncol = 1, scales = "free_y") +
  scale_colour_manual(values = unname(tdbg[c("navy", "teal", "gold", "slate")]), guide = "none") +
  labs(title = "Decomposition: every series = trend + seasonality + noise", x = NULL, y = NULL) + theme_tdbg(11)
save_fig(p2, "4-3", "f02", width = 11, height = 7.5)

# --- F03 · Seasonal plot ----------------------------------------------------------------------
p3 <- ggseasonplot(y, year.labels = TRUE) + labs(title = "Seasonal plot: each year climbs to a December peak", y = "Sales (₦ million)") + theme_tdbg() + theme(legend.position = "none")
save_fig(p3, "4-3", "f03")

# --- F04 · ACF -----------------------------------------------------------------------------------
p4 <- ggAcf(diff(log(y)), lag.max = 26) + labs(title = "Autocorrelation of monthly growth: a spike at lag 12 = yearly seasonality", x = "Lag (months)") + theme_tdbg()
save_fig(p4, "4-3", "f04")

# --- F05/F06 · Backtest ----------------------------------------------------------------------------
fc <- list(`Naive (last month)` = naive(tr, 12)$mean, `Seasonal naive (same month last year)` = snaive(tr, 12)$mean,
           `Exponential smoothing (ETS)` = forecast(ets(tr), 12)$mean,
           `Seasonal ARIMA` = exp(forecast(Arima(log(tr), order = c(1, 1, 1), seasonal = c(0, 1, 1)), 12)$mean))
bt <- bind_rows(lapply(names(fc), function(k) tibble(model = k, month = tail(dates, 12), value = as.numeric(fc[[k]]))))
p5 <- ggplot() + geom_line(data = filter(d, month >= as.Date("2023-01-01")), aes(month, sales_m_naira), linewidth = 1.4) +
  geom_line(data = bt, aes(month, value, colour = model), linewidth = 1) + geom_vline(xintercept = as.Date("2024-12-15"), linetype = "dotted") +
  scale_colour_manual(values = unname(tdbg[c("teal", "slate", "gold", "sky")]), name = NULL) + guides(colour = guide_legend(ncol = 2)) +
  labs(title = "Backtest: forecast 2025 using only data up to December 2024", x = NULL, y = "Sales (₦ million)") + theme_tdbg()
save_fig(p5, "4-3", "f05")
acc <- tibble(model = sub(" \\(.*", "", names(fc)), mape = sapply(fc, function(f) mape(as.numeric(te), as.numeric(f)))) |> mutate(model = factor(model, levels = model))
p6 <- ggplot(acc, aes(model, mape, fill = model)) + geom_col() + geom_text(aes(label = sprintf("%.1f%%", mape)), vjust = -.4) +
  scale_fill_manual(values = unname(tdbg[c("slate", "sky", "teal", "gold")]), guide = "none") +
  labs(title = "Forecast error in 2025 (MAPE): seasonal models win clearly", x = NULL, y = "Mean absolute % error") + theme_tdbg()
save_fig(p6, "4-3", "f06")
print(acc)

# --- F07 · 2026 forecast with intervals ----------------------------------------------------------------
fit <- Arima(log(y), order = c(1, 1, 1), seasonal = c(0, 1, 1)); f <- forecast(fit, 12, level = c(80, 95))
fd <- tibble(month = seq(as.Date("2026-01-01"), by = "month", length.out = 12), mean = exp(as.numeric(f$mean)),
             lo80 = exp(f$lower[, 1]), hi80 = exp(f$upper[, 1]), lo95 = exp(f$lower[, 2]), hi95 = exp(f$upper[, 2]))
p7 <- ggplot() + geom_line(data = filter(d, month >= as.Date("2022-01-01")), aes(month, sales_m_naira), linewidth = 1.2) +
  geom_ribbon(data = fd, aes(month, ymin = lo95, ymax = hi95), fill = tdbg[["teal"]], alpha = .15) +
  geom_ribbon(data = fd, aes(month, ymin = lo80, ymax = hi80), fill = tdbg[["teal"]], alpha = .3) +
  geom_line(data = fd, aes(month, mean), colour = tdbg[["teal"]], linewidth = 1.2) +
  labs(title = sprintf("2026 forecast: ₦%sm for the year — with honest uncertainty", format(round(sum(fd$mean)), big.mark = ",")),
       subtitle = "dark band = 80% interval; light band = 95% interval", x = NULL, y = "Sales (₦ million)") + theme_tdbg()
save_fig(p7, "4-3", "f07")

# --- F08 · Cash-flow scenarios --------------------------------------------------------------------------
set.seed(15)
sims <- replicate(2000, exp(as.numeric(simulate(fit, nsim = 12, future = TRUE))))
net <- sims * matrix(runif(length(sims), .86, .95), 12) - (sims * .78 + 4 + matrix(rnorm(length(sims), 0, 1.5), 12))
fan <- bind_rows(lapply(list(c(3, "March"), c(9, "September")), function(z) {
  mo <- as.integer(z[1]); cash <- 30 + apply(net, 2, cumsum); cash[mo:12, ] <- cash[mo:12, ] - 55
  pn <- mean(apply(cash, 2, min) < 0)
  q <- apply(cash, 1, quantile, c(.05, .25, .5, .75, .95))
  tibble(panel = sprintf("Pay in %s: %.0f%% chance of going overdrawn", z[2], 100 * pn), month = fd$month,
         q05 = q[1, ], q25 = q[2, ], q50 = q[3, ], q75 = q[4, ], q95 = q[5, ]) }))
p8 <- ggplot(fan, aes(month)) + geom_ribbon(aes(ymin = q05, ymax = q95), fill = tdbg[["teal"]], alpha = .15) +
  geom_ribbon(aes(ymin = q25, ymax = q75), fill = tdbg[["teal"]], alpha = .3) + geom_line(aes(y = q50), colour = tdbg[["teal"]], linewidth = 1.2) +
  geom_hline(yintercept = 0, colour = tdbg[["rust"]], linewidth = 1) + facet_wrap(~panel) +
  labs(title = "Cash-flow scenarios: ₦30m opening cash and a ₦55m expansion — timing changes the risk",
       subtitle = "bands = 50% and 90% of 2,000 simulated scenarios", x = NULL, y = "Cash balance (₦ million)") + theme_tdbg()
save_fig(p8, "4-3", "f08", width = 13, height = 5)
