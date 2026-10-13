# =============================================================================
# TDBG · Session 5.3 LAB · Is the line in control, and is our attrition model fair? (Python)
# Data: data/bottling_fill_volumes.csv, data/hr_employees.csv
# pip install pandas numpy scipy scikit-learn matplotlib   # once
# =============================================================================
import numpy as np, pandas as pd
import matplotlib.pyplot as plt
from scipy.stats import norm
from sklearn.model_selection import train_test_split
from sklearn.linear_model import LogisticRegression
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import roc_auc_score

# ---- PART A · Control chart for the bottling line ------------------------------------------------------
q = pd.read_csv("data/bottling_fill_volumes.csv")                   # 40 batches x 5 bottles; target 500 ml
g = q.groupby("batch").fill_ml.agg(xbar="mean", R=lambda s: s.max() - s.min())
base = g.loc[1:20]                                                  # set limits while the process was stable
A2 = 0.577                                                          # constant for samples of 5 (from SPC tables)
centre = base.xbar.mean(); UCL = centre + A2 * base.R.mean(); LCL = centre - A2 * base.R.mean()
print(f"LCL {LCL:.2f} | centre {centre:.2f} | UCL {UCL:.2f}")
print(g[(g.xbar > UCL) | (g.xbar < LCL)])                           # which batches are out of control?
plt.plot(g.index, g.xbar, marker="o"); [plt.axhline(v, ls=ls, color=c) for v, ls, c in [(LCL, "--", "red"), (centre, "-", "black"), (UCL, "--", "red")]]
plt.xlabel("Batch"); plt.ylabel("Average fill (ml)"); plt.show()

# Capability: can the process meet the 494–506 ml specification?
cpk = lambda s: min(506 - s.mean(), s.mean() - 494) / (3 * s.std())
print("Cpk before:", round(cpk(q.fill_ml[q.batch < 28]), 2), "| after:", round(cpk(q.fill_ml[q.batch >= 28]), 2), "(1.33+ is the usual target)")

# ---- PART B · Reorder point with safety stock -------------------------------------------------------------
mu, sigma, lead = 120, 40, 6                                        # daily demand (cases) and lead time (days)
z = norm.ppf(0.95)                                                  # 95% service level -> z = 1.65
safety = z * sigma * np.sqrt(lead); reorder_point = mu * lead + safety
print(f"safety stock {safety:.0f} cases | reorder point {reorder_point:.0f} cases")

# ---- PART C · Attrition model -----------------------------------------------------------------------------
h = pd.read_csv("data/hr_employees.csv"); h["log_salary"] = np.log(h.monthly_salary_naira)
print("attrition rate:", h.attrited.mean().round(3))
FEATS = ["age", "tenure_years", "log_salary", "engagement_score", "overtime", "years_since_promotion", "commute_minutes", "manager_rating"]
X = pd.concat([h[FEATS], pd.get_dummies(h.department, drop_first=True).astype(float)], axis=1)   # gender deliberately left out
Xtr, Xte, ytr, yte = train_test_split(X, h.attrited, test_size=0.3, random_state=20, stratify=h.attrited)
sc = StandardScaler().fit(Xtr)
fit = LogisticRegression(max_iter=3000).fit(sc.transform(Xtr), ytr)
print(pd.Series(np.exp(fit.coef_[0]), index=X.columns).round(2))   # odds ratio per 1 SD
p = fit.predict_proba(sc.transform(Xte))[:, 1]
print("AUC:", round(roc_auc_score(yte, p), 3))

# ---- PART D · Fairness audit --------------------------------------------------------------------------------
aud = pd.DataFrame({"gender": h.loc[Xte.index, "gender"], "y": yte.values, "flag": p >= np.quantile(p, 0.8)})   # HR calls the top 20%
print(aud.groupby("gender").apply(lambda d: pd.Series({"selection_rate": d.flag.mean(), "true_pos_rate": d.flag[d.y == 1].mean(),
                                                       "false_pos_rate": d.flag[d.y == 0].mean(), "actual_attrition": d.y.mean()}),
                                  include_groups=False).round(3))
print(h.groupby("gender").monthly_salary_naira.median())          # a possible reason: the pay gap

# ---- YOUR TURN ------------------------------------------------------------------------------------------
# (a) The line manager says batch 31 was "just bad luck". Use the control chart to reply.
# (b) What happens to safety stock if the supplier's lead time rises from 6 to 10 days?
# (c) Calculate the selection-rate ratio (women vs men). Does it pass the 'four-fifths' (0.8) rule?
#     Is the model unfair, or is it reflecting something real (the pay gap)? What should HR do?
