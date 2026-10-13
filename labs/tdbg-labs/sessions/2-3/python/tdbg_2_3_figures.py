# =============================================================================
# TDBG · Session 2.3 · Exploratory Data Analysis
# Replication script — regenerates every chart in the Session 2.3 deck (Python)
# Data: data/microfinance_loans_raw.csv — a deliberately messy loan book
# Run from the project root:  python sessions/2-3/python/tdbg_2_3_figures.py
# =============================================================================
import sys; sys.path.insert(0, "python")
import numpy as np, pandas as pd
import matplotlib.pyplot as plt
from matplotlib.ticker import FuncFormatter, PercentFormatter
from tdbg_style import *

set_style()
raw = pd.read_csv("data/microfinance_loans_raw.csv")

# --- F01 · Missing values per column ------------------------------------------
miss = raw.isna().mean().sort_values() * 100
fig, ax = plt.subplots()
bars = ax.barh(miss.index, miss.values, color=[RUST if v > 0 else GRID for v in miss.values])
ax.bar_label(bars, labels=[f"{v:.1f}%" if v > 0 else "0%" for v in miss.values], padding=4, fontsize=11)
ax.set(title="Completeness check: income is missing for 6% of loans", xlabel="% of rows missing")
ax.grid(axis="y", visible=False)
save(fig, "2-3", "f01")

# --- F02 · Loan amounts: spotting entry errors ----------------------------------
fig, ax = plt.subplots()
ax.hist(raw["loan_amount_naira"], bins=np.geomspace(2.5e4, 1.2e7, 60), color=TEAL, edgecolor="white")
ax.set_xscale("log")
ax.xaxis.set_major_formatter(FuncFormatter(naira))
big = raw["loan_amount_naira"].max()
ax.annotate(f"₦{big/1e6:.2f}m on a ₦320k monthly income —\n30× income. An extra zero?", xy=(big, 1), xytext=(1.0e6, 60),
            arrowprops=dict(arrowstyle="->", color=RUST), color=RUST, fontsize=12)
ax.set(title="Loan amounts (log scale): the long tail hides typing errors", xlabel="Loan amount (log scale)", ylabel="Loans")
save(fig, "2-3", "f02")

# --- F03 · Impossible values: borrower age ----------------------------------------
fig, ax = plt.subplots(figsize=(10, 4.2))
ages = raw["borrower_age"].dropna()
ax.boxplot(ages, vert=False, widths=0.5, patch_artist=True,
           boxprops=dict(facecolor="#D6E6EF", edgecolor=TEAL), medianprops=dict(color=GOLD, lw=3),
           flierprops=dict(marker="o", markerfacecolor=RUST, markeredgecolor=RUST, markersize=8))
ax.annotate("Age 140 — impossible.\nA validity error, not an outlier.", xy=(140, 1), xytext=(100, 1.3), color=RUST, fontsize=12,
            arrowprops=dict(arrowstyle="->", color=RUST))
ax.set_yticks([]); ax.set_ylim(0.6, 1.55)
ax.set(title="Validity check: borrower age", xlabel="Age (years)")
save(fig, "2-3", "f03")

# --- F04 · Consistency: one branch, many spellings ----------------------------------
lab = raw["branch"].value_counts()
fig, ax = plt.subplots()
cols = [RUST if (l != l.strip() or l != l.title()) else TEAL for l in lab.index]
ax.bar([repr(l) for l in lab.index], lab.values, color=cols)
ax.set(title="Consistency check: 'Ikeja' and 'ikeja ' are counted as different branches", ylabel="Loans")
plt.xticks(rotation=40, ha="right")
save(fig, "2-3", "f04")

# --- Clean (the decisions taught in the session) ------------------------------------
clean = raw.drop_duplicates().copy()
clean["branch"] = clean["branch"].str.strip().str.title()
clean.loc[clean["borrower_age"] > 100, "borrower_age"] = np.nan
# entry errors: a loan worth more than 10x monthly income (typical is about 2x)
ratio = clean["loan_amount_naira"] / clean["monthly_income_naira"]
clean = clean[~(ratio > 10)]

