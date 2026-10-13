# =============================================================================
# TDBG · Session 3.2 · Correlation & Linear Regression
# Replication script — regenerates every chart in the Session 3.2 deck (R)
# Data: data/fmcg_distributor_revenue.csv
# Note: F02 uses simulated data; R and Python draw different random numbers.
# =============================================================================
source("R/theme_tdbg.R")
suppressPackageStartupMessages({ library(dplyr); library(readr); library(tidyr); library(broom); library(patchwork) })
f <- read_csv("data/fmcg_distributor_revenue.csv", show_col_types = FALSE) |>
  mutate(region = relevel(factor(region), ref = "East"))
simple <- lm(revenue_m_naira ~ ad_spend_m_naira, data = f)
full   <- lm(revenue_m_naira ~ ad_spend_m_naira + price_index + active_outlets + sales_reps + rainfall_mm + region, data = f)

# --- F01 · Simple regression --------------------------------------------------------
lab1 <- sprintf("revenue = %.1f + %.2f × ad spend\nr = %.2f   R² = %.2f", coef(simple)[1], coef(simple)[2],
                cor(f$ad_spend_m_naira, f$revenue_m_naira), summary(simple)$r.squared)
p1 <- ggplot(f, aes(ad_spend_m_naira, revenue_m_naira)) + geom_point(colour = tdbg[["teal"]], alpha = .6) +
  geom_smooth(method = "lm", se = FALSE, colour = tdbg[["gold"]], linewidth = 1.4, formula = y ~ x) +
  annotate("label", x = 2.2, y = 120, hjust = 0, label = lab1, colour = tdbg[["navy"]]) +
  labs(title = "Each extra ₦1m of advertising goes with about ₦1.8m more revenue",
       x = "Advertising spend (₦ million / month)", y = "Revenue (₦ million / month)") + theme_tdbg()
save_fig(p1, "3-2", "f01")

# --- F02 · Correlation gallery ----------------------------------------------------------
set.seed(8); n <- 150; x <- rnorm(n)
sim <- bind_rows(
  tibble(panel = "r ≈ +0.9 strong positive", x = x, y = .9 * x + rnorm(n, 0, .45)),
  tibble(panel = "r ≈ +0.4 weak positive", x = x, y = .4 * x + rnorm(n, 0, .9)),
  tibble(panel = "r ≈ 0 no linear link", x = x, y = rnorm(n)),
  tibble(panel = "r ≈ −0.7 negative", x = x, y = -.7 * x + rnorm(n, 0, .7)),
  tibble(panel = "r ≈ 0 but strong curve!", x = x, y = x^2 + rnorm(n, 0, .3)),
  tibble(panel = "one outlier creates a high r!", x = c(rnorm(30, 0, .3), 4), y = c(rnorm(30, 0, .3), 4))) |>
  group_by(panel) |> mutate(r = cor(x, y), panel = sprintf("%s\n(computed r = %.2f)", panel, r[1])) |> ungroup() |>
  mutate(panel = factor(panel, levels = unique(panel)), warn = grepl("!", panel))
p2 <- ggplot(sim, aes(x, y, colour = warn)) + geom_point(alpha = .7, size = 1.2) + facet_wrap(~panel, scales = "free") +
  scale_colour_manual(values = c(`TRUE` = tdbg[["rust"]], `FALSE` = tdbg[["teal"]]), guide = "none") +
  labs(title = "Correlation measures straight-line association only — always plot the data", x = NULL, y = NULL) +
  theme_tdbg(11) + theme(axis.text = element_blank())
save_fig(p2, "3-2", "f02", width = 12, height = 7)

# --- F03 · Least squares residuals ---------------------------------------------------------
set.seed(3); sub <- slice_sample(f, n = 25) |> mutate(pred = predict(simple, newdata = cur_data()))
p3 <- ggplot(sub, aes(ad_spend_m_naira, revenue_m_naira)) +
  geom_segment(aes(xend = ad_spend_m_naira, yend = pred), colour = tdbg[["rust"]]) +
  geom_abline(intercept = coef(simple)[1], slope = coef(simple)[2], colour = tdbg[["gold"]], linewidth = 1.4) +
  geom_point(colour = tdbg[["teal"]], size = 3) +
  annotate("text", x = 13, y = 50, hjust = 0, colour = tdbg[["navy"]],
           label = "red lines = residuals\n(actual − predicted)\n\nOLS picks the line that makes\nthe sum of squared residuals\nas small as possible") +
  labs(title = "Ordinary least squares: the best-fitting straight line", x = "Advertising spend (₦m)", y = "Revenue (₦m)") + theme_tdbg()
