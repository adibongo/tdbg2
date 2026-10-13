# =============================================================================
# TDBG · Session 4.1 · Model Explainability & Lead Scoring
# Replication script — regenerates every chart in the Session 4.1 deck (Python)
# Data: data/b2b_leads.csv — 2,500 B2B leads (16% converted)
# Train = first 1,750 leads, test = last 750. Model: XGBoost; explanations: SHAP
# (exact TreeSHAP values from XGBoost's pred_contribs — the same method R uses).
# pip install xgboost shap
# =============================================================================
import sys; sys.path.insert(0, "python")
import numpy as np, pandas as pd, warnings
import matplotlib.pyplot as plt
import xgboost as xgb
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import roc_auc_score
from tdbg_style import *
warnings.filterwarnings("ignore")

set_style()
d = pd.read_csv("data/b2b_leads.csv")
X = pd.get_dummies(d.drop(columns=["lead_id", "converted"])).astype(float); y = d.converted
tr = np.arange(len(d)) < 1750
model = xgb.XGBClassifier(n_estimators=300, max_depth=3, learning_rate=.05, subsample=.8, colsample_bytree=.8, random_state=1).fit(X[tr], y[tr])
p = model.predict_proba(X[~tr])[:, 1]
lr = LogisticRegression(max_iter=5000).fit(X[tr], y[tr]); plr = lr.predict_proba(X[~tr])[:, 1]
print("AUC xgb", roc_auc_score(y[~tr], p), "logistic", roc_auc_score(y[~tr], plr))
Xte = X[~tr].reset_index(drop=True); yte = y[~tr].reset_index(drop=True); dte = d[~tr].reset_index(drop=True)
sv = model.get_booster().predict(xgb.DMatrix(Xte), pred_contribs=True)   # last column = baseline (bias)
S = pd.DataFrame(sv[:, :-1], columns=X.columns); base = sv[0, -1]

def nice(c):
    return (c.replace("lead_source_", "source: ").replace("company_size_", "size: ").replace("industry_", "industry: ")
             .replace("requested_demo", "requested demo").replace("days_since_first_touch", "days since first touch")
             .replace("web_visits", "web visits").replace("emails_opened", "emails opened"))

# --- F01 · Global importance: mean |SHAP| ---------------------------------------------
imp = S.abs().mean().sort_values().tail(10)
fig, ax = plt.subplots()
ax.barh([nice(c) for c in imp.index], imp.values, color=[GOLD if v == imp.max() else TEAL for v in imp.values])
ax.set(title="Global view: which drivers move lead scores the most?", xlabel="Average |SHAP value| (impact on log-odds of converting)")
save(fig, "4-1", "f01")

# --- F02 · SHAP summary (beeswarm) ---------------------------------------------------------
top = S.abs().mean().sort_values(ascending=False).head(8).index[::-1]
fig, ax = plt.subplots(figsize=(10, 6))
rng = np.random.default_rng(0)
for i, c in enumerate(top):
    v = Xte[c].values; vn = (v - v.min()) / (v.max() - v.min() + 1e-9)
    sc = ax.scatter(S[c], i + rng.uniform(-.28, .28, len(S)), c=vn, cmap="coolwarm", s=10, alpha=.75)
ax.axvline(0, color=INK, lw=.8); ax.set_yticks(range(len(top)), [nice(c) for c in top])
cb = fig.colorbar(sc, ax=ax, ticks=[0, 1]); cb.ax.set_yticklabels(["low", "high"]); cb.set_label("driver value")
ax.set(title="Each dot is one lead: red = high driver value, blue = low", xlabel="SHAP value (pushes score down ←  → pushes score up)")
save(fig, "4-1", "f02")

