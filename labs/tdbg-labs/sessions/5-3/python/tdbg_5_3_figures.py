# =============================================================================
# TDBG · Session 5.3 · Operations & People Analytics, and Responsible AI
# Replication script — regenerates every chart in the Session 5.3 deck (Python)
# Data: data/bottling_fill_volumes.csv (40 batches × 5 bottles from a Lagos bottling line; target 500 ml)
#       data/hr_employees.csv          (1,800 employees of a bank; 25% left within the year)
# F04 uses a small inventory simulation generated inside this script (seed 20).
# HR train/test: 70/30 stratified split, random_state = 20.
# =============================================================================
import sys; sys.path.insert(0, "python")
import numpy as np, pandas as pd
import matplotlib.pyplot as plt
from sklearn.model_selection import train_test_split
from sklearn.linear_model import LogisticRegression
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import roc_auc_score
from tdbg_style import *

set_style()
# ============================ PART A · Quality control (SPC) ==================================
q = pd.read_csv("data/bottling_fill_volumes.csv")
LSL, USL, TARGET = 494, 506, 500                                        # specification limits (ml)
g = q.groupby("batch").fill_ml.agg(xbar="mean", R=lambda s: s.max() - s.min())
base = g.loc[1:20]                                                      # Phase I: limits from the first 20 batches
A2, D3, D4 = 0.577, 0, 2.114                                            # control-chart constants for samples of 5
xbb, Rb = base.xbar.mean(), base.R.mean()
UCL, LCL = xbb + A2 * Rb, xbb - A2 * Rb
g["out"] = (g.xbar > UCL) | (g.xbar < LCL)
print(f"centre {xbb:.2f}, LCL {LCL:.2f}, UCL {UCL:.2f}; first out-of-control batch: {g.index[g.out].min()}")

# --- F01 · Run chart of every bottle -------------------------------------------------------------
fig, ax = plt.subplots(figsize=(11, 4.8))
idx = np.arange(1, len(q) + 1)
ax.scatter(idx, q.fill_ml, s=14, color=TEAL, alpha=.7); ax.plot(idx, q.fill_ml, color=TEAL, alpha=.25, lw=1)
ax.axhline(TARGET, color=NAVY, lw=1.5); ax.axhline(LSL, color=RUST, ls="--"); ax.axhline(USL, color=RUST, ls="--")
ax.text(len(q) + 3, LSL, "LSL 494", color=RUST, va="center", clip_on=False); ax.text(len(q) + 3, USL, "USL 506", color=RUST, va="center", clip_on=False); ax.text(len(q) + 3, TARGET, "target", color=NAVY, va="center", clip_on=False)
ax.set(title="200 bottles from Line 2: is anything changing, or is it all just noise?", xlabel="Bottle (in production order)", ylabel="Fill volume (ml)", xlim=(0, 201))
save(fig, "5-3", "f01")

# --- F02 · X-bar control chart -------------------------------------------------------------------
fig, ax = plt.subplots(figsize=(11, 5))
ax.plot(g.index, g.xbar, color=TEAL, marker="o", lw=1.8)
ax.scatter(g.index[g.out], g.xbar[g.out], s=90, color=RUST, zorder=3, label="out of control")
for v, lab, c in [(UCL, f"UCL {UCL:.1f}", RUST), (xbb, f"centre {xbb:.1f}", NAVY), (LCL, f"LCL {LCL:.1f}", RUST)]:
    ax.axhline(v, color=c, ls="--" if c == RUST else "-", lw=1.4); ax.text(41, v, lab, color=c, va="center", clip_on=False)
ax.axvspan(0.5, 20.5, color="#F3F6F9", zorder=0); ax.text(1, UCL + 0.35, "Phase I: limits set from batches 1–20", color=SLATE, fontsize=10)
ax.axvline(27.5, color=GOLD, ls=":"); ax.text(27.8, LCL - 0.3, "something changed here", color=GOLD, fontsize=10, weight="bold")
ax.set(title="X-bar chart: batch averages drift up after batch 27 and escape the control limits", xlabel="Batch (5 bottles each)", ylabel="Average fill (ml)", xlim=(0, 40.6))
ax.legend(loc="lower center"); save(fig, "5-3", "f02")

