# =============================================================================
# TDBG · Session 3.4 · Classification & Logistic Regression
# Replication script — regenerates every chart in the Session 3.4 deck (Python)
# Data: data/digital_loans.csv — 6,000 app-based microloans (18% defaulted)
# Train = first 4,200 loans, test = last 1,800 (same split in R and Python)
# =============================================================================
import sys; sys.path.insert(0, "python")
import numpy as np, pandas as pd
import matplotlib.pyplot as plt
import statsmodels.formula.api as smf
from sklearn.metrics import roc_curve, roc_auc_score
from tdbg_style import *

set_style()
d = pd.read_csv("data/digital_loans.csv")
d["log_income"] = np.log(d.monthly_income_naira); d["log_airtime"] = np.log(d.monthly_airtime_naira)
tr, te = d.iloc[:4200].copy(), d.iloc[4200:].copy()
FORM = ("defaulted ~ age + salary_earner + log_income + repayment_to_income + tenure_days + prior_loans_repaid"
        " + prior_late_payments + account_age_months + C(phone_os) + log_airtime + bvn_verified"
        " + C(acquisition_channel, Treatment('Organic')) + C(state, Treatment('Lagos'))")
m = smf.logit(FORM, tr).fit(disp=0)
te["p"] = m.predict(te)
GOOD, BAD = 8000, 45000          # margin on a repaid loan; loss on a default (assumptions)

# --- F01 · Why not a straight line? ------------------------------------------------------
bins = pd.cut(tr.repayment_to_income, np.linspace(0, 1.6, 17))
rate = tr.groupby(bins, observed=True)["defaulted"].mean(); mid = [i.mid for i in rate.index]
lin = smf.ols("defaulted ~ repayment_to_income", tr).fit(); lg = smf.logit("defaulted ~ repayment_to_income", tr).fit(disp=0)
xs = pd.DataFrame({"repayment_to_income": np.linspace(0, 3, 200)})
fig, ax = plt.subplots()
ax.scatter(tr.repayment_to_income, tr.defaulted + np.random.default_rng(1).uniform(-.03, .03, len(tr)), s=4, alpha=.15, color=SLATE)
ax.plot(mid, rate, "o", color=GOLD, ms=9, label="actual default rate in each band")
ax.plot(xs.repayment_to_income, lin.predict(xs), color=RUST, lw=2.5, ls="--", label="linear regression: goes below 0 and above 1")
ax.plot(xs.repayment_to_income, lg.predict(xs), color=TEAL, lw=3, label="logistic regression: stays between 0 and 1")
ax.set_xlim(0, 2.2); ax.set_ylim(-.15, 1.15); ax.legend(loc="upper left", fontsize=11, bbox_to_anchor=(0, .92))
ax.set(title="Predicting a yes/no outcome needs an S-shaped curve", xlabel="Repayment ÷ income over the loan term", ylabel="Defaulted (0 = no, 1 = yes)")
save(fig, "3-4", "f01")

# --- F02 · From score to probability: the logistic (sigmoid) curve -------------------------
z = np.linspace(-6, 6, 300)
fig, ax = plt.subplots()
ax.plot(z, 1 / (1 + np.exp(-z)), color=TEAL, lw=3.5)
for zz in (-2, 0, 2):
    pp = 1 / (1 + np.exp(-zz)); ax.plot(zz, pp, "o", color=GOLD, ms=10)
    ax.annotate(f"score {zz:+d} → {pp:.0%}", (zz, pp), xytext=(12, -18 if zz > 0 else 8), textcoords="offset points", fontsize=12, color=NAVY)
ax.set(title="Logistic regression turns any score into a probability between 0 and 1",
       xlabel="Linear score  z = b₀ + b₁x₁ + b₂x₂ + …  (the log-odds)", ylabel="Probability of default")
ax.yaxis.set_major_formatter(plt.FuncFormatter(lambda v, p: f"{v:.0%}"))
save(fig, "3-4", "f02")

