# =============================================================================
# TDBG · Session 3.1 · A/B Testing & Business Experimentation
# Replication script — regenerates every chart in the Session 3.1 deck (Python)
# Data: data/fintech_onboarding_ab.csv — 12,000 new app users, randomised to
#       A_control (current onboarding) or B_simplified (shorter KYC flow)
# Note: F03 (peeking) is a simulation; R and Python draw different random numbers.
# =============================================================================
import sys; sys.path.insert(0, "python")
import numpy as np, pandas as pd
import matplotlib.pyplot as plt
from matplotlib.ticker import PercentFormatter, FuncFormatter
from scipy import stats
from tdbg_style import *

set_style()
d = pd.read_csv("data/fintech_onboarding_ab.csv")
lab = {"A_control": "A · current flow", "B_simplified": "B · simplified flow"}

def prop_ci(x, n):
    p = x / n; h = 1.96 * np.sqrt(p * (1 - p) / n); return p, p - h, p + h

# --- F01 · Headline result: completion rate with 95% CIs ------------------------------
g = d.groupby("variant")["completed_onboarding"].agg(["sum", "count"])
fig, ax = plt.subplots()
for i, v in enumerate(g.index):
    p, lo, hi = prop_ci(g.loc[v, "sum"], g.loc[v, "count"])
    ax.bar(i, p, color=[SLATE, TEAL][i], width=.55)
    ax.errorbar(i, p, yerr=[[p - lo], [hi - p]], color=INK, capsize=10, lw=2)
    ax.text(i, hi + .006, f"{p:.1%}\n(n={g.loc[v,'count']:,})", ha="center", fontsize=13)
ax.set_xticks([0, 1], [lab[v] for v in g.index]); ax.set_ylim(0, .27)
ax.yaxis.set_major_formatter(PercentFormatter(1))
ax.set(title="Simplified onboarding lifts completion by 2.3 points (95% CI +0.9 to +3.7)", ylabel="Completed onboarding")
save(fig, "3-1", "f01")

# --- F02 · Sample size needed vs the smallest lift you care about --------------------------
base = .18; lifts = np.linspace(.005, .04, 80)
def n_needed(p1, p2, alpha=.05, power=.8):
    za, zb = stats.norm.ppf(1 - alpha / 2), stats.norm.ppf(power)
    pbar = (p1 + p2) / 2
    return ((za * np.sqrt(2 * pbar * (1 - pbar)) + zb * np.sqrt(p1 * (1 - p1) + p2 * (1 - p2))) / (p2 - p1)) ** 2
n = n_needed(base, base + lifts)
fig, ax = plt.subplots()
ax.plot(lifts * 100, n, color=TEAL, lw=3); ax.set_yscale("log")
for L in (.01, .02, .03):
    nn = n_needed(base, base + L); ax.plot(L * 100, nn, "o", color=GOLD, ms=10)
    ax.annotate(f"+{L*100:.0f} pt → {nn:,.0f} per group", (L * 100, nn), xytext=(8, 8), textcoords="offset points", fontsize=12, color=NAVY)
ax.yaxis.set_major_formatter(FuncFormatter(lambda v, p: f"{v:,.0f}"))
ax.set(title="Halve the lift you want to detect → need about 4× the users", xlabel="Minimum detectable lift (percentage points, from an 18% baseline)",
       ylabel="Users needed per group (log scale)")
save(fig, "3-1", "f02")

# --- F03 · The peeking problem: an A/A test checked every day --------------------------------
rng = np.random.default_rng(6)
fig, ax = plt.subplots()
crossed = 0
for k in range(20):
    a = rng.random(6000) < .18; b = rng.random(6000) < .18          # NO real difference
    ns = np.arange(200, 6001, 200); pv = []
    for m in ns:
        pa, pb = a[:m].mean(), b[:m].mean(); pp = (pa + pb) / 2
        z = (pb - pa) / np.sqrt(2 * pp * (1 - pp) / m); pv.append(2 * (1 - stats.norm.cdf(abs(z))))
    hit = min(pv) < .05; crossed += hit
    ax.plot(ns, pv, color=RUST if hit else "#C9D2DB", lw=1.6 if hit else 1, alpha=.9)
