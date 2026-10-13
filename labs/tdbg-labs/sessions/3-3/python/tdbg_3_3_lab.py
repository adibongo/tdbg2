# =============================================================================
# TDBG · Session 3.3 LAB · Forecasting weekly sales for a new beverage SKU (Python)
# Data: data/beverage_sku_sales.csv — train on rows 1–60, test on the other 340
# =============================================================================
import numpy as np, pandas as pd, warnings
warnings.filterwarnings("ignore")   # silence convergence chatter from tiny penalties
from sklearn.linear_model import LinearRegression, LassoCV, RidgeCV
from sklearn.preprocessing import StandardScaler
from sklearn.pipeline import make_pipeline
from sklearn.metrics import mean_squared_error

b = pd.read_csv("data/beverage_sku_sales.csv")
X = pd.get_dummies(b.drop(columns=["sku_week", "weekly_cases"]), drop_first=True).astype(float)
y = b["weekly_cases"]
Xtr, Xte, ytr, yte = X.iloc[:60], X.iloc[60:], y.iloc[:60], y.iloc[60:]
rmse = lambda a, p: np.sqrt(mean_squared_error(a, p))

# ---- 1. Ordinary regression with every driver -------------------------------------------
ols = make_pipeline(StandardScaler(), LinearRegression()).fit(Xtr, ytr)
print(pd.Series(ols[-1].coef_, X.columns).round(1).sort_values())
print("OLS  train", rmse(ytr, ols.predict(Xtr)), " test", rmse(yte, ols.predict(Xte)))

# ---- 2. Lasso: penalty chosen by 5-fold cross-validation -----------------------------------
lasso = make_pipeline(StandardScaler(), LassoCV(cv=5, random_state=1)).fit(Xtr, ytr)
coefs = pd.Series(lasso[-1].coef_, X.columns)
print("lambda:", lasso[-1].alpha_, "| drivers kept:", (coefs != 0).sum())
print(coefs[coefs != 0].round(1).sort_values())
print("Lasso test", rmse(yte, lasso.predict(Xte)))

# ---- 3. Ridge for comparison ------------------------------------------------------------------
ridge = make_pipeline(StandardScaler(), RidgeCV(alphas=np.logspace(-2, 4, 60))).fit(Xtr, ytr)
print("Ridge test", rmse(yte, ridge.predict(Xte)))

# ---- YOUR TURN ---------------------------------------------------------------------------------
# (a) Table: model, drivers used, train RMSE, test RMSE. Which would you deploy?
# (b) Why did OLS give social_impressions_k and its near-duplicate huge opposite coefficients?
# (c) Refit on 300 training weeks (X.iloc[:300]); does lasso still win? Why?
