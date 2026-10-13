# =============================================================================
# TDBG · Session 3.1 · A/B Testing & Business Experimentation
# Replication script — regenerates every chart in the Session 3.1 deck (R)
# Data: data/fintech_onboarding_ab.csv
# Note: F03 (peeking) is a simulation; R and Python draw different random numbers.
# =============================================================================
source("R/theme_tdbg.R")
suppressPackageStartupMessages({ library(dplyr); library(readr); library(tidyr); library(patchwork) })
d <- read_csv("data/fintech_onboarding_ab.csv", show_col_types = FALSE)
lab <- c(A_control = "A · current flow", B_simplified = "B · simplified flow")

# --- F01 · Completion with 95% CIs ---------------------------------------------------
g <- d |> group_by(variant) |> summarise(x = sum(completed_onboarding), n = n()) |>
  mutate(p = x / n, lo = p - 1.96 * sqrt(p * (1 - p) / n), hi = p + 1.96 * sqrt(p * (1 - p) / n))
p1 <- ggplot(g, aes(lab[variant], p, fill = variant)) + geom_col(width = .55) +
  geom_errorbar(aes(ymin = lo, ymax = hi), width = .12) +
  geom_text(aes(y = hi + .012, label = sprintf("%.1f%%\n(n=%s)", 100 * p, format(n, big.mark = ","))), size = 4.2) +
  scale_fill_manual(values = c(A_control = tdbg[["slate"]], B_simplified = tdbg[["teal"]]), guide = "none") +
  scale_y_continuous(labels = scales::percent, limits = c(0, .27)) +
  labs(title = "Simplified onboarding lifts completion by 2.3 points (95% CI +0.9 to +3.7)", x = NULL, y = "Completed onboarding") + theme_tdbg()
save_fig(p1, "3-1", "f01")

# --- F02 · Sample size vs minimum detectable lift -------------------------------------------
n_needed <- function(p1, p2, alpha = .05, power = .8) {
  za <- qnorm(1 - alpha / 2); zb <- qnorm(power); pbar <- (p1 + p2) / 2
  ((za * sqrt(2 * pbar * (1 - pbar)) + zb * sqrt(p1 * (1 - p1) + p2 * (1 - p2))) / (p2 - p1))^2
}
ss <- tibble(lift = seq(.005, .04, length.out = 80), n = n_needed(.18, .18 + lift))
pts <- tibble(lift = c(.01, .02, .03), n = n_needed(.18, .18 + lift))
p2 <- ggplot(ss, aes(100 * lift, n)) + geom_line(colour = tdbg[["teal"]], linewidth = 1.5) +
  geom_point(data = pts, colour = tdbg[["gold"]], size = 4) +
  geom_text(data = pts, aes(label = sprintf("+%.0f pt → %s per group", 100 * lift, format(round(n), big.mark = ","))), hjust = -0.1, vjust = -0.6) +
  scale_y_log10(labels = scales::comma) +
  labs(title = "Halve the lift you want to detect → need about 4× the users",
       x = "Minimum detectable lift (percentage points, from an 18% baseline)", y = "Users needed per group (log scale)") + theme_tdbg()
save_fig(p2, "3-1", "f02")
# Built-in check: power.prop.test(p1 = .18, p2 = .20, power = .8)

# --- F03 · Peeking at an A/A test -------------------------------------------------------------
set.seed(6)
ns <- seq(200, 6000, by = 200)
sims <- lapply(1:20, function(k) {
  a <- runif(6000) < .18; b <- runif(6000) < .18
  pv <- sapply(ns, function(m) { pa <- mean(a[1:m]); pb <- mean(b[1:m]); pp <- (pa + pb) / 2
    2 * (1 - pnorm(abs((pb - pa) / sqrt(2 * pp * (1 - pp) / m)))) })
  tibble(sim = k, n = ns, p = pv, hit = min(pv) < .05) })
sims <- bind_rows(sims)
p3 <- ggplot(sims, aes(n, p, group = sim, colour = hit)) + geom_line(alpha = .9) +
  geom_hline(yintercept = .05, linetype = "dashed", colour = tdbg[["navy"]]) +
  scale_y_log10() + scale_colour_manual(values = c(`TRUE` = tdbg[["rust"]], `FALSE` = "#C9D2DB"), guide = "none") +
  labs(title = sprintf("20 tests with NO real effect: %d dip below p = 0.05 if you keep peeking", sum(tapply(sims$hit, sims$sim, any))),
       x = "Users per group so far", y = "p-value (log scale)") + theme_tdbg()
