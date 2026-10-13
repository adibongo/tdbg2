# =============================================================================
# TDBG · Session 5.2 LAB · Who are our best customers, and which transfers are fraud? (R)
# Data: data/customer_orders.csv, data/mobile_money_txns.csv
# install.packages(c("dplyr", "readr", "lubridate", "pROC"))   # once
# =============================================================================
library(dplyr); library(readr); library(lubridate); library(pROC)

# ---- PART A · RFM segmentation -----------------------------------------------------------------------
o <- read_csv("data/customer_orders.csv", show_col_types = FALSE)
snap <- max(o$order_date) + 1                                        # treat the day after the last order as 'today'
rfm <- o |> group_by(customer_id) |>
  summarise(recency = as.numeric(snap - max(order_date)), frequency = n(), monetary = sum(order_value_naira))
summary(rfm)
rfm <- rfm |> mutate(r = 6 - ntile(recency, 5), f = ntile(frequency, 5), m = ntile(monetary, 5),   # 5 = best
                     segment = case_when(r >= 4 & f >= 4 ~ "Champions", r >= 3 & f >= 3 ~ "Loyal",
                                         r >= 4 & f <= 2 ~ "New / promising", r <= 2 & f >= 3 ~ "At risk",
                                         r <= 2 & f <= 2 ~ "Lost", TRUE ~ "Need attention"))
rfm |> group_by(segment) |> summarise(customers = n(), revenue_share = sum(monetary) / sum(rfm$monetary)) |> arrange(desc(revenue_share))

# Pareto: share of revenue from the top 20% of customers
rfm |> arrange(desc(monetary)) |> slice_head(prop = 0.2) |> summarise(top20_share = sum(monetary) / sum(rfm$monetary))

# ---- PART B · Customer lifetime value -------------------------------------------------------------------
c24 <- unique(o$customer_id[year(o$order_date) == 2024]); c25 <- unique(o$customer_id[year(o$order_date) == 2025])
retention <- length(intersect(c24, c25)) / length(c24); retention     # share of 2024 customers who came back in 2025
annual_spend <- o |> filter(year(order_date) == 2025) |> group_by(customer_id) |> summarise(s = sum(order_value_naira)) |> pull(s) |> mean()
margin <- 0.25 * annual_spend                                        # assume a 25% gross margin
d <- 0.20                                                            # discount rate: money today is worth more
clv <- function(r) margin * (1 + d) / (1 + d - r)
c(today = clv(retention), plus_10_points = clv(retention + 0.10))

# ---- PART C · Fraud detection --------------------------------------------------------------------------
m <- read_csv("data/mobile_money_txns.csv", show_col_types = FALSE) |>
  mutate(night = as.integer(hour <= 4 | hour >= 23), log_amount = log(amount_naira))
mean(m$is_fraud)                                                     # about 1.2%: a rare event
1 - mean(m$is_fraud)                                                 # 'accuracy' of a model that says 'never fraud'!
m |> group_by(new_device) |> summarise(fraud_rate = mean(is_fraud))
set.seed(19); idx <- sample(nrow(m), 0.7 * nrow(m)); tr <- m[idx, ]; te <- m[-idx, ]
fit <- glm(is_fraud ~ log_amount + night + new_device + new_payee + txns_last_hour + distance_from_home_km, data = tr, family = binomial)
summary(fit)$coefficients |> round(3)
te$p <- predict(fit, te, type = "response")
auc(te$is_fraud, te$p)

# Choose a threshold by cost: ₦1,500 to review an alert; a missed fraud loses the transfer amount
cost_at <- function(t) sum(te$p >= t) * 1500 + sum(te$amount_naira[te$p < t & te$is_fraud == 1])
th <- seq(0.01, 0.5, by = 0.01)
best <- th[which.min(sapply(th, cost_at))]
c(best_threshold = best, alerts = sum(te$p >= best), cost = cost_at(best), no_screening = sum(te$amount_naira[te$is_fraud == 1]))
table(flagged = te$p >= best, fraud = te$is_fraud)

# ---- YOUR TURN ------------------------------------------------------------------------------------------
# (a) Write one marketing action for 'Champions' and one for 'At risk'. Which is worth more money?
# (b) What happens to CLV if the gross margin is 15% instead of 25%? If retention falls to 55%?
# (c) Double the review cost to ₦3,000. How does the best threshold and number of alerts change? Why?
