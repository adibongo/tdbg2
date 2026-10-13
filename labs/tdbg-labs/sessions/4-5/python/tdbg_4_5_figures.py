# =============================================================================
# TDBG · Session 4.5 · Market Basket Analysis & Recommendation Engines
# Replication script — regenerates every chart in the Session 4.5 deck (Python)
# Data: data/supermarket_baskets.csv (3,000 Lagos supermarket baskets, one row per item)
#       data/product_ratings.csv (200 online-grocery customers rating 20 products, 1–5)
# Rules are computed directly from their definitions (support, confidence, lift),
# so no special package is needed. (R uses the 'arules' package — same numbers.)
# =============================================================================
import sys; sys.path.insert(0, "python")
import itertools, numpy as np, pandas as pd
import matplotlib.pyplot as plt
from tdbg_style import *

set_style()
b = pd.read_csv("data/supermarket_baskets.csv")
B = pd.crosstab(b.txn_id, b["item"]).clip(upper=1).astype(bool)      # one row per basket, one column per item
sup = B.mean()
rows = []
for a, c in itertools.permutations(B.columns, 2):
    s = (B[a] & B[c]).mean()
    if s >= 0.01: rows.append((a, c, s, s / sup[a], s / sup[a] / sup[c]))
R = pd.DataFrame(rows, columns=["lhs", "rhs", "support", "confidence", "lift"]).sort_values("lift", ascending=False)

# --- F01 · Item popularity (support) -----------------------------------------------------
top = sup.sort_values().tail(15)
fig, ax = plt.subplots()
ax.barh(top.index, top.values * 100, color=TEAL); ax.set(title="How often each item appears: 'support' (% of 3,000 baskets)", xlabel="% of baskets containing the item")
save(fig, "4-5", "f01")

# --- F02 · All rules: support vs confidence, coloured by lift -------------------------------
fig, ax = plt.subplots()
sc = ax.scatter(R.support * 100, R.confidence * 100, c=R.lift, cmap="YlOrRd", s=40, edgecolor="white", vmin=.8, vmax=3.4)
fig.colorbar(sc, ax=ax, label="lift")
for _, r in R.head(6).iloc[::2].iterrows(): ax.annotate(f"{r.lhs} → {r.rhs}", (r.support * 100, r.confidence * 100), xytext=(-8, 6), textcoords="offset points", ha="right", fontsize=11, color=NAVY)
ax.set(title=f"{len(R)} rules with support ≥ 1%: the strong ones are top-right and dark", xlabel="Support (% of baskets with both items)", ylabel="Confidence (% of 'if' baskets that also have 'then')")
save(fig, "4-5", "f02")

# --- F03 · Top rules by lift --------------------------------------------------------------------
t = R[R.confidence >= .3].head(12).iloc[::-1]
fig, ax = plt.subplots()
ax.barh([f"{a} → {c}" for a, c in zip(t.lhs, t.rhs)], t.lift, color=GOLD)
for i, (l, cf) in enumerate(zip(t.lift, t.confidence)): ax.text(l + .03, i, f"lift {l:.1f} · conf {cf:.0%}", va="center", fontsize=10)
ax.axvline(1, color=INK, ls="--"); ax.set_xlim(0, t.lift.max() * 1.35)
ax.set(title="Strongest rules: 'if' buyers are ~3× more likely to buy the 'then' item", xlabel="Lift (1 = no relationship)")
save(fig, "4-5", "f03")

# --- F04 · Lift matrix for the most common items ----------------------------------------------------
items = sup.sort_values(ascending=False).index[:14]
L = pd.DataFrame(index=items, columns=items, dtype=float)
for a in items:
    for c in items: L.loc[a, c] = np.nan if a == c else (B[a] & B[c]).mean() / sup[a] / sup[c]
