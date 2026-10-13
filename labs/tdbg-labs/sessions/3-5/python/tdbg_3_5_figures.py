# =============================================================================
# TDBG · Session 3.5 · Trees, Random Forests & Gradient Boosting
# Replication script — regenerates every chart in the Session 3.5 deck (Python)
# Data: data/digital_loans.csv — train = first 4,200 loans, test = last 1,800
# Note: forests and boosting use randomness; R and Python results differ slightly.
# =============================================================================
import sys; sys.path.insert(0, "python")
import numpy as np, pandas as pd, warnings
import matplotlib.pyplot as plt
import statsmodels.formula.api as smf
from sklearn.tree import DecisionTreeClassifier, plot_tree
from sklearn.ensemble import RandomForestClassifier, HistGradientBoostingClassifier
from sklearn.inspection import permutation_importance, partial_dependence
from sklearn.metrics import roc_auc_score, roc_curve
from tdbg_style import *
warnings.filterwarnings("ignore")

set_style()
d = pd.read_csv("data/digital_loans.csv")
X = pd.get_dummies(d.drop(columns=["loan_id", "defaulted"]), drop_first=True).astype(float); y = d.defaulted
Xtr, Xte, ytr, yte = X.iloc[:4200], X.iloc[4200:], y.iloc[:4200], y.iloc[4200:]
GOOD, BAD = 8000, 45000

# Models ------------------------------------------------------------------------------
d["log_income"] = np.log(d.monthly_income_naira); d["log_airtime"] = np.log(d.monthly_airtime_naira)
lr = smf.logit("defaulted ~ age + salary_earner + log_income + repayment_to_income + tenure_days + prior_loans_repaid"
               " + prior_late_payments + account_age_months + C(phone_os) + log_airtime + bvn_verified"
               " + C(acquisition_channel, Treatment('Organic')) + C(state, Treatment('Lagos'))", d.iloc[:4200]).fit(disp=0)
p = {"Logistic regression": lr.predict(d.iloc[4200:]).values}
tree = DecisionTreeClassifier(max_depth=4, min_samples_leaf=50, random_state=0).fit(Xtr, ytr); p["Decision tree (depth 4)"] = tree.predict_proba(Xte)[:, 1]
rf = RandomForestClassifier(n_estimators=500, min_samples_leaf=10, max_features="sqrt", random_state=0, n_jobs=-1).fit(Xtr, ytr); p["Random forest"] = rf.predict_proba(Xte)[:, 1]
gb = HistGradientBoostingClassifier(max_iter=300, learning_rate=.05, max_leaf_nodes=15, random_state=0).fit(Xtr, ytr); p["Gradient boosting"] = gb.predict_proba(Xte)[:, 1]
auc = {k: roc_auc_score(yte, v) for k, v in p.items()}; print(auc)

# --- F01 · A small decision tree -------------------------------------------------------
small = DecisionTreeClassifier(max_depth=3, min_samples_leaf=80, random_state=0).fit(Xtr, ytr)
fig, ax = plt.subplots(figsize=(14, 6.6))
plot_tree(small, feature_names=X.columns, class_names=["repaid", "default"], filled=True, rounded=True, impurity=False, proportion=True, precision=2, fontsize=10, ax=ax)
ax.set_title("A decision tree is a sequence of yes/no questions — read from the top", loc="left")
save(fig, "3-5", "f01")

# --- F02 · How a tree carves up the data (two drivers) -------------------------------------
two = DecisionTreeClassifier(max_depth=3, min_samples_leaf=60, random_state=0).fit(Xtr[["repayment_to_income", "prior_late_payments"]], ytr)
gx, gy = np.meshgrid(np.linspace(0, 1.6, 300), np.linspace(-.5, 5.5, 300))
zz = two.predict_proba(pd.DataFrame({"repayment_to_income": gx.ravel(), "prior_late_payments": gy.ravel()}))[:, 1].reshape(gx.shape)
fig, ax = plt.subplots()
cs = ax.contourf(gx, gy, zz, levels=10, cmap="YlOrRd", alpha=.8); fig.colorbar(cs, ax=ax, label="Predicted default rate")
s = d.iloc[:4200].sample(800, random_state=1)
ax.scatter(s.repayment_to_income, s.prior_late_payments + np.random.default_rng(2).uniform(-.25, .25, len(s)), c=np.where(s.defaulted == 1, RUST, NAVY), s=8, alpha=.6)
ax.set(title="A tree splits the space into boxes, each with its own default rate", xlabel="Repayment ÷ income", ylabel="Prior late payments (jittered)")
save(fig, "3-5", "f02")

