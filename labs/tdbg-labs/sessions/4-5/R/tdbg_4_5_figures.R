# =============================================================================
# TDBG · Session 4.5 · Market Basket Analysis & Recommendation Engines
# Replication script — regenerates every chart in the Session 4.5 deck (R)
# Data: data/supermarket_baskets.csv and data/product_ratings.csv
# install.packages("arules")   # once
# =============================================================================
source("R/theme_tdbg.R")
suppressPackageStartupMessages({ library(dplyr); library(readr); library(tidyr); library(arules) })
b <- read_csv("data/supermarket_baskets.csv", show_col_types = FALSE)
trans <- as(split(b$item, b$txn_id), "transactions")           # arules' basket format
rules <- apriori(trans, parameter = list(supp = .01, conf = 0, minlen = 2, maxlen = 2), control = list(verbose = FALSE))
R <- as(rules, "data.frame") |> mutate(lhs = gsub("[{}]", "", sub(" =>.*", "", rules)), rhs = gsub("[{}]", "", sub(".*=> ", "", rules))) |> arrange(desc(lift))
sup <- itemFrequency(trans)

# --- F01 · Support -------------------------------------------------------------------------
p1 <- tibble(item = names(sup), s = sup) |> slice_max(s, n = 15) |> ggplot(aes(100 * s, reorder(item, s))) + geom_col(fill = tdbg[["teal"]]) +
  labs(title = "How often each item appears: 'support' (% of 3,000 baskets)", x = "% of baskets containing the item", y = NULL) + theme_tdbg()
save_fig(p1, "4-5", "f01")

# --- F02 · Rules scatter ---------------------------------------------------------------------
p2 <- ggplot(R, aes(100 * support, 100 * confidence, colour = lift)) + geom_point(size = 2.5) +
  geom_text(data = R[c(1, 3, 5), ], aes(label = paste(lhs, "→", rhs)), hjust = 1.05, vjust = -.6, colour = tdbg[["navy"]], size = 3.6) +
  scale_colour_distiller(palette = "YlOrRd", direction = 1) +
  labs(title = sprintf("%d rules with support ≥ 1%%: the strong ones are top-right and dark", nrow(R)), x = "Support (% of baskets with both items)", y = "Confidence (%)") + theme_tdbg() + theme(legend.position = "right")
save_fig(p2, "4-5", "f02")

# --- F03 · Top rules ---------------------------------------------------------------------------
t <- R |> filter(confidence >= .3) |> slice_head(n = 12) |> mutate(rule = paste(lhs, "→", rhs))
p3 <- ggplot(t, aes(lift, reorder(rule, lift))) + geom_col(fill = tdbg[["gold"]]) + geom_vline(xintercept = 1, linetype = "dashed") +
  geom_text(aes(label = sprintf("lift %.1f · conf %.0f%%", lift, 100 * confidence)), hjust = -.05, size = 3.3) + expand_limits(x = 4.6) +
  labs(title = "Strongest rules: 'if' buyers are ~3× more likely to buy the 'then' item", x = "Lift (1 = no relationship)", y = NULL) + theme_tdbg()
save_fig(p3, "4-5", "f03")

# --- F04 · Lift matrix -----------------------------------------------------------------------------
items <- names(sort(sup, decreasing = TRUE))[1:14]
M <- as(trans[, items], "matrix")
L <- expand_grid(a = items, c = items) |> rowwise() |> mutate(lift = ifelse(a == c, NA, mean(M[, a] & M[, c]) / mean(M[, a]) / mean(M[, c]))) |> ungroup()
p4 <- ggplot(L, aes(factor(c, levels = items), factor(a, levels = rev(items)), fill = lift)) + geom_tile(colour = "white") +
  scale_fill_gradient2(low = "#2166AC", mid = "white", high = "#B2182B", midpoint = 1, limits = c(0, 3.4), na.value = "grey95") +
  labs(title = "Lift between pairs of popular items: red = bought together more than chance", x = NULL, y = NULL) +
  theme_tdbg() + theme(axis.text.x = element_text(angle = 50, hjust = 1), legend.position = "right", panel.grid = element_blank())
save_fig(p4, "4-5", "f04", width = 10, height = 8)

