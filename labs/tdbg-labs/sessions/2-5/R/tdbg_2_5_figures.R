# =============================================================================
# TDBG · Session 2.5 · Hypothesis Testing for Business Decisions
# Replication script — regenerates every chart in the Session 2.5 deck (R)
# Data: data/store_layout_test.csv and data/retail_transactions.csv
# =============================================================================
source("R/theme_tdbg.R")
suppressPackageStartupMessages({ library(dplyr); library(readr); library(tidyr) })
d  <- read_csv("data/store_layout_test.csv", show_col_types = FALSE)
tx <- read_csv("data/retail_transactions.csv", show_col_types = FALSE)
st <- d |> group_by(store_id, layout) |>
  summarise(conv = mean(conversion_rate), basket = mean(avg_basket_naira), .groups = "drop")
tt <- t.test(conv ~ layout, data = mutate(st, layout = factor(layout, levels = c("New", "Old"))))   # Welch t-test

# --- F01 · Null distribution and the p-value ---------------------------------------------
tstat <- unname(tt$statistic); dfw <- unname(tt$parameter); crit <- qt(.975, dfw)
nd <- tibble(x = seq(-4, 4, length.out = 500), y = dt(x, dfw))
p1 <- ggplot(nd, aes(x, y)) +
  geom_area(data = filter(nd, x <= -abs(tstat)), fill = tdbg[["gold"]], alpha = .8) +
  geom_area(data = filter(nd, x >= abs(tstat)), fill = tdbg[["gold"]], alpha = .8) +
  geom_line(colour = tdbg[["navy"]], linewidth = 1.2) +
  geom_vline(xintercept = tstat, colour = tdbg[["rust"]], linewidth = 1.2) +
  geom_vline(xintercept = c(-crit, crit), linetype = "dashed", colour = tdbg[["slate"]]) +
  annotate("text", x = tstat + .1, y = .37, hjust = 0, colour = tdbg[["rust"]], label = sprintf("our result\nt = %.2f", tstat)) +
  annotate("text", x = 2.3, y = .12, hjust = 0, colour = tdbg[["gold"]], fontface = "bold", label = sprintf("gold area = p-value\n= %.2f", tt$p.value)) +
  labs(title = "If the layout had NO effect, how surprising is our result?", x = "t statistic (difference ÷ standard error)", y = NULL) +
  theme_tdbg() + theme(axis.text.y = element_blank(), panel.grid = element_blank())
save_fig(p1, "2-5", "f01")

# --- F02 & F04 · Store-level dot plots ------------------------------------------------------
dots <- function(var, ylab, ttl, fmt) {
  m <- st |> group_by(layout) |> summarise(m = mean(.data[[var]]))
  ggplot(st, aes(factor(layout, levels = c("Old", "New")), .data[[var]], colour = layout)) +
    geom_jitter(width = .1, height = 0, size = 3, alpha = .85) +
    geom_crossbar(data = m, aes(y = m, ymin = m, ymax = m), colour = tdbg[["gold"]], width = .5, linewidth = .8) +
    geom_text(data = m, aes(y = m, label = fmt(m)), nudge_x = .42, colour = tdbg[["navy"]]) +
    scale_colour_manual(values = c(Old = tdbg[["slate"]], New = tdbg[["teal"]]), guide = "none") +
    labs(title = ttl, x = NULL, y = ylab) + theme_tdbg()
}
p2 <- dots("conv", "Average daily conversion rate", sprintf("Conversion per store: +%.1f pts, but stores differ a lot (p = %.2f)",
          100 * diff(rev(tapply(st$conv, st$layout, mean))), tt$p.value), function(m) sprintf("mean %.1f%%", 100 * m)) +
  scale_y_continuous(labels = scales::percent)
save_fig(p2, "2-5", "f02")
tb <- t.test(basket ~ layout, data = mutate(st, layout = factor(layout, levels = c("New", "Old"))))
mb <- tapply(st$basket, st$layout, mean)
p4 <- dots("basket", "Average basket (₦)", sprintf("Basket value per store: +₦%.0f (+%.1f%%), p = %.4f",
          mb["New"] - mb["Old"], 100 * (mb["New"] / mb["Old"] - 1), tb$p.value), function(m) paste0("mean ₦", format(round(m), big.mark = ",")))
save_fig(p4, "2-5", "f04")

# --- F03 · Wrong unit vs right unit ----------------------------------------------------------
pool <- d |> group_by(layout) |> summarise(b = sum(buyers), v = sum(visitors)) |> mutate(p = b / v)
pp <- prop.test(pool$b[pool$layout == "New"] |> c(pool$b[pool$layout == "Old"]), c(pool$v[pool$layout == "New"], pool$v[pool$layout == "Old"]))
ci <- tibble(unit = c("Treating 349,000 visitors as independent\n(wrong unit)", "Treating the 24 stores as the units\n(correct unit)"),
             est = c(diff(rev(pool$p)), unname(tt$estimate[1] - tt$estimate[2])),
             lo = c(pp$conf.int[1], tt$conf.int[1]), hi = c(pp$conf.int[2], tt$conf.int[2]))
