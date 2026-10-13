# =============================================================================
# TDBG · Session 3.2 LAB · What drives an FMCG distributor's revenue? (Python)
# Data: data/fmcg_distributor_revenue.csv — 240 distributor-months
# =============================================================================
import pandas as pd, numpy as np
import statsmodels.formula.api as smf
import matplotlib.pyplot as plt

f = pd.read_csv("data/fmcg_distributor_revenue.csv")

# ---- 1. Explore relationships first --------------------------------------------------
print(f.select_dtypes("number").corr().round(2))
pd.plotting.scatter_matrix(f[["revenue_m_naira", "ad_spend_m_naira", "active_outlets", "sales_reps", "price_index"]], figsize=(9, 9)); plt.show()

# ---- 2. Simple regression ---------------------------------------------------------------
m1 = smf.ols("revenue_m_naira ~ ad_spend_m_naira", data=f).fit()
print(m1.summary()); print(m1.conf_int())

# ---- 3. Multiple regression (East is the comparison region) ---------------------------------
m2 = smf.ols("revenue_m_naira ~ ad_spend_m_naira + price_index + active_outlets + sales_reps + rainfall_mm"
             " + C(region, Treatment('East'))", data=f).fit()
print(m2.summary())

# ---- 4. Diagnostics -------------------------------------------------------------------------------
fig, ax = plt.subplots(1, 2, figsize=(11, 4))
ax[0].scatter(m2.fittedvalues, m2.resid, alpha=.6); ax[0].axhline(0, color="red"); ax[0].set_title("Residuals vs fitted")
ax[1].hist(m2.resid, bins=25); ax[1].set_title("Residual distribution"); plt.show()

# ---- 5. What-if prediction ----------------------------------------------------------------------
new = pd.DataFrame({"ad_spend_m_naira": [10, 15], "price_index": 100, "active_outlets": 250,
                    "sales_reps": 8, "rainfall_mm": 120, "region": "Lagos"})
print(m2.get_prediction(new).summary_frame(alpha=0.05))   # obs_ci_* = prediction interval

# ---- YOUR TURN ------------------------------------------------------------------------------------
# (a) Interpret the active_outlets coefficient for a sales director.
# (b) Is an extra N5m of advertising worth it at a 25% gross margin?
# (c) One reason the advertising coefficient might NOT be causal.
