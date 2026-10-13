# =============================================================================
# TDBG · Session 2.2 · Statistical Foundations for Decision-Making
# Replication script — regenerates every chart in the Session 2.2 deck (R)
# Open tdbg-labs.Rproj in RStudio, then Source this file.
# Note: F01, F06 and F07 use random simulation; R and Python use different
# random-number generators, so those charts differ slightly — same lesson.
# =============================================================================
source("R/theme_tdbg.R")
suppressPackageStartupMessages({ library(dplyr); library(readr); library(tidyr) })
set.seed(2026)

basket <- read_csv("data/retail_basket_sizes.csv", show_col_types = FALSE)
income <- read_csv("data/bank_customer_income.csv", show_col_types = FALSE)
deliv  <- read_csv("data/delivery_times.csv", show_col_types = FALSE)

# --- F01 · Three shapes ---------------------------------------------------------
shapes <- bind_rows(
  tibble(shape = "Symmetric",    x = rnorm(5000, 50, 10)),
  tibble(shape = "Right-skewed", x = rlnorm(5000, 3.5, 0.6)),
  tibble(shape = "Left-skewed",  x = 100 - rlnorm(5000, 2.5, 0.6))) |>
  mutate(shape = factor(shape, levels = c("Symmetric", "Right-skewed", "Left-skewed")))
stats_df <- shapes |> group_by(shape) |> summarise(mean = mean(x), median = median(x))
p1 <- ggplot(shapes, aes(x, fill = shape)) +
  geom_histogram(bins = 45, colour = "white") +
  geom_vline(data = stats_df, aes(xintercept = mean), linetype = "dashed", colour = tdbg[["navy"]]) +
  geom_vline(data = stats_df, aes(xintercept = median), colour = tdbg[["ink"]]) +
  facet_wrap(~shape, scales = "free") +
  scale_fill_manual(values = unname(tdbg[c("teal", "gold", "rust")]), guide = "none") +
  labs(title = "Three shapes you will see every week", subtitle = "dashed = mean, solid = median",
       x = NULL, y = NULL) +
  theme_tdbg() + theme(axis.text.y = element_blank())
save_fig(p1, "2-2", "f01", width = 12, height = 4.2)

# --- F02 · When the mean misleads -------------------------------------------------
md <- median(income$monthly_income_naira); mn <- mean(income$monthly_income_naira)
p2 <- income |> filter(monthly_income_naira < 1.5e6) |>
  ggplot(aes(monthly_income_naira)) +
  geom_histogram(bins = 60, fill = tdbg[["teal"]], colour = "white") +
  geom_vline(xintercept = md, colour = tdbg[["gold"]], linewidth = 1.5) +
  geom_vline(xintercept = mn, colour = tdbg[["rust"]], linewidth = 1.5, linetype = "dashed") +
  annotate("label", x = md, y = 95, hjust = -0.05, label = paste0("Median ", naira(md)), colour = tdbg[["gold"]]) +
  annotate("label", x = mn, y = 80, hjust = -0.05, label = paste0("Mean ", naira(mn)), colour = tdbg[["rust"]]) +
  scale_x_continuous(labels = naira) +
  labs(title = "500 bank customers: the 'average' income describes almost nobody",
       x = "Monthly income (customers above ₦1.5m not shown)", y = "Customers") +
  theme_tdbg()
save_fig(p2, "2-2", "f02")

# --- F03 · Delivery times by warehouse -------------------------------------------
p3 <- deliv |> mutate(warehouse = factor(warehouse, levels = c("Lekki", "Apapa", "Ikeja"))) |>
  ggplot(aes(delivery_time_hours, warehouse)) +
  geom_boxplot(fill = "#D6E6EF", colour = tdbg[["teal"]], width = 0.55) +
  labs(title = "Delivery times: look at the spread, not just the middle",
       x = "Hours from order to doorstep", y = NULL) +
  theme_tdbg()
save_fig(p3, "2-2", "f03")