ci$wrong <- grepl("wrong", ci$unit)
p3 <- ggplot(ci, aes(100 * est, unit, colour = wrong)) +
  geom_vline(xintercept = 0) + geom_errorbarh(aes(xmin = 100 * lo, xmax = 100 * hi), height = .15, linewidth = 1.5) + geom_point(size = 4) +
  geom_text(aes(x = 100 * hi + .15, label = sprintf("%+.2f pts  [%+.2f, %+.2f]", 100 * est, 100 * lo, 100 * hi)), hjust = 0) +
  scale_colour_manual(values = c(`TRUE` = tdbg[["rust"]], `FALSE` = tdbg[["teal"]]), guide = "none") + xlim(-2, 4.6) +
  labs(title = "Same data, two answers: the wrong unit manufactures certainty", x = "Difference in conversion, new minus old (percentage points, 95% CI)", y = NULL) + theme_tdbg()
save_fig(p3, "2-5", "f03", height = 4.6)

# --- F05 · Type I / Type II -----------------------------------------------------------------
x <- seq(-4, 7, length.out = 600); cc <- 1.96
e <- tibble(x, h0 = dnorm(x), h1 = dnorm(x, 2.5))
p5 <- ggplot(e) +
  geom_area(data = filter(e, x >= cc), aes(x, h0, fill = "α — Type I error: false alarm"), alpha = .7) +
  geom_area(data = filter(e, x < cc), aes(x, h1, fill = "β — Type II error: missed effect"), alpha = .5) +
  geom_line(aes(x, h0, colour = "No real effect (H0 true)"), linewidth = 1.2) + geom_line(aes(x, h1, colour = "Real effect (H1 true)"), linewidth = 1.2) +
  geom_vline(xintercept = cc, linetype = "dashed") +
  annotate("text", x = 4.6, y = .2, label = sprintf("power = 1 − β\n= %.0f%%", 100 * (1 - pnorm(cc, 2.5))), colour = tdbg[["teal"]], fontface = "bold") +
  scale_fill_manual(values = unname(tdbg[c("rust", "gold")]), name = NULL) + scale_colour_manual(values = unname(tdbg[c("slate", "teal")]), name = NULL) +
  labs(title = "Every test trades false alarms against missed effects", x = "Test statistic", y = NULL) +
  theme_tdbg() + theme(axis.text.y = element_blank(), legend.direction = "vertical")
save_fig(p5, "2-5", "f05")

# --- F06 · Chi-square ------------------------------------------------------------------------
tab <- table(tx$region, tx$payment_method); chi <- chisq.test(tab)
mix <- as.data.frame(prop.table(tab, 1)) |> rename(region = Var1, method = Var2, share = Freq)
p6 <- ggplot(mix, aes(share, region, fill = method)) + geom_col() +
  geom_text(aes(label = scales::percent(share, 1)), position = position_stack(vjust = .5), colour = "white", size = 3.5) +
  scale_fill_manual(values = unname(tdbg[c("teal", "slate", "gold", "sky")]), name = NULL) +
  scale_x_continuous(labels = scales::percent) +
  labs(title = sprintf("Payment mix looks similar across regions (χ² = %.1f, p = %.2f)", chi$statistic, chi$p.value), x = NULL, y = NULL) + theme_tdbg()
save_fig(p6, "2-5", "f06")

# --- F07 · Significant vs important ----------------------------------------------------------------
n <- 10^seq(2, 6.3, length.out = 200); z <- (.202 - .2) / sqrt(.2 * .8 / n + .202 * .798 / n)
p7 <- ggplot(tibble(n, p = 2 * (1 - pnorm(z))), aes(n, p)) + geom_line(colour = tdbg[["teal"]], linewidth = 1.5) +
  geom_hline(yintercept = .05, linetype = "dashed", colour = tdbg[["rust"]]) + scale_x_log10(labels = scales::comma) +
  annotate("text", x = 3e4, y = .45, label = "Statistically significant —\nbut is a 0.2-point lift worth\nthe cost of a refit?", colour = tdbg[["navy"]]) +
  labs(title = "A 0.2-point lift (20.0% → 20.2%) becomes 'significant' with enough data", x = "Visitors per group (log scale)", y = "p-value") + theme_tdbg()
save_fig(p7, "2-5", "f07")

# --- F08 · Loyalty baskets ----------------------------------------------------------------------------
mw <- wilcox.test(basket_naira ~ loyalty_member, data = tx)
p8 <- ggplot(tx, aes(basket_naira, ifelse(loyalty_member == "Yes", "Loyalty member", "Not a member"))) +
  geom_boxplot(fill = "#D6E6EF", colour = tdbg[["teal"]], outlier.shape = NA, width = .5) +
  coord_cartesian(xlim = c(0, 27000)) + scale_x_continuous(labels = naira) +
  labs(title = sprintf("Members' baskets are larger (Mann–Whitney p = %.4f) — but why?", mw$p.value), x = "Basket value (outliers hidden)", y = NULL) + theme_tdbg()
save_fig(p8, "2-5", "f08")
