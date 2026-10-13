# =============================================================================
# TDBG · Session 2.5 · Hypothesis Testing for Business Decisions
# Replication script — regenerates every chart in the Session 2.5 deck (Python)
# Data: data/store_layout_test.csv (24 stores x 28 days) and data/retail_transactions.csv
# =============================================================================
import sys; sys.path.insert(0, "python")
import numpy as np, pandas as pd
import matplotlib.pyplot as plt
from matplotlib.ticker import FuncFormatter, PercentFormatter
from scipy import stats
from tdbg_style import *

set_style()
d = pd.read_csv("data/store_layout_test.csv")
tx = pd.read_csv("data/retail_transactions.csv")
# One row per STORE: the store is the unit that received the new layout
st = (d.groupby(["store_id", "layout"])
        .agg(conv=("conversion_rate", "mean"), basket=("avg_basket_naira", "mean")).reset_index())
new, old = st[st.layout == "New"], st[st.layout == "Old"]
tt = stats.ttest_ind(new.conv, old.conv, equal_var=False)

# --- F01 · What a p-value is: the null distribution ---------------------------------
dfw = tt.df; x = np.linspace(-4, 4, 500); y = stats.t.pdf(x, dfw)
fig, ax = plt.subplots()
ax.plot(x, y, color=NAVY, lw=2.5)
ax.fill_between(x, y, where=np.abs(x) >= tt.statistic, color=GOLD, alpha=.8)
crit = stats.t.ppf(.975, dfw)
ax.axvline(tt.statistic, color=RUST, lw=2.5); ax.axvline(-tt.statistic, color=RUST, lw=1, ls=":")
ax.text(tt.statistic + .1, .36, f"our result\nt = {tt.statistic:.2f}", color=RUST, fontsize=13)
ax.text(2.2, .1, f"gold area = p-value\n= {tt.pvalue:.2f}", color=GOLD, fontsize=13, fontweight="bold")
for c in (-crit, crit): ax.axvline(c, color=SLATE, ls="--", lw=1.2)
ax.text(crit + .05, .3, "5% cut-off", color=SLATE, fontsize=11)
ax.set_yticks([]); ax.grid(False)
ax.set(title="If the layout had NO effect, how surprising is our result?", xlabel="t statistic (difference ÷ standard error)")
save(fig, "2-5", "f01")

# --- F02 · Store-level conversion by layout --------------------------------------------
fig, ax = plt.subplots()
for i, (g, col) in enumerate([(old, SLATE), (new, TEAL)]):
    jitter = np.linspace(-0.12, 0.12, len(g))
    ax.scatter(i + jitter, g.conv * 100, s=80, color=col, alpha=.85, zorder=3)
    ax.hlines(g.conv.mean() * 100, i - .25, i + .25, color=GOLD, lw=3, zorder=4)
    ax.text(i + .3, g.conv.mean() * 100, f"mean {g.conv.mean():.1%}", va="center", color=NAVY, fontsize=13)
ax.set_xticks([0, 1], ["Old layout (12 stores)", "New layout (12 stores)"]); ax.set_xlim(-.6, 1.9)
ax.yaxis.set_major_formatter(PercentFormatter(decimals=0))
ax.set(title=f"Conversion per store: +{(new.conv.mean()-old.conv.mean())*100:.1f} pts, but stores differ a lot (p = {tt.pvalue:.2f})",
       ylabel="Average daily conversion rate")
save(fig, "2-5", "f02")

# --- F03 · The wrong unit: pooled visitors vs stores ------------------------------------
dn, do = d[d.layout == "New"], d[d.layout == "Old"]
p1, p0 = dn.buyers.sum() / dn.visitors.sum(), do.buyers.sum() / do.visitors.sum()
se_pool = np.sqrt(p1 * (1 - p1) / dn.visitors.sum() + p0 * (1 - p0) / do.visitors.sum())
diff = new.conv.mean() - old.conv.mean(); se_store = np.sqrt(new.conv.var() / 12 + old.conv.var() / 12)
fig, ax = plt.subplots(figsize=(10, 4.6))
rows = [("Treating 349,000 visitors as independent\n(wrong unit)", p1 - p0, 1.96 * se_pool, RUST),
        ("Treating the 24 stores as the units\n(correct unit)", diff, stats.t.ppf(.975, tt.df) * se_store, TEAL)]
for i, (lab, m, h, c) in enumerate(rows):
    ax.errorbar(m * 100, i, xerr=h * 100, fmt="o", color=c, elinewidth=4, capsize=8, ms=10)
    ax.text((m + h) * 100 + .15, i, f"{m*100:+.2f} pts  [{(m-h)*100:+.2f}, {(m+h)*100:+.2f}]", va="center", fontsize=12, color=c)
ax.axvline(0, color=INK, lw=1.2)
ax.set_yticks([0, 1], [r[0] for r in rows]); ax.set_ylim(-.6, 1.6); ax.set_xlim(-2, 4.6)
ax.set(title="Same data, two answers: the wrong unit manufactures certainty", xlabel="Difference in conversion, new minus old (percentage points, 95% CI)")
save(fig, "2-5", "f03")

