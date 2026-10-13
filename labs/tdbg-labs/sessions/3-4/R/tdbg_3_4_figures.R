# =============================================================================
# TDBG · Session 3.4 · Classification & Logistic Regression
# Replication script — regenerates every chart in the Session 3.4 deck (R)
# Data: data/digital_loans.csv. Train = first 4,200 loans, test = last 1,800.
# =============================================================================
source("R/theme_tdbg.R")
suppressPackageStartupMessages({ library(dplyr); library(readr); library(tidyr); library(broom); library(pROC); library(patchwork) })
d <- read_csv("data/digital_loans.csv", show_col_types = FALSE) |>
  mutate(log_income = log(monthly_income_naira), log_airtime = log(monthly_airtime_naira),
         acquisition_channel = relevel(factor(acquisition_channel), "Organic"), state = relevel(factor(state), "Lagos"))
tr <- d[1:4200, ]; te <- d[4201:6000, ]
m <- glm(defaulted ~ age + salary_earner + log_income + repayment_to_income + tenure_days + prior_loans_repaid +
           prior_late_payments + account_age_months + phone_os + log_airtime + bvn_verified + acquisition_channel + state,
         family = binomial, data = tr)
te$p <- predict(m, te, type = "response")
GOOD <- 8000; BAD <- 45000

# --- F01 · Linear vs logistic -----------------------------------------------------------
band <- tr |> mutate(b = cut(repayment_to_income, seq(0, 1.6, .1))) |> filter(!is.na(b)) |>
  group_by(b) |> summarise(x = mean(repayment_to_income), rate = mean(defaulted))
xs <- tibble(repayment_to_income = seq(0, 2.2, length.out = 200))
lin <- lm(defaulted ~ repayment_to_income, tr); lg <- glm(defaulted ~ repayment_to_income, binomial, tr)
xs$Linear <- predict(lin, xs); xs$Logistic <- predict(lg, xs, type = "response")
p1 <- ggplot() + geom_jitter(data = tr, aes(repayment_to_income, defaulted), height = .03, width = 0, alpha = .1, size = .6, colour = tdbg[["slate"]]) +
  geom_line(data = xs, aes(repayment_to_income, Linear), colour = tdbg[["rust"]], linetype = "dashed", linewidth = 1.2) +
  geom_line(data = xs, aes(repayment_to_income, Logistic), colour = tdbg[["teal"]], linewidth = 1.5) +
  geom_point(data = band, aes(x, rate), colour = tdbg[["gold"]], size = 3.5) + coord_cartesian(xlim = c(0, 2.2), ylim = c(-.15, 1.15)) +
  labs(title = "Predicting a yes/no outcome needs an S-shaped curve", subtitle = "dashed = linear regression; solid = logistic; dots = actual default rate by band",
       x = "Repayment ÷ income over the loan term", y = "Defaulted (0 = no, 1 = yes)") + theme_tdbg()
save_fig(p1, "3-4", "f01")

# --- F02 · Sigmoid ---------------------------------------------------------------------------
sg <- tibble(z = seq(-6, 6, length.out = 300), p = plogis(z)); pts <- tibble(z = c(-2, 0, 2), p = plogis(z))
p2 <- ggplot(sg, aes(z, p)) + geom_line(colour = tdbg[["teal"]], linewidth = 1.6) + geom_point(data = pts, colour = tdbg[["gold"]], size = 4) +
  geom_text(data = pts, aes(label = sprintf("score %+d → %.0f%%", z, 100 * p)), hjust = -.15, vjust = 1.2, colour = tdbg[["navy"]]) +
  scale_y_continuous(labels = scales::percent) +
  labs(title = "Logistic regression turns any score into a probability between 0 and 1",
       x = "Linear score z = b0 + b1x1 + b2x2 + ... (the log-odds)", y = "Probability of default") + theme_tdbg()
save_fig(p2, "3-4", "f02")

# --- F03 · Odds ratios --------------------------------------------------------------------------
ci <- confint.default(m)
spec <- tribble(~label, ~term, ~step,
  "Repayment ÷ income (+0.1)", "repayment_to_income", .1, "Each prior late payment", "prior_late_payments", 1,
  "Each prior loan repaid", "prior_loans_repaid", 1, "Salary earner (vs not)", "salary_earner", 1, "BVN verified (vs not)", "bvn_verified", 1,
  "iOS (vs Android)", "phone_osiOS", 1, "Paid social (vs organic)", "acquisition_channelPaid social", 1,
  "Referral (vs organic)", "acquisition_channelReferral", 1, "Age (+10 years)", "age", 10)
orr <- spec |> mutate(or = exp(coef(m)[term] * step), lo = exp(ci[term, 1] * step), hi = exp(ci[term, 2] * step),
                      col = ifelse(lo > 1, "up", ifelse(hi < 1, "down", "ns")))
p3 <- ggplot(orr, aes(or, reorder(label, or), colour = col)) + geom_vline(xintercept = 1) +
  geom_errorbarh(aes(xmin = lo, xmax = hi), height = .25, linewidth = 1.1) + geom_point(size = 3) +
  geom_text(aes(x = hi * 1.05, label = sprintf("×%.2f", or)), hjust = 0, colour = tdbg[["ink"]], size = 3.6) +
  scale_x_log10(breaks = c(.4, .6, 1, 1.5, 2.5)) + scale_colour_manual(values = c(up = tdbg[["rust"]], down = tdbg[["teal"]], ns = tdbg[["slate"]]), guide = "none") +
  labs(title = "Odds ratios: what multiplies — or divides — the odds of default", x = "Odds ratio (log scale; >1 raises risk, <1 lowers it)", y = NULL) + theme_tdbg()
save_fig(p3, "3-4", "f03")

