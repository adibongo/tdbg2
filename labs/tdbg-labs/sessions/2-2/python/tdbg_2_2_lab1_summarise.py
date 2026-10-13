# =========================================================================
# LAB 1: Measures of Central Tendency and Spread  (Python twin of the R lab)
# TDBG - Session 2.2 (Statistical Foundations for Decision-Making)
# Dataset: data/retail_basket_sizes.csv (Lagos supermarket chain, n = 400)
# Run from the project root (RStudio: open tdbg-labs.Rproj first).
# =========================================================================
import pandas as pd
import matplotlib.pyplot as plt

basket = pd.read_csv("data/retail_basket_sizes.csv")
print(basket.info()); print(basket.head())
x = basket["basket_size_naira"]; n = len(x)

# ---- Centre --------------------------------------------------------------
mean_x, median_x = x.mean(), x.median()
mode_x = x.mode().iloc[0]                    # pandas returns all modes; take the first
mode_count = (x == mode_x).sum()

# ---- Spread --------------------------------------------------------------
sd_x  = x.std()                              # pandas .std() uses n-1 (sample SD), like R's sd()
var_x = x.var()
q1, q3 = x.quantile([0.25, 0.75])
iqr_x = q3 - q1
cv = sd_x / mean_x                           # coefficient of variation: spread relative to the mean

# ---- Categorical mode -----------------------------------------------------
most_common_payment = basket["payment_method"].mode().iloc[0]

print(f"""
================ RETAIL BASKET SIZE SUMMARY (N = {n}) ================
Mean basket size      : N{mean_x:,.2f}
Median basket size    : N{median_x:,.2f}
Mode basket size      : N{mode_x:,.0f} (appears {mode_count} times)
Standard deviation    : N{sd_x:,.2f}
Variance              : {var_x:,.2f}
Q1 / Q3               : N{q1:,.2f} / N{q3:,.2f}
IQR                   : N{iqr_x:,.2f}
Min / Max             : N{x.min():,} / N{x.max():,}
Coefficient of var.   : {cv:.1%}
Most common payment   : {most_common_payment}
Mean - median gap     : N{mean_x - median_x:,.2f} (positive => right-skewed)
""")
print(x.describe())   # cross-check

# ---- Visualise --------------------------------------------------------------
fig, (a1, a2) = plt.subplots(2, 1, figsize=(9, 7))
a1.hist(x, bins=25, color="#0B5E82", edgecolor="white")
a1.axvline(mean_x, color="#B5541A", ls="--", lw=2, label=f"Mean = N{mean_x:,.0f}")
a1.axvline(median_x, color="#D99A2B", ls="--", lw=2, label=f"Median = N{median_x:,.0f}")
a1.set(title="Distribution of basket sizes (n = 400)", xlabel="Basket size (Naira)", ylabel="Receipts"); a1.legend()
a2.boxplot(x, vert=False); a2.set(title="Box plot of basket sizes", xlabel="Basket size (Naira)")
plt.tight_layout(); plt.show()
