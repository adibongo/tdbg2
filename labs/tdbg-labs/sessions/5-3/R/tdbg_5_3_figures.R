# =============================================================================
# TDBG · Session 5.3 · Operations & People Analytics, and Responsible AI
# Replication script — regenerates every chart in the Session 5.3 deck (R)
# Data: data/bottling_fill_volumes.csv and data/hr_employees.csv
# F04 uses a small inventory simulation; R's random numbers differ from Python's, so the
# stock-out counts differ slightly — the lesson is the same.
# =============================================================================
source("R/theme_tdbg.R")
suppressPackageStartupMessages({ library(dplyr); library(readr); library(tidyr); library(pROC); library(patchwork) })

# ============================ PART A · Quality control (SPC) ==================================
q <- read_csv("data/bottling_fill_volumes.csv", show_col_types = FALSE)
LSL <- 494; USL <- 506; TARGET <- 500
g <- q |> group_by(batch) |> summarise(xbar = mean(fill_ml), R = max(fill_ml) - min(fill_ml))
base <- filter(g, batch <= 20)                                         # Phase I: limits from batches 1–20
A2 <- 0.577; xbb <- mean(base$xbar); Rb <- mean(base$R)
UCL <- xbb + A2 * Rb; LCL <- xbb - A2 * Rb
g <- mutate(g, out = xbar > UCL | xbar < LCL)
cat(sprintf("centre %.2f, LCL %.2f, UCL %.2f; first out-of-control batch %d\n", xbb, LCL, UCL, min(g$batch[g$out])))

# --- F01 · Run chart -----------------------------------------------------------------------------
p1 <- q |> mutate(i = row_number()) |> ggplot(aes(i, fill_ml)) + geom_line(colour = tdbg[["teal"]], alpha = 0.3) +
  geom_point(colour = tdbg[["teal"]], size = 1.2) + geom_hline(yintercept = TARGET, colour = tdbg[["navy"]]) +
  geom_hline(yintercept = c(LSL, USL), colour = tdbg[["rust"]], linetype = 2) +
  annotate("text", x = 205, y = c(LSL, USL, TARGET), label = c("LSL 494", "USL 506", "target"), colour = c(tdbg[["rust"]], tdbg[["rust"]], tdbg[["navy"]]), hjust = 0, size = 3.4) +
  coord_cartesian(xlim = c(0, 215)) +
  labs(title = "200 bottles from Line 2: is anything changing, or is it all just noise?", x = "Bottle (in production order)", y = "Fill volume (ml)") + theme_tdbg()
save_fig(p1, "5-3", "f01")

# --- F02 · X-bar chart ---------------------------------------------------------------------------
p2 <- ggplot(g, aes(batch, xbar)) + annotate("rect", xmin = 0.5, xmax = 20.5, ymin = -Inf, ymax = Inf, fill = "#F3F6F9") +
  geom_hline(yintercept = c(LCL, UCL), linetype = 2, colour = tdbg[["rust"]]) + geom_hline(yintercept = xbb, colour = tdbg[["navy"]]) +
  geom_vline(xintercept = 27.5, linetype = 3, colour = tdbg[["gold"]]) +
  geom_line(colour = tdbg[["teal"]]) + geom_point(aes(colour = out), size = 2.6) +
  scale_colour_manual(values = c(`FALSE` = tdbg[["teal"]], `TRUE` = tdbg[["rust"]]), labels = c("in control", "out of control"), name = NULL) +
  annotate("text", x = 42, y = c(LCL, xbb, UCL), label = sprintf(c("LCL %.1f", "centre %.1f", "UCL %.1f"), c(LCL, xbb, UCL)), hjust = 0, size = 3.4) +
  annotate("text", x = 1, y = UCL + 0.35, label = "Phase I: limits set from batches 1–20", hjust = 0, colour = tdbg[["slate"]], size = 3.3) +
  annotate("text", x = 28, y = LCL - 0.3, label = "something changed here", hjust = 0, colour = tdbg[["gold"]], fontface = "bold", size = 3.3) +
  coord_cartesian(xlim = c(1, 46)) +
  labs(title = "X-bar chart: batch averages drift up after batch 27", subtitle = "…and escape the upper control limit", x = "Batch (5 bottles each)", y = "Average fill (ml)") + theme_tdbg()
