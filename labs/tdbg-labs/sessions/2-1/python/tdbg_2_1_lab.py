# =============================================================================
# TDBG · Session 2.1 LAB · Your first look at a real business dataset (Python)
# Dataset: data/retail_transactions.csv — 2,000 receipts from a Lagos retailer
# In RStudio: open this file and run line by line (Ctrl/Cmd + Enter);
# RStudio uses the 'reticulate' package to run Python for you.
# =============================================================================

# ---- 0. Packages ------------------------------------------------------------
# pip install pandas matplotlib      # run ONCE in a terminal if not installed
import pandas as pd                  # data frames: the Python equivalent of R's tibble
import matplotlib.pyplot as plt      # charts

# ---- 1. Load the data -------------------------------------------------------
# rows = observations (receipts), columns = variables (facts about each receipt)
tx = pd.read_csv("data/retail_transactions.csv", parse_dates=["date"])

# ---- 2. Inspect before you analyse ------------------------------------------
print(tx.shape)       # (rows, columns)
print(tx.head())      # first five rows — what does ONE row represent?
tx.info()             # each column and its type (int64, float64, object = text)

# QUESTION: Which columns are categorical (nominal)? Which are numeric (ratio)?

# ---- 3. Data quality checks --------------------------------------------------
print(tx.isna().sum())                    # missing values per column
print(tx["txn_id"].duplicated().sum())    # duplicate receipt IDs
print(tx["basket_naira"].min(), tx["basket_naira"].max())

# ---- 4. Descriptive analytics: what happened? --------------------------------
print(tx["basket_naira"].describe())

summary = (tx.groupby("category")
             .agg(receipts=("txn_id", "count"),
                  revenue_naira=("basket_naira", "sum"),
                  median_basket=("basket_naira", "median"))
             .sort_values("revenue_naira", ascending=False))
print(summary)

# ---- 5. A first chart --------------------------------------------------------
fig, ax = plt.subplots(figsize=(9, 5))
ax.hist(tx["basket_naira"], bins=50, color="#0B5E82", edgecolor="white")
ax.set(title="Basket value per receipt", xlabel="Naira", ylabel="Receipts")
plt.show()

# ---- 6. YOUR TURN -------------------------------------------------------------
# (a) Which store has the highest total revenue?
# (b) What share of receipts are from loyalty members?
# (c) Write ONE predictive business question this dataset could answer.

# ---- Answers (try first!) ------------------------------------------------------
# (a) tx.groupby("store")["basket_naira"].sum().sort_values(ascending=False)
# (b) (tx["loyalty_member"] == "Yes").mean()
# (c) e.g. "How much revenue should we expect next December, by store?"
