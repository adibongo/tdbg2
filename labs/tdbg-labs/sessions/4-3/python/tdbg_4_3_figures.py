# =============================================================================
# TDBG · Session 4.3 · Time Series & Business Forecasting
# Replication script — regenerates every chart in the Session 4.3 deck (Python)
# Data: data/sme_monthly_sales.csv — 84 months (2019–2025) of an SME's sales and cash flows
# Backtest: train on 2019–2024, test on the 12 months of 2025.
# Note: F08 is a Monte Carlo simulation; R and Python random draws differ slightly.
# =============================================================================
import sys; sys.path.insert(0, "python")
import numpy as np, pandas as pd, warnings
import matplotlib.pyplot as plt
from statsmodels.tsa.seasonal import STL
from statsmodels.tsa.holtwinters import ExponentialSmoothing
from statsmodels.tsa.arima.model import ARIMA
from statsmodels.graphics.tsaplots import plot_acf
from tdbg_style import *
warnings.filterwarnings("ignore")

set_style()
d = pd.read_csv("data/sme_monthly_sales.csv", parse_dates=["month"]).set_index("month"); d.index.freq = "MS"
y = d.sales_m_naira; tr, te = y[:"2024-12"], y["2025-01":]
mape = lambda a, p: float(np.mean(np.abs(np.asarray(a) - np.asarray(p)) / np.asarray(a)) * 100)

# --- F01 · The series ------------------------------------------------------------------
fig, ax = plt.subplots()
ax.plot(y.index, y, color=TEAL, lw=2.5)
dec = y[y.index.month == 12]; ax.plot(dec.index, dec, "o", color=GOLD, ms=8, label="December")
ax.axvspan(pd.Timestamp("2020-04-01"), pd.Timestamp("2020-06-30"), color=RUST, alpha=.15); ax.text(pd.Timestamp("2020-07-10"), 36, "2020 lockdown", color=RUST)
ax.legend(); ax.set(title="Monthly sales: steady growth, a December spike every year, one shock", ylabel="Sales (₦ million)")
save(fig, "4-3", "f01")

# --- F02 · Decomposition ----------------------------------------------------------------
st = STL(np.log(y), period=12, robust=True).fit()
fig, ax = plt.subplots(4, 1, figsize=(11, 7.5), sharex=True)
for a, s, t, c in zip(ax, [np.log(y), st.trend, st.seasonal, st.resid], ["Observed (log sales)", "Trend", "Seasonal", "Remainder"], [NAVY, TEAL, GOLD, SLATE]):
    a.plot(s.index, s, color=c, lw=2); a.set_ylabel(t, fontsize=11)
ax[0].set_title("Decomposition: every series = trend + seasonality + noise")
fig.tight_layout(); save(fig, "4-3", "f02")

# --- F03 · Seasonal plot ------------------------------------------------------------------
fig, ax = plt.subplots()
cols = plt.cm.viridis(np.linspace(0, .9, 7))
for c, (yr, s) in zip(cols, y.groupby(y.index.year)):
    ax.plot(s.index.month, s.values, color=c, lw=2, label=str(yr)); ax.text(12.15, s.values[-1], str(yr), color=c, va="center", fontsize=10)
ax.set_xticks(range(1, 13), list("JFMAMJJASOND")); ax.set_xlim(.7, 13)
ax.set(title="Seasonal plot: each year climbs to a December peak", xlabel="Month", ylabel="Sales (₦ million)")
save(fig, "4-3", "f03")

# --- F04 · Autocorrelation -------------------------------------------------------------------
fig, ax = plt.subplots()
plot_acf(np.log(y).diff().dropna(), lags=26, ax=ax, color=TEAL, vlines_kwargs={"colors": TEAL})
ax.set(title="Autocorrelation of monthly growth: a spike at lag 12 = yearly seasonality", xlabel="Lag (months)", ylabel="Correlation")
save(fig, "4-3", "f04")

# --- F05 · Backtest forecasts for 2025 ----------------------------------------------------------
fc = {"Naive (last month)": np.repeat(tr.iloc[-1], 12),
      "Seasonal naive (same month last year)": tr[-12:].values,
      "Exponential smoothing (Holt-Winters)": ExponentialSmoothing(tr, trend="add", seasonal="mul", seasonal_periods=12).fit().forecast(12).values,
      "Seasonal ARIMA": np.exp(ARIMA(np.log(tr), order=(1, 1, 1), seasonal_order=(0, 1, 1, 12)).fit().forecast(12)).values}