# --- F03 · Odds ratios with 95% CIs ---------------------------------------------------------
ci = m.conf_int(); rows = {
    "Repayment ÷ income (+0.1)": ("repayment_to_income", .1), "Each prior late payment": ("prior_late_payments", 1),
    "Each prior loan repaid": ("prior_loans_repaid", 1), "Salary earner (vs not)": ("salary_earner", 1),
    "BVN verified (vs not)": ("bvn_verified", 1), "iOS (vs Android)": ("C(phone_os)[T.iOS]", 1),
    "Paid social (vs organic)": ("C(acquisition_channel, Treatment('Organic'))[T.Paid social]", 1),
    "Referral (vs organic)": ("C(acquisition_channel, Treatment('Organic'))[T.Referral]", 1),
    "Age (+10 years)": ("age", 10)}
orr = pd.DataFrame({k: [np.exp(m.params[v] * s), np.exp(ci.loc[v, 0] * s), np.exp(ci.loc[v, 1] * s)] for k, (v, s) in rows.items()}, index=["or", "lo", "hi"]).T.sort_values("or")
fig, ax = plt.subplots()
for i, (k, r) in enumerate(orr.iterrows()):
    c = RUST if r.lo > 1 else TEAL if r.hi < 1 else SLATE
    ax.errorbar(r["or"], i, xerr=[[r["or"] - r.lo], [r.hi - r["or"]]], fmt="o", color=c, ms=9, elinewidth=3, capsize=5)
    ax.text(r.hi * 1.05, i, f"×{r['or']:.2f}", va="center", fontsize=11)
ax.axvline(1, color=INK); ax.set_xscale("log"); ax.set_yticks(range(len(orr)), orr.index)
ax.set_xticks([.4, .6, 1, 1.5, 2.5], ["0.4", "0.6", "1", "1.5", "2.5"]); ax.xaxis.set_minor_formatter(plt.NullFormatter())
ax.set(title="Odds ratios: what multiplies — or divides — the odds of default", xlabel="Odds ratio (log scale; >1 raises risk, <1 lowers it)")
save(fig, "3-4", "f03")

# --- F04 · Predicted probabilities: defaulters vs repayers ---------------------------------
fig, ax = plt.subplots()
bins_ = np.linspace(0, .9, 46)
ax.hist(te.p[te.defaulted == 0], bins_, color=SKY, alpha=.8, label="Repaid", density=True)
ax.hist(te.p[te.defaulted == 1], bins_, color=RUST, alpha=.6, label="Defaulted", density=True)
ax.axvline(.5, color=INK, ls="--"); ax.text(.51, ax.get_ylim()[1] * .85, "0.5 cut-off", fontsize=11)
ax.axvline(.2, color=GOLD, lw=2.5); ax.text(.21, ax.get_ylim()[1] * .7, "0.2 cut-off", color=GOLD, fontsize=11)
ax.set(title="Defaulters get higher scores — but the two groups overlap", xlabel="Predicted probability of default (test loans)", ylabel="Density")
ax.legend()
save(fig, "3-4", "f04")

# --- F05 · Confusion matrices at two thresholds -------------------------------------------------
fig, axes = plt.subplots(1, 2, figsize=(11, 4.8))
for ax, t in zip(axes, [.5, .2]):
    pr = (te.p >= t).astype(int)
    cm = np.array([[((pr == 0) & (te.defaulted == 0)).sum(), ((pr == 1) & (te.defaulted == 0)).sum()],
                   [((pr == 0) & (te.defaulted == 1)).sum(), ((pr == 1) & (te.defaulted == 1)).sum()]])
    ax.imshow([[1, 0], [0, 1]], cmap="Blues", alpha=.25)
    labs = [["True negative\n(approve, repaid)", "False positive\n(reject a good customer)"], ["False negative\n(approve, defaulted)", "True positive\n(reject a defaulter)"]]
    for i in range(2):
        for j in range(2):
            ax.text(j, i, f"{cm[i, j]:,}\n{labs[i][j]}", ha="center", va="center", fontsize=11, color=NAVY)
    rec = cm[1, 1] / cm[1].sum(); prec = cm[1, 1] / max(cm[:, 1].sum(), 1)
    ax.set_xticks([0, 1], ["Predicted: repay", "Predicted: default"]); ax.set_yticks([0, 1], ["Actual: repaid", "Actual: defaulted"])
    ax.set_title(f"Threshold {t}: catches {rec:.0%} of defaulters\n(precision {prec:.0%})", fontsize=13); ax.grid(False)
