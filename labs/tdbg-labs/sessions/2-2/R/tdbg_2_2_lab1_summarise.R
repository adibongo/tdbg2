# =========================================================================
# LAB 1: Measures of Central Tendency and Spread
# TDBG - Session 2.2 (Statistical Foundations for Decision-Making)
# Dataset: retail_basket_sizes.csv (Lagos supermarket chain, n = 400 receipts)
# =========================================================================
#
# LEARNING GOAL: Compute and interpret mean, median, mode, sd, IQR, and range
# for a right-skewed business variable (basket size in Naira), and visualize
# the shape of the distribution with a histogram and boxplot.
#
# FACILITATOR NOTE: Talk through why mean != median here (right skew from a
# few large "stock-up" baskets), and why the mode is a weak summary for
# continuous money data (many close-but-not-identical values).

# ---- 0. Setup ------------------------------------------------------------
# Point this at wherever you saved the CSV. In class, keep the data file in
# the same folder as this script and use a relative path, e.g. "retail_basket_sizes.csv"
data_path <- "data/retail_basket_sizes.csv"   # from the project root (open tdbg-labs.Rproj)
basket <- read.csv(data_path, stringsAsFactors = FALSE)

# Quick look at the data structure - always do this first
str(basket)
head(basket)

# The variable of interest for this lab: basket_size_naira
x <- basket$basket_size_naira
n <- length(x)

# ---- 1. Mean --------------------------------------------------------------
# The arithmetic average. Sensitive to extreme values (outliers pull it up
# in a right-skewed distribution like retail spend).
mean_x <- mean(x)

# ---- 2. Median ------------------------------------------------------------
# The middle value when data is sorted. Robust to outliers - a better
# "typical basket" summary than the mean when data is skewed.
median_x <- median(x)

# ---- 3. Mode --------------------------------------------------------------
# R has NO built-in mode() function (mode() in base R checks the storage
# type of an object, not the statistical mode!). We write our own helper.
get_mode <- function(v) {
  freq_table <- table(v)                     # frequency count of each value
  mode_value <- as.numeric(names(freq_table)[which.max(freq_table)])
  mode_count <- max(freq_table)
  list(value = mode_value, count = mode_count)
}
mode_result <- get_mode(x)

# NOTE FOR FACILITATOR: with continuous currency data, the "mode" is often
# just the most-repeated rounded value and isn't very meaningful on its own -
# a good teaching moment on when mode is/isn't a useful statistic
# (much more useful for categorical data, e.g. most common payment_method).

# ---- 4. Spread: standard deviation, IQR, range ----------------------------
sd_x <- sd(x)                    # sample standard deviation (uses n-1 denominator)
var_x <- var(x)                  # variance = sd^2

q <- quantile(x, probs = c(0.25, 0.5, 0.75))  # Q1, median, Q3
iqr_x <- IQR(x)                                # Q3 - Q1, robust spread measure
range_x <- range(x)                            # c(min, max)
range_width <- diff(range_x)                   # max - min

# ---- 5. Also worth showing: most common payment method (categorical mode) --
payment_mode <- get_mode(as.numeric(as.factor(basket$payment_method)))
payment_levels <- levels(as.factor(basket$payment_method))
most_common_payment <- payment_levels[payment_mode$value]

# ---- 6. Clean printed summary ---------------------------------------------
cat("\n================ RETAIL BASKET SIZE SUMMARY (N =", n, ") ================\n")
cat(sprintf("Mean basket size      : N%s\n", format(round(mean_x, 2), big.mark = ",")))
cat(sprintf("Median basket size    : N%s\n", format(round(median_x, 2), big.mark = ",")))
cat(sprintf("Mode basket size      : N%s (appears %d times)\n", mode_result$value, mode_result$count))
cat(sprintf("Standard deviation    : N%s\n", format(round(sd_x, 2), big.mark = ",")))
cat(sprintf("Variance              : %s\n", format(round(var_x, 2), big.mark = ",")))
cat(sprintf("Q1 (25th percentile)  : N%s\n", format(round(q[1], 2), big.mark = ",")))
cat(sprintf("Q3 (75th percentile)  : N%s\n", format(round(q[3], 2), big.mark = ",")))
cat(sprintf("IQR                   : N%s\n", format(round(iqr_x, 2), big.mark = ",")))
cat(sprintf("Min / Max             : N%s / N%s\n", range_x[1], range_x[2]))
cat(sprintf("Range (max - min)     : N%s\n", format(range_width, big.mark = ",")))
cat(sprintf("Most common payment   : %s\n", most_common_payment))
cat(sprintf("Mean vs Median gap    : N%s (positive => right-skewed)\n",
            format(round(mean_x - median_x, 2), big.mark = ",")))
cat("=========================================================================\n\n")

# Base R summary() as a cross-check against our manual calculations
print(summary(x))

# ---- 7. Visualize the distribution -----------------------------------------
# Histogram: shows the right skew - a long tail of large "stock-up" baskets
hist(x,
     breaks = 25,
     col = "steelblue",
     border = "white",
     main = "Distribution of Basket Sizes\nLagos Supermarket Chain (n = 400)",
     xlab = "Basket Size (Naira)",
     ylab = "Number of Receipts")
abline(v = mean_x, col = "red", lwd = 2, lty = 2)
abline(v = median_x, col = "darkgreen", lwd = 2, lty = 2)
legend("topright",
       legend = c(sprintf("Mean = N%.0f", mean_x), sprintf("Median = N%.0f", median_x)),
       col = c("red", "darkgreen"), lty = 2, lwd = 2, bty = "n")

# Boxplot: shows median, IQR box, whiskers, and outlier points beyond 1.5*IQR
boxplot(x,
        horizontal = TRUE,
        col = "lightblue",
        main = "Boxplot of Basket Sizes (Naira)",
        xlab = "Basket Size (Naira)")

# FACILITATOR TALKING POINT: point out the outlier dots on the right side of
# the boxplot - these are the same "stock-up" baskets creating the right
# skew visible in the histogram. This sets up Lab 3's discussion of why we
# still use the mean (with a confidence interval) for business reporting
# even when data is skewed, thanks to the Central Limit Theorem (Lab 2).
