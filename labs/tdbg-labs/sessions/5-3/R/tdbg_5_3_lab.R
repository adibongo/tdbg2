# =============================================================================
# TDBG · Session 5.3 LAB · Is the line in control, and is our attrition model fair? (R)
# Data: data/bottling_fill_volumes.csv, data/hr_employees.csv
# install.packages(c("dplyr", "readr", "pROC"))   # once
# =============================================================================
library(dplyr); library(readr); library(pROC)

# ---- PART A · Control chart for the bottling line ------------------------------------------------------
q <- read_csv("data/bottling_fill_volumes.csv", show_col_types = FALSE)    # 40 batches x 5 bottles; target 500 ml
g <- q |> group_by(batch) |> summarise(xbar = mean(fill_ml), R = max(fill_ml) - min(fill_ml))
base <- filter(g, batch <= 20)                                    # set limits while the process was stable
A2 <- 0.577                                                       # constant for samples of 5 (from SPC tables)
centre <- mean(base$xbar); UCL <- centre + A2 * mean(base$R); LCL <- centre - A2 * mean(base$R)
c(LCL = LCL, centre = centre, UCL = UCL)
g |> filter(xbar > UCL | xbar < LCL)                              # which batches are out of control?
plot(g$batch, g$xbar, type = "b", ylim = range(c(g$xbar, LCL, UCL)), xlab = "Batch", ylab = "Average fill (ml)")
abline(h = c(LCL, centre, UCL), lty = c(2, 1, 2), col = c("red", "black", "red"))

# Capability: can the process meet the 494–506 ml specification?
cpk <- function(s) min(506 - mean(s), mean(s) - 494) / (3 * sd(s))
c(before = cpk(q$fill_ml[q$batch < 28]), after = cpk(q$fill_ml[q$batch >= 28]))   # 1.33+ is the usual target

# ---- PART B · Reorder point with safety stock -------------------------------------------------------------
mu <- 120; sigma <- 40; lead <- 6                                 # daily demand (cases) and lead time (days)
z <- qnorm(0.95)                                                  # 95% service level -> z = 1.65
safety <- z * sigma * sqrt(lead); reorder_point <- mu * lead + safety
c(safety_stock = round(safety), reorder_point = round(reorder_point))

# ---- PART C · Attrition model -----------------------------------------------------------------------------
h <- read_csv("data/hr_employees.csv", show_col_types = FALSE) |> mutate(log_salary = log(monthly_salary_naira))
mean(h$attrited)
set.seed(20); idx <- sample(nrow(h), 0.7 * nrow(h)); tr <- h[idx, ]; te <- h[-idx, ]
fit <- glm(attrited ~ age + tenure_years + log_salary + engagement_score + overtime + years_since_promotion +
             commute_minutes + manager_rating + department, data = tr, family = binomial)   # gender deliberately left out
exp(coef(fit)) |> round(2)                                        # odds ratios
te$p <- predict(fit, te, type = "response")
auc(te$attrited, te$p)

# ---- PART D · Fairness audit --------------------------------------------------------------------------------
te$flag <- te$p >= quantile(te$p, 0.8)                            # HR will call the 20% most at risk
te |> group_by(gender) |> summarise(selection_rate = mean(flag), true_pos_rate = mean(flag[attrited == 1]),
                                    false_pos_rate = mean(flag[attrited == 0]), actual_attrition = mean(attrited))
h |> group_by(gender) |> summarise(median_salary = median(monthly_salary_naira))   # a possible reason: the pay gap

# ---- YOUR TURN ------------------------------------------------------------------------------------------
# (a) The line manager says batch 31 was "just bad luck". Use the control chart to reply.
# (b) What happens to safety stock if the supplier's lead time rises from 6 to 10 days?
# (c) Calculate the selection-rate ratio (women vs men). Does it pass the 'four-fifths' (0.8) rule?
#     Is the model unfair, or is it reflecting something real (the pay gap)? What should HR do?
