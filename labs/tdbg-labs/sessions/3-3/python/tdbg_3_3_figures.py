# =============================================================================
# TDBG · Session 3.3 · Regularised Regression & Predictive Sales
# Replication script — regenerates every chart in the Session 3.3 deck (Python)
# Data: data/beverage_sku_sales.csv — 400 SKU-weeks, 24 candidate drivers
#       (10 of them pure noise, 1 near-duplicate — just like real feature lists)
# Scenario: a NEW SKU with only 60 weeks of history. Train = first 60 rows,
#           test = the remaining 340 rows (identical split in R and Python).
# Note: cross-validation folds and F07 resampling are random; R and Python differ slightly.
# =============================================================================
import sys; sys.path.insert(0, "python")
import numpy as np, pandas as pd, warnings
import matplotlib.pyplot as plt
from sklearn.linear_model import LinearRegression, LassoCV, RidgeCV, lasso_path
from sklearn.preprocessing import StandardScaler
from sklearn.pipeline import make_pipeline
from sklearn.metrics import mean_squared_error
from tdbg_style import *
warnings.filterwarnings("ignore")

set_style()
b = pd.read_csv("data/beverage_sku_sales.csv")
X = pd.get_dummies(b.drop(columns=["sku_week", "weekly_cases"]), drop_first=True).astype(float)
y = b["weekly_cases"]
Xtr, Xte, ytr, yte = X.iloc[:60], X.iloc[60:], y.iloc[:60], y.iloc[60:]
rmse = lambda a, p: np.sqrt(mean_squared_error(a, p))

# --- F01 · Overfitting in one picture ---------------------------------------------------
s = b.iloc[:30]; xs = np.linspace(s.price_naira.min(), s.price_naira.max(), 200)
fig, axes = plt.subplots(1, 3, figsize=(13, 4.4), sharey=True)
for ax, deg, ttl in zip(axes, [1, 3, 12], ["Degree 1: too simple (underfit)", "Degree 3: about right", "Degree 12: memorises noise (overfit)"]):
    z = (s.price_naira - s.price_naira.mean()) / s.price_naira.std(); zz = (xs - s.price_naira.mean()) / s.price_naira.std()
    coef = np.polyfit(z, s.weekly_cases, deg); ax.scatter(s.price_naira, s.weekly_cases, color=TEAL, s=30)
    ax.plot(xs, np.clip(np.polyval(coef, zz), 500, 2500), color=RUST if deg == 12 else GOLD, lw=2.5); ax.set_title(ttl, fontsize=13)
    ax.set_xlabel("Price (₦)")
axes[0].set_ylabel("Weekly cases"); axes[0].set_ylim(700, 2300)
fig.tight_layout()
save(fig, "3-3", "f01")

# --- F02 · Training vs test error as complexity grows (the U-curve) ------------------------
feats = ["distribution_pct", "price_naira", "promo_depth_pct", "festive_week", "shelf_facings", "competitor_price", "temperature_c",
         "social_impressions_k", "radio_grp"] + [c for c in X.columns if c.startswith("noise")] + ["social_impressions_k_dup", "school_term"] + [c for c in X.columns if c.startswith("region")]
tr_e, te_e = [], []
ks = range(1, len(feats) + 1)
for k in ks:
    m = LinearRegression().fit(Xtr[feats[:k]], ytr)
    tr_e.append(rmse(ytr, m.predict(Xtr[feats[:k]]))); te_e.append(rmse(yte, m.predict(Xte[feats[:k]])))
fig, ax = plt.subplots()
ax.plot(ks, tr_e, color=TEAL, lw=3, label="Error on training weeks (looks better and better)")
ax.plot(ks, te_e, color=RUST, lw=3, label="Error on new weeks (the one that matters)")
best = int(np.argmin(te_e)) + 1; ax.axvline(best, color=SLATE, ls="--"); ax.text(best + .3, max(te_e) * .95, f"sweet spot ≈ {best} drivers", color=SLATE)
ax.set(title="More drivers always fit the past better — but can predict the future worse", xlabel="Number of drivers in the model (real drivers first, then noise)", ylabel="RMSE (cases per week)")
ax.legend()
save(fig, "3-3", "f02")

# --- F03 · How 5-fold cross-validation works --------------------------------------------------
fig, ax = plt.subplots(figsize=(11, 4.6))
for r in range(5):
    for c in range(5):
        ax.add_patch(plt.Rectangle((c * 1.05, 4 - r), 1, .75, color=GOLD if c == r else TEAL))
        ax.text(c * 1.05 + .5, 4 - r + .37, "validate" if c == r else "train", ha="center", va="center", color="white", fontsize=12, fontweight="bold")
    ax.text(5.4, 4 - r + .37, f"Round {r + 1} → error {r + 1}", va="center", fontsize=13, color=NAVY)
ax.text(5.4, -.5, "CV error = average of the 5 errors", fontsize=13, color=RUST, fontweight="bold")
ax.set_xlim(-.2, 8.2); ax.set_ylim(-.9, 5); ax.axis("off")
ax.set_title("5-fold cross-validation: every week is used for testing exactly once")
save(fig, "3-3", "f03")

