# =========================================================================
# LAB 3: A 95% confidence interval for average basket size (Python twin)
# TDBG - Session 2.2
# Dataset: data/retail_basket_sizes.csv (Lagos supermarket chain, n = 400)
# =========================================================================
import numpy as np, pandas as pd
from scipy import stats

x = pd.read_csv("data/retail_basket_sizes.csv")["basket_size_naira"]
n, mean, sd = len(x), x.mean(), x.std(ddof=1)
se = sd / np.sqrt(n)                          # standard error: precision of the sample mean

# Method A: by hand with z = 1.96
lo_z, hi_z = mean - 1.96 * se, mean + 1.96 * se
# Method B: the t distribution (what software uses; almost identical for n = 400)
t_crit = stats.t.ppf(0.975, df=n - 1)
lo_t, hi_t = stats.t.interval(0.95, df=n - 1, loc=mean, scale=se)

print(f"""
n = {n} | mean = N{mean:,.2f} | sd = N{sd:,.2f} | SE = N{se:,.2f}
Method A (z = 1.96)      : 95% CI = [N{lo_z:,.2f} , N{hi_z:,.2f}]
Method B (t = {t_crit:.4f}) : 95% CI = [N{lo_t:,.2f} , N{hi_t:,.2f}]

BUSINESS INTERPRETATION: we are 95% confident that the TRUE average basket
across all the chain's transactions lies between N{lo_z:,.0f} and N{hi_z:,.0f}.
""")

# By region: which store areas really differ?
g = (pd.read_csv("data/retail_basket_sizes.csv").groupby("region")["basket_size_naira"]
       .agg(["mean", "std", "count"]))
g["half_width"] = stats.t.ppf(0.975, g["count"] - 1) * g["std"] / np.sqrt(g["count"])
g["lower"], g["upper"] = g["mean"] - g["half_width"], g["mean"] + g["half_width"]
print(g.round(0))
# YOUR TURN: do the Ikeja and Lagos Mainland intervals overlap? What does that suggest?
