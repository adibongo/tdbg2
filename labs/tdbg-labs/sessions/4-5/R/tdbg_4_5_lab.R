# =============================================================================
# TDBG · Session 4.5 LAB · What sells with what — and what should we recommend? (R)
# Data: data/supermarket_baskets.csv, data/product_ratings.csv
# install.packages("arules")   # once
# =============================================================================
library(dplyr); library(readr); library(tidyr); library(arules)

# ---- PART A · Market basket analysis --------------------------------------------------------
b <- read_csv("data/supermarket_baskets.csv", show_col_types = FALSE)
trans <- as(split(b$item, b$txn_id), "transactions")
summary(trans)                                     # baskets, items, typical basket size
itemFrequencyPlot(trans, topN = 15)                # support of each item

rules <- apriori(trans, parameter = list(supp = 0.01, conf = 0.3, minlen = 2))
inspect(head(sort(rules, by = "lift"), 10))        # strongest rules
inspect(subset(rules, rhs %in% "Baby wipes"))      # what leads to baby wipes?

# Check one rule by hand: Bread -> Eggs
m <- as(trans, "matrix")
supp_both <- mean(m[, "Bread"] & m[, "Eggs"]); conf <- supp_both / mean(m[, "Bread"]); lift <- conf / mean(m[, "Eggs"])
c(support = supp_both, confidence = conf, lift = lift)

# ---- PART B · Item-based recommender ---------------------------------------------------------
rt <- read_csv("data/product_ratings.csv", show_col_types = FALSE)
M <- rt |> pivot_wider(names_from = item, values_from = rating) |> tibble::column_to_rownames("customer_id") |> as.matrix()
C <- sweep(M, 1, rowMeans(M, na.rm = TRUE))                     # remove each customer's 'generosity'
cosine <- function(a, b) { k <- !is.na(a) & !is.na(b); if (sum(k) < 3) return(NA); sum(a[k] * b[k]) / sqrt(sum(a[k]^2) * sum(b[k]^2)) }
S <- outer(colnames(C), colnames(C), Vectorize(function(i, j) if (i == j) NA else cosine(C[, i], C[, j])))
dimnames(S) <- list(colnames(C), colnames(C))
round(sort(S["Milo", ], decreasing = TRUE)[1:5], 2)            # products most like Milo

# Predict customer C017's rating of an untried product from similar products they rated
user <- "C017"; item <- "Tea"
rated <- names(which(!is.na(M[user, ]))); s <- S[rated, item]; s <- s[!is.na(s) & s > 0]
mean(M[user, ], na.rm = TRUE) + sum(s * C[user, names(s)]) / sum(s)

# ---- YOUR TURN ---------------------------------------------------------------------------------
# (a) Propose two shelf-placement or bundle promotions from the rules. Use lift AND support.
# (b) Diapers -> Beer has lift 2.3. Is it actionable? What else would you want to know?
# (c) Produce the top-3 recommendations for customer C042. Would you trust them? Why or why not?
