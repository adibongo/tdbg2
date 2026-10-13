# =============================================================================
# TDBG · Session 2.4 LAB · From cluttered chart to executive story (Python)
# Data: data/telecom_monthly_kpis.csv — monthly KPIs for 5 regions, 2024–2025
# =============================================================================
import pandas as pd, numpy as np
import matplotlib.pyplot as plt
k = pd.read_csv("data/telecom_monthly_kpis.csv"); k["date"] = pd.to_datetime(k["month"])

# ---- 1. Ask the question first -------------------------------------------------
# "Which region needs the CEO's attention this month, and why?"

# ---- 2. Default chart: every line the same weight ---------------------------------
k.pivot(index="date", columns="region", values="churn_rate_pct").plot(); plt.show()

# ---- 3. Declutter + focus -----------------------------------------------------------
fig, ax = plt.subplots(figsize=(10, 5))
for r, s in k.groupby("region"):
    nw = r == "North-West"
    ax.plot(s["date"], s["churn_rate_pct"], color="#B5541A" if nw else "lightgrey", lw=2.5 if nw else 1)
ax.set(title="North-West churn broke away from the pack in May 2025", ylabel="Monthly churn rate (%)")
ax.spines[["top", "right"]].set_visible(False); plt.show()

# ---- 4. Check the explanation: is uptime the driver? ------------------------------------
nw = k[k.region == "North-West"]
nw.plot.scatter("network_uptime_pct", "churn_rate_pct"); plt.show()
print(nw[["network_uptime_pct", "churn_rate_pct"]].corr())

# ---- 5. Bar chart done right ---------------------------------------------------------------
rev25 = k[k.month.str[:4] == "2025"].groupby("region")["revenue_bn_naira"].sum().sort_values()
ax = rev25.plot.barh(color="#0B5E82"); ax.bar_label(ax.containers[0], fmt="%.0f")
ax.set(title="FY2025 revenue by region (₦bn)", ylabel=""); plt.show()

# ---- YOUR TURN ----------------------------------------------------------------------------
# (a) Small multiples of NPS by region: plt.subplots(1, 5, sharey=True)
# (b) Write a one-slide story: headline, one chart, three bullets, one ask.
