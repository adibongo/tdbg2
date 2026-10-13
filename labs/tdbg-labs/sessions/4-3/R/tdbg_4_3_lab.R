# =============================================================================
# TDBG · Session 4.3 LAB · Forecast an SME's sales and cash (R)
# Data: data/sme_monthly_sales.csv — monthly sales, cash in, cash out (₦ million), 2019–2025
# install.packages("forecast")   # once
# =============================================================================
library(readr); library(forecast)
d <- read_csv("data/sme_monthly_sales.csv", show_col_types = FALSE)
y <- ts(d$sales_m_naira, start = c(2019, 1), frequency = 12)    # tell R it is monthly

# ---- 1. Look at the series -------------------------------------------------------------------
autoplot(y); ggseasonplot(y); ggAcf(diff(log(y)))
plot(stl(log(y), s.window = "periodic"))                        # trend + seasonal + remainder

# ---- 2. Backtest: hold out 2025 -------------------------------------------------------------------
tr <- window(y, end = c(2024, 12)); te <- window(y, start = c(2025, 1))
f_naive  <- snaive(tr, h = 12)                                   # benchmark: same month last year
f_ets    <- forecast(ets(tr), h = 12)                            # exponential smoothing (auto-selected)
f_arima  <- forecast(auto.arima(log(tr)), h = 12)                # ARIMA on log sales
accuracy(f_naive, te)["Test set", "MAPE"]
accuracy(f_ets, te)["Test set", "MAPE"]
mean(abs(as.numeric(te) - exp(as.numeric(f_arima$mean))) / as.numeric(te)) * 100

# ---- 3. Forecast 2026 with intervals -----------------------------------------------------------------
fit <- ets(y); f <- forecast(fit, h = 12, level = c(80, 95)); autoplot(f); sum(f$mean)

# ---- 4. Cash scenarios: ₦30m opening cash, ₦55m expansion -----------------------------------------------
set.seed(1)
sims <- replicate(2000, as.numeric(simulate(fit, nsim = 12, future = TRUE)))
net  <- sims * 0.905 - (sims * 0.78 + 4)                         # cash in minus cash out, per scenario
cash <- 30 + apply(net, 2, cumsum)
march <- cash; march[3:12, ] <- march[3:12, ] - 55
mean(apply(march, 2, min) < 0)                                   # chance of going overdrawn if paid in March

# ---- YOUR TURN -------------------------------------------------------------------------------------------
# (a) Which model would you use for the 2026 budget, and why? Quote its backtest MAPE.
# (b) Repeat step 4 for paying in June and in September. Recommend a month.
# (c) What external event could make every model here wrong? How would you guard against it?
