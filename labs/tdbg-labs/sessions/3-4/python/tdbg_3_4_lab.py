# =============================================================================
# TDBG · Session 3.4 LAB · Predicting loan default for a digital microlender (Python)
# Data: data/digital_loans.csv — train = first 4,200 loans; test = last 1,800
# Business assumptions: repaid loan earns N8,000 margin; a default loses N45,000
# =============================================================================
import numpy as np, pandas as pd
import statsmodels.formula.api as smf
from sklearn.metrics import roc_auc_score, confusion_matrix, RocCurveDisplay
import matplotlib.pyplot as plt

d = pd.read_csv("data/digital_loans.csv")
d["log_income"] = np.log(d.monthly_income_naira); d["log_airtime"] = np.log(d.monthly_airtime_naira)
tr, te = d.iloc[:4200].copy(), d.iloc[4200:].copy()
print("base rate:", tr.defaulted.mean())

# ---- 1. Logistic regression ------------------------------------------------------------------
m = smf.logit("defaulted ~ age + salary_earner + log_income + repayment_to_income + tenure_days + prior_loans_repaid"
              " + prior_late_payments + account_age_months + C(phone_os) + log_airtime + bvn_verified"
              " + C(acquisition_channel, Treatment('Organic')) + C(state, Treatment('Lagos'))", tr).fit()
print(m.summary())
print(np.exp(pd.concat([m.params, m.conf_int()], axis=1)).round(2))     # odds ratios with 95% CIs

# ---- 2–3. Predict and evaluate at a threshold -----------------------------------------------------
te["p"] = m.predict(te)
print(confusion_matrix(te.defaulted, (te.p >= 0.5).astype(int)))      # rows = actual, cols = predicted

# ---- 4. ROC / AUC -----------------------------------------------------------------------------------
print("AUC:", roc_auc_score(te.defaulted, te.p))
RocCurveDisplay.from_predictions(te.defaulted, te.p); plt.show()

# ---- 5. Threshold by profit -----------------------------------------------------------------------------
ts = np.arange(0.02, 0.91, 0.01)
profit = [8000 * ((te.defaulted == 0) & (te.p < t)).sum() - 45000 * ((te.defaulted == 1) & (te.p < t)).sum() for t in ts]
print("best threshold:", ts[int(np.argmax(profit))], "profit:", max(profit))

# ---- YOUR TURN ------------------------------------------------------------------------------------------
# (a) Interpret the prior_late_payments odds ratio for the credit committee.
# (b) At the best threshold: approval rate, default rate among approved, profit.
# (c) If loss on default rises to N60,000, how does the best threshold move? Why?
# (d) Which variable could act as a proxy for a protected trait?
