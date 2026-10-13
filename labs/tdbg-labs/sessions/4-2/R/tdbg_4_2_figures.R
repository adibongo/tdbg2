# =============================================================================
# TDBG · Session 4.2 · Unsupervised Learning: Clustering & Dimensionality Reduction
# Replication script — regenerates every chart in the Session 4.2 deck (R)
# Data: data/bank_customers_segmentation.csv
# Cluster NUMBERS differ from Python (random starts); we name clusters by profile.
# =============================================================================
source("R/theme_tdbg.R")
suppressPackageStartupMessages({ library(dplyr); library(readr); library(tidyr); library(cluster); library(patchwork) })
d <- read_csv("data/bank_customers_segmentation.csv", show_col_types = FALSE)
F <- c("avg_balance_naira", "monthly_transactions", "digital_share", "age", "products_held", "tenure_years")
LAB <- c(avg_balance_naira = "Balance (log)", monthly_transactions = "Transactions/month", digital_share = "Digital share",
         age = "Age", products_held = "Products held", tenure_years = "Tenure (yrs)")
Xr <- d[, F]; Xr$avg_balance_naira <- log(Xr$avg_balance_naira)
Z <- scale(Xr)                                                   # standardise every driver
set.seed(1)
km <- kmeans(Z, centers = 5, nstart = 20)
d$cluster <- km$cluster
names_map <- d |> count(cluster, true_segment) |> group_by(cluster) |> slice_max(n, n = 1) |> select(cluster, segment = true_segment)
d <- left_join(d, names_map, by = "cluster")
COL <- c(`Mass-market savers` = tdbg[["slate"]], `Digital youth` = tdbg[["sky"]], `Salary earners` = tdbg[["teal"]],
         Affluent = tdbg[["gold"]], `SME owners` = tdbg[["rust"]])

# --- F01 -------------------------------------------------------------------------------
p1 <- ggplot(d, aes(monthly_transactions, avg_balance_naira)) + geom_point(alpha = .35, size = .8, colour = tdbg[["navy"]]) +
  scale_y_log10(labels = naira) + labs(title = "3,400 customers, no labels: are there natural groups?", x = "Transactions per month", y = "Average balance (log scale)") + theme_tdbg()
save_fig(p1, "4-2", "f01")

# --- F02 · Elbow and silhouette --------------------------------------------------------------
set.seed(1); smp <- sample(nrow(Z), 2000)
kk <- tibble(k = 2:8) |> rowwise() |> mutate(m = list(kmeans(Z, k, nstart = 20)), wss = m$tot.withinss,
  sil = mean(silhouette(m$cluster[smp], dist(Z[smp, ]))[, 3])) |> ungroup()
g1 <- ggplot(kk, aes(k, wss)) + geom_line(colour = tdbg[["teal"]]) + geom_point(colour = tdbg[["teal"]]) + geom_vline(xintercept = 5, linetype = "dashed", colour = tdbg[["gold"]]) +
  labs(title = "Elbow: within-cluster spread", x = "Number of clusters k", y = "Total within-cluster sum of squares") + theme_tdbg(11)
g2 <- ggplot(kk, aes(k, sil)) + geom_line(colour = tdbg[["teal"]]) + geom_point(colour = tdbg[["teal"]]) + geom_vline(xintercept = 5, linetype = "dashed", colour = tdbg[["gold"]]) +
  labs(title = "Silhouette: how well separated (higher = better)", x = "Number of clusters k", y = "Average silhouette") + theme_tdbg(11)
save_fig(g1 | g2, "4-2", "f02", width = 12, height = 4.8)

# --- F03 · PCA view -----------------------------------------------------------------------------
pc <- prcomp(Z); ve <- pc$sdev^2 / sum(pc$sdev^2)
p3 <- ggplot(tibble(PC1 = pc$x[, 1], PC2 = pc$x[, 2], segment = d$segment), aes(PC1, PC2, colour = segment)) + geom_point(alpha = .5, size = .8) +
  scale_colour_manual(values = COL, name = NULL) + guides(colour = guide_legend(override.aes = list(size = 3, alpha = 1))) +
  labs(title = "Five segments, viewed on the first two principal components", x = sprintf("PC1 (%.0f%% of variation)", 100 * ve[1]), y = sprintf("PC2 (%.0f%%)", 100 * ve[2])) + theme_tdbg()
save_fig(p3, "4-2", "f03")
# Note: prcomp's component signs can be flipped relative to Python — the picture is a mirror image, same meaning.