save_fig(p2, "5-3", "f02")

# --- F03 · Capability ------------------------------------------------------------------------------
cpk <- function(s) min(USL - mean(s), mean(s) - LSL) / (3 * sd(s))
bf <- q$fill_ml[q$batch < 28]; af <- q$fill_ml[q$batch >= 28]
cat(sprintf("Cpk before %.2f after %.2f\n", cpk(bf), cpk(af)))
p3 <- q |> mutate(period = ifelse(batch < 28, sprintf("Batches 1–27: mean %.1f ml, Cpk %.2f", mean(bf), cpk(bf)), sprintf("Batches 28–40: mean %.1f ml, Cpk %.2f", mean(af), cpk(af)))) |>
  ggplot(aes(fill_ml, fill = period)) + geom_histogram(binwidth = 0.75, position = "identity", alpha = 0.7) +
  geom_vline(xintercept = c(LSL, USL), linetype = 2, colour = tdbg[["rust"]]) + geom_vline(xintercept = TARGET, colour = tdbg[["navy"]]) +
  scale_fill_manual(values = c(tdbg[["teal"]], tdbg[["gold"]]), name = NULL) + theme_tdbg() + theme(legend.position = "top", legend.direction = "vertical") +
  labs(title = "Process capability: the shift pushes fills towards the upper limit", x = "Fill volume (ml)", y = "Bottles")
save_fig(p3, "5-3", "f03")

# ============================ PART B · Inventory ===============================================
set.seed(20)
DAYS <- 180; MU <- 120; SD <- 40; LEAD <- 6; Q <- 600
demand <- round(pmax(0, rnorm(DAYS, MU, SD)))
simulate <- function(z) {
  rop <- MU * LEAD + z * SD * sqrt(LEAD); stock <- Q + rop; arr <- c(); level <- numeric(DAYS); short <- 0
  for (t in 1:DAYS) {
    stock <- stock + Q * sum(arr == t); arr <- arr[arr != t]
    sold <- min(stock, demand[t]); short <- short + demand[t] - sold; stock <- stock - sold; level[t] <- stock
    if (stock + Q * length(arr) <= rop) arr <- c(arr, t + LEAD)
  }
  list(level = level, rop = rop, short = short) }
inv <- bind_rows(lapply(c(0, 1.65), function(z) { s <- simulate(z)
  tibble(day = 1:DAYS, level = s$level, rop = s$rop,
         policy = sprintf("%s: %d stock-out days, %.0f cases lost, average stock %.0f",
                          ifelse(z == 0, "No safety stock", "Safety stock for 95% service (z = 1.65)"), sum(s$level == 0), s$short, mean(s$level))) }))
p4 <- ggplot(inv, aes(day, level)) + geom_area(fill = tdbg[["teal"]], alpha = 0.35) + geom_line(colour = tdbg[["teal"]]) +
  geom_hline(aes(yintercept = rop), linetype = 2, colour = tdbg[["gold"]]) +
  geom_point(data = filter(inv, level == 0), colour = tdbg[["rust"]], size = 2) +
  facet_wrap(~policy, ncol = 1) + labs(title = "Inventory: a little safety stock prevents most stock-outs", subtitle = "Dashed line = reorder point", x = "Day", y = "Cases in stock") + theme_tdbg()
save_fig(p4, "5-3", "f04", height = 6.2)

# ============================ PART C · People analytics & fairness ===============================
h <- read_csv("data/hr_employees.csv", show_col_types = FALSE) |> mutate(log_salary = log(monthly_salary_naira))
FEATS <- c("age", "tenure_years", "log_salary", "engagement_score", "overtime", "years_since_promotion", "commute_minutes", "manager_rating")
set.seed(20)
idx <- unlist(lapply(split(seq_len(nrow(h)), h$attrited), function(i) sample(i, round(0.7 * length(i)))))
tr <- h[idx, ]; te <- h[-idx, ]
mu <- sapply(tr[FEATS], mean); sdv <- sapply(tr[FEATS], sd)
std <- function(d) { d[FEATS] <- sweep(sweep(as.matrix(d[FEATS]), 2, mu), 2, sdv, "/"); d }
trs <- std(tr); tes <- std(te)
fml <- as.formula(paste("attrited ~", paste(FEATS, collapse = " + "), "+ department"))     # NOTE: gender is NOT a model input
lg <- glm(fml, data = trs, family = binomial)
te$p <- predict(lg, tes, type = "response")
cat(sprintf("attrition AUC %.3f\n", auc(te$attrited, te$p, quiet = TRUE)))

