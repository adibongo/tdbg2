# =============================================================================
# TDBG · Session 3.1 LAB · Analyse a fintech onboarding A/B test (R)
# Data: data/fintech_onboarding_ab.csv — 12,000 users randomised to A or B
# Primary metric: completed_onboarding (1/0)
# Guardrails: support_tickets per user, first_deposit_naira
# =============================================================================
library(dplyr); library(readr)
d <- read_csv("data/fintech_onboarding_ab.csv", show_col_types = FALSE)

# ---- STEP 0 · Plan (this is done BEFORE the test starts) ----------------------------
# Baseline completion 18%; smallest lift worth shipping = 2 points; alpha 5%; power 80%
power.prop.test(p1 = 0.18, p2 = 0.20, power = 0.80, sig.level = 0.05)   # ~6,000 per group

# ---- STEP 1 · Sanity checks: sample-ratio mismatch and balance --------------------------
table(d$variant)
chisq.test(table(d$variant))                       # SRM: expect a 50/50 split
prop.table(table(d$device, d$variant), 2)          # device mix should match

# ---- STEP 2 · Primary metric --------------------------------------------------------------
g <- d |> group_by(variant) |> summarise(completed = sum(completed_onboarding), users = n(), rate = completed / users)
g
prop.test(g$completed[c(2, 1)], g$users[c(2, 1)])    # B vs A: CI for the difference + p-value

# ---- STEP 3 · Guardrails ---------------------------------------------------------------------
t.test(support_tickets ~ variant, data = d)
d |> filter(completed_onboarding == 1) |> group_by(variant) |>
  summarise(median_deposit = median(first_deposit_naira), mean_deposit = mean(first_deposit_naira))
wilcox.test(first_deposit_naira ~ variant, data = filter(d, completed_onboarding == 1))

# ---- STEP 4 · Segments (exploratory only — not the decision) ------------------------------------
d |> group_by(device, variant) |> summarise(rate = mean(completed_onboarding), n = n(), .groups = "drop")

# ---- STEP 5 · Business value -----------------------------------------------------------------------
# 40,000 sign-ups a month; each completed onboarding is worth ~N2,500 in first-year margin.
lift <- diff(g$rate)            # B minus A
lift * 40000 * 2500             # extra margin per month

# ---- YOUR TURN ----------------------------------------------------------------------------------------
# (a) Ship, don't ship, or extend? Write the decision memo in 5 sentences, including the CI.
# (b) iOS shows almost no lift. Should B be shipped to Android and Web only? Why is that risky?
# (c) What would change if the support-ticket guardrail had risen by 30%?
