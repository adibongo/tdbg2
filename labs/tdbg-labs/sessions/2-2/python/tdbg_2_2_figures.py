# =============================================================================
# TDBG · Session 2.2 · Statistical Foundations for Decision-Making
# Replication script — regenerates every chart in the Session 2.2 deck (Python)
# Run from the project root:  python sessions/2-2/python/tdbg_2_2_figures.py
# Note: figures F01, F06 and F07 use random simulation. Python and R use
# different random-number generators, so those charts look slightly different
# between languages — the lesson they teach is identical.
# =============================================================================
import sys; sys.path.insert(0, "python")
import numpy as np, pandas as pd
import matplotlib.pyplot as plt
from matplotlib.ticker import FuncFormatter
from scipy import stats
from tdbg_style import *

set_style()
rng = np.random.default_rng(2026)
basket = pd.read_csv("data/retail_basket_sizes.csv")
income = pd.read_csv("data/bank_customer_income.csv")
deliv = pd.read_csv("data/delivery_times.csv")

# --- F01 · Three shapes you will see every week ------------------------------
fig, axes = plt.subplots(1, 3, figsize=(12, 4.2), sharey=False)
shapes = [("Symmetric", rng.normal(50, 10, 5000), TEAL, "e.g. fill volume of a bottle"),
          ("Right-skewed", rng.lognormal(3.5, 0.6, 5000), GOLD, "e.g. income, basket value"),
          ("Left-skewed", 100 - rng.lognormal(2.5, 0.6, 5000), RUST, "e.g. exam scores on an easy test")]
for ax, (name, x, col, eg) in zip(axes, shapes):
    ax.hist(x, bins=45, color=col, edgecolor="white")
    ax.axvline(np.mean(x), color=NAVY, lw=2, ls="--"); ax.axvline(np.median(x), color=INK, lw=2)
    ax.set_title(name); ax.set_xlabel(eg); ax.set_yticks([])
axes[0].text(0.02, 0.95, "dashed = mean\nsolid = median", transform=axes[0].transAxes, va="top", fontsize=11, color=SLATE)
fig.tight_layout()
save(fig, "2-2", "f01")

# --- F02 · When the mean misleads: monthly income of bank customers ---------
x = income["monthly_income_naira"]
fig, ax = plt.subplots()
ax.hist(x[x < 1_500_000], bins=60, color=TEAL, edgecolor="white")
ax.axvline(x.median(), color=GOLD, lw=3, label=f"Median ₦{x.median():,.0f}")
ax.axvline(x.mean(), color=RUST, lw=3, ls="--", label=f"Mean ₦{x.mean():,.0f}")
ax.xaxis.set_major_formatter(FuncFormatter(naira))
ax.set(title="500 bank customers: the 'average' income describes almost nobody",
       xlabel="Monthly income (customers above ₦1.5m not shown)", ylabel="Customers")
ax.legend(fontsize=13)
save(fig, "2-2", "f02")

# --- F03 · Same idea, different spread: delivery times by warehouse ---------
order = ["Ikeja", "Apapa", "Lekki"]
fig, ax = plt.subplots()
data = [deliv.loc[deliv.warehouse == w, "delivery_time_hours"] for w in order]
bp = ax.boxplot(data, vert=False, patch_artist=True, widths=0.55, medianprops=dict(color=GOLD, lw=3))
for patch in bp["boxes"]: patch.set(facecolor="#D6E6EF", edgecolor=TEAL)
ax.set_yticks([1, 2, 3], order)
ax.set(title="Delivery times: look at the spread, not just the middle", xlabel="Hours from order to doorstep")
save(fig, "2-2", "f03")

# --- F04 · Anatomy of a box plot (basket sizes) ------------------------------
b = basket["basket_size_naira"]
q1, med, q3 = b.quantile([.25, .5, .75]); iqr = q3 - q1
fig, ax = plt.subplots(figsize=(10, 4.2))
ax.boxplot(b, vert=False, patch_artist=True, widths=0.5,
           boxprops=dict(facecolor="#D6E6EF", edgecolor=TEAL), medianprops=dict(color=GOLD, lw=3))
for val, lab, yy in [(q1, f"Q1 ₦{q1:,.0f}", 1.38), (med, f"Median ₦{med:,.0f}", 1.45), (q3, f"Q3 ₦{q3:,.0f}", 1.38)]:
    ax.annotate(lab, xy=(val, 1.27), xytext=(val, yy), ha="center", color=NAVY, fontsize=12)
ax.annotate(f"IQR = ₦{iqr:,.0f}\n(middle 50% of baskets)", xy=((q1 + q3) / 2, 0.73), ha="center", color=TEAL, fontsize=12)
ax.annotate("outliers: beyond 1.5 × IQR", xy=(b.max(), 1.0), xytext=(b.max() - 2500, 0.62), color=RUST, fontsize=12,
            arrowprops=dict(arrowstyle="->", color=RUST))
ax.set_yticks([]); ax.set_ylim(0.5, 1.6)
ax.xaxis.set_major_formatter(FuncFormatter(naira))
ax.set(title="Reading a box plot: 400 Lagos supermarket receipts", xlabel="Basket value")
save(fig, "2-2", "f04")

# --- F05 · The normal curve and the 68–95–99.7 rule --------------------------
z = np.linspace(-4, 4, 400)
fig, ax = plt.subplots()
ax.plot(z, stats.norm.pdf(z), color=NAVY, lw=2.5)
for k, col, lab in [(3, "#D6E6EF", "99.7%"), (2, SKY, "95%"), (1, TEAL, "68%")]:
    m = (z >= -k) & (z <= k); ax.fill_between(z[m], stats.norm.pdf(z[m]), color=col)
