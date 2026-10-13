# =============================================================================
# TDBG · Session 3.2 · Correlation & Linear Regression
# Replication script — regenerates every chart in the Session 3.2 deck (Python)
# Data: data/fmcg_distributor_revenue.csv — 240 distributor-months for an FMCG firm
# Note: F02 uses simulated data; R and Python draw different random numbers.
# =============================================================================
import sys; sys.path.insert(0, "python")
import numpy as np, pandas as pd
import matplotlib.pyplot as plt
import statsmodels.formula.api as smf
from tdbg_style import *

set_style()
f = pd.read_csv("data/fmcg_distributor_revenue.csv")
simple = smf.ols("revenue_m_naira ~ ad_spend_m_naira", data=f).fit()
full = smf.ols("revenue_m_naira ~ ad_spend_m_naira + price_index + active_outlets + sales_reps + rainfall_mm + C(region, Treatment('East'))", data=f).fit()

# --- F01 · Simple regression: revenue vs advertising --------------------------------
fig, ax = plt.subplots()
ax.scatter(f.ad_spend_m_naira, f.revenue_m_naira, color=TEAL, alpha=.6, s=30)
xs = np.linspace(f.ad_spend_m_naira.min(), f.ad_spend_m_naira.max(), 50)
ax.plot(xs, simple.params.iloc[0] + simple.params.iloc[1] * xs, color=GOLD, lw=3)
r = f[["ad_spend_m_naira", "revenue_m_naira"]].corr().iloc[0, 1]
ax.text(2.2, 118, f"revenue = {simple.params.iloc[0]:.1f} + {simple.params.iloc[1]:.2f} × ad spend\nr = {r:.2f}   R² = {simple.rsquared:.2f}",
        fontsize=13, color=NAVY, bbox=dict(facecolor="white", edgecolor=GRID))
ax.set(title="Each extra ₦1m of advertising goes with about ₦1.8m more revenue", xlabel="Advertising spend (₦ million / month)", ylabel="Revenue (₦ million / month)")
save(fig, "3-2", "f01")

# --- F02 · What correlation does and does not capture ----------------------------------
rng = np.random.default_rng(8); n = 150
x = rng.normal(0, 1, n)
panels = [("r ≈ +0.9 strong positive", x, .9 * x + rng.normal(0, .45, n)),
          ("r ≈ +0.4 weak positive", x, .4 * x + rng.normal(0, .9, n)),
          ("r ≈ 0 no linear link", x, rng.normal(0, 1, n)),
          ("r ≈ −0.7 negative", x, -.7 * x + rng.normal(0, .7, n)),
          ("r ≈ 0 but strong curve!", x, x ** 2 + rng.normal(0, .3, n)),
          ("one outlier creates a high r!", np.append(rng.normal(0, .3, 30), 4), np.append(rng.normal(0, .3, 30), 4))]
fig, axes = plt.subplots(2, 3, figsize=(12, 7))
for ax, (ttl, a, b) in zip(axes.flat, panels):
    ax.scatter(a, b, color=RUST if "!" in ttl or "outlier" in ttl else TEAL, s=18, alpha=.7)
    ax.set_title(f"{ttl}\n(computed r = {np.corrcoef(a, b)[0, 1]:.2f})", fontsize=12); ax.set_xticks([]); ax.set_yticks([])
fig.suptitle("Correlation measures straight-line association only — always plot the data", x=.01, ha="left", color=NAVY, fontweight="bold")
fig.tight_layout()
save(fig, "3-2", "f02")

# --- F03 · Least squares: the line that minimises squared errors -----------------------
sub = f.sample(25, random_state=3)
fig, ax = plt.subplots()
pred = simple.predict(sub)
for xx, yy, pp in zip(sub.ad_spend_m_naira, sub.revenue_m_naira, pred):
    ax.plot([xx, xx], [yy, pp], color=RUST, lw=1.5, alpha=.8)
ax.scatter(sub.ad_spend_m_naira, sub.revenue_m_naira, color=TEAL, s=50, zorder=3)
ax.plot(xs, simple.params.iloc[0] + simple.params.iloc[1] * xs, color=GOLD, lw=3)
ax.text(13, 45, "red lines = residuals\n(actual − predicted)\n\nOLS picks the line that makes\nthe sum of squared residuals\nas small as possible", fontsize=12, color=NAVY)
ax.set(title="Ordinary least squares: the best-fitting straight line", xlabel="Advertising spend (₦m)", ylabel="Revenue (₦m)")
save(fig, "3-2", "f03")