# --- F03 · Tree depth: training vs test AUC -----------------------------------------------
depths = range(1, 16); tra, tea = [], []
for k in depths:
    t = DecisionTreeClassifier(max_depth=k, random_state=0).fit(Xtr, ytr)
    tra.append(roc_auc_score(ytr, t.predict_proba(Xtr)[:, 1])); tea.append(roc_auc_score(yte, t.predict_proba(Xte)[:, 1]))
fig, ax = plt.subplots()
ax.plot(depths, tra, color=TEAL, lw=3, label="Training AUC"); ax.plot(depths, tea, color=RUST, lw=3, label="Test AUC")
ax.axhline(auc["Random forest"], color=GOLD, ls="--", lw=2); ax.text(9.3, auc["Random forest"] + .01, "random forest (test)", color=GOLD)
ax.set(title="A single deep tree memorises the training data", xlabel="Maximum tree depth", ylabel="AUC"); ax.legend(loc="lower left")
save(fig, "3-5", "f03")

# --- F04 · More trees, more stable forest -----------------------------------------------------
ns = [1, 5, 10, 25, 50, 100, 200, 500]; aa = []
for n in ns:
    m = RandomForestClassifier(n_estimators=n, min_samples_leaf=10, random_state=0, n_jobs=-1).fit(Xtr, ytr); aa.append(roc_auc_score(yte, m.predict_proba(Xte)[:, 1]))
fig, ax = plt.subplots()
ax.plot(ns, aa, "o-", color=TEAL, lw=3, ms=8); ax.set_xscale("log")
ax.set_xticks(ns, [str(n) for n in ns])
ax.set(title="The 'wisdom of crowds': averaging many trees beats any one", xlabel="Number of trees in the forest (log scale)", ylabel="Test AUC")
save(fig, "3-5", "f04")

# --- F05 · ROC comparison --------------------------------------------------------------------
fig, ax = plt.subplots(figsize=(8, 6.5))
for (k, v), c in zip(p.items(), [SLATE, SKY, TEAL, GOLD]):
    f, t, _ = roc_curve(yte, v); ax.plot(f, t, color=c, lw=2.5, label=f"{k} (AUC {auc[k]:.3f})")
ax.plot([0, 1], [0, 1], ls=":", color=SLATE)
ax.set(title="Ensembles rank risk better than single models", xlabel="False positive rate", ylabel="True positive rate"); ax.legend(loc="lower right", fontsize=11)
save(fig, "3-5", "f05")

# --- F06 · Permutation importance (random forest, test data) -----------------------------------
pi = permutation_importance(rf, Xte, yte, scoring="roc_auc", n_repeats=10, random_state=0, n_jobs=-1)
imp = pd.Series(pi.importances_mean, X.columns).sort_values().tail(10)
fig, ax = plt.subplots()
ax.barh(imp.index, imp.values, color=[GOLD if v == imp.max() else TEAL for v in imp.values])
ax.set(title="What the forest relies on: drop in test AUC when each driver is scrambled", xlabel="Permutation importance (AUC lost)")
save(fig, "3-5", "f06")

# --- F07 · Partial dependence: the affordability threshold ---------------------------------------
pdp = partial_dependence(rf, Xtr, ["repayment_to_income"], grid_resolution=40, percentiles=(.02, .98))
gridv = pdp["grid_values"][0]; avg = pdp["average"][0]
fig, ax = plt.subplots()
ax.plot(gridv, avg, color=TEAL, lw=3.5)
ax.axvline(.55, color=GOLD, ls="--"); ax.text(.57, avg.min() + .01, "risk jumps\naround 0.55", color=GOLD, fontsize=12)
ax.yaxis.set_major_formatter(plt.FuncFormatter(lambda v, p: f"{v:.0%}"))
ax.set(title="Partial dependence: average predicted default as affordability worsens", xlabel="Repayment ÷ income", ylabel="Average predicted default probability")
save(fig, "3-5", "f07")

# --- F08 · Profit at the best threshold, by model ---------------------------------------------------
best = {}
for k, v in p.items():
    ts = np.linspace(.02, .9, 89)
    prof = [GOOD * ((yte.values == 0) & (v < t)).sum() - BAD * ((yte.values == 1) & (v < t)).sum() for t in ts]
    best[k] = max(prof) / 1e6
fig, ax = plt.subplots()
b = ax.bar(list(best), list(best.values()), color=[SLATE, SKY, TEAL, GOLD])
ax.bar_label(b, labels=[f"₦{v:.1f}m" for v in best.values()], padding=3, fontsize=13)
ax.set(title="Better ranking, more profit: best-threshold profit on 1,800 test applications", ylabel="Profit (₦ million)")
plt.xticks(fontsize=11)
save(fig, "3-5", "f08")
print(best)