# --- F04 · Average basket per store by layout ---------------------------------------------
tb = stats.ttest_ind(new.basket, old.basket, equal_var=False)
fig, ax = plt.subplots()
for i, (g, col) in enumerate([(old, SLATE), (new, TEAL)]):
    jitter = np.linspace(-0.12, 0.12, len(g))
    ax.scatter(i + jitter, g.basket, s=80, color=col, alpha=.85, zorder=3)
    ax.hlines(g.basket.mean(), i - .25, i + .25, color=GOLD, lw=3, zorder=4)
    ax.text(i + .3, g.basket.mean(), f"mean ₦{g.basket.mean():,.0f}", va="center", color=NAVY, fontsize=13)
ax.set_xticks([0, 1], ["Old layout", "New layout"]); ax.set_xlim(-.6, 1.9)
ax.yaxis.set_major_formatter(FuncFormatter(lambda v, p: f"₦{v:,.0f}"))
ax.set(title=f"Basket value per store: +₦{new.basket.mean()-old.basket.mean():,.0f} (+{new.basket.mean()/old.basket.mean()-1:.1%}), p = {tb.pvalue:.4f}",
       ylabel="Average basket (₦)")
save(fig, "2-5", "f04")

# --- F05 · Type I and Type II errors on one picture ------------------------------------------
x = np.linspace(-4, 7, 600); h0, h1 = stats.norm.pdf(x, 0, 1), stats.norm.pdf(x, 2.5, 1); c = 1.96
fig, ax = plt.subplots()
ax.plot(x, h0, color=SLATE, lw=2.5, label="World A: no real effect (H₀ true)")
ax.plot(x, h1, color=TEAL, lw=2.5, label="World B: real effect (H₁ true)")
ax.fill_between(x, h0, where=x >= c, color=RUST, alpha=.7, label="α — Type I error: false alarm")
ax.fill_between(x, h1, where=x < c, color=GOLD, alpha=.5, label="β — Type II error: missed effect")
ax.axvline(c, color=INK, ls="--"); ax.text(c + .08, .45, "decision\nthreshold", fontsize=11)
ax.text(4.6, .2, f"power = 1 − β\n= {1 - stats.norm.cdf(c, 2.5, 1):.0%}", color=TEAL, fontsize=13, fontweight="bold")
ax.set_yticks([]); ax.grid(False); ax.set_ylim(0, .62); ax.legend(loc="upper left", fontsize=11)
ax.set(title="Every test trades false alarms against missed effects", xlabel="Test statistic")
save(fig, "2-5", "f05")

# --- F06 · Chi-square: payment mix by region ---------------------------------------------------
ct = pd.crosstab(tx.region, tx.payment_method, normalize="index")
chi = stats.chi2_contingency(pd.crosstab(tx.region, tx.payment_method))
fig, ax = plt.subplots()
left = np.zeros(len(ct))
for col, c in zip(ct.columns, [TEAL, SLATE, GOLD, SKY]):
    ax.barh(ct.index, ct[col], left=left, color=c, label=col)
    for i, v in enumerate(ct[col]): ax.text(left[i] + v / 2, i, f"{v:.0%}", ha="center", va="center", color="white", fontsize=11)
    left += ct[col].values
ax.xaxis.set_major_formatter(PercentFormatter(1)); ax.legend(ncol=4, loc="upper center", bbox_to_anchor=(.5, -.1))
ax.set(title=f"Payment mix looks similar across regions (χ² = {chi[0]:.1f}, p = {chi[1]:.2f})")
save(fig, "2-5", "f06")

# --- F07 · Significant is not the same as important ----------------------------------------------
n = np.logspace(2, 6.3, 200); p0_, p1_ = .200, .202
z = (p1_ - p0_) / np.sqrt(p0_ * (1 - p0_) / n + p1_ * (1 - p1_) / n); pv = 2 * (1 - stats.norm.cdf(z))
fig, ax = plt.subplots()
ax.plot(n, pv, color=TEAL, lw=3); ax.axhline(.05, color=RUST, ls="--"); ax.text(130, .065, "p = 0.05", color=RUST, fontsize=12)
ax.set_xscale("log"); ax.set_ylim(0, 1)
ax.set(title="A 0.2-point lift (20.0% → 20.2%) becomes 'significant' with enough data",
       xlabel="Visitors per group (log scale)", ylabel="p-value")
ax.annotate("Statistically significant —\nbut is a 0.2-point lift worth\nthe cost of a refit?", xy=(8e5, .02), xytext=(3e4, .45),
            arrowprops=dict(arrowstyle="->", color=NAVY), fontsize=12, color=NAVY)
save(fig, "2-5", "f07")

# --- F08 · Loyalty members' baskets: comparing skewed groups ---------------------------------------
fig, ax = plt.subplots()
data = [tx.loc[tx.loyalty_member == "No", "basket_naira"], tx.loc[tx.loyalty_member == "Yes", "basket_naira"]]
bp = ax.boxplot(data, vert=False, patch_artist=True, widths=.5, medianprops=dict(color=GOLD, lw=3), showfliers=False)
for p, c in zip(bp["boxes"], ["#DDE3EA", "#D6E6EF"]): p.set(facecolor=c, edgecolor=TEAL)
ax.set_yticks([1, 2], ["Not a member", "Loyalty member"])
ax.xaxis.set_major_formatter(FuncFormatter(naira))
mw = stats.mannwhitneyu(data[1], data[0])
ax.set(title=f"Members' baskets are larger (Mann–Whitney p = {mw.pvalue:.4f}) — but why?", xlabel="Basket value (outliers hidden)")
save(fig, "2-5", "f08")