fig.tight_layout()
save(fig, "3-4", "f05")

# --- F06 · ROC curve ---------------------------------------------------------------------------
fpr, tpr, thr = roc_curve(te.defaulted, te.p); auc = roc_auc_score(te.defaulted, te.p)
fig, ax = plt.subplots(figsize=(8, 6.5))
ax.plot(fpr, tpr, color=TEAL, lw=3, label=f"Logistic regression (AUC = {auc:.2f})")
ax.plot([0, 1], [0, 1], color=SLATE, ls="--", label="Coin flip (AUC = 0.50)")
for t in (.5, .2):
    k = np.argmin(abs(thr - t)); ax.plot(fpr[k], tpr[k], "o", color=GOLD, ms=11); ax.annotate(f"threshold {t}", (fpr[k], tpr[k]), xytext=(10, -15), textcoords="offset points", fontsize=12)
ax.set(title="ROC curve: the trade-off across every threshold", xlabel="False positive rate (good customers rejected)", ylabel="True positive rate (defaulters caught)")
ax.legend(loc="lower right")
save(fig, "3-4", "f06")

# --- F07 · Choosing the threshold by profit ---------------------------------------------------------
ts = np.linspace(.02, .9, 89); prof = []
for t in ts:
    appr = te.p < t
    prof.append((GOOD * ((te.defaulted == 0) & appr).sum() - BAD * ((te.defaulted == 1) & appr).sum()) / 1e6)
best = ts[int(np.argmax(prof))]
fig, ax = plt.subplots()
ax.plot(ts, prof, color=TEAL, lw=3); ax.axvline(best, color=GOLD, lw=2.5); ax.axhline(0, color=INK, lw=.8)
appr_all = GOOD * (te.defaulted == 0).sum() - BAD * (te.defaulted == 1).sum()
ax.axhline(appr_all / 1e6, color=RUST, ls="--"); ax.text(.6, appr_all / 1e6 + .3, "approve everyone", color=RUST, fontsize=12)
ax.text(.42, max(prof) * .8, f"best cut-off ≈ {best:.2f}\nprofit ₦{max(prof):.1f}m on 1,800 applications", color=NAVY, fontsize=12)
ax.set(title="The best threshold is a business decision: profit, not accuracy", xlabel="Reject if predicted default probability ≥ threshold", ylabel="Profit on test applications (₦ million)")
save(fig, "3-4", "f07")

# --- F08 · Precision and recall vs threshold ------------------------------------------------------------
P, R = [], []
for t in ts:
    pr = te.p >= t; tp = (pr & (te.defaulted == 1)).sum()
    P.append(tp / pr.sum() if pr.sum() else np.nan); R.append(tp / (te.defaulted == 1).sum())
fig, ax = plt.subplots()
k = ts <= .7
ax.plot(ts[k], np.array(R)[k], color=RUST, lw=3, label="Recall: share of defaulters caught")
ax.plot(ts[k], np.array(P)[k], color=TEAL, lw=3, label="Precision: share of rejections that were defaulters")
ax.axhline(te.defaulted.mean(), color=SLATE, ls=":"); ax.text(.62, te.defaulted.mean() + .02, "base rate 19%", color=SLATE)
ax.yaxis.set_major_formatter(plt.FuncFormatter(lambda v, p: f"{v:.0%}")); ax.legend(loc="upper right")
ax.set(title="Raise the threshold: fewer false alarms, but more defaulters slip through", xlabel="Threshold", ylabel="Rate")
save(fig, "3-4", "f08")
print(f"AUC {auc:.3f}  best threshold {best:.2f}  max profit {max(prof):.2f}m  approve-all {appr_all/1e6:.2f}m")
