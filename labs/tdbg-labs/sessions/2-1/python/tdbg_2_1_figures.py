# =============================================================================
# TDBG · Session 2.1 · The Analytics Mindset, Data Literacy & Your Toolkit
# Replication script — regenerates every chart in the Session 2.1 deck (Python)
# Run from the project root (the folder with tdbg-labs.Rproj):
#     python sessions/2-1/python/tdbg_2_1_figures.py
# or, in RStudio: open this file and click "Source Script" (uses reticulate).
# =============================================================================
import sys; sys.path.insert(0, "python")
import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.ticker import FuncFormatter
from tdbg_style import *

set_style()
tx = pd.read_csv("data/retail_transactions.csv", parse_dates=["date"])

# --- Fig S2.1-F01 · What one row looks like: basket value per receipt --------
fig, ax = plt.subplots()
ax.hist(tx["basket_naira"], bins=50, color=TEAL, edgecolor="white")
ax.axvline(tx["basket_naira"].median(), color=GOLD, lw=2.5, label=f"Median ₦{tx['basket_naira'].median():,.0f}")
ax.axvline(tx["basket_naira"].mean(), color=RUST, lw=2.5, ls="--", label=f"Mean ₦{tx['basket_naira'].mean():,.0f}")
ax.xaxis.set_major_formatter(FuncFormatter(naira))
ax.set(title="2,000 receipts: most baskets are small, a few are very large",
       xlabel="Basket value per receipt", ylabel="Number of receipts")
ax.legend()
save(fig, "2-1", "f01")

# --- Fig S2.1-F02 · Descriptive analytics: revenue by category ---------------
rev = tx.groupby("category")["basket_naira"].sum().sort_values() / 1e6
fig, ax = plt.subplots()
bars = ax.barh(rev.index, rev.values, color=[GOLD if c == rev.idxmax() else TEAL for c in rev.index])
ax.bar_label(bars, labels=[f"₦{v:.1f}m" for v in rev.values], padding=4, color=INK)
ax.set(title="Descriptive: where did 2025 revenue come from?", xlabel="Revenue (₦ million)", ylabel="")
ax.grid(axis="y", visible=False)
save(fig, "2-1", "f02")

# --- Fig S2.1-F03 · Monthly revenue trend (the December spike) ---------------
monthly = tx.groupby(tx["date"].dt.to_period("M"))["basket_naira"].sum() / 1e6
fig, ax = plt.subplots()
ax.plot(monthly.index.astype(str), monthly.values, marker="o", color=TEAL, lw=2.5)
ax.annotate("December festive peak", xy=(11, monthly.iloc[11]), xytext=(7.2, monthly.max() * 0.98),
            arrowprops=dict(arrowstyle="->", color=GOLD), color=NAVY, fontsize=12)
ax.set(title="Diagnostic question: why does December jump?", xlabel="Month (2025)", ylabel="Revenue (₦ million)")
ax.set_xticks(range(12)); ax.set_xticklabels([m[-2:] for m in monthly.index.astype(str)])
save(fig, "2-1", "f03")

# --- Fig S2.1-F04 · Shoppers by hour of day ----------------------------------
by_hour = tx.groupby("hour").size()
fig, ax = plt.subplots()
ax.bar(by_hour.index, by_hour.values, color=[GOLD if h in (16, 17) else TEAL for h in by_hour.index])
ax.set(title="Operational question: when should we roster more cashiers?", xlabel="Hour of day", ylabel="Receipts")
ax.set_xticks(by_hour.index)
save(fig, "2-1", "f04")

# --- Fig S2.1-F05 · Loyalty members vs others (a first comparison) -----------
med = tx.groupby("loyalty_member")["basket_naira"].median()
fig, ax = plt.subplots(figsize=(10, 5.6))
bars = ax.bar(["Not a member", "Loyalty member"], [med["No"], med["Yes"]], color=[SLATE, GOLD], width=0.55)
ax.bar_label(bars, labels=[f"₦{v:,.0f}" for v in [med["No"], med["Yes"]]], padding=4, fontsize=14, color=INK)
ax.yaxis.set_major_formatter(FuncFormatter(naira))
ax.set(title="Typical (median) basket: loyalty members spend more — but why?", ylabel="Median basket value")
save(fig, "2-1", "f05")