save_fig(p3, "3-2", "f03")

# --- F04 · R² as drivers are added ------------------------------------------------------------
forms <- c(`Ad spend only` = "ad_spend_m_naira", `+ active outlets` = "ad_spend_m_naira + active_outlets",
           `+ sales reps` = "ad_spend_m_naira + active_outlets + sales_reps",
           `+ price index` = "ad_spend_m_naira + active_outlets + sales_reps + price_index",
           `+ region & rainfall` = "ad_spend_m_naira + active_outlets + sales_reps + price_index + region + rainfall_mm")
r2 <- tibble(step = factor(names(forms), levels = names(forms)),
             r2 = sapply(forms, function(rhs) summary(lm(as.formula(paste("revenue_m_naira ~", rhs)), data = f))$r.squared))
p4 <- ggplot(r2, aes(step, r2, fill = step == "+ region & rainfall")) + geom_col() +
  geom_text(aes(label = scales::percent(r2, 1)), vjust = -.4, size = 4.5) +
  scale_fill_manual(values = c(`TRUE` = tdbg[["gold"]], `FALSE` = tdbg[["teal"]]), guide = "none") +
  scale_y_continuous(labels = scales::percent, limits = c(0, 1)) +
  labs(title = "R²: share of revenue variation explained rises as real drivers are added", x = NULL, y = "R²") + theme_tdbg()
save_fig(p4, "3-2", "f04")

# --- F05 · Coefficient plot -------------------------------------------------------------------------
co <- tidy(full, conf.int = TRUE) |> filter(term != "(Intercept)") |>
  mutate(label = recode(term, ad_spend_m_naira = "Ad spend (per ₦1m)", price_index = "Price index (per point)",
                        active_outlets = "Active outlets (per outlet)", sales_reps = "Sales reps (per rep)", rainfall_mm = "Rainfall (per mm)",
                        regionLagos = "Region: Lagos vs East", regionNorth = "Region: North vs East", `regionSouth-West` = "Region: South-West vs East"),
         sig = conf.low > 0 | conf.high < 0)
p5 <- ggplot(co, aes(estimate, reorder(label, estimate), colour = sig)) + geom_vline(xintercept = 0) +
  geom_errorbarh(aes(xmin = conf.low, xmax = conf.high), height = .25, linewidth = 1.1) + geom_point(size = 3) +
  geom_text(aes(x = conf.high + .3, label = sprintf("%+.2f", estimate)), hjust = 0, colour = tdbg[["ink"]], size = 3.5) +
  scale_colour_manual(values = c(`TRUE` = tdbg[["teal"]], `FALSE` = tdbg[["slate"]]), guide = "none") +
  labs(title = "Effect of each driver on monthly revenue (₦m), holding the others fixed",
       x = "Coefficient with 95% CI (grey = not distinguishable from zero)", y = NULL) + theme_tdbg()
save_fig(p5, "3-2", "f05")

# --- F06 · Residual diagnostics ----------------------------------------------------------------------
au <- augment(full)
g1 <- ggplot(au, aes(.fitted, .resid)) + geom_point(colour = tdbg[["teal"]], alpha = .6) + geom_hline(yintercept = 0, colour = tdbg[["rust"]]) +
  labs(title = "Residuals vs fitted: no pattern = good", x = "Fitted revenue (₦m)", y = "Residual (₦m)") + theme_tdbg(11)
g2 <- ggplot(au, aes(.resid)) + geom_histogram(bins = 25, fill = tdbg[["teal"]], colour = "white") +
  labs(title = "Residuals roughly bell-shaped = good", x = "Residual (₦m)", y = NULL) + theme_tdbg(11)
save_fig(g1 | g2, "3-2", "f06", width = 12, height = 4.8)
# Base R alternative: par(mfrow = c(2, 2)); plot(full)

# --- F07 · Predicted vs actual ------------------------------------------------------------------------
p7 <- ggplot(au, aes(.fitted, revenue_m_naira)) + geom_point(colour = tdbg[["teal"]], alpha = .6) +
  geom_abline(colour = tdbg[["gold"]], linewidth = 1.2) +
  annotate("text", x = 40, y = 120, hjust = 0, colour = tdbg[["navy"]], size = 4.5,
           label = sprintf("R² = %.2f\ntypical error (RMSE) = ₦%.1fm", summary(full)$r.squared, sigma(full))) +
  labs(title = "Predicted vs actual revenue: points hug the 45° line", x = "Predicted revenue (₦m)", y = "Actual revenue (₦m)") + theme_tdbg()
save_fig(p7, "3-2", "f07")