# --- F03 · Capability: before vs after the shift -------------------------------------------------
before, after = q[q.batch < 28].fill_ml, q[q.batch >= 28].fill_ml
cpk = lambda s: min(USL - s.mean(), s.mean() - LSL) / (3 * s.std())
print(f"Cpk before {cpk(before):.2f}, after {cpk(after):.2f}; mean before {before.mean():.2f}, after {after.mean():.2f}")
fig, ax = plt.subplots(figsize=(10, 5))
bins = np.arange(493, 507.5, 0.75)
ax.hist(before, bins=bins, alpha=.75, color=TEAL, label=f"Batches 1–27: mean {before.mean():.1f} ml, Cpk {cpk(before):.2f}")
ax.hist(after, bins=bins, alpha=.75, color=GOLD, label=f"Batches 28–40: mean {after.mean():.1f} ml, Cpk {cpk(after):.2f}")
for v in (LSL, USL): ax.axvline(v, color=RUST, ls="--")
ax.axvline(TARGET, color=NAVY)
ax.set(title="Process capability: the shift pushes fills towards the upper limit (giveaway)", xlabel="Fill volume (ml)", ylabel="Bottles")
ax.legend(loc="upper left"); save(fig, "5-3", "f03")

# ============================ PART B · Inventory ===============================================
rng = np.random.default_rng(20)
DAYS, MU, SD, LEAD, Q = 180, 120, 40, 6, 600                             # cases/day, lead time days, order quantity
demand = np.maximum(0, rng.normal(MU, SD, DAYS)).round()
def simulate(z):
    rop = MU * LEAD + z * SD * np.sqrt(LEAD); stock, pipeline, level, short = Q + rop, [], [], 0
    for t in range(DAYS):
        stock += sum(qty for (arr, qty) in pipeline if arr == t); pipeline = [(a, q_) for (a, q_) in pipeline if a != t]
        sold = min(stock, demand[t]); short += demand[t] - sold; stock -= sold; level.append(stock)
        if stock + sum(q_ for _, q_ in pipeline) <= rop: pipeline.append((t + LEAD, Q))
    return np.array(level), rop, short
fig, axs = plt.subplots(2, 1, figsize=(11, 6.2), sharex=True)
for ax, (z, lab) in zip(axs, [(0, "No safety stock (reorder point = average lead-time demand)"), (1.65, "Safety stock for 95% service (z = 1.65)")]):
    lv, rop, short = simulate(z); so = (lv == 0).sum()
    ax.fill_between(range(DAYS), lv, color=TEAL, alpha=.35); ax.plot(lv, color=TEAL, lw=1.4)
    ax.axhline(rop, color=GOLD, ls="--"); ax.text(DAYS + 1, rop, f"reorder\npoint {rop:.0f}", color=GOLD, va="center", fontsize=9)
    ax.scatter(np.where(lv == 0)[0], np.zeros(so), color=RUST, s=25, zorder=3)
    ax.set_title(f"{lab}: {so} stock-out days, {short:,.0f} cases lost, average stock {lv.mean():.0f} cases", fontsize=11); ax.set_ylabel("Cases in stock")
    print(lab, "stockout days", so, "lost", short, "avg stock", lv.mean().round())
axs[1].set_xlabel("Day")
fig.suptitle("Inventory: a little safety stock prevents most stock-outs", fontsize=14, color=NAVY, weight="bold")
fig.tight_layout(); save(fig, "5-3", "f04")

# ============================ PART C · People analytics & fairness ===============================
h = pd.read_csv("data/hr_employees.csv")
h["log_salary"] = np.log(h.monthly_salary_naira)
FEATS = ["age", "tenure_years", "log_salary", "engagement_score", "overtime", "years_since_promotion", "commute_minutes", "manager_rating"]
X = pd.concat([h[FEATS], pd.get_dummies(h.department, prefix="dept", drop_first=True).astype(float)], axis=1)   # NOTE: gender is NOT a model input
Xtr, Xte, ytr, yte = train_test_split(X, h.attrited, test_size=0.3, random_state=20, stratify=h.attrited)
sc = StandardScaler().fit(Xtr)
lg = LogisticRegression(max_iter=3000).fit(sc.transform(Xtr), ytr); p = lg.predict_proba(sc.transform(Xte))[:, 1]
print("attrition AUC:", round(roc_auc_score(yte, p), 3))

