# =============================================================================
# TDBG · Session 2.3 · Exploratory Data Analysis
# Replication script — regenerates every chart in the Session 2.3 deck (R)
# Data: data/microfinance_loans_raw.csv — a deliberately messy loan book
# =============================================================================
source("R/theme_tdbg.R")
suppressPackageStartupMessages({ library(dplyr); library(readr); library(tidyr) })
raw <- read_csv("data/microfinance_loans_raw.csv", show_col_types = FALSE)

# --- F01 · Missing values per column ---------------------------------------------
miss <- tibble(col = names(raw), pct = 100 * colMeans(is.na(raw)))
p1 <- ggplot(miss, aes(pct, reorder(col, pct), fill = pct > 0)) + geom_col() +
  geom_text(aes(label = sprintf("%.1f%%", pct)), hjust = -0.15, size = 3.5) +
  scale_fill_manual(values = c(`TRUE` = tdbg[["rust"]], `FALSE` = tdbg[["grid"]]), guide = "none") +
  labs(title = "Completeness check: income is missing for 6% of loans", x = "% of rows missing", y = NULL) + theme_tdbg()
save_fig(p1, "2-3", "f01")

# --- F02 · Loan amounts on a log scale -----------------------------------------------
p2 <- ggplot(raw, aes(loan_amount_naira)) +
  geom_histogram(bins = 60, fill = tdbg[["teal"]], colour = "white") +
  scale_x_log10(labels = naira) +
  annotate("text", x = 2.5e6, y = 60, label = "₦9.45m on a ₦320k monthly income —\n30× income. An extra zero?",
           colour = tdbg[["rust"]], hjust = 0.5) +
  labs(title = "Loan amounts (log scale): the long tail hides typing errors", x = "Loan amount (log scale)", y = "Loans") + theme_tdbg()
save_fig(p2, "2-3", "f02")

# --- F03 · Impossible ages ------------------------------------------------------------
p3 <- raw |> filter(!is.na(borrower_age)) |> ggplot(aes(borrower_age, 1)) +
  geom_boxplot(fill = "#D6E6EF", colour = tdbg[["teal"]], outlier.colour = tdbg[["rust"]], outlier.size = 3, width = 0.4) +
  annotate("text", x = 118, y = 1.35, label = "Age 140 — impossible.\nA validity error, not an outlier.", colour = tdbg[["rust"]]) +
  coord_cartesian(ylim = c(0.6, 1.5)) +
  labs(title = "Validity check: borrower age", x = "Age (years)", y = NULL) + theme_tdbg() + theme(axis.text.y = element_blank())
save_fig(p3, "2-3", "f03", height = 4.2)

# --- F04 · Inconsistent branch labels --------------------------------------------------
lab <- raw |> count(branch, sort = TRUE) |>
  mutate(messy = branch != tools::toTitleCase(trimws(branch)) | branch != trimws(branch),
         shown = paste0("'", branch, "'"))
p4 <- ggplot(lab, aes(reorder(shown, -n), n, fill = messy)) + geom_col() +
  scale_fill_manual(values = c(`TRUE` = tdbg[["rust"]], `FALSE` = tdbg[["teal"]]), guide = "none") +
  labs(title = "Consistency check: 'Ikeja' and 'ikeja ' are counted as different branches", x = NULL, y = "Loans") +
  theme_tdbg() + theme(axis.text.x = element_text(angle = 40, hjust = 1))
save_fig(p4, "2-3", "f04")

# --- Clean -------------------------------------------------------------------------------
clean <- raw |> distinct() |>
  mutate(branch = tools::toTitleCase(trimws(branch)),
         borrower_age = ifelse(borrower_age > 100, NA, borrower_age),
         ratio = loan_amount_naira / monthly_income_naira) |>
  filter(is.na(ratio) | ratio <= 10)          # entry errors: loan > 10x monthly income