# --- F04 · Lasso coefficient path ---------------------------------------------------------------
sc = StandardScaler().fit(Xtr); Z = sc.transform(Xtr)
alphas, coefs, _ = lasso_path(Z, ytr - ytr.mean(), n_alphas=100)
fig, ax = plt.subplots()
real = ["distribution_pct", "price_naira", "promo_depth_pct", "festive_week", "shelf_facings", "competitor_price", "temperature_c"]
for j, c in enumerate(X.columns):
    is_real = c in real
    ax.plot(np.log10(alphas), coefs[j], color=TEAL if is_real else "#C9D2DB", lw=2.2 if is_real else 1)
    if is_real: ax.text(np.log10(alphas)[-1] - .05, coefs[j][-1], c.replace("_naira", "").replace("_pct", " %"), fontsize=9, ha="right", va="center", color=NAVY)
ax.invert_xaxis()
ax.set(title="Lasso path: as the penalty relaxes (right), drivers enter one by one — noise last",
       xlabel="log₁₀(penalty λ)  ←  stronger            weaker  →", ylabel="Standardised coefficient")
save(fig, "3-3", "f04")

# --- F05 · Choosing λ by cross-validation -------------------------------------------------------
lcv = make_pipeline(StandardScaler(), LassoCV(cv=5, random_state=1, alphas=100)).fit(Xtr, ytr)
L = lcv[-1]; mse = L.mse_path_.mean(1); se = L.mse_path_.std(1) / np.sqrt(5)
fig, ax = plt.subplots()
ax.errorbar(np.log10(L.alphas_), np.sqrt(mse), yerr=se / (2 * np.sqrt(mse)), color=TEAL, ecolor="#C9D2DB", fmt="o", ms=4)
ax.axvline(np.log10(L.alpha_), color=GOLD, lw=2.5); ax.text(np.log10(L.alpha_) + .05, np.sqrt(mse).max() * .95, f"best λ = {L.alpha_:.1f}", color=GOLD, fontsize=13)
ax.set(title="Cross-validation picks the penalty with the lowest out-of-sample error", xlabel="log₁₀(penalty λ)", ylabel="CV RMSE (cases per week)")
save(fig, "3-3", "f05")

# --- F06 · OLS vs lasso coefficients (60 training weeks) ------------------------------------------
ols = make_pipeline(StandardScaler(), LinearRegression()).fit(Xtr, ytr)
co = pd.DataFrame({"OLS": ols[-1].coef_, "Lasso": L.coef_}, index=X.columns).sort_values("OLS")
fig, ax = plt.subplots(figsize=(10, 7))
yy = np.arange(len(co))
ax.barh(yy + .2, co.OLS, .4, color="#B8C7D3", label="Ordinary regression (OLS)")
ax.barh(yy - .2, co.Lasso, .4, color=TEAL, label="Lasso")
ax.set_yticks(yy, co.index, fontsize=10); ax.axvline(0, color=INK, lw=.8); ax.legend(loc="lower right")
ax.set(title=f"Lasso sets {int((co.Lasso == 0).sum())} of {len(co)} coefficients to exactly zero — mostly the noise", xlabel="Standardised coefficient (cases per week per SD)")
save(fig, "3-3", "f06")

# --- F07 · When does regularisation pay? (learning curve) -------------------------------------------
rng = np.random.default_rng(9); pool, test = np.arange(300), np.arange(300, 400); sizes = [35, 50, 80, 150, 300]
res = {k: [] for k in ["OLS", "Ridge", "Lasso"]}
for n in sizes:
    acc = {k: [] for k in res}
    for rep in range(15):
        tr = rng.choice(pool, n, replace=False)
        for k, m in [("OLS", make_pipeline(StandardScaler(), LinearRegression())), ("Ridge", make_pipeline(StandardScaler(), RidgeCV(alphas=np.logspace(-2, 4, 60)))),
                     ("Lasso", make_pipeline(StandardScaler(), LassoCV(cv=5, random_state=1)))]:
            m.fit(X.iloc[tr], y.iloc[tr]); acc[k].append(rmse(y.iloc[test], m.predict(X.iloc[test])))
    for k in res: res[k].append(np.mean(acc[k]))
fig, ax = plt.subplots()
for k, c in zip(res, [SLATE, GOLD, TEAL]): ax.plot(sizes, res[k], "o-", color=c, lw=2.5, label=k)
ax.set(title="Regularisation helps most when history is short", xlabel="Training weeks available", ylabel="Test RMSE (cases per week)"); ax.legend()
save(fig, "3-3", "f07")

# --- F08 · Test-set accuracy of the lasso model --------------------------------------------------------
p = lcv.predict(Xte); po = ols.predict(Xte)
fig, ax = plt.subplots()
ax.scatter(p, yte, color=TEAL, alpha=.6, s=22)
lims = [850, 2100]; ax.plot(lims, lims, color=GOLD, lw=2.5)
ax.text(880, 1950, f"Lasso test RMSE = {rmse(yte, p):.0f} cases\nOLS test RMSE   = {rmse(yte, po):.0f} cases\n(trained on 60 weeks, tested on 340)", fontsize=12, color=NAVY)
ax.set(title="Predicting 340 unseen weeks", xlabel="Predicted weekly cases", ylabel="Actual weekly cases")
save(fig, "3-3", "f08")
print("lasso alpha", L.alpha_, "test rmse lasso", rmse(yte, p), "ols", rmse(yte, po), "zeros", (L.coef_ == 0).sum())