# --- F05 · What drives attrition? (standardised odds ratios) -------------------------------------
LAB = {"engagement_score": "Engagement score", "manager_rating": "Manager rating", "overtime": "Works overtime", "years_since_promotion": "Years since promotion",
       "commute_minutes": "Commute (minutes)", "log_salary": "Salary (log)", "tenure_years": "Tenure (years)", "age": "Age"}
orr = pd.Series(np.exp(lg.coef_[0]), index=X.columns)
orr = orr[[c for c in X.columns if c in LAB]].rename(LAB).sort_values()
fig, ax = plt.subplots(figsize=(10, 5))
ax.barh(orr.index, orr.values - 1, left=1, color=[RUST if v > 1 else TEAL for v in orr.values])
ax.axvline(1, color=NAVY)
for i, v in enumerate(orr.values): ax.text(v + (0.02 if v > 1 else -0.02), i, f"{v:.2f}", va="center", ha="left" if v > 1 else "right", fontsize=10)
ax.set(title="Attrition drivers: odds ratio for a one-standard-deviation increase", xlabel="Odds ratio (> 1 raises the chance of leaving; < 1 lowers it)", xlim=(0.45, 1.4))
save(fig, "5-3", "f05")

# --- F06 · Fairness audit by gender --------------------------------------------------------------
flag = p >= np.quantile(p, 0.8)                                          # HR will call the top 20% riskiest
aud = pd.DataFrame({"gender": h.loc[Xte.index, "gender"].map({"F": "Women", "M": "Men"}), "y": yte.values, "flag": flag})
res = aud.groupby("gender").apply(lambda d: pd.Series({"Selection rate\n(% flagged)": d.flag.mean() * 100,
                                                      "True positive rate\n(% of leavers flagged)": d.flag[d.y == 1].mean() * 100,
                                                      "False positive rate\n(% of stayers flagged)": d.flag[d.y == 0].mean() * 100,
                                                      "Actual attrition\n(%)": d.y.mean() * 100}), include_groups=False)
print(res.round(1)); print("selection-rate ratio (lower/higher):", round(res.iloc[:, 0].min() / res.iloc[:, 0].max(), 2))
pay = h.groupby("gender").monthly_salary_naira.median(); print("median pay:", pay.to_dict())
fig, ax = plt.subplots(figsize=(11, 5))
x = np.arange(res.shape[1]); w = 0.38
for i, (gname, col) in enumerate([("Men", SLATE), ("Women", GOLD)]):
    vals = res.loc[gname].values; ax.bar(x + (i - .5) * w, vals, w, color=col, label=gname)
    for xi, v in zip(x, vals): ax.text(xi + (i - .5) * w, v + 0.6, f"{v:.0f}%", ha="center", fontsize=10)
ax.set_xticks(x, res.columns); ax.legend()
ax.set(title="Fairness audit: gender is not an input, yet women are flagged more often", ylabel="%")
save(fig, "5-3", "f06")

# --- F07 · Where attrition costs most -----------------------------------------------------------
h["p"] = lg.predict_proba(sc.transform(X))[:, 1]
h["exp_cost"] = h.p * h.monthly_salary_naira * 6                         # replacing someone ≈ 6 months' salary
dc = h.groupby("department").agg(staff=("p", "size"), leavers=("p", "sum"), cost=("exp_cost", "sum")).sort_values("cost")
fig, ax = plt.subplots(figsize=(10, 5))
ax.barh(dc.index, dc.cost / 1e6, color=TEAL)
for i, (c, l, s) in enumerate(zip(dc.cost, dc.leavers, dc.staff)): ax.text(c / 1e6 + 1, i, f"₦{c / 1e6:.0f}m · {l:.0f} expected leavers of {s}", va="center", fontsize=10)
ax.set_xlim(0, dc.cost.max() / 1e6 * 1.5)
ax.set(title="Expected cost of attrition next year by department (replacement ≈ 6 months' salary)", xlabel="₦ million")
save(fig, "5-3", "f07")
print("Session 5.3 figures saved.")
