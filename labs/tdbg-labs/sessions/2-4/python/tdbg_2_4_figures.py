# =============================================================================
# TDBG · Session 2.4 · Data Visualisation & Storytelling for Business
# Replication script — regenerates every chart in the Session 2.4 deck (Python)
# Data: data/telecom_monthly_kpis.csv — 24 months x 5 regions of a telco
# =============================================================================
import sys; sys.path.insert(0, "python")
import numpy as np, pandas as pd
import matplotlib.pyplot as plt
from tdbg_style import *

set_style()
k = pd.read_csv("data/telecom_monthly_kpis.csv")
k["date"] = pd.to_datetime(k["month"])
regions = ["Lagos", "North-West", "South-South", "South-East", "North-Central"]

# --- F01 · Chart chooser: six questions, six charts ----------------------------------
fig, ax = plt.subplots(2, 3, figsize=(13, 7))
rev25 = k[k.month.str[:4] == "2025"].groupby("region")["revenue_bn_naira"].sum().sort_values()
ax[0, 0].barh(rev25.index, rev25.values, color=TEAL); ax[0, 0].set_title("Compare categories → bar")
lag = k[k.region == "Lagos"]; ax[0, 1].plot(lag["date"], lag["revenue_bn_naira"], color=TEAL, lw=2.5)
ax[0, 1].set_title("Change over time → line"); ax[0, 1].tick_params(axis="x", labelrotation=30, labelsize=9)
ax[0, 2].scatter(k["network_uptime_pct"], k["nps"], color=TEAL, alpha=.7); ax[0, 2].set_title("Relationship → scatter")
ax[1, 0].hist(k["arpu_naira"], bins=20, color=TEAL, edgecolor="white"); ax[1, 0].set_title("Distribution → histogram")
sh = k[k.month == "2025-12"].set_index("region")["data_revenue_share"]
ax[1, 1].barh(sh.index, sh.values, color=TEAL, label="Data"); ax[1, 1].barh(sh.index, 1 - sh.values, left=sh.values, color=GRID, label="Voice & other")
ax[1, 1].set_title("Part-to-whole → stacked bar"); ax[1, 1].legend(fontsize=9, loc="lower right")
hm = k.pivot(index="region", columns="month", values="churn_rate_pct").loc[regions]
ax[1, 2].imshow(hm.values, aspect="auto", cmap="YlOrRd"); ax[1, 2].set_yticks(range(5), regions, fontsize=9)
ax[1, 2].set_xticks([0, 12, 23], ["Jan-24", "Jan-25", "Dec-25"]); ax[1, 2].set_title("Pattern in a grid → heat map"); ax[1, 2].grid(False)
for a in ax.flat: a.title.set_fontsize(13)
fig.tight_layout()
save(fig, "2-4", "f01")

# --- F02 · A cluttered chart (what NOT to do) ----------------------------------------------
fig, ax = plt.subplots()
cols = ["#E41A1C", "#377EB8", "#4DAF4A", "#984EA3", "#FF7F00"]
ax.pie(rev25.values, labels=rev25.index, colors=cols, autopct="%1.1f%%", shadow=True, explode=[0.05] * 5, startangle=90,
       textprops=dict(fontsize=12))
ax.set_title("REVENUE BY REGION FY2025 (₦ BN) !!!", color="red", fontsize=18, loc="center")
ax.legend(rev25.index, loc="upper left", bbox_to_anchor=(1.0, 1))
save(fig, "2-4", "f02")

# --- F03 · The same data, decluttered ------------------------------------------------------
fig, ax = plt.subplots()
b = ax.barh(rev25.index, rev25.values, color=[GOLD if r == "Lagos" else "#B8C7D3" for r in rev25.index])
ax.bar_label(b, labels=[f"₦{v:.0f}bn" for v in rev25.values], padding=5, fontsize=13, color=INK)
ax.set_xticks([]); ax.grid(False); ax.spines[["bottom", "left"]].set_visible(False)
ax.tick_params(axis="y", length=0, labelsize=13)
ax.set_title("Lagos earns a third of revenue — more than the next two regions combined")
save(fig, "2-4", "f03")

# --- F04 · Spaghetti: every line the same weight ----------------------------------------------
fig, ax = plt.subplots()
for r, c in zip(regions, PALETTE):
    s = k[k.region == r]; ax.plot(s["date"], s["churn_rate_pct"], lw=2, color=c, label=r)
ax.set(title="Monthly churn rate by region", ylabel="Churn rate (%)"); ax.legend(ncol=5, fontsize=10, loc="upper center")
save(fig, "2-4", "f04")

# --- F05 · Focus: grey the context, colour the story -----------------------------------------
fig, ax = plt.subplots()
for r in regions:
    s = k[k.region == r]
    if r != "North-West": ax.plot(s["date"], s["churn_rate_pct"], color="#C9D2DB", lw=1.8)