save_fig(p3, "3-1", "f03")

# --- F04 · Balance check -------------------------------------------------------------------------
mix <- d |> count(variant, device) |> group_by(variant) |> mutate(share = n / sum(n))
srm <- chisq.test(table(d$variant))
p4 <- ggplot(mix, aes(device, share, fill = variant)) + geom_col(position = "dodge", width = .75) +
  geom_text(aes(label = scales::percent(share, .1)), position = position_dodge(.75), vjust = -.4, size = 3.5) +
  scale_fill_manual(values = c(A_control = tdbg[["slate"]], B_simplified = tdbg[["teal"]]), labels = lab, name = NULL) +
  scale_y_continuous(labels = scales::percent) +
  labs(title = sprintf("Balance check: device mix is the same in A and B (SRM p = %.2f)", srm$p.value), x = NULL, y = "Share of users") + theme_tdbg()
save_fig(p4, "3-1", "f04", height = 4.6)

# --- F05 · Guardrails -------------------------------------------------------------------------------
tk <- d |> group_by(variant) |> summarise(m = mean(support_tickets), h = 1.96 * sd(support_tickets) / sqrt(n()))
dp <- d |> filter(completed_onboarding == 1) |> group_by(variant) |> summarise(med = median(first_deposit_naira))
g1 <- ggplot(tk, aes(substr(variant, 1, 1), m, fill = variant)) + geom_col(width = .55) + geom_errorbar(aes(ymin = m - h, ymax = m + h), width = .1) +
  scale_fill_manual(values = c(A_control = tdbg[["slate"]], B_simplified = tdbg[["teal"]]), guide = "none") +
  labs(title = "Support tickets per user\n(guardrail: must not rise much)", x = NULL, y = NULL) + theme_tdbg(11)
g2 <- ggplot(dp, aes(substr(variant, 1, 1), med, fill = variant)) + geom_col(width = .55) +
  geom_text(aes(label = paste0("₦", format(med, big.mark = ","))), vjust = -.4) +
  scale_fill_manual(values = c(A_control = tdbg[["slate"]], B_simplified = tdbg[["teal"]]), guide = "none") + scale_y_continuous(labels = naira) +
  labs(title = "Median first deposit\n(guardrail: quality of new users)", x = NULL, y = NULL) + theme_tdbg(11)
save_fig((g1 | g2) + plot_annotation(title = "Guardrails: no meaningful harm to support load or deposit size", theme = theme_tdbg()), "3-1", "f05", width = 11, height = 4.6)

# --- F06 · Lift by device ------------------------------------------------------------------------------
lift <- function(s) { a <- s$completed_onboarding[s$variant == "A_control"]; b <- s$completed_onboarding[s$variant == "B_simplified"]
  tibble(diff = mean(b) - mean(a), se = sqrt(mean(a) * (1 - mean(a)) / length(a) + mean(b) * (1 - mean(b)) / length(b)), n = nrow(s)) }
seg <- bind_rows(d |> group_by(device) |> group_modify(~ lift(.x)) |> ungroup(), lift(d) |> mutate(device = "All users"))
p6 <- ggplot(seg, aes(100 * diff, factor(device, levels = c("Android", "Web", "iOS", "All users")), colour = device == "All users")) +
  geom_vline(xintercept = 0) +
  geom_errorbarh(aes(xmin = 100 * (diff - 1.96 * se), xmax = 100 * (diff + 1.96 * se)), height = .2, linewidth = 1.2) + geom_point(size = 4) +
  geom_text(aes(x = 6.4, label = sprintf("%+.1f pts  (n=%s)", 100 * diff, format(n, big.mark = ","))), hjust = 0, colour = tdbg[["ink"]]) +
  scale_colour_manual(values = c(`TRUE` = tdbg[["navy"]], `FALSE` = tdbg[["teal"]]), guide = "none") + xlim(-4, 9.6) +
  labs(title = "Lift by device: every interval overlaps the overall effect", x = "Lift in completion, B minus A (points, 95% CI)", y = NULL) + theme_tdbg()
save_fig(p6, "3-1", "f06")
