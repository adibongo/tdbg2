# =============================================================================
# TDBG · Session 2.3 LAB · A disciplined EDA of a messy loan book (Python)
# Data: data/microfinance_loans_raw.csv  (1,515 rows — some of them wrong!)
# =============================================================================
import numpy as np, pandas as pd
import matplotlib.pyplot as plt

raw = pd.read_csv("data/microfinance_loans_raw.csv")

# ---- STEP 1 · Profile --------------------------------------------------------------
print(raw.shape); raw.info(); print(raw.describe(include="all").T)

# ---- STEP 2 · Completeness ------------------------------------------------------------
print((raw.isna().mean() * 100).round(1))
print(raw.assign(b=raw["branch"].str.strip().str.lower())
         .groupby("b")["monthly_income_naira"].apply(lambda s: s.isna().mean()))

# ---- STEP 3 · Uniqueness ---------------------------------------------------------------
print("duplicate rows:", raw.duplicated().sum(), "| repeated IDs:", raw["loan_id"].duplicated().sum())

# ---- STEP 4 · Consistency ----------------------------------------------------------------
print(raw["branch"].value_counts())

# ---- STEP 5 · Validity & outliers ----------------------------------------------------------
print(raw["borrower_age"].agg(["min", "max"]))
print(raw[raw["borrower_age"] > 100])
ratio = raw["loan_amount_naira"] / raw["monthly_income_naira"]
print(raw.assign(ratio=ratio).nlargest(10, "ratio")[["loan_id", "loan_amount_naira", "monthly_income_naira", "ratio"]])

# ---- STEP 6 · Clean — every decision written down ---------------------------------------------
clean = raw.drop_duplicates().copy()
clean["branch"] = clean["branch"].str.strip().str.title()
clean.loc[clean["borrower_age"] > 100, "borrower_age"] = np.nan
ratio = clean["loan_amount_naira"] / clean["monthly_income_naira"]
clean = clean[~(ratio > 10)]
print(len(raw), "->", len(clean), "rows")

# ---- STEP 7 · Explore -------------------------------------------------------------------------
clean["loan_amount_naira"].plot(kind="hist", bins=np.geomspace(2.5e4, 3e6, 50), logx=True); plt.show()
print(clean.groupby("sector")["defaulted"].agg(["mean", "count"]).sort_values("mean"))
bands = pd.cut(clean["borrower_age"], [18, 25, 35, 45, 55, 70])
print(clean.groupby(bands, observed=True)["defaulted"].agg(["mean", "count"]))
print(clean[["borrower_age", "monthly_income_naira", "loan_amount_naira", "term_months", "defaulted"]].corr().round(2))

# ---- STEP 8 · Save ---------------------------------------------------------------------------
# clean.to_csv("data/microfinance_loans_cleaned_by_me.csv", index=False)

# ---- YOUR TURN ---------------------------------------------------------------------------------
# (a) Which branch has the highest default rate after cleaning? Is the gap big enough to matter?
# (b) Drop, fill, or flag missing incomes? Argue your choice.
# (c) Write three hypotheses from your EDA that a model in Session 3.4 should test.
