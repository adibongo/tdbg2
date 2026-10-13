# =============================================================================
# TDBG · Session 5.2 · Customer & Financial Analytics: CLV, Churn, Credit & Fraud
# Replication script — regenerates every chart in the Session 5.2 deck (Python)
# Data: data/customer_orders.csv   (12,121 orders from 1,200 online-retail customers, 2024–2025)
#       data/mobile_money_txns.csv (20,000 mobile-money transfers, 1.2% fraud)
# Fraud train/test: 70/30 stratified split, random_state = 19.
# =============================================================================
import sys; sys.path.insert(0, "python")
import numpy as np, pandas as pd
import matplotlib.pyplot as plt
from sklearn.model_selection import train_test_split
from sklearn.linear_model import LogisticRegression
from sklearn.ensemble import HistGradientBoostingClassifier
from sklearn.metrics import precision_recall_curve, average_precision_score, roc_auc_score
from tdbg_style import *

set_style()
# ============================ PART A · RFM and CLV ============================================
o = pd.read_csv("data/customer_orders.csv", parse_dates=["order_date"])
snap = o.order_date.max() + pd.Timedelta(days=1)                       # 'today' = day after the last order
rfm = o.groupby("customer_id").agg(last=("order_date", "max"), F=("order_date", "size"), M=("order_value_naira", "sum"))
rfm["R"] = (snap - rfm["last"]).dt.days
# Scores 1–5 by quintile (5 = best). Recency: fewer days = better.
rfm["r"] = pd.qcut(rfm.R.rank(method="first"), 5, labels=[5, 4, 3, 2, 1]).astype(int)
rfm["f"] = pd.qcut(rfm.F.rank(method="first"), 5, labels=[1, 2, 3, 4, 5]).astype(int)
rfm["m"] = pd.qcut(rfm.M.rank(method="first"), 5, labels=[1, 2, 3, 4, 5]).astype(int)
def segment(x):
    if x.r >= 4 and x.f >= 4: return "Champions"
    if x.r >= 3 and x.f >= 3: return "Loyal"
    if x.r >= 4 and x.f <= 2: return "New / promising"
    if x.r <= 2 and x.f >= 3: return "At risk"
    if x.r <= 2 and x.f <= 2: return "Lost"
    return "Need attention"
rfm["segment"] = rfm.apply(segment, axis=1)
ORDER = ["Champions", "Loyal", "New / promising", "Need attention", "At risk", "Lost"]

# --- F01 · The three RFM ingredients -------------------------------------------------------------
fig, axs = plt.subplots(1, 3, figsize=(12.5, 4.2))
axs[0].hist(rfm.R, bins=30, color=TEAL); axs[0].set(title="Recency: days since last order", xlabel="days")
axs[1].hist(rfm.F, bins=30, color=GOLD); axs[1].set(title="Frequency: number of orders", xlabel="orders")
axs[2].hist(rfm.M / 1000, bins=30, color=NAVY); axs[2].set(title="Monetary: total spend (₦ thousand)", xlabel="₦ thousand")
for a in axs: a.set_ylabel("customers")
fig.suptitle("RFM: three simple numbers describe every customer — all heavily skewed", fontsize=14, color=NAVY, weight="bold")
fig.tight_layout(); save(fig, "5-2", "f01")

# --- F02 · RFM segments: customers vs revenue ----------------------------------------------------
seg = rfm.groupby("segment").agg(customers=("M", "size"), revenue=("M", "sum")).reindex(ORDER)
seg["pct_customers"] = seg.customers / seg.customers.sum() * 100; seg["pct_revenue"] = seg.revenue / seg.revenue.sum() * 100
print(seg.round(1))
x = np.arange(len(ORDER)); w = 0.38
fig, ax = plt.subplots(figsize=(11, 5))
ax.bar(x - w / 2, seg.pct_customers, w, color=SLATE, label="% of customers")
ax.bar(x + w / 2, seg.pct_revenue, w, color=TEAL, label="% of revenue")
for i, (c, v) in enumerate(zip(seg.pct_customers, seg.pct_revenue)):
    ax.text(i - w / 2, c + 0.8, f"{c:.0f}%", ha="center", fontsize=10); ax.text(i + w / 2, v + 0.8, f"{v:.0f}%", ha="center", fontsize=10, weight="bold")
