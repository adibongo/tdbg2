# =========================================================================
# LAB 3: Standard Error and the 95% Confidence Interval
# TDBG - Session 2.2 (Statistical Foundations for Decision-Making)
# Dataset: retail_basket_sizes.csv (Lagos supermarket chain, n = 400 receipts)
# =========================================================================
#
# LEARNING GOAL: Build a 95% confidence interval for the true (population)
# mean basket size two ways - (1) the manual "mean +/- 1.96*SE" formula
# students learn by hand, and (2) R's built-in t.test() - and show that
# they agree closely. This connects Lab 1 (descriptive stats), Lab 2 (the
# CLT, which is WHY this works), and real decision-making: "What is our
# best estimate of average basket size, and how confident are we in it?"

# ---- 0. Load data -----------------------------------------------------------
data_path <- "data/retail_basket_sizes.csv"   # from the project root (open tdbg-labs.Rproj)
basket <- read.csv(data_path, stringsAsFactors = FALSE)

x <- basket$basket_size_naira
n <- length(x)

# ---- 1. Sample mean and sample standard deviation ---------------------------
sample_mean <- mean(x)
sample_sd <- sd(x)   # base R sd() already uses the n-1 (sample) denominator

# ---- 2. Standard Error (SE) --------------------------------------------------
# SE measures how much the SAMPLE MEAN would vary from sample to sample -
# it is NOT the same as the standard deviation of individual receipts.
# Formula: SE = s / sqrt(n)
se <- sample_sd / sqrt(n)

# ---- 3. METHOD A: Manual 95% CI using the normal (z) approximation ----------
# For large n (our n = 400 is well over the usual n >= 30 rule of thumb),
# the sampling distribution of the mean is approximately normal (CLT!),
# so we use the z critical value 1.96 for a 95% confidence level.
z_critical <- 1.96
margin_of_error_z <- z_critical * se
ci_lower_manual <- sample_mean - margin_of_error_z
ci_upper_manual <- sample_mean + margin_of_error_z

# ---- 4. METHOD B: R's built-in t.test() -------------------------------------
# t.test() uses the t-distribution (df = n - 1) instead of the normal (z).
# With n = 400, the t and z critical values are nearly identical (~1.9659
# vs 1.96), so the two CIs below should be very close - a good teaching
# moment on WHY the t-distribution exists (it corrects for extra
# uncertainty from estimating sigma with s, which matters more in small
# samples) and why, at large n, it barely matters which one you use.
ttest_result <- t.test(x, conf.level = 0.95)
ci_lower_t <- ttest_result$conf.int[1]
ci_upper_t <- ttest_result$conf.int[2]
t_critical <- qt(0.975, df = n - 1)  # extract the exact t critical value used

# ---- 5. Clean side-by-side printed comparison --------------------------------
cat("\n================ CONFIDENCE INTERVAL FOR MEAN BASKET SIZE ================\n")
cat(sprintf("Sample size (n)                 : %d\n", n))
cat(sprintf("Sample mean                     : N%s\n", format(round(sample_mean, 2), big.mark = ",")))
cat(sprintf("Sample standard deviation (s)    : N%s\n", format(round(sample_sd, 2), big.mark = ",")))
cat(sprintf("Standard Error (SE = s/sqrt(n))  : N%s\n", format(round(se, 2), big.mark = ",")))
cat("---------------------------------------------------------------------------\n")
cat("METHOD A: Manual formula  ->  mean +/- 1.96 * SE\n")
cat(sprintf("  Critical value (z)             : %.4f\n", z_critical))
cat(sprintf("  Margin of error                : N%s\n", format(round(margin_of_error_z, 2), big.mark = ",")))
cat(sprintf("  95%% CI                         : [N%s , N%s]\n",
            format(round(ci_lower_manual, 2), big.mark = ","),
            format(round(ci_upper_manual, 2), big.mark = ",")))
cat("---------------------------------------------------------------------------\n")
cat("METHOD B: R's t.test()  ->  mean +/- t(0.975, df=n-1) * SE\n")
cat(sprintf("  Critical value (t, df=%d)      : %.4f\n", n - 1, t_critical))
cat(sprintf("  95%% CI                         : [N%s , N%s]\n",
            format(round(ci_lower_t, 2), big.mark = ","),
            format(round(ci_upper_t, 2), big.mark = ",")))
cat("=============================================================================\n\n")

cat("Full t.test() output for reference:\n")
print(ttest_result)

cat("\nBUSINESS INTERPRETATION:\n")
cat(sprintf(
  "We are 95%% confident that the TRUE average basket size across all Lagos\n"
))
cat(sprintf(
  "supermarket transactions (not just our sample of %d receipts) lies between\n", n
))
cat(sprintf(
  "N%s and N%s. This is a much more honest business statement than\n",
  format(round(ci_lower_manual, 2), big.mark = ","),
  format(round(ci_upper_manual, 2), big.mark = ",")
))
cat("just reporting the single point estimate of the sample mean.\n\n")

# FACILITATOR TALKING POINT: ask students what happens to the width of the
# CI if n were smaller (e.g. one store's data, n=40) - SE gets bigger,
# margin of error gets bigger, interval gets WIDER. Bigger samples give
# more precise (narrower) estimates of the population mean - this is the
# direct payoff of the CLT-driven SE formula from Lab 2.
