# =============================================================================
# TDBG · Session 2.4 · Data Visualisation & Storytelling for Business
# Replication script — regenerates every chart in the Session 2.4 deck (R)
# Data: data/telecom_monthly_kpis.csv
# =============================================================================
source("R/theme_tdbg.R")
suppressPackageStartupMessages({ library(dplyr); library(readr); library(tidyr); library(patchwork) })
k <- read_csv("data/telecom_monthly_kpis.csv", show_col_types = FALSE) |>
  mutate(date = as.Date(paste0(month, "-01")))
regions <- c("Lagos", "North-West", "South-South", "South-East", "North-Central")
rev25 <- k |> filter(substr(month, 1, 4) == "2025") |> group_by(region) |> summarise(rev = sum(revenue_bn_naira))

# --- F01 · Chart chooser ------------------------------------------------------------------
small <- theme_tdbg(10)
g1 <- ggplot(rev25, aes(rev, reorder(region, rev))) + geom_col(fill = tdbg[["teal"]]) + labs(title = "Compare categories → bar", x = NULL, y = NULL) + small
g2 <- ggplot(filter(k, region == "Lagos"), aes(date, revenue_bn_naira)) + geom_line(colour = tdbg[["teal"]], linewidth = 1) + labs(title = "Change over time → line", x = NULL, y = NULL) + small
g3 <- ggplot(k, aes(network_uptime_pct, nps)) + geom_point(colour = tdbg[["teal"]], alpha = .7) + labs(title = "Relationship → scatter", x = NULL, y = NULL) + small
g4 <- ggplot(k, aes(arpu_naira)) + geom_histogram(bins = 20, fill = tdbg[["teal"]], colour = "white") + labs(title = "Distribution → histogram", x = NULL, y = NULL) + small
g5 <- k |> filter(month == "2025-12") |> transmute(region, Data = data_revenue_share, `Voice & other` = 1 - data_revenue_share) |>
  pivot_longer(-region) |> ggplot(aes(value, region, fill = name)) + geom_col() +
  scale_fill_manual(values = c(Data = tdbg[["teal"]], `Voice & other` = tdbg[["grid"]]), name = NULL) +
  labs(title = "Part-to-whole → stacked bar", x = NULL, y = NULL) + small
g6 <- ggplot(k, aes(date, factor(region, levels = rev(regions)), fill = churn_rate_pct)) + geom_tile() +
  scale_fill_distiller(palette = "YlOrRd", direction = 1, guide = "none") + labs(title = "Pattern in a grid → heat map", x = NULL, y = NULL) + small
save_fig((g1 | g2 | g3) / (g4 | g5 | g6), "2-4", "f01", width = 13, height = 7)

# --- F02 · Cluttered pie (what NOT to do) -------------------------------------------------------
p2 <- ggplot(rev25, aes("", rev, fill = region)) + geom_col(width = 1, colour = "grey40") +
  coord_polar(theta = "y") + geom_text(aes(label = sprintf("%.1f%%", 100 * rev / sum(rev))), position = position_stack(vjust = .5)) +
  scale_fill_manual(values = c("#E41A1C", "#377EB8", "#4DAF4A", "#984EA3", "#FF7F00")) +
  labs(title = "REVENUE BY REGION FY2025 (₦ BN) !!!", x = NULL, y = NULL) +
  theme_void(14) + theme(plot.title = element_text(colour = "red", face = "bold", hjust = .5))
save_fig(p2, "2-4", "f02")

# --- F03 · Decluttered ---------------------------------------------------------------------------
p3 <- ggplot(rev25, aes(rev, reorder(region, rev), fill = region == "Lagos")) + geom_col() +
  geom_text(aes(label = sprintf("₦%.0fbn", rev)), hjust = -0.1, size = 4.5) +
  scale_fill_manual(values = c(`TRUE` = tdbg[["gold"]], `FALSE` = "#B8C7D3"), guide = "none") +
  scale_x_continuous(expand = expansion(mult = c(0, .12))) +
  labs(title = "Lagos earns a third of revenue — more than the next two regions combined", x = NULL, y = NULL) +
  theme_tdbg() + theme(axis.text.x = element_blank(), panel.grid = element_blank(), axis.line = element_blank())
save_fig(p3, "2-4", "f03")

# --- F04 · Spaghetti ------------------------------------------------------------------------------
p4 <- ggplot(k, aes(date, churn_rate_pct, colour = region)) + geom_line(linewidth = 1) + scale_colour_tdbg(name = NULL) +
  labs(title = "Monthly churn rate by region", x = NULL, y = "Churn rate (%)") + theme_tdbg()
save_fig(p4, "2-4", "f04")

