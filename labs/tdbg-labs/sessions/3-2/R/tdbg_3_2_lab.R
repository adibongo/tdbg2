# =============================================================================
# TDBG · Session 3.2 LAB · What drives an FMCG distributor's revenue? (R)
# Data: data/fmcg_distributor_revenue.csv — 240 distributor-months
# =============================================================================
library(dplyr); library(readr); library(broom)
f <- read_csv("data/fmcg_distributor_revenue.csv", show_col_types = FALSE)

# ---- 1. Explore relationships first --------------------------------------------------
round(cor(select(f, where(is.numeric))), 2)
pairs(select(f, revenue_m_naira, ad_spend_m_naira, active_outlets, sales_reps, price_index))

# ---- 2. Simple regression: one driver ---------------------------------------------------
m1 <- lm(revenue_m_naira ~ ad_spend_m_naira, data = f)
summary(m1)                     # slope, R-squared, p-value
confint(m1)                     # 95% CI for the slope

# ---- 3. Multiple regression: several drivers at once ---------------------------------------
f$region <- relevel(factor(f$region), ref = "East")         # East = comparison region
m2 <- lm(revenue_m_naira ~ ad_spend_m_naira + price_index + active_outlets + sales_reps + rainfall_mm + region, data = f)
summary(m2)
tidy(m2, conf.int = TRUE)       # tidy table of coefficients with CIs
glance(m2)                      # R2, adjusted R2, sigma (typical error)

# ---- 4. Diagnostics: is the straight-line model reasonable? ------------------------------------
par(mfrow = c(2, 2)); plot(m2); par(mfrow = c(1, 1))

# ---- 5. Use the model: a what-if prediction ------------------------------------------------------
new <- tibble(ad_spend_m_naira = c(10, 15), price_index = 100, active_outlets = 250,
              sales_reps = 8, rainfall_mm = 120, region = factor("Lagos", levels = levels(f$region)))
predict(m2, newdata = new, interval = "prediction")   # range for an individual month

# ---- YOUR TURN ------------------------------------------------------------------------------------
# (a) Interpret the active_outlets coefficient in one sentence a sales director would understand.
# (b) Is an extra N5m of advertising worth it if gross margin on revenue is 25%? Show the arithmetic.
# (c) Name one reason the advertising coefficient might NOT be causal.
