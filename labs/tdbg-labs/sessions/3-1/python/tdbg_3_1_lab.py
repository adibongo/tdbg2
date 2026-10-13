# =============================================================================
# TDBG · Session 3.1 LAB · Analyse a fintech onboarding A/B test (Python)
# Data: data/fintech_onboarding_ab.csv — 12,000 users randomised to A or B
# =============================================================================
import numpy as np, pandas as pd
from scipy import stats
from statsmodels.stats.power import NormalIndPower
from statsmodels.stats.proportion import proportion_effectsize, proportions_ztest, confint_proportions_2indep

d = pd.read_csv("data/fintech_onboarding_ab.csv")

# ---- STEP 0 · Plan: baseline 18%, smallest lift worth shipping 2 points ------------------
es = proportion_effectsize(0.20, 0.18)
print("users per group:", NormalIndPower().solve_power(es, alpha=0.05, power=0.80))

# ---- STEP 1 · Sanity checks ---------------------------------------------------------------
print(d.variant.value_counts(), stats.chisquare(d.variant.value_counts()))
print(pd.crosstab(d.device, d.variant, normalize="columns"))

# ---- STEP 2 · Primary metric -----------------------------------------------------------------
g = d.groupby("variant")["completed_onboarding"].agg(["sum", "count", "mean"]); print(g)
xb, nb, xa, na = g.loc["B_simplified", "sum"], g.loc["B_simplified", "count"], g.loc["A_control", "sum"], g.loc["A_control", "count"]
print(proportions_ztest([xb, xa], [nb, na]))
print("95% CI for B - A:", confint_proportions_2indep(xb, nb, xa, na))

# ---- STEP 3 · Guardrails ---------------------------------------------------------------------
print(stats.ttest_ind(d[d.variant == "B_simplified"].support_tickets, d[d.variant == "A_control"].support_tickets))
c = d[d.completed_onboarding == 1]
print(c.groupby("variant")["first_deposit_naira"].agg(["median", "mean"]))
print(stats.mannwhitneyu(c[c.variant == "B_simplified"].first_deposit_naira, c[c.variant == "A_control"].first_deposit_naira))

# ---- STEP 4 · Segments (exploratory) ------------------------------------------------------------
print(d.groupby(["device", "variant"])["completed_onboarding"].agg(["mean", "count"]).unstack())

# ---- STEP 5 · Business value --------------------------------------------------------------------
lift = g.loc["B_simplified", "mean"] - g.loc["A_control", "mean"]
print(f"Extra margin per month: N{lift * 40000 * 2500:,.0f}")

# ---- YOUR TURN --------------------------------------------------------------------------------------
# (a) Ship, don't ship, or extend? 5-sentence memo with the CI.
# (b) Ship to Android and Web only? Why is that risky?
# (c) What if support tickets had risen 30%?