# --- F05 · Focus ----------------------------------------------------------------------------------
p5 <- ggplot(k, aes(date, churn_rate_pct, group = region)) +
  geom_line(data = filter(k, region != "North-West"), colour = "#C9D2DB", linewidth = .8) +
  geom_line(data = filter(k, region == "North-West"), colour = tdbg[["rust"]], linewidth = 1.6) +
  geom_vline(xintercept = as.Date("2025-05-01"), linetype = "dotted", colour = tdbg[["slate"]]) +
  annotate("text", x = as.Date("2025-04-20"), y = 2.75, label = "May 2025: network\nuptime starts slipping", hjust = 1, colour = tdbg[["slate"]]) +
  annotate("text", x = as.Date("2025-06-01"), y = 2.45, label = "North-West", hjust = 0, colour = tdbg[["rust"]], fontface = "bold") +
  annotate("text", x = as.Date("2025-08-01"), y = 1.83, label = "Other regions", hjust = 0, colour = tdbg[["slate"]]) +
  labs(title = "North-West churn broke away from the pack in May 2025", x = NULL, y = "Monthly churn rate (%)") + theme_tdbg()
save_fig(p5, "2-4", "f05")

# --- F06 · Truncated vs honest axis -----------------------------------------------------------------
nps <- k |> filter(month %in% c("2025-04", "2025-12")) |> group_by(month) |> summarise(nps = mean(nps)) |>
  mutate(lab = ifelse(month == "2025-04", "Apr 2025", "Dec 2025"))
b6 <- function(lims, col, ttl) ggplot(nps, aes(lab, nps)) + geom_col(fill = c(tdbg[["slate"]], col)) +
  geom_text(aes(label = sprintf("%.1f", nps)), vjust = -0.4) + coord_cartesian(ylim = lims) +
  labs(title = ttl, x = NULL, y = NULL) + theme_tdbg(11) + theme(plot.title = element_text(colour = col))
p6 <- b6(c(37.2, 40.7), tdbg[["rust"]], "Misleading: axis starts near the data") | b6(c(0, 60), tdbg[["teal"]], "Honest: bars start at zero")
save_fig(p6 + plot_annotation(title = "Company-wide NPS — same numbers, two stories", theme = theme_tdbg()), "2-4", "f06", width = 11, height = 4.8)

# --- F07 · Small multiples ---------------------------------------------------------------------------
p7 <- ggplot(mutate(k, region = factor(region, levels = regions)), aes(date, nps, colour = region == "North-West")) +
  geom_line(linewidth = 1) + facet_wrap(~region, nrow = 1) +
  scale_colour_manual(values = c(`TRUE` = tdbg[["rust"]], `FALSE` = tdbg[["teal"]]), guide = "none") +
  labs(title = "Small multiples: one chart per region, same scale — the outlier jumps out", x = NULL, y = "NPS") +
  theme_tdbg(11) + theme(axis.text.x = element_blank())
save_fig(p7, "2-4", "f07", width = 13, height = 3.6)

# --- F08 · One-page dashboard -------------------------------------------------------------------------
tot <- k |> group_by(date) |> summarise(rev = sum(revenue_bn_naira))
focus <- function(var, ttl) ggplot(k, aes(date, .data[[var]], group = region)) +
  geom_line(data = filter(k, region != "North-West"), colour = "#C9D2DB") +
  geom_line(data = filter(k, region == "North-West"), colour = tdbg[["rust"]], linewidth = 1.2) +
  labs(title = ttl, x = NULL, y = NULL) + theme_tdbg(10)
dec <- filter(k, month == "2025-12")
kpi <- ggplot() + xlim(0, 4) + ylim(0, 1) + theme_void() +
  annotate("text", x = 0:3 + .05, y = .75, hjust = 0, size = 3.5, colour = tdbg[["slate"]], fontface = "bold",
           label = c("REVENUE (DEC)", "SUBSCRIBERS", "ARPU", "CHURN — NORTH-WEST")) +
  annotate("text", x = 0:3 + .05, y = .35, hjust = 0, size = 8, fontface = "bold", colour = c(rep(tdbg[["teal"]], 3), tdbg[["rust"]]),
           label = c(sprintf("₦%.1fbn", sum(dec$revenue_bn_naira)), sprintf("%.1fm", sum(dec$subscribers_m)),
                     sprintf("₦%s", format(round(sum(dec$revenue_bn_naira) * 1e9 / (sum(dec$subscribers_m) * 1e6)), big.mark = ",")),
                     sprintf("%.1f%%", dec$churn_rate_pct[dec$region == "North-West"])))
trend <- ggplot(tot, aes(date, rev)) + geom_line(colour = tdbg[["teal"]], linewidth = 1.2) +
  labs(title = "Revenue is growing steadily (₦bn per month)", x = NULL, y = NULL) + theme_tdbg(10)
p8 <- kpi / (trend | (focus("churn_rate_pct", "…but North-West churn is rising (%)") / focus("network_uptime_pct", "…as its network uptime slips (%)"))) +
  plot_layout(heights = c(1, 4))
save_fig(p8, "2-4", "f08", width = 13, height = 7.2)