ax.set_xticks(x, ORDER); ax.legend()
ax.set(title="RFM segments: Champions and Loyal customers bring in most of the revenue", ylabel="% of total")
save(fig, "5-2", "f02")

# --- F03 · Pareto: how concentrated is revenue? --------------------------------------------------
s = rfm.M.sort_values(ascending=False).values
cum_c = np.arange(1, len(s) + 1) / len(s) * 100; cum_r = s.cumsum() / s.sum() * 100
top20 = cum_r[int(0.2 * len(s)) - 1]
fig, ax = plt.subplots(figsize=(9, 5.5))
ax.plot(cum_c, cum_r, color=TEAL, lw=3); ax.plot([0, 100], [0, 100], color=SLATE, ls=":", label="if every customer spent the same")
ax.axvline(20, color=GOLD, ls="--"); ax.axhline(top20, color=GOLD, ls="--")
ax.text(22, top20 - 7, f"top 20% of customers = {top20:.0f}% of revenue", color=GOLD, fontsize=12, weight="bold")
ax.set(title="Revenue concentration: a minority of customers carries the business", xlabel="% of customers (biggest spenders first)", ylabel="% of revenue (cumulative)")
ax.legend(loc="lower right"); save(fig, "5-2", "f03")

# --- F04 · Customer lifetime value and retention -------------------------------------------------
o["year"] = o.order_date.dt.year
y24 = set(o.loc[o.year == 2024, "customer_id"]); y25 = set(o.loc[o.year == 2025, "customer_id"])
retention = len(y24 & y25) / len(y24)
annual_spend = o[o.year == 2025].groupby("customer_id").order_value_naira.sum().mean()
margin = 0.25 * annual_spend; d = 0.20                                     # 25% gross margin, 20% discount rate
clv = lambda r: margin * (1 + d) / (1 + d - r)                              # margin earned at start of each year
rr = np.linspace(0.3, 0.9, 100)
print(f"retention {retention:.2f}; annual spend {annual_spend:,.0f}; margin {margin:,.0f}; CLV now {clv(retention):,.0f}; at +10pts {clv(retention + .1):,.0f}")
fig, ax = plt.subplots(figsize=(10, 5.5))
ax.plot(rr * 100, clv(rr) / 1000, color=TEAL, lw=3)
for r_, c_, lab in [(retention, RUST, "today"), (retention + 0.10, GOLD, "+10 points")]:
    ax.scatter(r_ * 100, clv(r_) / 1000, s=120, color=c_, zorder=3)
    ax.annotate(f"{lab}: {r_:.0%} retention\nCLV ≈ {naira(clv(r_))}", (r_ * 100, clv(r_) / 1000), xytext=(-150, 30), textcoords="offset points",
                fontsize=11, color=c_, weight="bold", arrowprops=dict(arrowstyle="-", color=c_))
ax.set(title="Customer lifetime value rises steeply with retention",
       xlabel="Annual retention rate (%)", ylabel="CLV per customer (₦ thousand)")
save(fig, "5-2", "f04")

# ============================ PART B · Fraud ===================================================
m = pd.read_csv("data/mobile_money_txns.csv")
m["night"] = ((m.hour <= 4) | (m.hour >= 23)).astype(int); m["log_amount"] = np.log(m.amount_naira)
FEATS = ["log_amount", "night", "new_device", "new_payee", "txns_last_hour", "distance_from_home_km"]

# --- F05 · Fraud rate by red flag ----------------------------------------------------------------
flags = {"New device": m.new_device == 1, "New payee": m.new_payee == 1, "Night (11pm–5am)": m.night == 1,
         "4+ transfers in last hour": m.txns_last_hour >= 4, "Over 50 km from home": m.distance_from_home_km > 50}