# --- F04 · Score distributions --------------------------------------------------------------------
p4 <- ggplot(te, aes(p, fill = factor(defaulted, labels = c("Repaid", "Defaulted")))) +
  geom_histogram(aes(y = after_stat(density)), bins = 45, position = "identity", alpha = .6) +
  geom_vline(xintercept = .5, linetype = "dashed") + geom_vline(xintercept = .2, colour = tdbg[["gold"]], linewidth = 1.2) +
  scale_fill_manual(values = c(Repaid = tdbg[["sky"]], Defaulted = tdbg[["rust"]]), name = NULL) +
  labs(title = "Defaulters get higher scores — but the two groups overlap", x = "Predicted probability of default (test loans)", y = "Density") + theme_tdbg()
save_fig(p4, "3-4", "f04")

# --- F05 · Confusion matrices ------------------------------------------------------------------------
cm_plot <- function(t) {
  cm <- te |> mutate(pred = ifelse(p >= t, "Predicted: default", "Predicted: repay"), act = ifelse(defaulted == 1, "Actual: defaulted", "Actual: repaid")) |>
    count(act, pred) |> mutate(correct = (act == "Actual: defaulted") == (pred == "Predicted: default"))
  rec <- with(te, sum(p >= t & defaulted == 1) / sum(defaulted == 1)); prec <- with(te, sum(p >= t & defaulted == 1) / sum(p >= t))
  ggplot(cm, aes(pred, factor(act, levels = c("Actual: defaulted", "Actual: repaid")), fill = correct)) + geom_tile(colour = "white") +
    geom_text(aes(label = format(n, big.mark = ",")), size = 6, colour = tdbg[["navy"]]) +
    scale_fill_manual(values = c(`TRUE` = "#C9D6E3", `FALSE` = "white"), guide = "none") +
    labs(title = sprintf("Threshold %.1f: catches %.0f%% of defaulters\n(precision %.0f%%)", t, 100 * rec, 100 * prec), x = NULL, y = NULL) + theme_tdbg(11)
}
save_fig(cm_plot(.5) | cm_plot(.2), "3-4", "f05", width = 11, height = 4.8)

# --- F06 · ROC -------------------------------------------------------------------------------------------
r <- roc(te$defaulted, te$p, quiet = TRUE)
rc <- tibble(fpr = 1 - r$specificities, tpr = r$sensitivities)
mk <- tibble(t = c(.5, .2)) |> rowwise() |> mutate(fpr = mean(te$p[te$defaulted == 0] >= t), tpr = mean(te$p[te$defaulted == 1] >= t))
p6 <- ggplot(rc, aes(fpr, tpr)) + geom_line(colour = tdbg[["teal"]], linewidth = 1.5) + geom_abline(linetype = "dashed", colour = tdbg[["slate"]]) +
  geom_point(data = mk, colour = tdbg[["gold"]], size = 4) + geom_text(data = mk, aes(label = paste("threshold", t)), hjust = -.15, vjust = 1.3) +
  annotate("text", x = .62, y = .12, label = sprintf("Logistic regression AUC = %.2f\nCoin flip AUC = 0.50", auc(r)), hjust = 0) +
  labs(title = "ROC curve: the trade-off across every threshold", x = "False positive rate (good customers rejected)", y = "True positive rate (defaulters caught)") + theme_tdbg()
save_fig(p6, "3-4", "f06", width = 8, height = 6.5)

# --- F07 · Profit by threshold ---------------------------------------------------------------------------
ts <- seq(.02, .9, by = .01)
prof <- tibble(t = ts, profit = sapply(ts, function(t) with(te, GOOD * sum(defaulted == 0 & p < t) - BAD * sum(defaulted == 1 & p < t)) / 1e6))
best <- prof$t[which.max(prof$profit)]; all <- with(te, GOOD * sum(defaulted == 0) - BAD * sum(defaulted == 1)) / 1e6
p7 <- ggplot(prof, aes(t, profit)) + geom_line(colour = tdbg[["teal"]], linewidth = 1.5) + geom_vline(xintercept = best, colour = tdbg[["gold"]], linewidth = 1.2) +
  geom_hline(yintercept = all, colour = tdbg[["rust"]], linetype = "dashed") + geom_hline(yintercept = 0) +
  annotate("text", x = .42, y = max(prof$profit) * .8, hjust = 0, label = sprintf("best cut-off ≈ %.2f\nprofit ₦%.1fm on 1,800 applications", best, max(prof$profit))) +
  annotate("text", x = .6, y = all + .3, label = "approve everyone", colour = tdbg[["rust"]]) +
  labs(title = "The best threshold is a business decision: profit, not accuracy", x = "Reject if predicted default probability ≥ threshold", y = "Profit on test applications (₦ million)") + theme_tdbg()
save_fig(p7, "3-4", "f07")

# --- F08 · Precision and recall -------------------------------------------------------------------------
pr <- tibble(t = seq(.02, .7, by = .01)) |> rowwise() |>
  mutate(Recall = mean(te$p[te$defaulted == 1] >= t), Precision = sum(te$p >= t & te$defaulted == 1) / sum(te$p >= t)) |> ungroup() |> pivot_longer(-t)
p8 <- ggplot(pr, aes(t, value, colour = name)) + geom_line(linewidth = 1.5) + geom_hline(yintercept = mean(te$defaulted), linetype = "dotted") +
  scale_colour_manual(values = c(Recall = tdbg[["rust"]], Precision = tdbg[["teal"]]), name = NULL) + scale_y_continuous(labels = scales::percent) +
  labs(title = "Raise the threshold: fewer false alarms, but more defaulters slip through", x = "Threshold", y = "Rate") + theme_tdbg()
save_fig(p8, "3-4", "f08")
