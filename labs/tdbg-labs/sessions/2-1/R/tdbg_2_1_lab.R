# =============================================================================
# TDBG · Session 2.1 LAB · Your first look at a real business dataset (R)
# Dataset: data/retail_transactions.csv — 2,000 receipts from a Lagos retailer
# Open tdbg-labs.Rproj in RStudio, then run this file line by line
# (Ctrl/Cmd + Enter). Read every comment — it tells you WHAT and WHY.
# =============================================================================

# ---- 0. Packages ------------------------------------------------------------
# install.packages(c("dplyr", "readr", "ggplot2"))   # run ONCE if not installed
library(dplyr)    # data manipulation: filter, group, summarise
library(readr)    # fast, friendly CSV reading
library(ggplot2)  # charts

# ---- 1. Load the data -------------------------------------------------------
# A CSV is just a table saved as text. read_csv() turns it into a "data frame":
# rows = observations (receipts), columns = variables (facts about each receipt).
tx <- read_csv("data/retail_transactions.csv", show_col_types = FALSE)

# ---- 2. Inspect before you analyse -------------------------------------------
dim(tx)        # how many rows and columns?
head(tx)       # first six rows — what does ONE row represent?
glimpse(tx)    # every column, its type (<dbl> number, <chr> text, <date>)

# QUESTION: Which columns are categorical (nominal)? Which are numeric (ratio)?
# Is 'hour' numeric or categorical for the question "when are we busiest"?

# ---- 3. Data quality checks ---------------------------------------------------
colSums(is.na(tx))          # missing values per column (completeness)
sum(duplicated(tx$txn_id))  # duplicate receipt IDs (uniqueness)
range(tx$basket_naira)      # smallest and largest basket (validity)

# ---- 4. Descriptive analytics: what happened? ----------------------------------
summary(tx$basket_naira)    # min, quartiles, median, mean, max

tx |>
  group_by(category) |>
  summarise(receipts = n(),
            revenue_naira = sum(basket_naira),
            median_basket = median(basket_naira)) |>
  arrange(desc(revenue_naira))

# ---- 5. A first chart -----------------------------------------------------------
ggplot(tx, aes(x = basket_naira)) +
  geom_histogram(bins = 50, fill = "#0B5E82", colour = "white") +
  labs(title = "Basket value per receipt", x = "Naira", y = "Receipts")

# ---- 6. YOUR TURN ----------------------------------------------------------------
# (a) Which store has the highest total revenue?
# (b) What share of receipts are from loyalty members?
# (c) Write ONE business question this dataset could answer that is
#     predictive (what will happen?) rather than descriptive.

# ---- Answers (try first!) ---------------------------------------------------------
# (a) tx |> group_by(store) |> summarise(rev = sum(basket_naira)) |> arrange(desc(rev))
# (b) mean(tx$loyalty_member == "Yes")
# (c) e.g. "How much revenue should we expect next December, by store?"
