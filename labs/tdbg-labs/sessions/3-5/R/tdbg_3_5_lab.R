# =============================================================================
# TDBG · Session 3.5 LAB · Can ensembles beat the logistic credit score? (R)
# Data: data/digital_loans.csv — train = first 4,200 loans; test = last 1,800
# install.packages(c("rpart", "rpart.plot", "ranger", "gbm", "pROC"))   # once
# =============================================================================
library(dplyr); library(readr); library(rpart); library(rpart.plot); library(ranger); library(gbm); library(pROC)
d <- read_csv("data/digital_loans.csv", show_col_types = FALSE) |>
  mutate(across(c(phone_os, acquisition_channel, state), factor))
tr <- d[1:4200, ]; te <- d[4201:6000, ]
f <- defaulted ~ age + salary_earner + monthly_income_naira + loan_amount_naira + tenure_days + repayment_to_income +
  prior_loans_repaid + prior_late_payments + account_age_months + phone_os + monthly_airtime_naira + bvn_verified + acquisition_channel + state

# ---- 1. A single decision tree ----------------------------------------------------------------
tree <- rpart(f, data = tr, method = "class", control = rpart.control(maxdepth = 4, minbucket = 50, cp = 0))
rpart.plot(tree, type = 4, extra = 107)              # read the rules top-down
p_tree <- predict(tree, te)[, "1"]

# ---- 2. Random forest: many de-correlated trees, averaged ------------------------------------------
set.seed(0)
rf <- ranger(f, data = mutate(tr, defaulted = factor(defaulted)), num.trees = 500, min.node.size = 10,
             probability = TRUE, importance = "permutation", seed = 0)
p_rf <- predict(rf, te)$predictions[, "1"]
sort(rf$variable.importance, decreasing = TRUE)      # which drivers matter most?

# ---- 3. Gradient boosting: trees built in sequence, each fixing the last one's errors ----------------
gb <- gbm(f, data = tr, distribution = "bernoulli", n.trees = 300, shrinkage = 0.05,
          interaction.depth = 4, n.minobsinnode = 20, verbose = FALSE)
p_gb <- predict(gb, te, n.trees = 300, type = "response")

# ---- 4. Compare on the SAME test loans ------------------------------------------------------------------
c(tree = auc(te$defaulted, p_tree), forest = auc(te$defaulted, p_rf), boosting = auc(te$defaulted, p_gb))

# ---- 5. Translate into money: best-threshold profit ---------------------------------------------------------
profit <- function(p) max(sapply(seq(.02, .9, by = .01), function(t)
  8000 * sum(te$defaulted == 0 & p < t) - 45000 * sum(te$defaulted == 1 & p < t)))
sapply(list(tree = p_tree, forest = p_rf, boosting = p_gb), profit)

# ---- YOUR TURN -----------------------------------------------------------------------------------------------
# (a) Write the decision tree's top three rules as plain-English credit policy.
# (b) Tune: try num.trees = 100 vs 1000 and min.node.size = 5 vs 50. What happens to test AUC?
# (c) The forest earns more but is harder to explain. Which would you deploy at a regulated lender? Why?
