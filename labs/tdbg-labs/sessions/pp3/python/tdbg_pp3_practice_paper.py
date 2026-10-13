# =============================================================================
# TDBG · Practice Paper 3 · Module 3 Practice Paper — PRACTICE PAPER (Python)
# Reproduces every Section B output in the Practice Paper 3 deck.
# (Question B4 uses Fig S5.3-F02, reproduced by sessions/5-3/python/tdbg_5_3_figures.py.)
# =============================================================================
import warnings; warnings.filterwarnings("ignore")
import itertools, numpy as np, pandas as pd
from statsmodels.tsa.holtwinters import ExponentialSmoothing
from sklearn.model_selection import train_test_split
from sklearn.linear_model import LogisticRegression

# ---- B1 · Forecast backtest: SME monthly sales -------------------------------------------------
d = pd.read_csv("data/sme_monthly_sales.csv", parse_dates=["month"]).set_index("month"); d.index.freq = "MS"
y = d.sales_m_naira; tr, te = y[:"2024-12"], y["2025-01":"2025-12"]
mape = lambda a, p: float(np.mean(np.abs(np.asarray(a) - np.asarray(p)) / np.asarray(a)) * 100)
hw = ExponentialSmoothing(tr, trend="add", seasonal="mul", seasonal_periods=12).fit()
print("MAPE, 2025 test year")
for name, f in [("Naive (last month)", np.repeat(tr.iloc[-1], 12)), ("Seasonal naive", tr[-12:].values), ("Holt-Winters", hw.forecast(12).values)]:
    print(f"  {name:<20} {mape(te, f):5.1f}%")
full = ExponentialSmoothing(y[:"2025-12"], trend="add", seasonal="mul", seasonal_periods=12).fit()
resid_sd = np.std(full.resid)
fc = full.forecast(3)
print("\nHolt-Winters forecast, next 3 months (₦m), approx. 80% interval = ±1.28 × residual SD")
for m, v in fc.items(): print(f"  {m:%b %Y}  {v:6.1f}   [{v - 1.28 * resid_sd:6.1f}, {v + 1.28 * resid_sd:6.1f}]")

# ---- B2 · Association rules: supermarket baskets -----------------------------------------------
b = pd.read_csv("data/supermarket_baskets.csv")
B = pd.crosstab(b.txn_id, b["item"]).clip(upper=1).astype(bool); sup = B.mean()
print(f"\n{len(B)} baskets")
print(f"{'rule':<26}{'support':>9}{'confidence':>12}{'lift':>7}")
for a, c in [("Tea", "Sugar"), ("Sugar", "Tea"), ("Diapers", "Beer"), ("Rice", "Detergent")]:
    s = (B[a] & B[c]).mean(); conf = s / sup[a]
    print(f"{a + ' -> ' + c:<26}{s:9.3f}{conf:12.3f}{conf / sup[c]:7.2f}")

# ---- B3 · Fraud alerts: confusion matrix at threshold 0.10 ---------------------------------------
m = pd.read_csv("data/mobile_money_txns.csv")
m["night"] = ((m.hour <= 4) | (m.hour >= 23)).astype(int); m["log_amount"] = np.log(m.amount_naira)
FEATS = ["log_amount", "night", "new_device", "new_payee", "txns_last_hour", "distance_from_home_km"]
Xtr, Xte, ytr, yte = train_test_split(m[FEATS], m.is_fraud, test_size=0.3, random_state=19, stratify=m.is_fraud)
p = LogisticRegression(max_iter=3000).fit(Xtr, ytr).predict_proba(Xte)[:, 1]
print("\nTest transfers:", len(yte))
print(pd.crosstab(pd.Series(p >= 0.10, name="flagged"), pd.Series(yte.values, name="fraud")))
