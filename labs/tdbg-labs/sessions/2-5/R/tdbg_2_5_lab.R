# =============================================================================
# TDBG · Session 2.5 LAB · Did the new store layout work? (R)
# Data: data/store_layout_test.csv  — 24 Lagos stores x 28 days
#       (12 stores got the NEW layout, 12 kept the OLD one)
#       data/retail_transactions.csv — for the chi-square and loyalty tests
# =============================================================================
library(dplyr); library(readr)
d  <- read_csv("data/store_layout_test.csv", show_col_types = FALSE)
tx <- read_csv("data/retail_transactions.csv", show_col_types = FALSE)

# ---- STEP 1 · State the hypotheses BEFORE looking at results ---------------------------
# H0: the new layout does not change average conversion (difference = 0)
# H1: it does (difference != 0).   Significance level alpha = 0.05

# ---- STEP 2 · Choose the right unit: the STORE got the layout, so analyse stores --------
st <- d |> group_by(store_id, layout) |>
  summarise(conv = mean(conversion_rate), basket = mean(avg_basket_naira), .groups = "drop")
st |> group_by(layout) |> summarise(mean_conv = mean(conv), sd_conv = sd(conv), stores = n())

# ---- STEP 3 · Two-sample t-test (Welch: does not assume equal spreads) -------------------
t.test(conv ~ layout, data = st)
#   Read: the 95% CI for the difference, and the p-value.

# ---- STEP 4 · The pseudo-replication trap: pretend every visitor is independent ---------
pool <- d |> group_by(layout) |> summarise(buyers = sum(buyers), visitors = sum(visitors))
prop.test(pool$buyers, pool$visitors)          # tiny p-value — but wrong unit!

# ---- STEP 5 · Second metric: basket value per store -----------------------------------------
t.test(basket ~ layout, data = st)

# ---- STEP 6 · Chi-square test of independence: payment method vs region -----------------------
tab <- table(tx$region, tx$payment_method); tab
chisq.test(tab)

# ---- STEP 7 · Skewed data: loyalty vs non-loyalty basket values ----------------------------------
wilcox.test(basket_naira ~ loyalty_member, data = tx)     # rank-based (Mann–Whitney)
t.test(log(basket_naira) ~ loyalty_member, data = tx)     # or a t-test on log values

# ---- YOUR TURN ------------------------------------------------------------------------------------
# (a) Write a 3-sentence recommendation to the COO on the layout, using CIs, not just p-values.
# (b) The basket uplift is +N219 per receipt. With ~520 visitors and ~21% conversion per store-day,
#     what is the extra revenue per store per year? Is that worth a N4m refit per store?
# (c) Why is the store, not the visitor, the right unit here?
