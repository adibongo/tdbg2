# =============================================================================
# TDBG · Session 4.1 LAB · Score and explain B2B leads for a sales director (Python)
# Data: data/b2b_leads.csv — train = first 1,750 leads; test = last 750
# pip install xgboost shap
# =============================================================================
import numpy as np, pandas as pd
import xgboost as xgb, shap
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import roc_auc_score

d = pd.read_csv("data/b2b_leads.csv")
X = pd.get_dummies(d.drop(columns=["lead_id", "converted"])).astype(float); y = d.converted
tr = np.arange(len(d)) < 1750

# ---- 1. Two candidate models ---------------------------------------------------------------
lr = LogisticRegression(max_iter=5000).fit(X[tr], y[tr])
xg = xgb.XGBClassifier(n_estimators=300, max_depth=3, learning_rate=.05, subsample=.8, colsample_bytree=.8, random_state=1).fit(X[tr], y[tr])
p_lr, p_xg = lr.predict_proba(X[~tr])[:, 1], xg.predict_proba(X[~tr])[:, 1]
print("AUC logistic", roc_auc_score(y[~tr], p_lr), " xgboost", roc_auc_score(y[~tr], p_xg))

# ---- 2. Global explanation with SHAP ---------------------------------------------------------
explainer = shap.TreeExplainer(xg)
sv = explainer(X[~tr])
shap.plots.bar(sv)            # mean |SHAP| per driver
shap.plots.beeswarm(sv)       # direction and spread

# ---- 3. Local explanation: the hottest lead -------------------------------------------------------
i = int(np.argmax(p_xg))
print(d[~tr].iloc[i])
shap.plots.waterfall(sv[i])   # why this lead scored so high

# ---- 4. Lead grades and cumulative gains ------------------------------------------------------------
grade = pd.qcut(p_xg, [0, .5, .8, .95, 1], labels=["D", "C", "B", "A"])
print(pd.DataFrame({"grade": grade, "converted": y[~tr].values}).groupby("grade", observed=True)["converted"].agg(["mean", "count"]))
o = np.argsort(-p_xg); cum = y[~tr].values[o].cumsum() / y[~tr].sum()
print("share of conversions in top 30%:", cum[int(.3 * len(o)) - 1])

# ---- YOUR TURN ------------------------------------------------------------------------------------------
# (a) 3-line explanation of the hottest lead for the account manager.
# (b) Logistic is as accurate as XGBoost here — which would you deploy, and why?
# (c) Sales can call 200 leads a week: expected conversions using the grades?
