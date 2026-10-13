# =============================================================================
# TDBG · Session 3.3 · Regularised Regression & Predictive Sales
# Replication script — regenerates every chart in the Session 3.3 deck (R)
# Data: data/beverage_sku_sales.csv. Train = first 60 rows, test = remaining 340.
# Note: CV folds and F07 resampling are random; R and Python differ slightly.
# =============================================================================
source("R/theme_tdbg.R")
suppressPackageStartupMessages({ library(dplyr); library(readr); library(tidyr); library(glmnet); library(patchwork) })
b <- read_csv("data/beverage_sku_sales.csv", show_col_types = FALSE)
X <- model.matrix(weekly_cases ~ . - sku_week, data = b)[, -1]          # dummies for region
y <- b$weekly_cases
tr <- 1:60; te <- 61:400
rmse <- function(a, p) sqrt(mean((a - p)^2))

# --- F01 · Overfitting --------------------------------------------------------------
s <- b[1:30, ]; grid <- tibble(price_naira = seq(min(s$price_naira), max(s$price_naira), length.out = 200))
fits <- bind_rows(lapply(c(1, 3, 12), function(d) {
  m <- lm(weekly_cases ~ poly(price_naira, d), data = s)
  grid |> mutate(pred = pmin(pmax(predict(m, grid), 500), 2500), deg = d) }))
fits$panel <- factor(c(`1` = "Degree 1: too simple (underfit)", `3` = "Degree 3: about right", `12` = "Degree 12: memorises noise (overfit)")[as.character(fits$deg)],
                     levels = c("Degree 1: too simple (underfit)", "Degree 3: about right", "Degree 12: memorises noise (overfit)"))
p1 <- ggplot() + geom_point(data = crossing(s, panel = factor(levels(fits$panel), levels = levels(fits$panel))), aes(price_naira, weekly_cases), colour = tdbg[["teal"]]) +
  geom_line(data = fits, aes(price_naira, pred, colour = deg == 12), linewidth = 1.2) + facet_wrap(~panel) +
  scale_colour_manual(values = c(`TRUE` = tdbg[["rust"]], `FALSE` = tdbg[["gold"]]), guide = "none") +
  coord_cartesian(ylim = c(700, 2300)) + labs(title = NULL, x = "Price (₦)", y = "Weekly cases") + theme_tdbg(11)
save_fig(p1, "3-3", "f01", width = 13, height = 4.4)

# --- F02 · Train vs test error by number of drivers ---------------------------------------
feats <- c("distribution_pct", "price_naira", "promo_depth_pct", "festive_week", "shelf_facings", "competitor_price", "temperature_c",
           "social_impressions_k", "radio_grp", grep("^noise", colnames(X), value = TRUE), "social_impressions_k_dup", "school_term",
           grep("^region", colnames(X), value = TRUE))
err <- bind_rows(lapply(seq_along(feats), function(k) {
  m <- lm.fit(cbind(1, X[tr, feats[1:k], drop = FALSE]), y[tr]); cf <- m$coefficients; cf[is.na(cf)] <- 0
  tibble(k = k, Training = rmse(y[tr], cbind(1, X[tr, feats[1:k], drop = FALSE]) %*% cf),
         `New weeks` = rmse(y[te], cbind(1, X[te, feats[1:k], drop = FALSE]) %*% cf)) })) |> pivot_longer(-k)
best <- err |> filter(name == "New weeks") |> slice_min(value) |> pull(k)
p2 <- ggplot(err, aes(k, value, colour = name)) + geom_line(linewidth = 1.4) + geom_vline(xintercept = best, linetype = "dashed", colour = tdbg[["slate"]]) +
  scale_colour_manual(values = c(Training = tdbg[["teal"]], `New weeks` = tdbg[["rust"]]), name = NULL) +
  labs(title = "More drivers always fit the past better — but can predict the future worse",
       x = "Number of drivers in the model (real drivers first, then noise)", y = "RMSE (cases per week)") + theme_tdbg()
save_fig(p2, "3-3", "f02")

# --- F03 · Cross-validation diagram --------------------------------------------------------
cv <- crossing(round = 1:5, fold = 1:5) |> mutate(role = ifelse(round == fold, "validate", "train"))
p3 <- ggplot(cv, aes(fold, -round, fill = role)) + geom_tile(colour = "white", width = .95, height = .8) +
  geom_text(aes(label = role), colour = "white", fontface = "bold") +
  annotate("text", x = 5.7, y = -(1:5), label = paste0("Round ", 1:5, " → error ", 1:5), hjust = 0, colour = tdbg[["navy"]]) +
  annotate("text", x = 5.7, y = -6, label = "CV error = average of the 5 errors", hjust = 0, colour = tdbg[["rust"]], fontface = "bold") +
  scale_fill_manual(values = c(train = tdbg[["teal"]], validate = tdbg[["gold"]]), guide = "none") + xlim(0.5, 8) +
  labs(title = "5-fold cross-validation: every week is used for testing exactly once") + theme_void(13) +
  theme(plot.title = element_text(face = "bold", colour = tdbg[["navy"]]))
save_fig(p3, "3-3", "f03", width = 11, height = 4.6)

