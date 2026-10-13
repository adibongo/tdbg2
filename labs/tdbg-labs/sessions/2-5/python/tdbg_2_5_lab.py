# =============================================================================
# TDBG · Session 2.5 LAB · Did the new store layout work? (Python)
# Data: data/store_layout_test.csv and data/retail_transactions.csv
# =============================================================================
import numpy as np, pandas as pd
from scipy import stats
from statsmodels.stats.proportion import proportions_ztest

d = pd.read_csv("data/store_layout_test.csv")
tx = pd.read_csv("data/retail_transactions.csv")

# ---- STEP 1 · Hypotheses: H0 difference = 0 ; H1 difference != 0 ; alpha = 0.05

# ---- STEP 2 · The store is the unit ------------------------------------------------
st = (d.groupby(["store_id", "layout"])
        .agg(conv=("conversion_rate", "mean"), basket=("avg_basket_naira", "mean")).reset_index())
print(st.groupby("layout")["conv"].agg(["mean", "std", "count"]))

# ---- STEP 3 · Welch two-sample t-test ------------------------------------------------
new, old = st[st.layout == "New"], st[st.layout == "Old"]
res = stats.ttest_ind(new.conv, old.conv, equal_var=False)
print(res)
ci = res.confidence_interval(0.95); print("95% CI for difference:", ci)   # scipy >= 1.11

# ---- STEP 4 · The pseudo-replication trap ----------------------------------------------
pool = d.groupby("layout")[["buyers", "visitors"]].sum()
print(proportions_ztest(pool.loc[["New", "Old"], "buyers"], pool.loc[["New", "Old"], "visitors"]))

# ---- STEP 5 · Basket value per store -----------------------------------------------------
print(stats.ttest_ind(new.basket, old.basket, equal_var=False))

# ---- STEP 6 · Chi-square: payment method vs region ------------------------------------------
tab = pd.crosstab(tx.region, tx.payment_method); print(tab)
chi2, p, dof, expected = stats.chi2_contingency(tab); print(f"chi2={chi2:.2f}, df={dof}, p={p:.3f}")

# ---- STEP 7 · Skewed data: loyalty baskets ------------------------------------------------------
yes, no = tx.loc[tx.loyalty_member == "Yes", "basket_naira"], tx.loc[tx.loyalty_member == "No", "basket_naira"]
print(stats.mannwhitneyu(yes, no))
print(stats.ttest_ind(np.log(yes), np.log(no)))

# ---- YOUR TURN -------------------------------------------------------------------------------------
# (a) 3-sentence recommendation to the COO, using CIs.
# (b) Extra revenue per store per year from +N219 per receipt? Worth a N4m refit?
# (c) Why is the store, not the visitor, the right unit?
