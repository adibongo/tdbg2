# =============================================================================
# TDBG · Session 4.5 LAB · What sells with what — and what should we recommend? (Python)
# Data: data/supermarket_baskets.csv, data/product_ratings.csv
# =============================================================================
import itertools, numpy as np, pandas as pd

# ---- PART A · Market basket analysis --------------------------------------------------------
b = pd.read_csv("data/supermarket_baskets.csv")
B = pd.crosstab(b.txn_id, b["item"]).clip(upper=1).astype(bool)     # basket x item, True if bought
print(B.shape, "| average items per basket:", B.sum(axis=1).mean())
sup = B.mean(); print(sup.sort_values(ascending=False).head(10))

rules = []
for a, c in itertools.permutations(B.columns, 2):
    s = (B[a] & B[c]).mean()                       # support: share of baskets with both
    if s >= 0.01:
        conf = s / sup[a]                          # confidence: P(c | a)
        rules.append((a, c, s, conf, conf / sup[c]))   # lift: confidence / P(c)
R = pd.DataFrame(rules, columns=["if", "then", "support", "confidence", "lift"])
print(R[R.confidence >= .3].sort_values("lift", ascending=False).head(10).round(3))

# ---- PART B · Item-based recommender -----------------------------------------------------------
rt = pd.read_csv("data/product_ratings.csv")
M = rt.pivot(index="customer_id", columns="item", values="rating")
C = M.sub(M.mean(axis=1), axis=0)
def cosine(a, b):
    k = a.notna() & b.notna()
    return np.nan if k.sum() < 3 else (a[k] * b[k]).sum() / np.sqrt((a[k] ** 2).sum() * (b[k] ** 2).sum())
S = pd.DataFrame({i: {j: np.nan if i == j else cosine(C[i], C[j]) for j in M.columns} for i in M.columns})
print(S["Milo"].sort_values(ascending=False).head(5).round(2))

user, item = "C017", "Tea"
rated = M.loc[user].dropna().index; s = S.loc[rated, item].dropna(); s = s[s > 0]
print("predicted:", M.loc[user].mean() + (s * C.loc[user, s.index]).sum() / s.sum())

# ---- YOUR TURN ---------------------------------------------------------------------------------
# (a) Two shelf/bundle promotions from the rules (use lift AND support).
# (b) Diapers -> Beer has lift 2.3. Actionable? (c) Top-3 recommendations for C042 — trust them?