# --- F05 · Relationship: income vs loan size, coloured by default ------------------
fig, ax = plt.subplots()
for flag, col, lab_ in [(0, SKY, "Repaid"), (1, RUST, "Defaulted")]:
    s = clean[clean["defaulted"] == flag]
    ax.scatter(s["monthly_income_naira"], s["loan_amount_naira"], s=14 if flag == 0 else 22, alpha=0.6, color=col, label=lab_)
ax.set_xscale("log"); ax.set_yscale("log")
ax.xaxis.set_major_formatter(FuncFormatter(naira)); ax.yaxis.set_major_formatter(FuncFormatter(naira))
ax.set(title="Bigger incomes, bigger loans — and defaults are scattered throughout",
       xlabel="Monthly income (log)", ylabel="Loan amount (log)")
ax.legend()
save(fig, "2-3", "f05")

# --- F06 · Default rate by age band ---------------------------------------------------
clean["age_band"] = pd.cut(clean["borrower_age"], [18, 25, 35, 45, 55, 70], labels=["18–25", "26–35", "36–45", "46–55", "56+"])
rate = clean.groupby("age_band", observed=True)["defaulted"].agg(["mean", "count"])
fig, ax = plt.subplots()
bars = ax.bar(rate.index.astype(str), rate["mean"] * 100, color=[GOLD if i == 0 else TEAL for i in range(len(rate))])
ax.bar_label(bars, labels=[f"{m:.0%}\n(n={n})" for m, n in zip(rate["mean"], rate["count"])], padding=3, fontsize=11)
ax.axhline(clean["defaulted"].mean() * 100, color=SLATE, ls="--", lw=1.5)
ax.text(4.45, clean["defaulted"].mean() * 100 + 0.4, "portfolio average", color=SLATE, ha="right", fontsize=11)
ax.yaxis.set_major_formatter(PercentFormatter()); ax.set_ylim(0, 21)
ax.set(title="Hypothesis from EDA: younger borrowers default more often", xlabel="Borrower age band", ylabel="Default rate")
save(fig, "2-3", "f06")

# --- F07 · Correlation heat map of numeric columns ------------------------------------
clean["repayment_to_income"] = clean["loan_amount_naira"] / clean["term_months"] / clean["monthly_income_naira"]
num = clean[["borrower_age", "monthly_income_naira", "loan_amount_naira", "term_months", "monthly_rate_pct",
             "prior_loans", "repayment_to_income", "defaulted"]].corr()
fig, ax = plt.subplots(figsize=(9.5, 7))
im = ax.imshow(num, cmap="RdBu_r", vmin=-1, vmax=1)
labels = ["age", "income", "loan amt", "term", "rate %", "prior loans", "repay/income", "defaulted"]
ax.set_xticks(range(8), labels, rotation=40, ha="right"); ax.set_yticks(range(8), labels); ax.grid(False)
for i in range(8):
    for j in range(8):
        ax.text(j, i, f"{num.iloc[i, j]:.2f}", ha="center", va="center", fontsize=10, color="white" if abs(num.iloc[i, j]) > .5 else INK)
fig.colorbar(im, ax=ax, shrink=0.8)
ax.set_title("Correlations: strong links among inputs, weak single links to default")
save(fig, "2-3", "f07")

# --- F08 · Default rate by number of prior loans -----------------------------------------
pr = clean.assign(prior=clean["prior_loans"].clip(upper=4)).groupby("prior")["defaulted"].agg(["mean", "count"])
fig, ax = plt.subplots()
bars = ax.bar(["0", "1", "2", "3", "4+"], pr["mean"] * 100, color=TEAL)
ax.bar_label(bars, labels=[f"{m:.0%}\n(n={n})" for m, n in zip(pr["mean"], pr["count"])], padding=3, fontsize=11)
ax.yaxis.set_major_formatter(PercentFormatter()); ax.set_ylim(0, 17)
ax.set(title="Repeat borrowers default a little less — but watch the small groups", xlabel="Prior loans with us", ylabel="Default rate")
save(fig, "2-3", "f08")
