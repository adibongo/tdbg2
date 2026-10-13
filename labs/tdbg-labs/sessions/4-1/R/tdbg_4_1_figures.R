# =============================================================================
# TDBG · Session 4.1 · Model Explainability & Lead Scoring
# Replication script — regenerates every chart in the Session 4.1 deck (R)
# Data: data/b2b_leads.csv — train = first 1,750 leads, test = last 750
# Model: XGBoost; explanations: exact TreeSHAP via predict(..., predcontrib = TRUE)
# install.packages("xgboost")   # once (may take a few minutes to compile on Linux)
# Note: boosting uses random subsampling; R and Python numbers differ slightly.
# =============================================================================
source("R/theme_tdbg.R")
suppressPackageStartupMessages({ library(dplyr); library(readr); library(tidyr); library(xgboost); library(pROC) })
d <- read_csv("data/b2b_leads.csv", show_col_types = FALSE)
X <- model.matrix(~ . - 1, data = select(d, -lead_id, -converted) |> mutate(across(where(is.character), factor)),
                  contrasts.arg = lapply(select(d, industry, company_size, lead_source), function(x) contrasts(factor(x), contrasts = FALSE)))
y <- d$converted; tr <- 1:1750; te <- 1751:2500
set.seed(1)
model <- xgb.train(params = list(objective = "binary:logistic", max_depth = 3, eta = .05, subsample = .8, colsample_bytree = .8),
                   data = xgb.DMatrix(X[tr, ], label = y[tr]), nrounds = 300, verbose = 0)
p <- predict(model, xgb.DMatrix(X[te, ]))
dd <- select(d, -lead_id); lr <- glm(converted ~ ., binomial, data = dd[tr, ]); plr <- predict(lr, dd[te, ], type = "response")
cat("AUC xgb", auc(y[te], p, quiet = TRUE), " logistic", auc(y[te], plr, quiet = TRUE), "\n")
sv <- predict(model, xgb.DMatrix(X[te, ]), predcontrib = TRUE)
base <- sv[1, ncol(sv)]; S <- as.data.frame(sv[, -ncol(sv)])      # last column = baseline ("BIAS")
nice <- function(c) { c <- sub("^lead_source", "source: ", c); c <- sub("^company_size", "size: ", c); c <- sub("^industry", "industry: ", c)
  c <- sub("requested_demo", "requested demo", c); c <- sub("days_since_first_touch", "days since first touch", c)
  c <- sub("web_visits", "web visits", c); sub("emails_opened", "emails opened", c) }

# --- F01 · Mean |SHAP| ------------------------------------------------------------------------
imp <- sort(colMeans(abs(S)), decreasing = TRUE)[1:10]
p1 <- ggplot(tibble(v = nice(names(imp)), i = imp), aes(i, reorder(v, i), fill = i == max(i))) + geom_col() +
  scale_fill_manual(values = c(`TRUE` = tdbg[["gold"]], `FALSE` = tdbg[["teal"]]), guide = "none") +
  labs(title = "Global view: which drivers move lead scores the most?", x = "Average |SHAP value| (impact on log-odds of converting)", y = NULL) + theme_tdbg()
save_fig(p1, "4-1", "f01")

# --- F02 · Beeswarm ----------------------------------------------------------------------------
top <- names(imp)[1:8]
bee <- bind_rows(lapply(top, function(c) { v <- X[te, c]; tibble(var = nice(c), shap = S[[c]], val = (v - min(v)) / (max(v) - min(v) + 1e-9)) }))
p2 <- ggplot(bee, aes(shap, factor(var, levels = rev(nice(top))), colour = val)) + geom_jitter(height = .25, width = 0, size = .9, alpha = .75) +
  geom_vline(xintercept = 0) + scale_colour_gradient2(low = "#3B4CC0", mid = "#DDDDDD", high = "#B40426", midpoint = .5, breaks = c(0, 1), labels = c("low", "high"), name = "driver value") +
  labs(title = "Each dot is one lead: red = high driver value, blue = low", x = "SHAP value (pushes score down ←  → pushes score up)", y = NULL) + theme_tdbg() + theme(legend.position = "right")
save_fig(p2, "4-1", "f02", height = 6)