# --- F04 · Anatomy of a box plot -----------------------------------------------------
q <- quantile(basket$basket_size_naira, c(.25, .5, .75))
p4 <- ggplot(basket, aes(basket_size_naira, y = 1)) +
  geom_boxplot(fill = "#D6E6EF", colour = tdbg[["teal"]], width = 0.4) +
  annotate("text", x = q, y = 1.3, label = c(paste("Q1", naira(q[1])), paste("Median", naira(q[2])), paste("Q3", naira(q[3]))),
           colour = tdbg[["navy"]], vjust = c(0, -1, 0)) +
  annotate("text", x = mean(q[c(1, 3)]), y = 0.72, label = paste0("IQR = ", naira(q[3] - q[1]), "\n(middle 50% of baskets)"),
           colour = tdbg[["teal"]]) +
  annotate("text", x = max(basket$basket_size_naira) - 1500, y = 0.7, label = "outliers: beyond 1.5 × IQR", colour = tdbg[["rust"]]) +
  scale_x_continuous(labels = naira) + coord_cartesian(ylim = c(0.5, 1.6)) +
  labs(title = "Reading a box plot: 400 Lagos supermarket receipts", x = "Basket value", y = NULL) +
  theme_tdbg() + theme(axis.text.y = element_blank())
save_fig(p4, "2-2", "f04", height = 4.2)

# --- F05 · The normal curve -------------------------------------------------------------
z <- tibble(z = seq(-4, 4, length.out = 400), d = dnorm(z))
p5 <- ggplot(z, aes(z, d)) +
  geom_area(data = filter(z, abs(z) <= 3), fill = "#D6E6EF") +
  geom_area(data = filter(z, abs(z) <= 2), fill = tdbg[["sky"]]) +
  geom_area(data = filter(z, abs(z) <= 1), fill = tdbg[["teal"]]) +
  geom_line(colour = tdbg[["navy"]], linewidth = 1.2) +
  annotate("text", x = 0, y = 0.17, label = "68% within ±1 SD", colour = "white", fontface = "bold") +
  annotate("text", x = 2.7, y = 0.22, label = "95% within ±2 SD", colour = tdbg[["navy"]], fontface = "bold") +
  annotate("text", x = 2.8, y = 0.12, label = "99.7% within ±3 SD", colour = tdbg[["navy"]], fontface = "bold") +
  scale_x_continuous(breaks = -3:3, labels = c("μ−3σ", "μ−2σ", "μ−σ", "μ", "μ+σ", "μ+2σ", "μ+3σ")) +
  labs(title = "The normal curve: where 'typical' and 'unusual' live", x = NULL, y = NULL) +
  theme_tdbg() + theme(axis.text.y = element_blank(), panel.grid = element_blank())
save_fig(p5, "2-2", "f05")

# --- F06 · Central Limit Theorem ---------------------------------------------------------
pop <- pmin(income$monthly_income_naira, 2e6)
clt <- bind_rows(
  tibble(panel = "Population: raw incomes", value = pop),
  lapply(c(5, 30, 100), function(n) tibble(panel = paste0("Means of samples of n=", n),
                                            value = replicate(3000, mean(sample(pop, n, replace = TRUE)))))) |>
  mutate(panel = factor(panel, levels = unique(panel)))
p6 <- ggplot(clt, aes(value, fill = panel == "Population: raw incomes")) +
  geom_histogram(bins = 40, colour = "white") +
  facet_wrap(~panel, nrow = 1, scales = "free") +
  scale_fill_manual(values = c(`TRUE` = tdbg[["slate"]], `FALSE` = tdbg[["teal"]]), guide = "none") +
  scale_x_continuous(labels = naira, n.breaks = 3) +
  labs(title = "Skewed population → bell-shaped sample means as n grows", x = NULL, y = NULL) +
  theme_tdbg(11) + theme(axis.text.y = element_blank())
save_fig(p6, "2-2", "f06", width = 13, height = 4)