rows = [(k, m.is_fraud[v].mean() * 100, m.is_fraud[~v].mean() * 100) for k, v in flags.items()]
fr = pd.DataFrame(rows, columns=["flag", "with", "without"]).sort_values("with")
fig, ax = plt.subplots(figsize=(10.5, 5))
y_ = np.arange(len(fr))
ax.barh(y_ + 0.2, fr["with"], 0.4, color=RUST, label="flag present"); ax.barh(y_ - 0.2, fr["without"], 0.4, color=SLATE, label="flag absent")
for i, (a, b) in enumerate(zip(fr["with"], fr["without"])): ax.text(a + 0.15, i + 0.2, f"{a:.1f}%", va="center", fontsize=10, weight="bold")
ax.axvline(m.is_fraud.mean() * 100, color=GOLD, ls="--"); ax.text(m.is_fraud.mean() * 100 + 0.1, len(fr) - 0.45, f"overall {m.is_fraud.mean():.1%}", color=GOLD)
ax.set_yticks(y_, fr.flag); ax.legend(loc="lower right")
ax.set(title="Fraud is rare (1.2%) — but much more common when red flags appear", xlabel="% of transfers that are fraud")
save(fig, "5-2", "f05")

# --- F06 · Precision–recall: the right scorecard for rare events ---------------------------------
Xtr, Xte, ytr, yte = train_test_split(m[FEATS], m.is_fraud, test_size=0.3, random_state=19, stratify=m.is_fraud)
lg = LogisticRegression(max_iter=3000).fit(Xtr, ytr); p_lg = lg.predict_proba(Xte)[:, 1]
gb = HistGradientBoostingClassifier(random_state=1, max_depth=3, learning_rate=0.05).fit(Xtr, ytr); p_gb = gb.predict_proba(Xte)[:, 1]
print("never-fraud accuracy:", round(1 - yte.mean(), 4), "| AUC lg", round(roc_auc_score(yte, p_lg), 3), "gb", round(roc_auc_score(yte, p_gb), 3))
fig, ax = plt.subplots(figsize=(9.5, 5.5))
for p, c, n in [(p_lg, TEAL, "Logistic regression"), (p_gb, GOLD, "Gradient boosting")]:
    pr, rc, _ = precision_recall_curve(yte, p); ax.plot(rc * 100, pr * 100, color=c, lw=2.5, label=f"{n} (avg precision {average_precision_score(yte, p):.2f})")
ax.axhline(yte.mean() * 100, color=SLATE, ls=":", label=f"random guessing ({yte.mean():.1%})")
ax.set(title="Precision vs recall: catching more fraud means more false alarms", xlabel="Recall: % of fraud caught", ylabel="Precision: % of alerts that are fraud", ylim=(0, 100))
ax.legend(); save(fig, "5-2", "f06")

# --- F07 · Choosing the alert threshold by cost ---------------------------------------------------
REVIEW = 1500                                         # ₦ cost of an analyst reviewing one alert
amt = np.exp(Xte.log_amount.values); yv = yte.values
th = np.linspace(0.001, 0.5, 300)
cost = [(p_lg >= t).sum() * REVIEW + amt[(p_lg < t) & (yv == 1)].sum() for t in th]
alerts = [(p_lg >= t).sum() for t in th]
b = int(np.argmin(cost)); none_cost = amt[yv == 1].sum()
print(f"best threshold {th[b]:.3f}: alerts {alerts[b]}, cost {cost[b]:,.0f} vs no model {none_cost:,.0f}; recall {((p_lg >= th[b]) & (yv == 1)).sum() / yv.sum():.2f}")
fig, ax = plt.subplots(figsize=(10, 5.5))
ax.plot(th, np.array(cost) / 1e6, color=TEAL, lw=3)
ax.axhline(none_cost / 1e6, color=RUST, ls=":"); ax.text(0.3, none_cost / 1e6 * 1.02, f"no screening: {naira(none_cost)} lost", color=RUST)
ax.scatter(th[b], cost[b] / 1e6, s=120, color=GOLD, zorder=3)
ax.annotate(f"best threshold ≈ {th[b]:.2f}\n{alerts[b]} alerts to review\ntotal cost {naira(cost[b])}", (th[b], cost[b] / 1e6), xytext=(30, -80), textcoords="offset points",
            color=GOLD, weight="bold", arrowprops=dict(arrowstyle="-", color=GOLD))
ax.set_ylim(0, none_cost / 1e6 * 1.7)
ax.set(title="Pick the threshold that minimises review cost + fraud losses (6,000 test transfers)",
       xlabel="Alert threshold (flag if predicted fraud probability ≥ threshold)", ylabel="Total cost (₦ million)")
save(fig, "5-2", "f07")
print("Session 5.2 figures saved.")
