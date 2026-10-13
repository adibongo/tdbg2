# =============================================================================
# TDBG · Session 3.5 LAB · Can ensembles beat the logistic credit score? (Python)
# Data: data/digital_loans.csv — train = first 4,200 loans; test = last 1,800
# =============================================================================
import numpy as np, pandas as pd
import matplotlib.pyplot as plt
from sklearn.tree import DecisionTreeClassifier, plot_tree, export_text
from sklearn.ensemble import RandomForestClassifier, HistGradientBoostingClassifier
from sklearn.inspection import permutation_importance
from sklearn.metrics import roc_auc_score

d = pd.read_csv("data/digital_loans.csv")
X = pd.get_dummies(d.drop(columns=["loan_id", "defaulted"]), drop_first=True).astype(float); y = d.defaulted
Xtr, Xte, ytr, yte = X.iloc[:4200], X.iloc[4200:], y.iloc[:4200], y.iloc[4200:]

# ---- 1. A single decision tree --------------------------------------------------------------
tree = DecisionTreeClassifier(max_depth=4, min_samples_leaf=50, random_state=0).fit(Xtr, ytr)
print(export_text(tree, feature_names=list(X.columns)))     # the rules as text
p_tree = tree.predict_proba(Xte)[:, 1]

# ---- 2. Random forest -----------------------------------------------------------------------------
rf = RandomForestClassifier(n_estimators=500, min_samples_leaf=10, random_state=0, n_jobs=-1).fit(Xtr, ytr)
p_rf = rf.predict_proba(Xte)[:, 1]
pi = permutation_importance(rf, Xte, yte, scoring="roc_auc", n_repeats=10, random_state=0, n_jobs=-1)
print(pd.Series(pi.importances_mean, X.columns).sort_values(ascending=False).head(10))

# ---- 3. Gradient boosting ----------------------------------------------------------------------------
gb = HistGradientBoostingClassifier(max_iter=300, learning_rate=0.05, max_leaf_nodes=15, random_state=0).fit(Xtr, ytr)
p_gb = gb.predict_proba(Xte)[:, 1]

# ---- 4. Compare AUC on the same test loans ---------------------------------------------------------------
print({k: round(roc_auc_score(yte, v), 3) for k, v in {"tree": p_tree, "forest": p_rf, "boosting": p_gb}.items()})

# ---- 5. Best-threshold profit ------------------------------------------------------------------------------
def profit(p):
    return max(8000 * ((yte == 0) & (p < t)).sum() - 45000 * ((yte == 1) & (p < t)).sum() for t in np.arange(.02, .91, .01))
print({k: profit(v) for k, v in {"tree": p_tree, "forest": p_rf, "boosting": p_gb}.items()})

# ---- YOUR TURN -----------------------------------------------------------------------------------------------
# (a) Write the tree's top three rules as plain-English credit policy.
# (b) Try n_estimators=100 vs 1000 and min_samples_leaf=5 vs 50. Effect on test AUC?
# (c) Forest vs explainable model at a regulated lender: which would you deploy, and why?
