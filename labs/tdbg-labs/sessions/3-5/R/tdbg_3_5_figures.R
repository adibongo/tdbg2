# =============================================================================
# TDBG · Session 3.5 · Trees, Random Forests & Gradient Boosting
# Replication script — regenerates every chart in the Session 3.5 deck (R)
# Data: data/digital_loans.csv — train = first 4,200 loans, test = last 1,800
# Note: forests and boosting use randomness; R and Python results differ slightly.
# =============================================================================
source("R/theme_tdbg.R")
suppressPackageStartupMessages({ library(dplyr); library(readr); library(tidyr); library(rpart); library(rpart.plot)
  library(ranger); library(gbm); library(pROC) })
d <- read_csv("data/digital_loans.csv", show_col_types = FALSE) |>
  mutate(across(c(phone_os, acquisition_channel, state), factor),
         acquisition_channel = relevel(acquisition_channel, "Organic"), state = relevel(state, "Lagos"),
         log_income = log(monthly_income_naira), log_airtime = log(monthly_airtime_naira))
tr <- d[1:4200, ]; te <- d[4201:6000, ]
vars <- c("age", "salary_earner", "monthly_income_naira", "loan_amount_naira", "tenure_days", "repayment_to_income", "prior_loans_repaid",
          "prior_late_payments", "account_age_months", "phone_os", "monthly_airtime_naira", "bvn_verified", "acquisition_channel", "state")
f_all <- as.formula(paste("defaulted ~", paste(vars, collapse = " + ")))
GOOD <- 8000; BAD <- 45000
set.seed(0)

lr <- glm(defaulted ~ age + salary_earner + log_income + repayment_to_income + tenure_days + prior_loans_repaid + prior_late_payments +
            account_age_months + phone_os + log_airtime + bvn_verified + acquisition_channel + state, binomial, tr)
tree <- rpart(f_all, data = tr, method = "class", control = rpart.control(maxdepth = 4, minbucket = 50, cp = 0))
rf <- ranger(f_all, data = mutate(tr, defaulted = factor(defaulted)), num.trees = 500, min.node.size = 10, probability = TRUE,
             importance = "permutation", seed = 0)
gb <- gbm(f_all, data = tr, distribution = "bernoulli", n.trees = 300, shrinkage = .05, interaction.depth = 4, n.minobsinnode = 20, verbose = FALSE)
p <- list(`Logistic regression` = predict(lr, te, type = "response"),
          `Decision tree (depth 4)` = predict(tree, te)[, "1"],
          `Random forest` = predict(rf, te)$predictions[, "1"],
          `Gradient boosting` = predict(gb, te, n.trees = 300, type = "response"))
aucs <- sapply(p, function(v) as.numeric(auc(te$defaulted, v, quiet = TRUE))); print(round(aucs, 3))

# --- F01 · A small decision tree ------------------------------------------------------------
small <- rpart(f_all, data = tr, method = "class", control = rpart.control(maxdepth = 3, minbucket = 80, cp = 0))
dir.create("sessions/3-5/figures/r", recursive = TRUE, showWarnings = FALSE)
png("sessions/3-5/figures/r/3-5_f01.png", width = 14, height = 6.6, units = "in", res = 200)
rpart.plot(small, type = 4, extra = 107, box.palette = "OrBu", main = "A decision tree is a sequence of yes/no questions — read from the top")
dev.off()

# --- F02 · Partition of two drivers -----------------------------------------------------------
two <- rpart(defaulted ~ repayment_to_income + prior_late_payments, data = tr, control = rpart.control(maxdepth = 3, minbucket = 60, cp = 0))
grid <- crossing(repayment_to_income = seq(0, 1.6, length.out = 200), prior_late_payments = seq(-.5, 5.5, length.out = 200))
grid$p <- predict(two, grid)
pts <- slice_sample(tr, n = 800)
p2 <- ggplot(grid, aes(repayment_to_income, prior_late_payments)) + geom_raster(aes(fill = p), alpha = .85) +
  geom_jitter(data = pts, aes(colour = factor(defaulted)), width = 0, height = .25, size = .8, alpha = .6) +
  scale_fill_distiller(palette = "YlOrRd", direction = 1, name = "Predicted\ndefault rate") +
  scale_colour_manual(values = c(`0` = tdbg[["navy"]], `1` = tdbg[["rust"]]), guide = "none") +
  labs(title = "A tree splits the space into boxes, each with its own default rate", x = "Repayment ÷ income", y = "Prior late payments (jittered)") + theme_tdbg()
save_fig(p2, "3-5", "f02")

# --- F03 · Depth vs AUC ---------------------------------------------------------------------------
dep <- bind_rows(lapply(1:15, function(k) {
  t <- rpart(f_all, data = tr, method = "class", control = rpart.control(maxdepth = k, cp = 0, minsplit = 2, minbucket = 1, xval = 0))
  tibble(depth = k, Training = as.numeric(auc(tr$defaulted, predict(t, tr)[, "1"], quiet = TRUE)),
         Test = as.numeric(auc(te$defaulted, predict(t, te)[, "1"], quiet = TRUE))) })) |> pivot_longer(-depth)