fig, ax = plt.subplots(figsize=(10, 8))
im = ax.imshow(L.values.astype(float), cmap="RdBu_r", vmin=0, vmax=3.4); fig.colorbar(im, ax=ax, label="lift", shrink=.8)
ax.set_xticks(range(len(items)), items, rotation=50, ha="right"); ax.set_yticks(range(len(items)), items); ax.grid(False)
ax.set_title("Lift between pairs of popular items: red = bought together more than chance")
save(fig, "4-5", "f04")

# --- Recommender: item-based collaborative filtering --------------------------------------------------
rt = pd.read_csv("data/product_ratings.csv")
M = rt.pivot(index="customer_id", columns="item", values="rating")
C = M.sub(M.mean(axis=1), axis=0)                                  # centre each customer's ratings
def cosine(a, b):
    m = a.notna() & b.notna()
    if m.sum() < 3: return np.nan
    return float((a[m] * b[m]).sum() / np.sqrt((a[m] ** 2).sum() * (b[m] ** 2).sum()) + 1e-9)
S = pd.DataFrame({i: {j: (np.nan if i == j else cosine(C[i], C[j])) for j in M.columns} for i in M.columns})

# --- F05 · Item–item similarity -----------------------------------------------------------------------
fig, ax = plt.subplots(figsize=(10, 8))
im = ax.imshow(S.values.astype(float), cmap="RdBu_r", vmin=-1, vmax=1); fig.colorbar(im, ax=ax, label="similarity (cosine of centred ratings)", shrink=.8)
ax.set_xticks(range(len(S)), S.columns, rotation=50, ha="right"); ax.set_yticks(range(len(S)), S.index); ax.grid(False)
ax.set_title("Item similarity: products that the same customers rate alike")
save(fig, "4-5", "f05")

def predict(user, item, k=5):
    rated = M.loc[user].dropna().drop(item, errors="ignore")
    sims = S.loc[rated.index, item].dropna(); sims = sims[sims > 0].sort_values(ascending=False).head(k)
    if sims.empty: return M[item].mean()
    return M.loc[user].mean() + (sims * C.loc[user, sims.index]).sum() / sims.sum()

# --- F06 · Recommendations for one customer --------------------------------------------------------------
u = "C017"; unrated = M.columns[M.loc[u].isna()]
pred = pd.Series({i: predict(u, i) for i in unrated}).sort_values()
fig, ax = plt.subplots()
ax.barh(pred.index, pred.values, color=[GOLD if v >= pred.nlargest(3).min() else "#B8C7D3" for v in pred.values])
ax.set_xlim(1, 5); ax.set(title=f"Customer {u}: predicted ratings for products not yet tried — recommend the top 3", xlabel="Predicted rating (1–5)")
save(fig, "4-5", "f06")

# --- F07 · Does it beat 'recommend the most popular'? Leave-one-out test ---------------------------------
rng = np.random.default_rng(17); err_cf, err_pop = [], []
for user in M.index:
    rated = M.loc[user].dropna()
    if len(rated) < 5: continue
    item = rng.choice(rated.index); truth = rated[item]
    saved = M.loc[user, item]; M.loc[user, item] = np.nan; C.loc[user] = M.loc[user] - M.loc[user].mean()
    err_cf.append(predict(user, item) - truth); err_pop.append(M[item].mean() - truth)
    M.loc[user, item] = saved; C.loc[user] = M.loc[user] - M.loc[user].mean()
rmse = {"Popularity (item average)": np.sqrt(np.mean(np.square(err_pop))), "Item-based collaborative filtering": np.sqrt(np.mean(np.square(err_cf)))}
fig, ax = plt.subplots()
bb = ax.bar(list(rmse), list(rmse.values()), color=[SLATE, TEAL], width=.5); ax.bar_label(bb, labels=[f"{v:.2f}" for v in rmse.values()], padding=3, fontsize=14)
ax.set(title="Hidden-rating test: personalised predictions miss by less", ylabel="RMSE (rating points; lower is better)")
save(fig, "4-5", "f07")
print(R.head(8).round(3), rmse, pred.tail(3), sep="\n")