ax.annotate("68% within ±1 SD", xy=(0, 0.17), ha="center", color="white", fontsize=13, fontweight="bold")
ax.annotate("95% within ±2 SD", xy=(1.5, 0.07), xytext=(2.3, 0.22), color=NAVY, fontsize=13, fontweight="bold",
            arrowprops=dict(arrowstyle="->", color=NAVY))
ax.annotate("99.7% within ±3 SD", xy=(2.5, 0.01), xytext=(2.4, 0.12), color=NAVY, fontsize=13, fontweight="bold",
            arrowprops=dict(arrowstyle="->", color=NAVY))
ax.set_xticks(range(-3, 4), ["μ−3σ", "μ−2σ", "μ−σ", "μ", "μ+σ", "μ+2σ", "μ+3σ"])
ax.set_yticks([]); ax.grid(False)
ax.set(title="The normal curve: where 'typical' and 'unusual' live")
save(fig, "2-2", "f05")

# --- F06 · The Central Limit Theorem in action -------------------------------
pop = income["monthly_income_naira"].clip(upper=2_000_000).values
fig, axes = plt.subplots(1, 4, figsize=(13, 4))
axes[0].hist(pop, bins=40, color=SLATE, edgecolor="white"); axes[0].set_title("Population: raw incomes")
for ax, n in zip(axes[1:], [5, 30, 100]):
    means = [rng.choice(pop, n).mean() for _ in range(3000)]
    ax.hist(means, bins=40, color=TEAL, edgecolor="white"); ax.set_title(f"Means of samples of n={n}")
for ax in axes: ax.set_yticks([]); ax.xaxis.set_major_formatter(FuncFormatter(naira)); ax.tick_params(axis="x", labelsize=9)
fig.suptitle("Skewed population → bell-shaped sample means as n grows", x=0.01, ha="left", color=NAVY, fontweight="bold", fontsize=15)
fig.tight_layout()
save(fig, "2-2", "f06")

# --- F07 · What '95% confident' really means (50 repeated samples) -----------
popd = deliv["delivery_time_hours"].values; mu = popd.mean()
fig, ax = plt.subplots()
miss = 0
for i in range(50):
    s = rng.choice(popd, 40); m = s.mean(); h = 1.96 * s.std(ddof=1) / np.sqrt(40)
    hit = (m - h <= mu <= m + h); miss += (not hit)
    ax.plot([m - h, m + h], [i, i], color=TEAL if hit else RUST, lw=2.2)
    ax.plot(m, i, "o", color=TEAL if hit else RUST, ms=4)
ax.axvline(mu, color=GOLD, lw=2.5, label=f"True average {mu:.2f} h")
ax.set(title=f"50 samples, 50 intervals: {50 - miss} capture the truth, {miss} miss (red)",
       xlabel="Average delivery time (hours)", ylabel="Sample number")
ax.legend(loc="lower right")
save(fig, "2-2", "f07")

# --- F08 · Confidence intervals for average basket by region ----------------
g = basket.groupby("region")["basket_size_naira"].agg(["mean", "std", "count"])
g["half"] = stats.t.ppf(0.975, g["count"] - 1) * g["std"] / np.sqrt(g["count"])
g = g.sort_values("mean")
fig, ax = plt.subplots()
ax.errorbar(g["mean"], g.index, xerr=g["half"], fmt="o", color=TEAL, ecolor=TEAL, elinewidth=3, capsize=6, ms=9)
for reg, r in g.iterrows():
    ax.text(r["mean"] + r["half"] + 60, reg, f"₦{r['mean']:,.0f} ± {r['half']:,.0f}  (n={int(r['count'])})", va="center", fontsize=11, color=INK)
ax.xaxis.set_major_formatter(FuncFormatter(naira))
ax.set_xlim(7300, 10200)
ax.set(title="Average basket by region with 95% confidence intervals", xlabel="Average basket value")
save(fig, "2-2", "f08")

# --- F09 · Binomial: defaults among 20 new loans (p = 10%) -------------------
k = np.arange(0, 11); p = stats.binom.pmf(k, 20, 0.10)
fig, ax = plt.subplots()
bars = ax.bar(k, p, color=[GOLD if kk >= 5 else TEAL for kk in k])
ax.bar_label(bars, labels=[f"{v:.0%}" if v >= 0.005 else "" for v in p], padding=3, fontsize=11)
ax.set_xticks(k)
ax.set(title="20 loans, each with a 10% default risk: how many default?", xlabel="Number of defaults", ylabel="Probability")
ax.text(6.3, 0.2, f"P(5 or more) = {1 - stats.binom.cdf(4, 20, .1):.1%}", color=GOLD, fontsize=14, fontweight="bold")
save(fig, "2-2", "f09")

# --- F10 · Bayes with natural frequencies: a fraud alert -------------------
fig, ax = plt.subplots(figsize=(10, 4.6))
total, fraud = 10000, 50; tp = 0.95 * fraud; fp = 0.05 * (total - fraud)
ax.barh(["Flagged by the system"], [tp], color=RUST, label=f"Real fraud: {tp:.0f}")
ax.barh(["Flagged by the system"], [fp], left=[tp], color=SKY, label=f"False alarms: {fp:.0f}")
ax.set_xlim(0, tp + fp + 30)
ax.text(tp + fp / 2, 0, f"Only {tp / (tp + fp):.0%} of alerts are real fraud", ha="center", va="center", fontsize=15, color=NAVY, fontweight="bold")
ax.set(title="10,000 transactions · 0.5% fraud · alarm 95% accurate", xlabel="Number of flagged transactions")
ax.legend(loc="upper center", bbox_to_anchor=(0.5, -0.22), ncol=2); ax.grid(axis="y", visible=False)
save(fig, "2-2", "f10")