s = k[k.region == "North-West"]; ax.plot(s["date"], s["churn_rate_pct"], color=RUST, lw=3.2)
ax.axvline(pd.Timestamp("2025-05-01"), color=SLATE, ls=":", lw=1.5)
ax.text(pd.Timestamp("2025-04-20"), 2.78, "May 2025: network\nuptime starts slipping  ", color=SLATE, fontsize=11, va="top", ha="right")
ax.text(pd.Timestamp("2025-06-01"), 2.45, "North-West", color=RUST, fontsize=13, fontweight="bold")
ax.text(pd.Timestamp("2025-08-01"), 1.83, "Other regions", color=SLATE, fontsize=12)
ax.set(title="North-West churn broke away from the pack in May 2025", ylabel="Monthly churn rate (%)")
save(fig, "2-4", "f05")

# --- F06 · Truncated axis vs honest axis ---------------------------------------------------------
nps = k[k.month.isin(["2025-04", "2025-12"])].groupby("month")["nps"].mean()
fig, ax = plt.subplots(1, 2, figsize=(11, 4.8))
ax[0].bar(["Apr 2025", "Dec 2025"], nps.values, color=[SLATE, RUST]); ax[0].set_ylim(min(nps) - 1, max(nps) + 0.5)
ax[0].set_title("Misleading: axis starts near the data", color=RUST)
ax[1].bar(["Apr 2025", "Dec 2025"], nps.values, color=[SLATE, TEAL]); ax[1].set_ylim(0, 60)
ax[1].set_title("Honest: bars start at zero", color=TEAL)
for a in ax: a.bar_label(a.containers[0], labels=[f"{v:.1f}" for v in nps.values], padding=3)
fig.suptitle("Company-wide NPS — same numbers, two stories", x=0.01, ha="left", color=NAVY, fontweight="bold")
fig.tight_layout()
save(fig, "2-4", "f06")

# --- F07 · Small multiples: NPS by region -----------------------------------------------------------
fig, ax = plt.subplots(1, 5, figsize=(13, 3.6), sharey=True)
for a, r in zip(ax, regions):
    s = k[k.region == r]; a.plot(s["date"], s["nps"], color=RUST if r == "North-West" else TEAL, lw=2)
    a.set_title(r, fontsize=12, color=RUST if r == "North-West" else NAVY); a.set_xticks([]); a.set_ylim(20, 55)
ax[0].set_ylabel("NPS")
fig.suptitle("Small multiples: one chart per region, same scale — the outlier jumps out", x=0.01, ha="left", color=NAVY, fontweight="bold")
fig.tight_layout()
save(fig, "2-4", "f07")

# --- F08 · A one-page executive dashboard ---------------------------------------------------------
dec, nov = k[k.month == "2025-12"], k[k.month == "2025-11"]
fig = plt.figure(figsize=(13, 7.2)); gs = fig.add_gridspec(3, 4, height_ratios=[0.8, 2, 2], hspace=0.55, wspace=0.35)
tiles = [("Revenue (Dec)", f"₦{dec.revenue_bn_naira.sum():.1f}bn", f"{(dec.revenue_bn_naira.sum()/nov.revenue_bn_naira.sum()-1)*100:+.1f}% vs Nov", TEAL),
         ("Subscribers", f"{dec.subscribers_m.sum():.1f}m", f"{(dec.subscribers_m.sum()-nov.subscribers_m.sum())*1000:+.0f}k vs Nov", TEAL),
         ("ARPU", f"₦{(dec.revenue_bn_naira.sum()*1e9/(dec.subscribers_m.sum()*1e6)):,.0f}", "per subscriber / month", TEAL),
         ("Churn — North-West", f"{dec[dec.region=='North-West'].churn_rate_pct.iloc[0]:.1f}%", "up from 1.9% in Apr 2025", RUST)]
for i, (lab, val, sub, c) in enumerate(tiles):
    a = fig.add_subplot(gs[0, i]); a.axis("off")
    a.text(0, 0.95, lab.upper(), fontsize=10, color=SLATE, fontweight="bold", transform=a.transAxes)
    a.text(0, 0.35, val, fontsize=24, color=c, fontweight="bold", transform=a.transAxes)
    a.text(0, 0.0, sub, fontsize=10, color=SLATE, transform=a.transAxes)
a1 = fig.add_subplot(gs[1:, :2]); tot = k.groupby("date")["revenue_bn_naira"].sum()
a1.plot(tot.index, tot.values, color=TEAL, lw=2.5); a1.set_title("Revenue is growing steadily (₦bn per month)", fontsize=13)
a1.tick_params(axis="x", labelrotation=30, labelsize=9)
a2 = fig.add_subplot(gs[1, 2:])
for r in regions:
    s = k[k.region == r]; a2.plot(s["date"], s["churn_rate_pct"], color=RUST if r == "North-West" else "#C9D2DB", lw=2.5 if r == "North-West" else 1.5)
a2.set_title("…but North-West churn is rising (%)", fontsize=13); a2.set_xticks([])
a3 = fig.add_subplot(gs[2, 2:])
for r in regions:
    s = k[k.region == r]; a3.plot(s["date"], s["network_uptime_pct"], color=RUST if r == "North-West" else "#C9D2DB", lw=2.5 if r == "North-West" else 1.5)
a3.set_title("…as its network uptime slips (%)", fontsize=13); a3.tick_params(axis="x", labelrotation=30, labelsize=9)
save(fig, "2-4", "f08")
