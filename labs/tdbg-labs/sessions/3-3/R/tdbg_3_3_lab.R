# =============================================================================
# TDBG · Session 3.3 LAB · Forecasting weekly sales for a new beverage SKU (R)
# Data: data/beverage_sku_sales.csv — 400 SKU-weeks, 24 candidate drivers
# The SKU is new: we only have 60 weeks to learn from (rows 1–60).
# We judge every model on the other 340 weeks it has never seen.
# =============================================================================
library(readr); library(glmnet)
b <- read_csv("data/beverage_sku_sales.csv", show_col_types = FALSE)
X <- model.matrix(weekly_cases ~ . - sku_week, data = b)[, -1]
y <- b$weekly_cases
tr <- 1:60; te <- 61:400
rmse <- function(a, p) sqrt(mean((a - p)^2))

# ---- 1. Ordinary regression with every driver -----------------------------------------
b2 <- b[, names(b) != "sku_week"]             # drop the ID column
ols <- lm(weekly_cases ~ ., data = b2[tr, ])
summary(ols)                                   # note the huge, opposite-signed social_impressions coefficients
rmse(y[tr], predict(ols))                      # training error  (flattering)
rmse(y[te], predict(ols, newdata = b2[te, ]))  # test error      (honest)

# ---- 2. Lasso with cross-validated penalty ------------------------------------------------
set.seed(1)
cv_lasso <- cv.glmnet(X[tr, ], y[tr], alpha = 1, nfolds = 5)   # alpha = 1 -> lasso
plot(cv_lasso)                                  # CV error vs log(lambda)
coef(cv_lasso, s = "lambda.min")                # which drivers survived?
rmse(y[te], predict(cv_lasso, X[te, ], s = "lambda.min"))

# ---- 3. Ridge for comparison ----------------------------------------------------------------
cv_ridge <- cv.glmnet(X[tr, ], y[tr], alpha = 0, nfolds = 5)   # alpha = 0 -> ridge
rmse(y[te], predict(cv_ridge, X[te, ], s = "lambda.min"))

# ---- 4. A simpler lasso: the '1-standard-error' rule ------------------------------------------
coef(cv_lasso, s = "lambda.1se")                # fewer drivers, nearly the same accuracy
rmse(y[te], predict(cv_lasso, X[te, ], s = "lambda.1se"))

# ---- YOUR TURN -----------------------------------------------------------------------------------
# (a) Make a table: model, number of drivers used, training RMSE, test RMSE. Which would you deploy?
# (b) Why did OLS give social_impressions_k and its near-duplicate huge opposite coefficients?
# (c) Refit all models on 300 training weeks (tr <- 1:300; te <- 301:400). Does lasso still win? Why?