# --- Recommender: item-based collaborative filtering --------------------------------------------------
rt <- read_csv("data/product_ratings.csv", show_col_types = FALSE)
Mr <- rt |> pivot_wider(names_from = item, values_from = rating) |> tibble::column_to_rownames("customer_id") |> as.matrix()
Mr <- Mr[, sort(colnames(Mr))]
centre <- function(M) sweep(M, 1, rowMeans(M, na.rm = TRUE))
cosine <- function(a, b) { m <- !is.na(a) & !is.na(b); if (sum(m) < 3) return(NA); sum(a[m] * b[m]) / sqrt(sum(a[m]^2) * sum(b[m]^2)) }
sim_matrix <- function(C) { S <- matrix(NA, ncol(C), ncol(C), dimnames = list(colnames(C), colnames(C)))
  for (i in colnames(C)) for (j in colnames(C)) if (i != j) S[i, j] <- cosine(C[, i], C[, j]); S }
C <- centre(Mr); S <- sim_matrix(C)
predict_cf <- function(M, C, S, user, item, k = 5) {
  rated <- setdiff(names(which(!is.na(M[user, ]))), item)
  s <- S[rated, item]; s <- sort(s[!is.na(s) & s > 0], decreasing = TRUE)[seq_len(min(k, sum(!is.na(s) & s > 0)))]
  if (length(s) == 0) return(mean(M[, item], na.rm = TRUE))
  mean(M[user, ], na.rm = TRUE) + sum(s * C[user, names(s)]) / sum(s) }

# --- F05 · Similarity heat map ---------------------------------------------------------------------------
sd_ <- as.data.frame(as.table(S)) |> rename(i = Var1, j = Var2, s = Freq)
p5 <- ggplot(sd_, aes(j, factor(i, levels = rev(colnames(S))), fill = s)) + geom_tile() +
  scale_fill_gradient2(low = "#2166AC", mid = "white", high = "#B2182B", limits = c(-1, 1), na.value = "grey95", name = "similarity") +
  labs(title = "Item similarity: products that the same customers rate alike", x = NULL, y = NULL) +
  theme_tdbg() + theme(axis.text.x = element_text(angle = 50, hjust = 1), legend.position = "right", panel.grid = element_blank())
save_fig(p5, "4-5", "f05", width = 10, height = 8)

# --- F06 · Recommendations for C017 -------------------------------------------------------------------------
u <- "C017"; unrated <- names(which(is.na(Mr[u, ])))
pr <- tibble(item = unrated, pred = sapply(unrated, function(i) predict_cf(Mr, C, S, u, i))) |> mutate(top = rank(-pred) <= 3)
p6 <- ggplot(pr, aes(pred, reorder(item, pred), fill = top)) + geom_col() + coord_cartesian(xlim = c(1, 5)) +
  scale_fill_manual(values = c(`TRUE` = tdbg[["gold"]], `FALSE` = "#B8C7D3"), guide = "none") +
  labs(title = paste0("Customer ", u, ": predicted ratings for untried products — recommend the top 3"), x = "Predicted rating (1–5)", y = NULL) + theme_tdbg()
save_fig(p6, "4-5", "f06")

# --- F07 · Leave-one-out test ----------------------------------------------------------------------------------
set.seed(17); e_cf <- e_pop <- c()
for (user in rownames(Mr)) {
  rated <- names(which(!is.na(Mr[user, ]))); if (length(rated) < 5) next
  item <- sample(rated, 1); truth <- Mr[user, item]
  M2 <- Mr; M2[user, item] <- NA; C2 <- C; C2[user, ] <- M2[user, ] - mean(M2[user, ], na.rm = TRUE)
  e_cf <- c(e_cf, predict_cf(M2, C2, S, user, item) - truth); e_pop <- c(e_pop, mean(M2[, item], na.rm = TRUE) - truth) }
rm_ <- tibble(model = factor(c("Popularity (item average)", "Item-based collaborative filtering"), levels = c("Popularity (item average)", "Item-based collaborative filtering")),
              rmse = c(sqrt(mean(e_pop^2)), sqrt(mean(e_cf^2))))
p7 <- ggplot(rm_, aes(model, rmse, fill = model)) + geom_col(width = .5) + geom_text(aes(label = sprintf("%.2f", rmse)), vjust = -.4, size = 5) +
  scale_fill_manual(values = c(tdbg[["slate"]], tdbg[["teal"]]), guide = "none") +
  labs(title = "Hidden-rating test: personalised predictions miss by less", subtitle = "(similarities computed once on all data for simplicity)", x = NULL, y = "RMSE (rating points; lower is better)") + theme_tdbg()
save_fig(p7, "4-5", "f07")
