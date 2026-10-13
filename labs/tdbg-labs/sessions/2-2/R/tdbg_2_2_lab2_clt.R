# =========================================================================
# LAB 2: The Central Limit Theorem (CLT) in Action
# TDBG - Session 2.2 (Statistical Foundations for Decision-Making)
# Dataset: bank_customer_income.csv (Nigerian retail bank, n = 500 customers)
# =========================================================================
#
# LEARNING GOAL: Treat the 500 customers as our "population." Its income
# distribution is strongly right-skewed (a few high-net-worth customers).
# We repeatedly draw random samples of size n = 30 WITH REPLACEMENT, compute
# the sample mean each time, and show that the distribution of those 1,000
# sample means is approximately NORMAL even though the population is not.
# This is the Central Limit Theorem - the theoretical foundation for using
# the normal distribution to build confidence intervals (see Lab 3).

set.seed(123)  # reproducibility - every run of this script gives identical results

# ---- 0. Load the "population" ----------------------------------------------
data_path <- "data/bank_customer_income.csv"   # from the project root (open tdbg-labs.Rproj)
bank <- read.csv(data_path, stringsAsFactors = FALSE)

population <- bank$monthly_income_naira
N <- length(population)

pop_mean <- mean(population)
pop_sd   <- sd(population)     # sample sd of our full 500-row "population"

cat("\n================ POPULATION SUMMARY (N =", N, ") ================\n")
cat(sprintf("Population mean income   : N%s\n", format(round(pop_mean, 2), big.mark = ",")))
cat(sprintf("Population median income : N%s\n", format(round(median(population), 2), big.mark = ",")))
cat(sprintf("Population sd            : N%s\n", format(round(pop_sd, 2), big.mark = ",")))
cat("Note the large gap between mean and median - classic right skew driven\n")
cat("by a small number of high-net-worth customers.\n")
cat("=====================================================================\n\n")

# ---- 1. Repeated sampling simulation ---------------------------------------
n_sim <- 1000   # number of repeated samples to draw
sample_n <- 30  # size of EACH sample (a common rule-of-thumb minimum for CLT)

sample_means <- numeric(n_sim)  # pre-allocate a vector to store results (fast)

for (i in 1:n_sim) {
  one_sample <- sample(population, size = sample_n, replace = TRUE)
  sample_means[i] <- mean(one_sample)
}

# ---- 2. Compare theory vs. simulation --------------------------------------
sim_mean_of_means <- mean(sample_means)
sim_sd_of_means <- sd(sample_means)              # this IS the empirical standard error
theoretical_se <- pop_sd / sqrt(sample_n)         # CLT formula: SE = sigma / sqrt(n)

cat("================ CLT SIMULATION RESULTS ================\n")
cat(sprintf("Number of simulated samples        : %d\n", n_sim))
cat(sprintf("Each sample size (n)                : %d\n", sample_n))
cat(sprintf("Mean of the %d sample means        : N%s\n", n_sim, format(round(sim_mean_of_means, 2), big.mark = ",")))
cat(sprintf("  (compare to population mean)      : N%s\n", format(round(pop_mean, 2), big.mark = ",")))
cat(sprintf("SD of the %d sample means (empirical SE): N%s\n", n_sim, format(round(sim_sd_of_means, 2), big.mark = ",")))
cat(sprintf("Theoretical SE = pop_sd / sqrt(n)   : N%s\n", format(round(theoretical_se, 2), big.mark = ",")))
cat("These two SE values should be close - that closeness IS the CLT at work.\n")
cat("==========================================================\n\n")

# ---- 3. Visualize: population shape vs. sampling distribution shape --------
# Side-by-side panels make the CLT visually obvious to students
par(mfrow = c(1, 2))  # 1 row, 2 columns of plots

hist(population,
     breaks = 40,
     col = "tomato",
     border = "white",
     main = "Population:\nIndividual Customer Incomes\n(strongly right-skewed)",
     xlab = "Monthly Income (Naira)")
abline(v = pop_mean, col = "black", lwd = 2, lty = 2)

hist(sample_means,
     breaks = 30,
     col = "seagreen3",
     border = "white",
     main = sprintf("Sampling Distribution of the Mean\n(%d samples, each n = %d)", n_sim, sample_n),
     xlab = "Sample Mean Income (Naira)")
abline(v = sim_mean_of_means, col = "black", lwd = 2, lty = 2)

par(mfrow = c(1, 1))  # reset plotting layout back to default (1 panel)

# FACILITATOR TALKING POINT: the LEFT panel is skewed and lumpy - that is
# the real, messy distribution of individual customer incomes. The RIGHT
# panel, built purely by repeated averaging, is approximately bell-shaped
# and centered on the same population mean. This is exactly what lets us
# use the normal distribution to build a confidence interval around a
# sample mean in Lab 3, EVEN THOUGH individual basket sizes / incomes are
# not normally distributed themselves.
