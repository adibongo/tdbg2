# =============================================================================
# TDBG · Practice Paper 2 · Module 2 Practice Paper — PRACTICE PAPER (Python)
# Reproduces Section B outputs and Fig PP2-F01.
# =============================================================================
import sys; sys.path.insert(0, "python")
import numpy as np, pandas as pd
import matplotlib.pyplot as plt
import statsmodels.formula.api as smf
from sklearn.metrics import roc_auc_score, roc_curve, confusion_matrix
from tdbg_style import *
set_style()

# ---- B1 · What explains salary? -------------------------------------------------------
h = pd.read_csv("data/hr_attrition_salary.csv"); h["salary_k"] = h.monthly_salary_naira / 1000
m1 = smf.ols("salary_k ~ tenure_months + engagement_score + C(department, Treatment('Customer Support'))", h).fit()
print(m1.summary())

# ---- B2 · Churn classifier --------------------------------------------------------------
t = pd.read_csv("data/telecom_churn.csv"); tr, te = t.iloc[:3500], t.iloc[3500:].copy()
m2 = smf.logit("churned ~ tenure_months + dropped_calls + complaints + multi_sim + data_gb_month + C(plan, Treatment('Postpaid'))", tr).fit(disp=0)
print(np.exp(m2.params).round(2))
te["p"] = m2.predict(te)
print(confusion_matrix(te.churned, (te.p >= .3).astype(int)))   # rows actual, cols predicted
auc = roc_auc_score(te.churned, te.p); print("AUC", auc)
f, tp, _ = roc_curve(te.churned, te.p)
fig, ax = plt.subplots(figsize=(8, 6)); ax.plot(f, tp, color=TEAL, lw=3); ax.plot([0, 1], [0, 1], ls="--", color=SLATE)
ax.text(.6, .2, f"AUC = {auc:.2f}", fontsize=15)
ax.set(title="Practice B2 · ROC curve of the churn model (test data)", xlabel="False positive rate", ylabel="True positive rate")
save(fig, "pp2", "f01")
