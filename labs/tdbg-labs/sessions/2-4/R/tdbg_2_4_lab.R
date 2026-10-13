# =============================================================================
# TDBG · Session 2.4 LAB · From cluttered chart to executive story (R)
# Data: data/telecom_monthly_kpis.csv — monthly KPIs for 5 regions, 2024–2025
# =============================================================================
library(dplyr); library(readr); library(ggplot2)
k <- read_csv("data/telecom_monthly_kpis.csv", show_col_types = FALSE) |>
  mutate(date = as.Date(paste0(month, "-01")))

# ---- 1. Ask the question first ------------------------------------------------
# "Which region needs the CEO's attention this month, and why?"

# ---- 2. Default chart: every line the same weight --------------------------------
ggplot(k, aes(date, churn_rate_pct, colour = region)) + geom_line()

# ---- 3. Declutter + focus: grey the context, colour the story ---------------------
k <- k |> mutate(focus = region == "North-West")
ggplot(k, aes(date, churn_rate_pct, group = region, colour = focus, linewidth = focus)) +
  geom_line() +
  scale_colour_manual(values = c(`TRUE` = "#B5541A", `FALSE` = "grey80"), guide = "none") +
  scale_linewidth_manual(values = c(`TRUE` = 1.5, `FALSE` = 0.6), guide = "none") +
  labs(title = "North-West churn broke away from the pack in May 2025",   # title = the message
       x = NULL, y = "Monthly churn rate (%)") +
  theme_minimal()

# ---- 4. Check the explanation: is uptime the driver? --------------------------------
k |> filter(region == "North-West") |>
  ggplot(aes(network_uptime_pct, churn_rate_pct)) + geom_point() + geom_smooth(method = "lm", se = FALSE)
cor(k$network_uptime_pct[k$focus], k$churn_rate_pct[k$focus])

# ---- 5. Bar chart done right: sorted, labelled, one highlight --------------------------
rev25 <- k |> filter(substr(month, 1, 4) == "2025") |> group_by(region) |> summarise(rev = sum(revenue_bn_naira))
ggplot(rev25, aes(rev, reorder(region, rev))) + geom_col(fill = "#0B5E82") +
  geom_text(aes(label = round(rev)), hjust = -0.2) + labs(title = "FY2025 revenue by region (₦bn)", x = NULL, y = NULL)

# ---- YOUR TURN -------------------------------------------------------------------------------
# (a) Build a small-multiples chart of NPS by region with facet_wrap(~region).
# (b) Write a one-slide story: headline (the message), one chart, three bullet points, one ask.
# (c) The full replication of the deck's dashboard is in tdbg_2_4_figures.R (Fig S2.4-F08).