# --- F04 · Lasso path (glmnet standardises the drivers for you) ------------------------------
set.seed(1)
fit <- glmnet(X[tr, ], y[tr], alpha = 1)
path <- as.matrix(fit$beta) * apply(X[tr, ], 2, sd)            # standardised coefficients
real <- c("distribution_pct", "price_naira", "promo_depth_pct", "festive_week", "shelf_facings", "competitor_price", "temperature_c")
pd <- as_tibble(t(path)) |> mutate(loglam = log10(fit$lambda)) |> pivot_longer(-loglam) |> mutate(real = name %in% real)
p4 <- ggplot(pd, aes(loglam, value, group = name, colour = real, linewidth = real)) + geom_line() + scale_x_reverse() +
  scale_colour_manual(values = c(`TRUE` = tdbg[["teal"]], `FALSE` = "#C9D2DB"), guide = "none") +
  scale_linewidth_manual(values = c(`TRUE` = 1.1, `FALSE` = .5), guide = "none") +
  labs(title = "Lasso path: as the penalty relaxes (right), drivers enter one by one — noise last",
       x = "log10(penalty λ)  ← stronger            weaker →", y = "Standardised coefficient") + theme_tdbg()
save_fig(p4, "3-3", "f04")

# --- F05 · Choosing lambda by CV ---------------------------------------------------------------
cvfit <- cv.glmnet(X[tr, ], y[tr], alpha = 1, nfolds = 5)
cvd <- tibble(loglam = log10(cvfit$lambda), rmse = sqrt(cvfit$cvm), lo = sqrt(cvfit$cvlo), hi = sqrt(cvfit$cvup))
p5 <- ggplot(cvd, aes(loglam, rmse)) + geom_errorbar(aes(ymin = lo, ymax = hi), colour = "#C9D2DB") + geom_point(colour = tdbg[["teal"]]) +
  geom_vline(xintercept = log10(cvfit$lambda.min), colour = tdbg[["gold"]], linewidth = 1.2) +
  annotate("text", x = log10(cvfit$lambda.min) + .05, y = max(cvd$rmse), hjust = 0, colour = tdbg[["gold"]], label = sprintf("best λ = %.1f", cvfit$lambda.min)) +
  labs(title = "Cross-validation picks the penalty with the lowest out-of-sample error", x = "log10(penalty λ)", y = "CV RMSE (cases per week)") + theme_tdbg()
save_fig(p5, "3-3", "f05")

# --- F06 · OLS vs lasso coefficients -----------------------------------------------------------
ols <- lm(y[tr] ~ scale(X[tr, ]))
co <- tibble(term = colnames(X), OLS = coef(ols)[-1], Lasso = as.numeric(coef(cvfit, s = "lambda.min"))[-1] * apply(X[tr, ], 2, sd)) |>
  mutate(term = reorder(term, OLS)) |> pivot_longer(-term)
p6 <- ggplot(co, aes(value, term, fill = name)) + geom_col(position = position_dodge(.8), width = .75) + geom_vline(xintercept = 0) +
  scale_fill_manual(values = c(OLS = "#B8C7D3", Lasso = tdbg[["teal"]]), name = NULL) +
  labs(title = sprintf("Lasso sets %d of %d coefficients to exactly zero — mostly the noise", sum(coef(cvfit, s = "lambda.min")[-1] == 0), ncol(X)),
       x = "Standardised coefficient (cases per week per SD)", y = NULL) + theme_tdbg(11)
save_fig(p6, "3-3", "f06", height = 7)

# --- F07 · Learning curve -----------------------------------------------------------------------
set.seed(9); sizes <- c(35, 50, 80, 150, 300); pool <- 1:300; test <- 301:400
lc <- bind_rows(lapply(sizes, function(n) bind_rows(lapply(1:15, function(r) {
  i <- sample(pool, n)
  o <- lm.fit(cbind(1, X[i, ]), y[i])$coefficients; o[is.na(o)] <- 0
  rg <- cv.glmnet(X[i, ], y[i], alpha = 0, nfolds = 5); ls <- cv.glmnet(X[i, ], y[i], alpha = 1, nfolds = 5)
  tibble(n = n, OLS = rmse(y[test], cbind(1, X[test, ]) %*% o), Ridge = rmse(y[test], predict(rg, X[test, ], s = "lambda.min")),
         Lasso = rmse(y[test], predict(ls, X[test, ], s = "lambda.min"))) })))) |>
  pivot_longer(-n) |> group_by(n, name) |> summarise(rmse = mean(value), .groups = "drop")
p7 <- ggplot(lc, aes(n, rmse, colour = name)) + geom_line(linewidth = 1.3) + geom_point(size = 2.5) +
  scale_colour_manual(values = c(OLS = tdbg[["slate"]], Ridge = tdbg[["gold"]], Lasso = tdbg[["teal"]]), name = NULL) +
  labs(title = "Regularisation helps most when history is short", x = "Training weeks available", y = "Test RMSE (cases per week)") + theme_tdbg()
save_fig(p7, "3-3", "f07")

# --- F08 · Test-set accuracy ---------------------------------------------------------------------
pl <- as.numeric(predict(cvfit, X[te, ], s = "lambda.min"))
po <- as.numeric(cbind(1, X[te, ]) %*% {o <- lm.fit(cbind(1, X[tr, ]), y[tr])$coefficients; o[is.na(o)] <- 0; o})
p8 <- ggplot(tibble(pred = pl, actual = y[te]), aes(pred, actual)) + geom_point(colour = tdbg[["teal"]], alpha = .6) +
  geom_abline(colour = tdbg[["gold"]], linewidth = 1.2) +
  annotate("text", x = 900, y = 1980, hjust = 0, colour = tdbg[["navy"]],
           label = sprintf("Lasso test RMSE = %.0f cases\nOLS test RMSE   = %.0f cases\n(trained on 60 weeks, tested on 340)", rmse(y[te], pl), rmse(y[te], po))) +
  labs(title = "Predicting 340 unseen weeks", x = "Predicted weekly cases", y = "Actual weekly cases") + theme_tdbg()
save_fig(p8, "3-3", "f08")
