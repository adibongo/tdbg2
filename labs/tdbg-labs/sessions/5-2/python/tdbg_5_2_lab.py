# =============================================================================
# TDBG · Session 5.2 LAB · Who are our best customers, and which transfers are fraud? (Python)
# Data: data/customer_orders.csv, data/mobile_money_txns.csv
# pip install pandas numpy scikit-learn   # once
# =============================================================================
import numpy as np, pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import roc_auc_score

# ---- PART A · RFM segmentation -----------------------------------------------------------------------
o = pd.read_csv("data/customer_orders.csv", parse_dates=["order_date"])
snap = o.order_date.max() + pd.Timedelta(days=1)                       # treat the day after the last order as 'today'
rfm = o.groupby("customer_id").agg(last=("order_date", "max"), frequency=("order_date", "size"), monetary=("order_value_naira", "sum"))
rfm["recency"] = (snap - rfm["last"]).dt.days
print(rfm[["recency", "frequency", "monetary"]].describe().round(0))
rfm["r"] = pd.qcut(rfm.recency.rank(method="first"), 5, labels=[5, 4, 3, 2, 1]).astype(int)   # 5 = best
rfm["f"] = pd.qcut(rfm.frequency.rank(method="first"), 5, labels=[1, 2, 3, 4, 5]).astype(int)
rfm["m"] = pd.qcut(rfm.monetary.rank(method="first"), 5, labels=[1, 2, 3, 4, 5]).astype(int)
def segment(x):
    if x.r >= 4 and x.f >= 4: return "Champions"
    if x.r >= 3 and x.f >= 3: return "Loyal"
    if x.r >= 4 and x.f <= 2: return "New / promising"
    if x.r <= 2 and x.f >= 3: return "At risk"
    if x.r <= 2 and x.f <= 2: return "Lost"
    return "Need attention"
rfm["segment"] = rfm.apply(segment, axis=1)
print(rfm.groupby("segment").agg(customers=("monetary", "size"), revenue_share=("monetary", lambda s: s.sum() / rfm.monetary.sum()))
      .sort_values("revenue_share", ascending=False).round(3))
top = rfm.monetary.sort_values(ascending=False)
print("Top 20% of customers' share of revenue:", round(top.head(int(0.2 * len(top))).sum() / top.sum(), 3))

# ---- PART B · Customer lifetime value -------------------------------------------------------------------
yr = o.order_date.dt.year
c24, c25 = set(o.customer_id[yr == 2024]), set(o.customer_id[yr == 2025])
retention = len(c24 & c25) / len(c24); print("retention:", round(retention, 3))   # 2024 customers who came back in 2025
annual_spend = o[yr == 2025].groupby("customer_id").order_value_naira.sum().mean()
margin = 0.25 * annual_spend                                            # assume a 25% gross margin
d = 0.20                                                                # discount rate: money today is worth more
clv = lambda r: margin * (1 + d) / (1 + d - r)
print(f"CLV today: ₦{clv(retention):,.0f} | with +10 points retention: ₦{clv(retention + 0.10):,.0f}")

# ---- PART C · Fraud detection --------------------------------------------------------------------------
m = pd.read_csv("data/mobile_money_txns.csv")
m["night"] = ((m.hour <= 4) | (m.hour >= 23)).astype(int); m["log_amount"] = np.log(m.amount_naira)
print("fraud rate:", m.is_fraud.mean().round(4), "| accuracy of 'never fraud':", (1 - m.is_fraud.mean()).round(4))
print(m.groupby("new_device").is_fraud.mean().round(3))
FEATS = ["log_amount", "night", "new_device", "new_payee", "txns_last_hour", "distance_from_home_km"]
Xtr, Xte, ytr, yte = train_test_split(m[FEATS], m.is_fraud, test_size=0.3, random_state=19, stratify=m.is_fraud)
fit = LogisticRegression(max_iter=3000).fit(Xtr, ytr)
print(pd.Series(fit.coef_[0], index=FEATS).round(3))
p = fit.predict_proba(Xte)[:, 1]
print("AUC:", round(roc_auc_score(yte, p), 3))

# Choose a threshold by cost: ₦1,500 to review an alert; a missed fraud loses the transfer amount
amt = m.loc[Xte.index, "amount_naira"].values; y = yte.values
cost_at = lambda t: (p >= t).sum() * 1500 + amt[(p < t) & (y == 1)].sum()
th = np.arange(0.01, 0.51, 0.01); best = th[np.argmin([cost_at(t) for t in th])]
print(f"best threshold {best:.2f}: {(p >= best).sum()} alerts, cost ₦{cost_at(best):,.0f} vs no screening ₦{amt[y == 1].sum():,.0f}")
print(pd.crosstab(p >= best, y, rownames=["flagged"], colnames=["fraud"]))

# ---- YOUR TURN ------------------------------------------------------------------------------------------
# (a) Write one marketing action for 'Champions' and one for 'At risk'. Which is worth more money?
# (b) What happens to CLV if the gross margin is 15% instead of 25%? If retention falls to 55%?
# (c) Double the review cost to ₦3,000. How does the best threshold and number of alerts change? Why?