# --- F05 · Income vs loan size ---------------------------------------------------------
p5 <- clean |> filter(!is.na(monthly_income_naira)) |>
  mutate(status = ifelse(defaulted == 1, "Defaulted", "Repaid")) |>
  ggplot(aes(monthly_income_naira, loan_amount_naira, colour = status)) +
  geom_point(alpha = 0.6, size = 1.6) +
  scale_x_log10(labels = naira) + scale_y_log10(labels = naira) +
  scale_colour_manual(values = c(Repaid = tdbg[["sky"]], Defaulted = tdbg[["rust"]]), name = NULL) +
  labs(title = "Bigger incomes, bigger loans — and defaults are scattered throughout",
       x = "Monthly income (log)", y = "Loan amount (log)") + theme_tdbg()
save_fig(p5, "2-3", "f05")

# --- F06 · Default rate by age band ------------------------------------------------------
rate <- clean |> filter(!is.na(borrower_age)) |>
  mutate(band = cut(borrower_age, c(18, 25, 35, 45, 55, 70), labels = c("18–25", "26–35", "36–45", "46–55", "56+"))) |>
  group_by(band) |> summarise(rate = mean(defaulted), n = n())
p6 <- ggplot(rate, aes(band, rate, fill = band == "18–25")) + geom_col() +
  geom_text(aes(label = sprintf("%.0f%%\n(n=%d)", 100 * rate, n)), vjust = -0.2, size = 3.6) +
  geom_hline(yintercept = mean(clean$defaulted), linetype = "dashed", colour = tdbg[["slate"]]) +
  scale_fill_manual(values = c(`TRUE` = tdbg[["gold"]], `FALSE` = tdbg[["teal"]]), guide = "none") +
  scale_y_continuous(labels = scales::percent, limits = c(0, 0.21)) +
  labs(title = "Hypothesis from EDA: younger borrowers default more often", x = "Borrower age band", y = "Default rate") + theme_tdbg()
save_fig(p6, "2-3", "f06")

# --- F07 · Correlation heat map ------------------------------------------------------------
num <- clean |> mutate(repay_income = loan_amount_naira / term_months / monthly_income_naira) |>
  select(age = borrower_age, income = monthly_income_naira, `loan amt` = loan_amount_naira, term = term_months,
         `rate %` = monthly_rate_pct, `prior loans` = prior_loans, `repay/income` = repay_income, defaulted)
cm <- cor(num, use = "pairwise.complete.obs")
cm_long <- as.data.frame(as.table(cm))
p7 <- ggplot(cm_long, aes(Var2, Var1, fill = Freq)) + geom_tile(colour = "white") +
  geom_text(aes(label = sprintf("%.2f", Freq), colour = abs(Freq) > 0.5), size = 3.4) +
  scale_colour_manual(values = c(`TRUE` = "white", `FALSE` = tdbg[["ink"]]), guide = "none") +
  scale_fill_gradient2(low = "#2166AC", mid = "white", high = "#B2182B", limits = c(-1, 1), name = NULL) +
  scale_y_discrete(limits = rev) +
  labs(title = "Correlations: strong links among inputs, weak single links to default", x = NULL, y = NULL) +
  theme_tdbg() + theme(axis.text.x = element_text(angle = 40, hjust = 1), panel.grid = element_blank())
save_fig(p7, "2-3", "f07", width = 9.5, height = 7)

# --- F08 · Default by prior loans --------------------------------------------------------------
pr <- clean |> mutate(prior = ifelse(prior_loans >= 4, "4+", as.character(prior_loans))) |>
  group_by(prior) |> summarise(rate = mean(defaulted), n = n())
p8 <- ggplot(pr, aes(prior, rate)) + geom_col(fill = tdbg[["teal"]]) +
  geom_text(aes(label = sprintf("%.0f%%\n(n=%d)", 100 * rate, n)), vjust = -0.2, size = 3.6) +
  scale_y_continuous(labels = scales::percent, limits = c(0, 0.17)) +
  labs(title = "Repeat borrowers default a little less — but watch the small groups", x = "Prior loans with us", y = "Default rate") + theme_tdbg()
save_fig(p8, "2-3", "f08")
