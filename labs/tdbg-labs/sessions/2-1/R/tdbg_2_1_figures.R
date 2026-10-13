# =============================================================================
# TDBG · Session 2.1 · The Analytics Mindset, Data Literacy & Your Toolkit
# Replication script — regenerates every chart in the Session 2.1 deck (R)
# Open tdbg-labs.Rproj in RStudio, then Source this file.
# =============================================================================
source("R/theme_tdbg.R")
suppressPackageStartupMessages({ library(dplyr); library(readr) })

tx <- read_csv("data/retail_transactions.csv", show_col_types = FALSE)

# --- Fig S2.1-F01 · Basket value per receipt -----------------------------------
md <- median(tx$basket_naira); mn <- mean(tx$basket_naira)
p1 <- ggplot(tx, aes(basket_naira)) +
  geom_histogram(bins = 50, fill = tdbg[["teal"]], colour = "white") +
  geom_vline(xintercept = md, colour = tdbg[["gold"]], linewidth = 1.2) +
  geom_vline(xintercept = mn, colour = tdbg[["rust"]], linewidth = 1.2, linetype = "dashed") +
  annotate("text", x = md, y = Inf, vjust = 2, hjust = -0.05, colour = tdbg[["gold"]],
           label = paste0("Median ", naira(md))) +
  annotate("text", x = mn, y = Inf, vjust = 4, hjust = -0.05, colour = tdbg[["rust"]],
           label = paste0("Mean ", naira(mn))) +
  scale_x_continuous(labels = naira) +
  labs(title = "2,000 receipts: most baskets are small, a few are very large",
       x = "Basket value per receipt", y = "Number of receipts") +
  theme_tdbg()
save_fig(p1, "2-1", "f01")

# --- Fig S2.1-F02 · Revenue by category ------------------------------------------
rev <- tx |> group_by(category) |> summarise(rev = sum(basket_naira) / 1e6) |>
  mutate(top = rev == max(rev))
p2 <- ggplot(rev, aes(rev, reorder(category, rev), fill = top)) +
  geom_col() +
  geom_text(aes(label = sprintf("₦%.1fm", rev)), hjust = -0.1, colour = tdbg[["ink"]]) +
  scale_fill_manual(values = c(`FALSE` = tdbg[["teal"]], `TRUE` = tdbg[["gold"]]), guide = "none") +
  scale_x_continuous(expand = expansion(mult = c(0, 0.12))) +
  labs(title = "Descriptive: where did 2025 revenue come from?", x = "Revenue (₦ million)", y = NULL) +
  theme_tdbg()
save_fig(p2, "2-1", "f02")

# --- Fig S2.1-F03 · Monthly revenue trend ----------------------------------------
monthly <- tx |> mutate(month = format(as.Date(date), "%m")) |>
  group_by(month) |> summarise(rev = sum(basket_naira) / 1e6)
p3 <- ggplot(monthly, aes(month, rev, group = 1)) +
  geom_line(colour = tdbg[["teal"]], linewidth = 1.2) + geom_point(colour = tdbg[["teal"]], size = 2.5) +
  annotate("text", x = 8.5, y = max(monthly$rev), label = "December festive peak", colour = tdbg[["navy"]]) +
  labs(title = "Diagnostic question: why does December jump?", x = "Month (2025)", y = "Revenue (₦ million)") +
  theme_tdbg()
save_fig(p3, "2-1", "f03")

# --- Fig S2.1-F04 · Shoppers by hour of day --------------------------------------
by_hour <- tx |> count(hour) |> mutate(peak = hour %in% c(16, 17))
p4 <- ggplot(by_hour, aes(factor(hour), n, fill = peak)) + geom_col() +
  scale_fill_manual(values = c(`FALSE` = tdbg[["teal"]], `TRUE` = tdbg[["gold"]]), guide = "none") +
  labs(title = "Operational question: when should we roster more cashiers?", x = "Hour of day", y = "Receipts") +
  theme_tdbg()
save_fig(p4, "2-1", "f04")

# --- Fig S2.1-F05 · Loyalty members vs others -------------------------------------
med <- tx |> group_by(loyalty_member) |> summarise(m = median(basket_naira)) |>
  mutate(lab = factor(ifelse(loyalty_member == "Yes", "Loyalty member", "Not a member"),
                      levels = c("Not a member", "Loyalty member")))
p5 <- ggplot(med, aes(lab, m, fill = loyalty_member)) + geom_col(width = 0.55) +
  geom_text(aes(label = paste0("₦", format(round(m), big.mark = ","))), vjust = -0.5, size = 5) +
  scale_fill_manual(values = c(No = tdbg[["slate"]], Yes = tdbg[["gold"]]), guide = "none") +
  scale_y_continuous(labels = naira, expand = expansion(mult = c(0, 0.1))) +
  labs(title = "Typical (median) basket: loyalty members spend more — but why?", x = NULL, y = "Median basket value") +
  theme_tdbg()
save_fig(p5, "2-1", "f05")
