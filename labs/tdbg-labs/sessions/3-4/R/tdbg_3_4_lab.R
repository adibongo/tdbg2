# =============================================================================
# TDBG · Session 3.4 LAB · Predicting loan default for a digital microlender (R)
# Data: data/digital_loans.csv — 6,000 loans. Train = first 4,200; test = last 1,800.
# Business assumptions: a repaid loan earns N8,000 margin; a default loses N45,000.
# =============================================================================
library(dplyr); library(readr); library(pROC)
d <- read_csv("data/digital_loans.csv", show_col_types = FALSE) |>
  mutate(log_income = log(monthly_income_naira), log_airtime = log(monthly_airtime_naira),
         acquisition_channel = relevel(factor(acquisition_channel), "Organic"), state = relevel(factor(state), "Lagos"))
tr <- d[1:4200, ]; te <- d[4201:6000, ]
mean(tr$defaulted)                                   # base rate: what share default?

# ---- 1. Fit a logistic regression ----------------------------------------------------------
m <- glm(defaulted ~ age + salary_earner + log_income + repayment_to_income + tenure_days + prior_loans_repaid +
           prior_late_payments + account_age_months + phone_os + log_airtime + bvn_verified + acquisition_channel + state,
         family = binomial, data = tr)
summary(m)                                           # coefficients are in log-odds
round(exp(cbind(OR = coef(m), confint.default(m))), 2)   # odds ratios with 95% CIs

# ---- 2. Predict probabilities for the test loans ----------------------------------------------
te$p <- predict(m, te, type = "response")
summary(te$p)

# ---- 3. Evaluate: confusion matrix at a threshold ------------------------------------------------
thr <- 0.5
table(predicted = te$p >= thr, actual = te$defaulted)
# Accuracy can mislead: predicting 'no default' for everyone is already ~81% accurate!

# ---- 4. Threshold-free evaluation: ROC and AUC ------------------------------------------------------
r <- roc(te$defaulted, te$p); auc(r); plot(r)

# ---- 5. Choose the threshold by profit ------------------------------------------------------------------
profit <- function(t) with(te, 8000 * sum(defaulted == 0 & p < t) - 45000 * sum(defaulted == 1 & p < t))
ts <- seq(0.02, 0.9, by = 0.01); pr <- sapply(ts, profit)
ts[which.max(pr)]; max(pr)
plot(ts, pr / 1e6, type = "l", xlab = "threshold", ylab = "profit (N million)")

# ---- YOUR TURN ------------------------------------------------------------------------------------------
# (a) Interpret the odds ratio for prior_late_payments in one sentence for the credit committee.
# (b) At the profit-maximising threshold: approval rate, default rate among approved loans, profit.
# (c) If the loss on default rises to N60,000 (higher interest rates), how does the best threshold move? Why?
# (d) Gender is not in the model. Name one variable that could still act as a proxy for a protected trait.