# --- F05 · Attrition drivers -----------------------------------------------------------------------
LAB <- c(engagement_score = "Engagement score", manager_rating = "Manager rating", overtime = "Works overtime", years_since_promotion = "Years since promotion",
         commute_minutes = "Commute (minutes)", log_salary = "Salary (log)", tenure_years = "Tenure (years)", age = "Age")
orr <- tibble(var = names(LAB), label = LAB, or = exp(coef(lg)[names(LAB)]))
p5 <- ggplot(orr, aes(or, reorder(label, or))) +
  geom_segment(aes(x = 1, xend = or, yend = reorder(label, or), colour = or > 1), linewidth = 9) +
  geom_vline(xintercept = 1, colour = tdbg[["navy"]]) + geom_text(aes(label = sprintf("%.2f", or), hjust = ifelse(or > 1, -0.3, 1.3)), size = 3.4) +
  scale_colour_manual(values = c(`TRUE` = tdbg[["rust"]], `FALSE` = tdbg[["teal"]]), guide = "none") +
  coord_cartesian(xlim = c(0.45, 1.4)) +
  labs(title = "Attrition drivers: odds ratio for a one-standard-deviation increase", x = "Odds ratio (> 1 raises the chance of leaving; < 1 lowers it)", y = NULL) + theme_tdbg()
save_fig(p5, "5-3", "f05")

# --- F06 · Fairness audit by gender --------------------------------------------------------------
te$flag <- te$p >= quantile(te$p, 0.8)
aud <- te |> mutate(gender = ifelse(gender == "F", "Women", "Men")) |> group_by(gender) |>
  summarise(`Selection rate\n(% flagged)` = 100 * mean(flag), `True positive rate\n(% of leavers flagged)` = 100 * mean(flag[attrited == 1]),
            `False positive rate\n(% of stayers flagged)` = 100 * mean(flag[attrited == 0]), `Actual attrition\n(%)` = 100 * mean(attrited))
print(aud)
p6 <- aud |> pivot_longer(-gender) |> mutate(name = factor(name, names(aud)[-1])) |> ggplot(aes(name, value, fill = gender)) +
  geom_col(position = position_dodge(0.8), width = 0.75) + geom_text(aes(label = sprintf("%.0f%%", value)), position = position_dodge(0.8), vjust = -0.4, size = 3.4) +
  scale_fill_manual(values = c(Men = tdbg[["slate"]], Women = tdbg[["gold"]]), name = NULL) +
  labs(title = "Fairness audit: gender is not an input, yet women are flagged more often", x = NULL, y = "%") + theme_tdbg()
save_fig(p6, "5-3", "f06")

# --- F07 · Expected cost of attrition ----------------------------------------------------------------
h$p <- predict(lg, std(h), type = "response")
dc <- h |> group_by(department) |> summarise(staff = n(), leavers = sum(p), cost = sum(p * monthly_salary_naira * 6))
p7 <- ggplot(dc, aes(cost / 1e6, reorder(department, cost))) + geom_col(fill = tdbg[["teal"]]) +
  geom_text(aes(label = sprintf("₦%.0fm · %.0f expected leavers of %d", cost / 1e6, leavers, staff)), hjust = -0.05, size = 3.4) +
  coord_cartesian(xlim = c(0, max(dc$cost) / 1e6 * 1.55)) +
  labs(title = "Expected cost of attrition next year by department", subtitle = "Replacing an employee ≈ 6 months' salary", x = "₦ million", y = NULL) + theme_tdbg()
save_fig(p7, "5-3", "f07")
message("Session 5.3 figures saved.")