# --- F03/F04 · Local explanations: waterfall for two leads -------------------------------------
def waterfall(i, fid, ttl):
    contrib = S.iloc[i]; raw = dte.iloc[i]
    keep = contrib.abs().sort_values(ascending=False).head(6).index
    other = contrib.drop(keep).sum()
    items = [(f"{nice(c)} = {int(Xte.loc[i, c]) if Xte.loc[i, c] == int(Xte.loc[i, c]) else round(Xte.loc[i, c], 1)}", contrib[c]) for c in keep] + [("all other drivers", other)]
    fig, ax = plt.subplots()
    cur = base
    for k, (lab, v) in enumerate(items):
        ax.barh(k, v, left=cur, color=RUST if v > 0 else TEAL)
        ax.text(cur + v + (.03 if v > 0 else -.03), k, f"{v:+.2f}", va="center", ha="left" if v > 0 else "right", fontsize=11)
        cur += v
    ax.axvline(base, color=SLATE, ls=":"); ax.axvline(cur, color=GOLD, lw=2); ax.margins(x=.12)
    prob = 1 / (1 + np.exp(-cur)); pbase = 1 / (1 + np.exp(-base))
    ax.set_yticks(range(len(items)), [l for l, _ in items]); ax.invert_yaxis()
    ax.set(title=f"{ttl}: score {prob:.0%} vs average lead {pbase:.0%}", xlabel="Log-odds of converting (start at the average, add each driver's push)")
    save(fig, "4-1", fid)
    return prob
hot = int(np.argmax(p)); cold = int(np.argsort(p)[len(p) // 10])
ph = waterfall(hot, "f03", f"Why lead {dte.lead_id[hot]} is hot"); pc = waterfall(cold, "f04", f"Why lead {dte.lead_id[cold]} is cold")

# --- F05 · Dependence: web visits, coloured by demo request -----------------------------------------
fig, ax = plt.subplots()
for dm, col, lab in [(0, SKY, "no demo requested"), (1, RUST, "demo requested")]:
    k = Xte.requested_demo == dm
    ax.scatter(Xte.web_visits[k] + rng.uniform(-.2, .2, k.sum()), S.web_visits[k], s=14, alpha=.6, color=col, label=lab)
ax.axhline(0, color=INK, lw=.8); ax.legend()
ax.set(title="SHAP dependence: more web visits generally push the score up", xlabel="Web visits", ylabel="SHAP value for web visits")
save(fig, "4-1", "f05")

# --- F06 · Cumulative gains: who to call first -------------------------------------------------------
order = np.argsort(-p); cum = yte.values[order].cumsum() / yte.sum(); frac = np.arange(1, len(p) + 1) / len(p)
order_lr = np.argsort(-plr); cum_lr = yte.values[order_lr].cumsum() / yte.sum()
fig, ax = plt.subplots()
ax.plot(frac * 100, cum * 100, color=GOLD, lw=3, label="XGBoost score"); ax.plot(frac * 100, cum_lr * 100, color=TEAL, lw=2.5, ls="--", label="Logistic score")
ax.plot([0, 100], [0, 100], color=SLATE, ls=":", label="Random calling")
k30 = int(.3 * len(p)) - 1; ax.plot(30, cum[k30] * 100, "o", color=NAVY, ms=10)
ax.annotate(f"Call the top 30% of leads →\ncatch {cum[k30]:.0%} of all conversions", (30, cum[k30] * 100), xytext=(42, 35), arrowprops=dict(arrowstyle="->"), fontsize=12, color=NAVY)
ax.set(title="Cumulative gains: scoring lets sales focus on the leads that convert", xlabel="% of leads contacted (highest scores first)", ylabel="% of all conversions captured"); ax.legend(loc="lower right")
save(fig, "4-1", "f06")

# --- F07 · Conversion rate by score band --------------------------------------------------------------
bands = pd.qcut(p, [0, .5, .8, .95, 1], labels=["D (bottom 50%)", "C (next 30%)", "B (next 15%)", "A (top 5%)"])
br = pd.DataFrame({"band": bands, "y": yte}).groupby("band", observed=True)["y"].agg(["mean", "count"])
fig, ax = plt.subplots()
b = ax.bar(br.index.astype(str), br["mean"] * 100, color=[SLATE, SKY, TEAL, GOLD])
ax.bar_label(b, labels=[f"{m:.0%}\n(n={n})" for m, n in zip(br["mean"], br["count"])], padding=3, fontsize=12)
ax.axhline(yte.mean() * 100, color=RUST, ls="--"); ax.text(-.4, yte.mean() * 100 + 1.5, f"average {yte.mean():.0%}", color=RUST)
ax.set_ylim(0, br["mean"].max() * 120)
ax.set(title="Lead grades: conversion rate by score band on test leads", ylabel="Conversion rate (%)")
save(fig, "4-1", "f07")
print("hot", dte.lead_id[hot], ph, "cold", dte.lead_id[cold], pc); print(br)
