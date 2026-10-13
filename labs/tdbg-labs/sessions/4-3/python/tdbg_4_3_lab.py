# =============================================================================
# TDBG · Session 4.3 LAB · Forecast an SME's sales and cash (Python)
# Data: data/sme_monthly_sales.csv
# =============================================================================
import numpy as np, pandas as pd, warnings
import matplotlib.pyplot as plt
from statsmodels.tsa.seasonal import STL
from statsmodels.tsa.holtwinters import ExponentialSmoothing
from statsmodels.tsa.arima.model import ARIMA
warnings.filterwarnings("ignore")

d = pd.read_csv("data/sme_monthly_sales.csv", parse_dates=["month"]).set_index("month"); d.index.freq = "MS"
y = d["sales_m_naira"]

# ---- 1. Look at the series -----------------------------------------------------------------
y.plot(title="Monthly sales"); plt.show()
STL(np.log(y), period=12).fit().plot(); plt.show()

# ---- 2. Backtest: hold out 2025 ----------------------------------------------------------------
tr, te = y[:"2024-12"], y["2025-01":]
mape = lambda a, p: np.mean(np.abs(np.asarray(a) - np.asarray(p)) / np.asarray(a)) * 100
print("seasonal naive", mape(te, tr[-12:].values))
hw = ExponentialSmoothing(tr, trend="add", seasonal="mul", seasonal_periods=12).fit(); print("Holt-Winters", mape(te, hw.forecast(12)))
ar = ARIMA(np.log(tr), order=(1, 1, 1), seasonal_order=(0, 1, 1, 12)).fit(); print("seasonal ARIMA", mape(te, np.exp(ar.forecast(12))))

# ---- 3. Forecast 2026 with intervals ---------------------------------------------------------------
m = ARIMA(np.log(y), order=(1, 1, 1), seasonal_order=(0, 1, 1, 12)).fit(); g = m.get_forecast(12)
print(np.exp(g.predicted_mean).round(1)); print(np.exp(g.conf_int(alpha=0.2)).round(1))   # 80% interval
print("2026 total:", np.exp(g.predicted_mean).sum())

# ---- 4. Cash scenarios -----------------------------------------------------------------------------
sims = np.exp(m.simulate(12, repetitions=2000, anchor="end")).values.reshape(12, -1)
net = sims * 0.905 - (sims * 0.78 + 4); cash = 30 + np.cumsum(net, axis=0)
march = cash.copy(); march[2:] -= 55
print("P(overdrawn) if paid in March:", (march.min(axis=0) < 0).mean())

# ---- YOUR TURN ---------------------------------------------------------------------------------------
# (a) Which model for the 2026 budget, and why? (b) Try June and September. (c) What could break every model?
