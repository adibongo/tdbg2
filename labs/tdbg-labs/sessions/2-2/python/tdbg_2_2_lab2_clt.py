# =========================================================================
# LAB 2: The Central Limit Theorem by simulation  (Python twin of the R lab)
# TDBG - Session 2.2
# Dataset: data/bank_customer_income.csv (Nigerian retail bank, n = 500)
# Idea: treat the 500 customers as the "population", draw many samples of
# n = 30, and watch the sample MEANS form a bell curve even though incomes
# themselves are extremely right-skewed.
# =========================================================================
import numpy as np, pandas as pd
import matplotlib.pyplot as plt

rng = np.random.default_rng(123)             # reproducible random numbers
population = pd.read_csv("data/bank_customer_income.csv")["monthly_income_naira"].values
pop_mean, pop_sd = population.mean(), population.std(ddof=1)
print(f"Population mean N{pop_mean:,.0f} | median N{np.median(population):,.0f} | sd N{pop_sd:,.0f}")

n_sim, sample_n = 1000, 30
sample_means = np.array([rng.choice(population, sample_n, replace=True).mean() for _ in range(n_sim)])

print(f"Mean of {n_sim} sample means       : N{sample_means.mean():,.0f} (population mean N{pop_mean:,.0f})")
print(f"Empirical SE (sd of sample means) : N{sample_means.std(ddof=1):,.0f}")
print(f"Theoretical SE = sd / sqrt(n)     : N{pop_sd / np.sqrt(sample_n):,.0f}")
print("The two SE values should be close - that closeness IS the CLT at work.")

fig, (a1, a2) = plt.subplots(1, 2, figsize=(12, 4.5))
a1.hist(population, bins=40, color="#B5541A", edgecolor="white"); a1.set_title("Population: individual incomes")
a2.hist(sample_means, bins=30, color="#0B5E82", edgecolor="white"); a2.set_title(f"{n_sim} sample means (n = {sample_n})")
plt.tight_layout(); plt.show()

# YOUR TURN: change sample_n to 5, then 100. What happens to the shape and
# to the spread (SE) of the sample means? Why does n = 100 give a narrower curve?