fig, ax = plt.subplots()
ax.plot(y["2023":].index, y["2023":], color=INK, lw=3, label="Actual")
for (k, v), c in zip(fc.items(), [SLATE, SKY, TEAL, GOLD]): ax.plot(te.index, v, color=c, lw=2.2, ls="--" if "aive" in k else "-", label=k)
ax.axvline(pd.Timestamp("2024-12-15"), color=SLATE, ls=":"); ax.text(pd.Timestamp("2025-01-10"), y["2023":].max() * .98, "test period →", color=SLATE)
ax.legend(fontsize=10, loc="upper left"); ax.set(title="Backtest: forecast 2025 using only data up to December 2024", ylabel="Sales (₦ million)")
save(fig, "4-3", "f05")

# --- F06 · Accuracy ------------------------------------------------------------------------------------
acc = {k.split(" (")[0]: mape(te, v) for k, v in fc.items()}
fig, ax = plt.subplots()
b = ax.bar(list(acc), list(acc.values()), color=[SLATE, SKY, TEAL, GOLD]); ax.bar_label(b, labels=[f"{v:.1f}%" for v in acc.values()], padding=3, fontsize=13)
ax.set(title="Forecast error in 2025 (MAPE): seasonal models win clearly", ylabel="Mean absolute % error"); plt.xticks(fontsize=11)
save(fig, "4-3", "f06")

# --- F07 · 2026 forecast with intervals -----------------------------------------------------------------
m = ARIMA(np.log(y), order=(1, 1, 1), seasonal_order=(0, 1, 1, 12)).fit(); g = m.get_forecast(12)
mean = np.exp(g.predicted_mean); ci80 = np.exp(g.conf_int(alpha=.2)); ci95 = np.exp(g.conf_int(alpha=.05))
fig, ax = plt.subplots()
ax.plot(y["2022":].index, y["2022":], color=INK, lw=2.5, label="Actual")
ax.fill_between(mean.index, ci95.iloc[:, 0], ci95.iloc[:, 1], color=TEAL, alpha=.15, label="95% interval")
ax.fill_between(mean.index, ci80.iloc[:, 0], ci80.iloc[:, 1], color=TEAL, alpha=.3, label="80% interval")
ax.plot(mean.index, mean, color=TEAL, lw=2.5, label="Forecast")
ax.legend(loc="upper left"); ax.set(title=f"2026 forecast: ₦{mean.sum():,.0f}m for the year — with honest uncertainty", ylabel="Sales (₦ million)")
save(fig, "4-3", "f07")

# --- F08 · Cash-flow fan chart: when can we afford a ₦55m expansion? -------------------------------
rng = np.random.default_rng(15); sims = np.exp(m.simulate(12, repetitions=2000, anchor="end")).values.reshape(12, -1)
r_in = rng.uniform(.86, .95, sims.shape)
net = sims * r_in - (sims * .78 + 4 + rng.normal(0, 1.5, sims.shape))       # monthly net cash flow scenarios
idx = mean.index; fig, axes = plt.subplots(1, 2, figsize=(13, 5), sharey=True); pneg = {}
for ax, mo, lab in zip(axes, [2, 8], ["March", "September"]):
    cash = 30 + np.cumsum(net, axis=0); cash[mo:] -= 55                        # opening cash ₦30m; ₦55m capex
    q = np.percentile(cash, [5, 25, 50, 75, 95], axis=1); pneg[lab] = (cash.min(axis=0) < 0).mean()
    ax.fill_between(idx, q[0], q[4], color=TEAL, alpha=.15, label="90% of scenarios"); ax.fill_between(idx, q[1], q[3], color=TEAL, alpha=.3, label="50% of scenarios")
    ax.plot(idx, q[2], color=TEAL, lw=2.5, label="median path"); ax.axhline(0, color=RUST, lw=2)
    ax.set_title(f"Pay in {lab}: {pneg[lab]:.0%} chance of going overdrawn", color=RUST if pneg[lab] > .1 else TEAL)
    ax.tick_params(axis="x", labelrotation=30)
axes[0].set_ylabel("Cash balance (₦ million)"); axes[1].legend(loc="upper left")
fig.suptitle("Cash-flow scenarios: ₦30m opening cash and a ₦55m expansion — timing changes the risk", x=.01, ha="left", color=NAVY, fontweight="bold")
fig.tight_layout(); save(fig, "4-3", "f08")
print(acc, mean.sum(), pneg)