# --- F04 · Adding drivers: how much revenue variation we explain -----------------------------
steps = [("Ad spend only", "ad_spend_m_naira"), ("+ active outlets", "ad_spend_m_naira + active_outlets"),
         ("+ sales reps", "ad_spend_m_naira + active_outlets + sales_reps"),
         ("+ price index", "ad_spend_m_naira + active_outlets + sales_reps + price_index"),
         ("+ region & rainfall", "ad_spend_m_naira + active_outlets + sales_reps + price_index + C(region) + rainfall_mm")]
r2 = [smf.ols("revenue_m_naira ~ " + rhs, data=f).fit().rsquared for _, rhs in steps]
fig, ax = plt.subplots()
b = ax.bar([s[0] for s in steps], r2, color=[TEAL] * 4 + [GOLD])
ax.bar_label(b, labels=[f"{v:.0%}" for v in r2], padding=3, fontsize=13)
ax.set_ylim(0, 1); ax.yaxis.set_major_formatter(plt.FuncFormatter(lambda v, p: f"{v:.0%}"))
ax.set(title="R²: share of revenue variation explained rises as real drivers are added", ylabel="R²")
save(fig, "3-2", "f04")

# --- F05 · Coefficient plot with 95% CIs (multiple regression) ------------------------------
ci = full.conf_int(); keep = [k for k in full.params.index if k != "Intercept"]
names = {"ad_spend_m_naira": "Ad spend (per ₦1m)", "price_index": "Price index (per point)", "active_outlets": "Active outlets (per outlet)",
         "sales_reps": "Sales reps (per rep)", "rainfall_mm": "Rainfall (per mm)"}
lab = [names.get(k, k.replace("C(region, Treatment('East'))[T.", "Region: ").replace("]", " vs East")) for k in keep]
order = np.argsort(full.params[keep].values)
fig, ax = plt.subplots()
for i, j in enumerate(order):
    k = keep[j]; m = full.params[k]; lo, hi = ci.loc[k]
    sig = not (lo <= 0 <= hi)
    ax.errorbar(m, i, xerr=[[m - lo], [hi - m]], fmt="o", color=TEAL if sig else SLATE, ms=8, elinewidth=3, capsize=5)
    ax.text(hi + .3, i, f"{m:+.2f}", va="center", fontsize=11, color=INK)
ax.axvline(0, color=INK); ax.set_yticks(range(len(keep)), [lab[j] for j in order])
ax.set(title="Effect of each driver on monthly revenue (₦m), holding the others fixed", xlabel="Coefficient with 95% CI (grey = not distinguishable from zero)")
save(fig, "3-2", "f05")

# --- F06 · Residual diagnostics -------------------------------------------------------------------
fig, ax = plt.subplots(1, 2, figsize=(12, 4.8))
ax[0].scatter(full.fittedvalues, full.resid, color=TEAL, alpha=.6, s=20); ax[0].axhline(0, color=RUST)
ax[0].set(title="Residuals vs fitted: no pattern = good", xlabel="Fitted revenue (₦m)", ylabel="Residual (₦m)")
ax[1].hist(full.resid, bins=25, color=TEAL, edgecolor="white"); ax[1].set(title="Residuals roughly bell-shaped = good", xlabel="Residual (₦m)")
fig.tight_layout()
save(fig, "3-2", "f06")

# --- F07 · Predicted vs actual ---------------------------------------------------------------------
fig, ax = plt.subplots()
ax.scatter(full.fittedvalues, f.revenue_m_naira, color=TEAL, alpha=.6, s=25)
lims = [f.revenue_m_naira.min() - 5, f.revenue_m_naira.max() + 5]; ax.plot(lims, lims, color=GOLD, lw=2.5)
ax.text(lims[0] + 5, lims[1] - 15, f"R² = {full.rsquared:.2f}\ntypical error (RMSE) = ₦{np.sqrt(full.mse_resid):.1f}m", fontsize=13, color=NAVY)
ax.set(title="Predicted vs actual revenue: points hug the 45° line", xlabel="Predicted revenue (₦m)", ylabel="Actual revenue (₦m)")
save(fig, "3-2", "f07")