# --- F03/F04 · Waterfalls ----------------------------------------------------------------------------
waterfall <- function(i, fid, ttl) {
  ctr <- unlist(S[i, ]); keep <- names(sort(abs(ctr), decreasing = TRUE))[1:6]
  vals <- c(ctr[keep], `all other drivers` = sum(ctr[setdiff(names(ctr), keep)]))
  labs_ <- c(paste0(nice(keep), " = ", round(X[te[i], keep], 1)), "all other drivers")
  wf <- tibble(lab = factor(labs_, levels = rev(labs_)), v = vals, end = base + cumsum(vals), start = end - v)
  ggplot(wf, aes(y = lab)) + geom_vline(xintercept = base, linetype = "dotted") + geom_vline(xintercept = base + sum(vals), colour = tdbg[["gold"]], linewidth = 1) +
    geom_segment(aes(x = start, xend = end, yend = lab, colour = v > 0), linewidth = 9) +
    geom_text(aes(x = end, label = sprintf("%+.2f", v), hjust = ifelse(v > 0, -0.2, 1.2)), size = 3.6) +
    scale_colour_manual(values = c(`TRUE` = tdbg[["rust"]], `FALSE` = tdbg[["teal"]]), guide = "none") +
    scale_x_continuous(expand = expansion(mult = .15)) +
    labs(title = sprintf("%s: score %.0f%% vs average lead %.0f%%", ttl, 100 * plogis(base + sum(vals)), 100 * plogis(base)),
         x = "Log-odds of converting (start at the average, add each driver's push)", y = NULL) + theme_tdbg()
}
hot <- which.max(p); cold <- order(p)[floor(length(p) / 10)]
save_fig(waterfall(hot, "f03", paste("Why lead", d$lead_id[te[hot]], "is hot")), "4-1", "f03")
save_fig(waterfall(cold, "f04", paste("Why lead", d$lead_id[te[cold]], "is cold")), "4-1", "f04")

# --- F05 · Dependence ----------------------------------------------------------------------------------
dep <- tibble(visits = X[te, "web_visits"], shap = S$web_visits, demo = factor(X[te, "requested_demo"], labels = c("no demo requested", "demo requested")))
p5 <- ggplot(dep, aes(visits, shap, colour = demo)) + geom_jitter(width = .2, height = 0, alpha = .6) + geom_hline(yintercept = 0) +
  scale_colour_manual(values = c(tdbg[["sky"]], tdbg[["rust"]]), name = NULL) +
  labs(title = "SHAP dependence: more web visits generally push the score up", x = "Web visits", y = "SHAP value for web visits") + theme_tdbg()
save_fig(p5, "4-1", "f05")

# --- F06 · Cumulative gains -------------------------------------------------------------------------------
gains <- function(score, name) { o <- order(-score); tibble(model = name, pct = 100 * seq_along(o) / length(o), cap = 100 * cumsum(y[te][o]) / sum(y[te])) }
g <- bind_rows(gains(p, "XGBoost score"), gains(plr, "Logistic score"))
p6 <- ggplot(g, aes(pct, cap, colour = model, linetype = model)) + geom_line(linewidth = 1.3) + geom_abline(linetype = "dotted") +
  scale_colour_manual(values = c(`XGBoost score` = tdbg[["gold"]], `Logistic score` = tdbg[["teal"]]), name = NULL) +
  scale_linetype_manual(values = c(`XGBoost score` = "solid", `Logistic score` = "dashed"), name = NULL) +
  labs(title = "Cumulative gains: scoring lets sales focus on the leads that convert", x = "% of leads contacted (highest scores first)", y = "% of all conversions captured") + theme_tdbg()
save_fig(p6, "4-1", "f06")

# --- F07 · Score bands ---------------------------------------------------------------------------------------
q <- quantile(p, c(.5, .8, .95))
band <- cut(p, c(-Inf, q, Inf), labels = c("D (bottom 50%)", "C (next 30%)", "B (next 15%)", "A (top 5%)"))
br <- tibble(band, y = y[te]) |> group_by(band) |> summarise(rate = mean(y), n = n())
p7 <- ggplot(br, aes(band, rate, fill = band)) + geom_col() + geom_text(aes(label = sprintf("%.0f%%\n(n=%d)", 100 * rate, n)), vjust = -.2) +
  geom_hline(yintercept = mean(y[te]), linetype = "dashed", colour = tdbg[["rust"]]) +
  scale_fill_manual(values = unname(tdbg[c("slate", "sky", "teal", "gold")]), guide = "none") + scale_y_continuous(labels = scales::percent, expand = expansion(mult = c(0, .2))) +
  labs(title = "Lead grades: conversion rate by score band on test leads", x = NULL, y = "Conversion rate") + theme_tdbg()
save_fig(p7, "4-1", "f07")
