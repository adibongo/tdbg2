# =============================================================================
# TDBG · Session 2.3 LAB · A disciplined EDA of a messy loan book (R)
# Data: data/microfinance_loans_raw.csv  (1,515 rows — some of them wrong!)
# Goal: find and fix data problems BEFORE anyone builds a model on this file.
# =============================================================================
library(dplyr); library(readr); library(ggplot2)

raw <- read_csv("data/microfinance_loans_raw.csv", show_col_types = FALSE)

# ---- STEP 1 · Profile: shape, types, first rows --------------------------------
dim(raw); glimpse(raw); summary(raw)

# ---- STEP 2 · Completeness: what is missing? -------------------------------------
colSums(is.na(raw))
round(100 * colMeans(is.na(raw)), 1)          # % missing per column

# Is missing income random, or concentrated somewhere?
raw |> group_by(branch_clean = trimws(tolower(branch))) |>
  summarise(pct_income_missing = mean(is.na(monthly_income_naira)))

# ---- STEP 3 · Uniqueness: duplicate rows / IDs --------------------------------------
sum(duplicated(raw))                  # fully identical rows
sum(duplicated(raw$loan_id))          # repeated loan IDs

# ---- STEP 4 · Consistency: categorical labels -----------------------------------------
count(raw, branch, sort = TRUE)       # spot 'ikeja ' vs 'Ikeja'
count(raw, sector); count(raw, gender)

# ---- STEP 5 · Validity & outliers: numeric ranges ---------------------------------------
range(raw$borrower_age, na.rm = TRUE)                # anything impossible?
raw |> filter(borrower_age > 100)
raw |> mutate(ratio = loan_amount_naira / monthly_income_naira) |>
  arrange(desc(ratio)) |> select(loan_id, loan_amount_naira, monthly_income_naira, ratio) |> head(10)

# ---- STEP 6 · Clean — every decision written down -------------------------------------------
clean <- raw |>
  distinct() |>                                                   # drop 15 exact duplicates
  mutate(branch = tools::toTitleCase(trimws(branch)),             # one spelling per branch
         borrower_age = ifelse(borrower_age > 100, NA, borrower_age),   # impossible -> missing
         ratio = loan_amount_naira / monthly_income_naira) |>
  filter(is.na(ratio) | ratio <= 10) |>                           # drop likely extra-zero entries
  select(-ratio)
nrow(raw); nrow(clean)

# ---- STEP 7 · Explore: distributions and relationships ----------------------------------------
ggplot(clean, aes(loan_amount_naira)) + geom_histogram(bins = 50) + scale_x_log10()
clean |> group_by(sector) |> summarise(default_rate = mean(defaulted), n = n()) |> arrange(desc(default_rate))
clean |> mutate(band = cut(borrower_age, c(18, 25, 35, 45, 55, 70))) |>
  group_by(band) |> summarise(default_rate = mean(defaulted), n = n())
cor(select(clean, borrower_age, monthly_income_naira, loan_amount_naira, term_months, defaulted),
    use = "pairwise.complete.obs") |> round(2)

# ---- STEP 8 · Save the cleaned file for modelling sessions ------------------------------------
# write_csv(clean, "data/microfinance_loans_cleaned_by_me.csv")

# ---- YOUR TURN -----------------------------------------------------------------------------------
# (a) Which branch has the highest default rate after cleaning? Is the gap big enough to matter?
# (b) Should missing incomes be dropped, filled with the median, or kept as 'unknown'? Argue it.
# (c) Write three hypotheses from your EDA that a model in Session 3.4 should test.
