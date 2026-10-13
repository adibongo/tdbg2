# =============================================================================
# TDBG · Session 5.4 · CAPSTONE STARTER (R)
# A complete question-to-recommendation workflow you can copy for your capstone.
# Worked example: "Which subscribers should the retention team call this month?"
# Data: data/telecom_churn.csv (replace with your own file and outcome)
# Also regenerates Fig S5.4-F01. R's random split differs from Python's, so numbers differ slightly.
# =============================================================================
source("R/theme_tdbg.R")
suppressPackageStartupMessages({ library(dplyr); library(readr); library(pROC); library(gbm) })

# ---- STEP 1 · The business question and the decision ----------------------------------------------
CALL_COST <- 800; VALUE_SAVED <- 12000; SAVE_RATE <- 0.30      # assumptions: write yours down and test them

# ---- STEP 2 · Data: load, check, clean -------------------------------------------------------------
d <- read_csv("data/telecom_churn.csv", show_col_types = FALSE) |> mutate(postpaid = as.integer(plan == "Postpaid"))
dim(d); sum(is.na(d)); summary(d)
mean(d$churned)                                                 # base rate

# ---- STEP 3 · Explore -----------------------------------------------------------------------------------
d |> group_by(complaints) |> summarise(churn = mean(churned))
d |> group_by(tenure_band = cut(tenure_months, c(0, 6, 12, 24, 48, 72))) |> summarise(churn = mean(churned))

# ---- STEP 4 · Model: benchmark and challenger on held-out data ------------------------------------------
set.seed(22)
idx <- unlist(lapply(split(seq_len(nrow(d)), d$churned), function(i) sample(i, round(0.7 * length(i)))))
tr <- d[idx, ]; te <- d[-idx, ]
fml <- churned ~ tenure_months + data_gb_month + voice_minutes + dropped_calls + complaints + avg_recharge_naira + multi_sim + postpaid
lg <- glm(fml, data = tr, family = binomial); te$p <- predict(lg, te, type = "response")
gb <- gbm(fml, data = tr, distribution = "bernoulli", n.trees = 300, interaction.depth = 3, shrinkage = 0.05, verbose = FALSE)
cat(sprintf("test AUC — logistic %.3f | boosting %.3f\n", auc(te$churned, te$p, quiet = TRUE),
            auc(te$churned, predict(gb, te, n.trees = 300, type = "response"), quiet = TRUE)))
round(exp(coef(lg)), 3)                                         # odds ratios per unit

# ---- STEP 5 · Value: turn predictions into a naira decision ------------------------------------------
dec <- te |> arrange(desc(p)) |> mutate(decile = ceiling(10 * row_number() / n())) |> group_by(decile) |>
  summarise(customers = n(), churners = sum(churned)) |>
  mutate(net_value = churners * SAVE_RATE * VALUE_SAVED - customers * CALL_COST, cumulative = cumsum(net_value))
print(dec)
best <- dec$decile[which.max(dec$cumulative)]
cat(sprintf("Call the top %d deciles (%d%%): net value ≈ ₦%s\n", best, best * 10, format(max(dec$cumulative), big.mark = ",")))

# ---- STEP 6 · Check: fairness and robustness ----------------------------------------------------------
te |> mutate(flag = p >= quantile(p, 1 - best / 10)) |> group_by(plan) |> summarise(called = mean(flag))
for (sr in c(0.2, 0.3, 0.4)) { v <- cumsum(dec$churners * sr * VALUE_SAVED - dec$customers * CALL_COST)
  cat(sprintf("save rate %.0f%%: best = top %d deciles, value ₦%s\n", 100 * sr, which.max(v), format(max(v), big.mark = ","))) }

# ---- STEP 7 · Communicate: one chart, one recommendation ------------------------------------------------
p1 <- ggplot(dec, aes(decile)) + geom_col(aes(y = net_value / 1000, fill = net_value > 0)) +
  geom_line(aes(y = cumulative / 1000), colour = tdbg[["gold"]], linewidth = 1.3) + geom_point(aes(y = cumulative / 1000), colour = tdbg[["gold"]], size = 2.5) +
  geom_hline(yintercept = 0, colour = "grey50") +
  annotate("text", x = best + 0.4, y = max(dec$cumulative) / 1000 * 0.85, hjust = 0, colour = tdbg[["gold"]], fontface = "bold",
           label = sprintf("stop here: call the top %d%%\n≈ %s net value", best * 10, naira(max(dec$cumulative)))) +
  scale_fill_manual(values = c(`TRUE` = tdbg[["teal"]], `FALSE` = tdbg[["rust"]]), guide = "none") + scale_x_continuous(breaks = 1:10) +
  labs(title = "Who to call: the first deciles pay for themselves", subtitle = "Bars = net value of calling each decile; line = cumulative",
       x = "Risk decile (1 = highest predicted churn)", y = "₦ thousand (1,500 test subscribers)") + theme_tdbg()
save_fig(p1, "5-4", "f01")