p3 <- ggplot(dep, aes(depth, value, colour = name)) + geom_line(linewidth = 1.4) +
  geom_hline(yintercept = aucs["Random forest"], linetype = "dashed", colour = tdbg[["gold"]]) +
  scale_colour_manual(values = c(Training = tdbg[["teal"]], Test = tdbg[["rust"]]), name = NULL) +
  labs(title = "A single deep tree memorises the training data", subtitle = "dashed = random forest test AUC (note: rpart caps depth at 30)", x = "Maximum tree depth", y = "AUC") + theme_tdbg()
save_fig(p3, "3-5", "f03")

# --- F04 · Number of trees -------------------------------------------------------------------------
nt <- tibble(n = c(1, 5, 10, 25, 50, 100, 200, 500)) |> rowwise() |>
  mutate(auc = as.numeric(auc(te$defaulted, predict(ranger(f_all, data = mutate(tr, defaulted = factor(defaulted)), num.trees = n,
                                                           min.node.size = 10, probability = TRUE, seed = 0), te)$predictions[, "1"], quiet = TRUE)))
p4 <- ggplot(nt, aes(n, auc)) + geom_line(colour = tdbg[["teal"]], linewidth = 1.4) + geom_point(colour = tdbg[["teal"]], size = 3) +
  scale_x_log10(breaks = nt$n) +
  labs(title = "The 'wisdom of crowds': averaging many trees beats any one", x = "Number of trees in the forest (log scale)", y = "Test AUC") + theme_tdbg()
save_fig(p4, "3-5", "f04")

# --- F05 · ROC comparison ------------------------------------------------------------------------------
rocs <- bind_rows(lapply(names(p), function(k) { r <- roc(te$defaulted, p[[k]], quiet = TRUE)
  tibble(model = sprintf("%s (AUC %.3f)", k, aucs[k]), fpr = 1 - r$specificities, tpr = r$sensitivities) }))
p5 <- ggplot(rocs, aes(fpr, tpr, colour = model)) + geom_line(linewidth = 1.1) + geom_abline(linetype = "dotted") +
  scale_colour_manual(values = unname(tdbg[c("teal", "sky", "gold", "slate")]), name = NULL) +
  labs(title = "Ensembles rank risk better than single models", x = "False positive rate", y = "True positive rate") +
  theme_tdbg() + theme(legend.position = "bottom", legend.direction = "vertical")
save_fig(p5, "3-5", "f05", width = 8, height = 6.5)

# --- F06 · Permutation importance -----------------------------------------------------------------------
imp <- sort(rf$variable.importance, decreasing = TRUE)[1:10]
p6 <- ggplot(tibble(var = names(imp), v = imp), aes(v, reorder(var, v), fill = v == max(v))) + geom_col() +
  scale_fill_manual(values = c(`TRUE` = tdbg[["gold"]], `FALSE` = tdbg[["teal"]]), guide = "none") +
  labs(title = "What the forest relies on: permutation importance", subtitle = "ranger measures the drop in accuracy (out-of-bag) when a driver is scrambled",
       x = "Permutation importance", y = NULL) + theme_tdbg()
save_fig(p6, "3-5", "f06")

# --- F07 · Partial dependence (computed by hand) -------------------------------------------------------------
gridv <- quantile(tr$repayment_to_income, seq(.02, .98, length.out = 40))
pdv <- sapply(gridv, function(v) { tmp <- tr; tmp$repayment_to_income <- v; mean(predict(rf, tmp)$predictions[, "1"]) })
p7 <- ggplot(tibble(x = gridv, y = pdv), aes(x, y)) + geom_line(colour = tdbg[["teal"]], linewidth = 1.6) +
  geom_vline(xintercept = .55, linetype = "dashed", colour = tdbg[["gold"]]) +
  annotate("text", x = .57, y = min(pdv) + .01, hjust = 0, label = "risk jumps\naround 0.55", colour = tdbg[["gold"]]) +
  scale_y_continuous(labels = scales::percent) +
  labs(title = "Partial dependence: average predicted default as affordability worsens", x = "Repayment ÷ income", y = "Average predicted default probability") + theme_tdbg()
save_fig(p7, "3-5", "f07")

# --- F08 · Profit by model ------------------------------------------------------------------------------------
best <- sapply(p, function(v) max(sapply(seq(.02, .9, by = .01), function(t) GOOD * sum(te$defaulted == 0 & v < t) - BAD * sum(te$defaulted == 1 & v < t))) / 1e6)
p8 <- ggplot(tibble(model = factor(names(best), levels = names(best)), profit = best), aes(model, profit, fill = model)) + geom_col() +
  geom_text(aes(label = sprintf("₦%.1fm", profit)), vjust = -.4, size = 4.5) +
  scale_fill_manual(values = unname(tdbg[c("slate", "sky", "teal", "gold")]), guide = "none") +
  labs(title = "Better ranking, more profit: best-threshold profit on 1,800 test applications", x = NULL, y = "Profit (₦ million)") + theme_tdbg()
save_fig(p8, "3-5", "f08")