# --- F07 · 50 confidence intervals ----------------------------------------------------------
mu <- mean(deliv$delivery_time_hours)
cis <- tibble(i = 1:50) |> rowwise() |>
  mutate(s = list(sample(deliv$delivery_time_hours, 40, replace = TRUE)),
         m = mean(s), h = 1.96 * sd(s) / sqrt(40), hit = (m - h <= mu) & (mu <= m + h)) |> ungroup()
p7 <- ggplot(cis, aes(y = i, colour = hit)) +
  geom_segment(aes(x = m - h, xend = m + h, yend = i), linewidth = 1) + geom_point(aes(x = m)) +
  geom_vline(xintercept = mu, colour = tdbg[["gold"]], linewidth = 1.2) +
  scale_colour_manual(values = c(`TRUE` = tdbg[["teal"]], `FALSE` = tdbg[["rust"]]), guide = "none") +
  labs(title = sprintf("50 samples, 50 intervals: %d capture the truth, %d miss (red)", sum(cis$hit), sum(!cis$hit)),
       x = "Average delivery time (hours)", y = "Sample number") +
  theme_tdbg()
save_fig(p7, "2-2", "f07")

# --- F08 · CI for average basket by region ---------------------------------------------------
g <- basket |> group_by(region) |>
  summarise(mean = mean(basket_size_naira), sd = sd(basket_size_naira), n = n()) |>
  mutate(half = qt(0.975, n - 1) * sd / sqrt(n))
p8 <- ggplot(g, aes(mean, reorder(region, mean))) +
  geom_errorbarh(aes(xmin = mean - half, xmax = mean + half), height = 0.2, colour = tdbg[["teal"]], linewidth = 1.2) +
  geom_point(size = 3.5, colour = tdbg[["teal"]]) +
  geom_text(aes(x = mean + half + 60, label = sprintf("₦%s ± %s  (n=%d)", format(round(mean), big.mark = ","), round(half), n)),
            hjust = 0, size = 3.6) +
  scale_x_continuous(labels = naira, limits = c(7300, 10200)) +
  labs(title = "Average basket by region with 95% confidence intervals", x = "Average basket value", y = NULL) +
  theme_tdbg()
save_fig(p8, "2-2", "f08")

# --- F09 · Binomial --------------------------------------------------------------------------
b <- tibble(k = 0:10, p = dbinom(k, 20, 0.10))
p9 <- ggplot(b, aes(factor(k), p, fill = k >= 5)) + geom_col() +
  geom_text(aes(label = ifelse(p >= 0.005, scales::percent(p, 1), "")), vjust = -0.4, size = 3.6) +
  annotate("text", x = 8, y = 0.2, label = sprintf("P(5 or more) = %.1f%%", 100 * (1 - pbinom(4, 20, .1))),
           colour = tdbg[["gold"]], fontface = "bold", size = 5) +
  scale_fill_manual(values = c(`FALSE` = tdbg[["teal"]], `TRUE` = tdbg[["gold"]]), guide = "none") +
  labs(title = "20 loans, each with a 10% default risk: how many default?", x = "Number of defaults", y = "Probability") +
  theme_tdbg()
save_fig(p9, "2-2", "f09")

# --- F10 · Bayes with natural frequencies ------------------------------------------------------
tp <- 0.95 * 50; fp <- 0.05 * 9950
f <- tibble(kind = factor(c("Real fraud", "False alarms"), levels = c("False alarms", "Real fraud")), n = c(tp, fp))
p10 <- ggplot(f, aes(n, "Flagged by the system", fill = kind)) + geom_col(width = 0.6) +
  annotate("text", x = (tp + fp) / 2, y = 1, label = sprintf("Only %.0f%% of alerts are real fraud", 100 * tp / (tp + fp)),
           colour = tdbg[["navy"]], fontface = "bold", size = 5.5) +
  scale_fill_manual(values = c(`Real fraud` = tdbg[["rust"]], `False alarms` = tdbg[["sky"]]), name = NULL) +
  labs(title = "10,000 transactions · 0.5% fraud · alarm 95% accurate", x = "Number of flagged transactions", y = NULL) +
  theme_tdbg()
save_fig(p10, "2-2", "f10", height = 4.6)
