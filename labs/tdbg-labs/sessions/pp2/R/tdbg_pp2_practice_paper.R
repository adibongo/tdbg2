# =============================================================================
# TDBG · Practice Paper 2 · Module 2 Practice Paper — PRACTICE PAPER (R)
# Reproduces every output in Section B and the practice-paper figures.
# Data: data/hr_attrition_salary.csv (B1) and data/telecom_churn.csv (B2)
# =============================================================================
source("R/theme_tdbg.R")
suppressPackageStartupMessages({ library(dplyr); library(readr); library(pROC) })

# ---- B1 · What explains salary? ---------------------------------------------------------
h <- read_csv("data/hr_attrition_salary.csv", show_col_types = FALSE) |> mutate(department = relevel(factor(department), "Customer Support"))
m1 <- lm(monthly_salary_naira / 1000 ~ tenure_months + engagement_score + department, data = h)
summary(m1)

# ---- B2 · Churn classifier ---------------------------------------------------------------
t <- read_csv("data/telecom_churn.csv", show_col_types = FALSE)
tr <- t[1:3500, ]; te <- t[3501:5000, ]
m2 <- glm(churned ~ tenure_months + dropped_calls + complaints + multi_sim + data_gb_month + plan, binomial, tr)
round(exp(coef(m2)), 2)
te$p <- predict(m2, te, type = "response")
table(predicted = as.integer(te$p >= 0.3), actual = te$churned)
auc(te$churned, te$p)

r <- roc(te$churned, te$p, quiet = TRUE)
p1 <- ggplot(tibble(fpr = 1 - r$specificities, tpr = r$sensitivities), aes(fpr, tpr)) + geom_line(colour = tdbg[["teal"]], linewidth = 1.4) +
  geom_abline(linetype = "dashed") + annotate("text", x = .6, y = .2, label = sprintf("AUC = %.2f", auc(r)), size = 5) +
  labs(title = "Practice B2 · ROC curve of the churn model (test data)", x = "False positive rate", y = "True positive rate") + theme_tdbg()
save_fig(p1, "pp2", "f01", width = 8, height = 6)
