# =============================================================================
# TDBG · Practice Paper 1 · Module 1 Practice Paper — PRACTICE PAPER (Python)
# Reproduces every output used in Section B, plus Fig PP1-F01 and PP1-F02.
# Data: data/hr_attrition_salary.csv — 300 employees of a Lagos services firm
# =============================================================================
import sys; sys.path.insert(0, "python")
import numpy as np, pandas as pd
import matplotlib.pyplot as plt
from matplotlib.ticker import FuncFormatter
from scipy import stats
from tdbg_style import *

set_style()
h = pd.read_csv("data/hr_attrition_salary.csv")

# ---- B1 · Describe monthly salary ---------------------------------------------------
s = h["monthly_salary_naira"]
print(s.describe()); print("95% CI:", stats.t.interval(.95, len(s) - 1, s.mean(), stats.sem(s)))
fig, ax = plt.subplots()
ax.hist(s, bins=30, color=TEAL, edgecolor="white")
ax.axvline(s.median(), color=GOLD, lw=2.5, label=f"median ₦{s.median():,.0f}")
ax.axvline(s.mean(), color=RUST, lw=2.5, ls="--", label=f"mean ₦{s.mean():,.0f}")
ax.xaxis.set_major_formatter(FuncFormatter(naira)); ax.legend()
ax.set(title="Practice B1 · Monthly salary of 300 employees", xlabel="Monthly salary", ylabel="Employees")
save(fig, "pp1", "f01")

# ---- B2 · Do leavers have lower engagement? ---------------------------------------------
print(h.groupby("attrited")["engagement_score"].agg(["mean", "std", "count"]))
print(stats.ttest_ind(h[h.attrited == 0].engagement_score, h[h.attrited == 1].engagement_score, equal_var=False))
fig, ax = plt.subplots()
data = [h[h.attrited == 0].engagement_score, h[h.attrited == 1].engagement_score]
ax.boxplot(data, widths=.5, patch_artist=True, boxprops=dict(facecolor="#D6E6EF", edgecolor=TEAL), medianprops=dict(color=TEAL, lw=2))
ax.plot([1, 2], [d.mean() for d in data], "o", color=GOLD, ms=10, label="mean")
ax.set_xticks([1, 2], ["Stayed", "Left"]); ax.legend()
ax.set(title="Practice B2 · Engagement score by attrition status", ylabel="Engagement score (1–10)")
save(fig, "pp1", "f02")

# ---- B3 · Is attrition related to department? ----------------------------------------------
tab = pd.crosstab(h.department, h.attrited); print(tab); print(pd.crosstab(h.department, h.attrited, normalize="index"))
chi2, p, dof, exp = stats.chi2_contingency(tab)
print(f"chi2 = {chi2:.3f}, df = {dof}, p = {p:.4f}"); print("expected counts:\n", np.round(exp, 1))