ax.axhline(.05, color=NAVY, ls="--"); ax.set_yscale("log"); ax.set_ylim(.003, 1.05)
ax.set(title=f"20 tests with NO real effect: {crossed} dip below p = 0.05 at some point if you keep peeking",
       xlabel="Users per group so far", ylabel="p-value (log scale)")
save(fig, "3-1", "f03")

# --- F04 · Randomisation check: are the groups alike? -------------------------------------------
mix = pd.crosstab(d.device, d.variant, normalize="columns")
fig, ax = plt.subplots(figsize=(10, 4.6))
x = np.arange(len(mix)); w = .38
for j, v in enumerate(mix.columns):
    b = ax.bar(x + (j - .5) * w, mix[v], w, color=[SLATE, TEAL][j], label=lab[v])
    ax.bar_label(b, labels=[f"{t:.1%}" for t in mix[v]], padding=3, fontsize=11)
ax.set_xticks(x, mix.index); ax.yaxis.set_major_formatter(PercentFormatter(1)); ax.legend()
srm = stats.chisquare(d.variant.value_counts())
ax.set(title=f"Balance check: device mix is the same in A and B (split {d.variant.value_counts()['A_control']:,} / {d.variant.value_counts()['B_simplified']:,}, SRM p = {srm.pvalue:.2f})",
       ylabel="Share of users")
save(fig, "3-1", "f04")

# --- F05 · Guardrail metrics ---------------------------------------------------------------------
fig, ax = plt.subplots(1, 2, figsize=(11, 4.6))
t = d.groupby("variant")["support_tickets"].agg(["mean", "std", "count"])
for i, v in enumerate(t.index):
    h = 1.96 * t.loc[v, "std"] / np.sqrt(t.loc[v, "count"])
    ax[0].bar(i, t.loc[v, "mean"], color=[SLATE, TEAL][i], width=.55); ax[0].errorbar(i, t.loc[v, "mean"], yerr=h, color=INK, capsize=8)
ax[0].set_xticks([0, 1], ["A", "B"]); ax[0].set_title("Support tickets per user\n(guardrail: must not rise much)")
dep = d[d.completed_onboarding == 1].groupby("variant")["first_deposit_naira"].median()
ax[1].bar([0, 1], dep.values, color=[SLATE, TEAL], width=.55)
ax[1].bar_label(ax[1].containers[0], labels=[f"₦{v:,.0f}" for v in dep.values], padding=3)
ax[1].set_xticks([0, 1], ["A", "B"]); ax[1].set_title("Median first deposit\n(guardrail: quality of new users)")
ax[1].yaxis.set_major_formatter(FuncFormatter(naira))
fig.suptitle("Guardrails: no meaningful harm to support load or deposit size", x=.01, ha="left", color=NAVY, fontweight="bold")
fig.tight_layout()
save(fig, "3-1", "f05")

# --- F06 · Lift by device — with honest uncertainty -----------------------------------------------
rows = []
for dev, s in d.groupby("device"):
    a, b = s[s.variant == "A_control"].completed_onboarding, s[s.variant == "B_simplified"].completed_onboarding
    diff = b.mean() - a.mean(); se = np.sqrt(a.mean() * (1 - a.mean()) / len(a) + b.mean() * (1 - b.mean()) / len(b))
    rows.append((dev, diff, se, len(s)))
a, b = d[d.variant == "A_control"].completed_onboarding, d[d.variant == "B_simplified"].completed_onboarding
rows.append(("All users", b.mean() - a.mean(), np.sqrt(a.mean() * (1 - a.mean()) / len(a) + b.mean() * (1 - b.mean()) / len(b)), len(d)))
fig, ax = plt.subplots()
for i, (dev, m, se, n) in enumerate(rows):
    col = NAVY if dev == "All users" else TEAL
    ax.errorbar(m * 100, i, xerr=1.96 * se * 100, fmt="s" if dev == "All users" else "o", color=col, ms=10, elinewidth=3, capsize=6)
    ax.text(6.4, i, f"{m*100:+.1f} pts  (n={n:,})", va="center", fontsize=12)
ax.axvline(0, color=INK); ax.set_yticks(range(len(rows)), [r[0] for r in rows]); ax.set_xlim(-4, 9.6)
ax.set(title="Lift by device: every interval overlaps the overall effect", xlabel="Lift in completion, B minus A (points, 95% CI)")
save(fig, "3-1", "f06")
