# =============================================================================
# TDBG · Session 4.2 LAB · Segmenting a bank's retail customers (R)
# Data: data/bank_customers_segmentation.csv — 3,400 customers
# =============================================================================
library(dplyr); library(readr); library(cluster)
d <- read_csv("data/bank_customers_segmentation.csv", show_col_types = FALSE)
F <- c("avg_balance_naira", "monthly_transactions", "digital_share", "age", "products_held", "tenure_years")

# ---- 1. Prepare: log the skewed balance, then standardise every driver ------------------
X <- d[, F]; X$avg_balance_naira <- log(X$avg_balance_naira)
Z <- scale(X)          # without this, balance (in naira) would dominate every distance

# ---- 2. Choose k: elbow and silhouette ----------------------------------------------------
set.seed(1)
wss <- sapply(2:8, function(k) kmeans(Z, k, nstart = 20)$tot.withinss); plot(2:8, wss, type = "b")
smp <- sample(nrow(Z), 2000)
sil <- sapply(2:8, function(k) mean(silhouette(kmeans(Z, k, nstart = 20)$cluster[smp], dist(Z[smp, ]))[, 3])); plot(2:8, sil, type = "b")

# ---- 3. Fit k-means with k = 5 and PROFILE the clusters --------------------------------------
km <- kmeans(Z, centers = 5, nstart = 20)
d$cluster <- km$cluster
d |> group_by(cluster) |> summarise(customers = n(), across(all_of(F), median))
# Now NAME each cluster from its profile, e.g. "high balance, older, 4 products" = Affluent.

# ---- 4. PCA: see six drivers in two dimensions --------------------------------------------------
pc <- prcomp(Z); summary(pc)          # variance explained
round(pc$rotation[, 1:2], 2)          # loadings
plot(pc$x[, 1:2], col = d$cluster, pch = 20, cex = .5)

# ---- 5. Check against the bank's own labels (only possible because data are synthetic) ----------
table(cluster = d$cluster, true = d$true_segment)

# ---- 6. Hierarchical clustering on a sample ------------------------------------------------------------
hc <- hclust(dist(Z[smp[1:60], ]), method = "ward.D2"); plot(hc); rect.hclust(hc, k = 5)

# ---- YOUR TURN -----------------------------------------------------------------------------------------
# (a) Give each segment a name, a one-line description and ONE product or service to offer it.
# (b) Re-run k-means WITHOUT scale(). What changes and why?
# (c) Which segment is the biggest growth opportunity: largest, richest, or fastest-growing? Argue it.