# --- F04 · Profile heat map ------------------------------------------------------------------------
prof <- as_tibble(Z) |> mutate(segment = d$segment) |> group_by(segment) |> summarise(across(everything(), mean)) |> pivot_longer(-segment, values_to = "z")
med <- d |> group_by(segment) |> summarise(across(all_of(F), median)) |> pivot_longer(-segment, values_to = "m")
pf <- left_join(prof, med, by = c("segment", "name")) |>
  mutate(lab = case_when(name == "avg_balance_naira" ~ naira(m), name == "digital_share" ~ scales::percent(m, 1), name == "tenure_years" ~ sprintf("%.1f", m), TRUE ~ sprintf("%.0f", m)),
         name = factor(LAB[name], levels = LAB))
p4 <- ggplot(pf, aes(name, segment, fill = z)) + geom_tile(colour = "white") + geom_text(aes(label = lab, colour = abs(z) > 1)) +
  scale_fill_gradient2(low = "#2166AC", mid = "white", high = "#B2182B", limits = c(-2, 2), oob = scales::squish, name = "standardised\naverage") +
  scale_colour_manual(values = c(`TRUE` = "white", `FALSE` = tdbg[["ink"]]), guide = "none") +
  labs(title = "Segment profiles", subtitle = "colour = above/below bank average; numbers = typical (median) values", x = NULL, y = NULL) + theme_tdbg() + theme(legend.position = "right", panel.grid = element_blank())
save_fig(p4, "4-2", "f04", height = 4.8)

# --- F05 · Size vs value -------------------------------------------------------------------------------
sz <- d |> group_by(segment) |> summarise(customers = n(), balances = sum(avg_balance_naira)) |>
  mutate(`share of customers` = customers / sum(customers), `share of total balances` = balances / sum(balances)) |>
  select(segment, starts_with("share")) |> pivot_longer(-segment)
p5 <- ggplot(sz, aes(value, reorder(segment, value * (name == "share of total balances")), fill = name)) + geom_col(position = position_dodge(.8), width = .75) +
  geom_text(aes(label = scales::percent(value, 1)), position = position_dodge(.8), hjust = -.2, size = 3.6) +
  scale_fill_manual(values = c(`share of customers` = "#B8C7D3", `share of total balances` = tdbg[["teal"]]), name = NULL) +
  scale_x_continuous(labels = scales::percent, expand = expansion(mult = c(0, .1))) +
  labs(title = "Who holds the money?", subtitle = "The Affluent — 10% of customers — hold 43% of balances", x = NULL, y = NULL) + theme_tdbg()
save_fig(p5, "4-2", "f05")

# --- F06 · Scree --------------------------------------------------------------------------------------
sc <- tibble(pc = 1:6, ve = ve, cum = cumsum(ve))
p6 <- ggplot(sc, aes(pc)) + geom_col(aes(y = 100 * ve), fill = tdbg[["teal"]]) + geom_line(aes(y = 100 * cum), colour = tdbg[["gold"]], linewidth = 1.2) +
  geom_point(aes(y = 100 * cum), colour = tdbg[["gold"]], size = 3) + geom_text(aes(y = 100 * cum + 4, label = scales::percent(cum, 1))) +
  scale_x_continuous(breaks = 1:6) + labs(title = "PCA: two components keep about two-thirds of the information in six drivers", x = "Principal component", y = "% of total variation") + theme_tdbg()
save_fig(p6, "4-2", "f06")

# --- F07 · Loadings -------------------------------------------------------------------------------------
ld <- as_tibble(pc$rotation[, 1:2], rownames = "var") |> mutate(var = LAB[var]) |> pivot_longer(-var)
p7 <- ggplot(ld, aes(value, var, fill = value < 0)) + geom_col() + geom_vline(xintercept = 0) + facet_wrap(~name) +
  scale_fill_manual(values = c(`TRUE` = tdbg[["rust"]], `FALSE` = tdbg[["teal"]]), guide = "none") +
  labs(title = "Loadings: what each principal component measures", subtitle = "signs may be mirrored vs Python; read which drivers move together", x = "Loading", y = NULL) + theme_tdbg()
save_fig(p7, "4-2", "f07", width = 12, height = 4.6)

# --- F08 · Dendrogram ------------------------------------------------------------------------------------
set.seed(3); idx <- d |> mutate(i = row_number()) |> group_by(segment) |> slice_sample(n = 8) |> pull(i)
hc <- hclust(dist(Z[idx, ]), method = "ward.D2")
dir.create("sessions/4-2/figures/r", recursive = TRUE, showWarnings = FALSE)
png("sessions/4-2/figures/r/4-2_f08.png", width = 12, height = 5, units = "in", res = 200)
plot(hc, labels = sub(" .*", "", d$segment[idx]), main = "Hierarchical clustering: merge the most similar customers step by step", xlab = "", sub = "", ylab = "Distance at which groups merge")
rect.hclust(hc, k = 5, border = unname(tdbg[c("teal", "gold", "rust", "navy", "slate")]))
dev.off()
