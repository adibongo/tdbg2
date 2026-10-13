# =============================================================================
# TDBG · Session 4.1 LAB · Score and explain B2B leads for a sales director (R)
# Data: data/b2b_leads.csv — train = first 1,750 leads; test = last 750
# install.packages(c("xgboost", "pROC"))   # once
# =============================================================================
library(dplyr); library(readr); library(xgboost); library(pROC)
d <- read_csv("data/b2b_leads.csv", show_col_types = FALSE)
X <- model.matrix(~ . - 1, data = select(d, -lead_id, -converted) |> mutate(across(where(is.character), factor)),
                  contrasts.arg = lapply(select(d, industry, company_size, lead_source), function(x) contrasts(factor(x), contrasts = FALSE)))
y <- d$converted; tr <- 1:1750; te <- 1751:2500

# ---- 1. Two candidate models -----------------------------------------------------------------
dd <- select(d, -lead_id)                                             # drop the ID column
lr <- glm(converted ~ ., binomial, data = dd[tr, ])                   # glass box
summary(lr)
set.seed(1)
xg <- xgb.train(params = list(objective = "binary:logistic", max_depth = 3, eta = .05, subsample = .8, colsample_bytree = .8),
                data = xgb.DMatrix(X[tr, ], label = y[tr]), nrounds = 300, verbose = 0)
p_lr <- predict(lr, dd[te, ], type = "response"); p_xg <- predict(xg, xgb.DMatrix(X[te, ]))
c(logistic = auc(y[te], p_lr), xgboost = auc(y[te], p_xg))         # is the black box even better?

# ---- 2. Global explanation: mean |SHAP| -------------------------------------------------------------
sv <- predict(xg, xgb.DMatrix(X[te, ]), predcontrib = TRUE)         # one SHAP value per lead per driver
S <- sv[, -ncol(sv)]; base <- sv[1, ncol(sv)]
sort(colMeans(abs(S)), decreasing = TRUE)

# ---- 3. Local explanation: why is THIS lead hot? ------------------------------------------------------
i <- which.max(p_xg)
d[te[i], ]                                             # the lead's details
sort(S[i, ], decreasing = TRUE)[1:5]                   # top drivers pushing it up
plogis(base + sum(S[i, ]))                             # = the model's predicted probability (check!)

# ---- 4. Lead scoring: grades and cumulative gains -------------------------------------------------------
q <- quantile(p_xg, c(.5, .8, .95))
grade <- cut(p_xg, c(-Inf, q, Inf), labels = c("D", "C", "B", "A"))
tibble(grade, converted = y[te]) |> group_by(grade) |> summarise(rate = mean(converted), leads = n())
o <- order(-p_xg); cum <- cumsum(y[te][o]) / sum(y[te])
cum[round(.3 * length(o))]                              # share of conversions in the top 30% of leads

# ---- YOUR TURN ------------------------------------------------------------------------------------------
# (a) Write a 3-line explanation of the hottest lead for the account manager (no jargon).
# (b) The logistic model is as accurate as XGBoost here. Which would you deploy, and why?
# (c) Sales can call 200 leads a week. Using the grades, how many conversions should they expect?
