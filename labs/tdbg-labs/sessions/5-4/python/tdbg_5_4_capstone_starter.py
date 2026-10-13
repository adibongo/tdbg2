# =============================================================================
# TDBG · Session 5.4 · CAPSTONE STARTER (Python)
# A complete question-to-recommendation workflow you can copy for your capstone.
# Worked example: "Which subscribers should the retention team call this month?"
# Data: data/telecom_churn.csv (replace with your own file and outcome)
# Also regenerates Fig S5.4-F01 (the 'one chart' for the board).
# =============================================================================
import sys; sys.path.insert(0, "python")
import numpy as np, pandas as pd
import matplotlib.pyplot as plt
from sklearn.model_selection import train_test_split
from sklearn.linear_model import LogisticRegression
from sklearn.ensemble import HistGradientBoostingClassifier
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import roc_auc_score
from tdbg_style import *
set_style()

# ---- STEP 1 · The business question and the decision ----------------------------------------------
# Decision: which subscribers get a retention call (cost ₦800 per call)?
# Success metric: net naira value = saved customers × value per save − call costs.
CALL_COST, VALUE_SAVED, SAVE_RATE = 800, 12000, 0.30     # assumptions: write yours down and test them

# ---- STEP 2 · Data: load, check, clean -------------------------------------------------------------
d = pd.read_csv("data/telecom_churn.csv")
print(d.shape); print(d.isna().sum().sum(), "missing values"); print(d.describe().round(1).T)
d["postpaid"] = (d.plan == "Postpaid").astype(int)
y = d.churned; X = d.drop(columns=["subscriber_id", "plan", "churned"])
print("base rate (churn):", y.mean().round(3))

# ---- STEP 3 · Explore: which drivers move with the outcome? ---------------------------------------
print(d.groupby("complaints").churned.mean().round(3))
print(d.groupby(pd.cut(d.tenure_months, [0, 6, 12, 24, 48, 72])).churned.mean().round(3))

# ---- STEP 4 · Model: a simple benchmark and a challenger, judged on held-out data --------------------
Xtr, Xte, ytr, yte = train_test_split(X, y, test_size=0.3, random_state=22, stratify=y)
sc = StandardScaler().fit(Xtr)
lg = LogisticRegression(max_iter=2000).fit(sc.transform(Xtr), ytr); p_lg = lg.predict_proba(sc.transform(Xte))[:, 1]
gb = HistGradientBoostingClassifier(max_depth=3, learning_rate=0.05, random_state=1).fit(Xtr, ytr); p_gb = gb.predict_proba(Xte)[:, 1]
print(f"test AUC — logistic {roc_auc_score(yte, p_lg):.3f} | boosting {roc_auc_score(yte, p_gb):.3f}")
print(pd.Series(np.exp(lg.coef_[0]), index=X.columns).round(2).sort_values())   # odds ratio per 1 SD

# ---- STEP 5 · Value: turn predictions into a naira decision ------------------------------------------
t = pd.DataFrame({"p": p_lg, "y": yte.values}).sort_values("p", ascending=False).reset_index(drop=True)
t["decile"] = t.index // (len(t) // 10) + 1
dec = t.groupby("decile").agg(customers=("y", "size"), churners=("y", "sum"))
dec["net_value"] = dec.churners * SAVE_RATE * VALUE_SAVED - dec.customers * CALL_COST
dec["cumulative"] = dec.net_value.cumsum()
print(dec)
best = int(dec.cumulative.idxmax()); print(f"Call the top {best} deciles ({best * 10}% of subscribers): net value ≈ ₦{dec.cumulative.max():,.0f} per {len(t):,} subscribers")

# ---- STEP 6 · Check: fairness and robustness ----------------------------------------------------------
t2 = pd.DataFrame({"plan": d.loc[Xte.index, "plan"].values, "flag": p_lg >= np.sort(p_lg)[::-1][int(best / 10 * len(p_lg)) - 1]})
print(t2.groupby("plan").flag.mean().round(3))           # are we calling one group far more? Is that justified?
for sr in (0.2, 0.3, 0.4):                                # sensitivity: does the answer survive other assumptions?
    v = (dec.churners * sr * VALUE_SAVED - dec.customers * CALL_COST).cumsum()
    print(f"save rate {sr:.0%}: best = top {int(v.idxmax())} deciles, value ₦{v.max():,.0f}")

# ---- STEP 7 · Communicate: one chart, one recommendation ------------------------------------------------
fig, ax = plt.subplots(figsize=(10, 5.5))
cols = [TEAL if v > 0 else RUST for v in dec.net_value]
ax.bar(dec.index, dec.net_value / 1000, color=cols, label="net value of calling this decile")
ax.plot(dec.index, dec.cumulative / 1000, color=GOLD, marker="o", lw=2.5, label="cumulative net value")
ax.axhline(0, color=SLATE, lw=0.8)
ax.annotate(f"stop here: call the top {best * 10}%\n≈ {naira(dec.cumulative.max())} net value", (best, dec.cumulative.max() / 1000),
            xytext=(30, -45), textcoords="offset points", color=GOLD, weight="bold", fontsize=11, arrowprops=dict(arrowstyle="-", color=GOLD))
ax.set_xticks(dec.index, [f"{i}\n{'highest risk' if i == 1 else ('lowest' if i == 10 else '')}" for i in dec.index])
ax.set(title="Who to call: the first deciles pay for themselves; the last ones lose money",
       xlabel="Risk decile (1 = highest predicted churn)", ylabel="₦ thousand (1,500 test subscribers)")
ax.legend(loc="lower left"); save(fig, "5-4", "f01")
