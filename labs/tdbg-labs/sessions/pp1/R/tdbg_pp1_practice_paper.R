# =============================================================================
# TDBG · Practice Paper 1 · Module 1 Practice Paper — PRACTICE PAPER (R)
# Reproduces every output used in Section B of the practice paper, plus the
# two practice-paper charts (Fig PP1-F01, PP1-F02).
# Data: data/hr_attrition_salary.csv — 300 employees of a Lagos services firm
# =============================================================================
source("R/theme_tdbg.R")
suppressPackageStartupMessages({ library(dplyr); library(readr) })
h <- read_csv("data/hr_attrition_salary.csv", show_col_types = FALSE)

# ---- B1 · Describe monthly salary -----------------------------------------------
summary(h$monthly_salary_naira)
sd(h$monthly_salary_naira)
t.test(h$monthly_salary_naira)$conf.int          # 95% CI for the average salary

p1 <- ggplot(h, aes(monthly_salary_naira)) + geom_histogram(bins = 30, fill = tdbg[["teal"]], colour = "white") +
  geom_vline(xintercept = median(h$monthly_salary_naira), colour = tdbg[["gold"]], linewidth = 1.2) +
  geom_vline(xintercept = mean(h$monthly_salary_naira), colour = tdbg[["rust"]], linewidth = 1.2, linetype = "dashed") +
  scale_x_continuous(labels = naira) +
  labs(title = "Practice B1 · Monthly salary of 300 employees", subtitle = "solid = median, dashed = mean", x = "Monthly salary", y = "Employees") + theme_tdbg()
save_fig(p1, "pp1", "f01")

# ---- B2 · Do leavers have lower engagement? ------------------------------------------
h |> group_by(attrited) |> summarise(mean_eng = mean(engagement_score), sd = sd(engagement_score), n = n())
t.test(engagement_score ~ attrited, data = h)

p2 <- ggplot(h, aes(factor(attrited, labels = c("Stayed", "Left")), engagement_score)) +
  geom_boxplot(fill = "#D6E6EF", colour = tdbg[["teal"]], width = .5) +
  stat_summary(fun = mean, geom = "point", colour = tdbg[["gold"]], size = 4) +
  labs(title = "Practice B2 · Engagement score by attrition status", subtitle = "gold dot = mean", x = NULL, y = "Engagement score (1–10)") + theme_tdbg()
save_fig(p2, "pp1", "f02")

# ---- B3 · Is attrition related to department? --------------------------------------------
tab <- table(h$department, h$attrited); tab
prop.table(tab, 1)
chisq.test(tab)            # note the warning: some expected counts are below 5
chisq.test(tab)$expected
