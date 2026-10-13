# =============================================================================
# TDBG · Session 4.2 · Unsupervised Learning: Clustering & Dimensionality Reduction
# Replication script — regenerates every chart in the Session 4.2 deck (Python)
# Data: data/bank_customers_segmentation.csv — 3,400 retail bank customers
# (the 'true_segment' column is hidden from the algorithms; we use it only at
#  the end to check how well clustering rediscovered real groups)
# Note: k-means starts from random centres; cluster NUMBERS differ between R and
# Python, so we name clusters by their profile.
# =============================================================================
import sys; sys.path.insert(0, "python")
import numpy as np, pandas as pd
import matplotlib.pyplot as plt
from sklearn.preprocessing import StandardScaler
from sklearn.cluster import KMeans
from sklearn.decomposition import PCA
from sklearn.metrics import silhouette_score
from scipy.cluster.hierarchy import linkage, dendrogram
from tdbg_style import *

set_style()
d = pd.read_csv("data/bank_customers_segmentation.csv")
F = ["avg_balance_naira", "monthly_transactions", "digital_share", "age", "products_held", "tenure_years"]
LAB = {"avg_balance_naira": "Balance (log)", "monthly_transactions": "Transactions/month", "digital_share": "Digital share",
       "age": "Age", "products_held": "Products held", "tenure_years": "Tenure (yrs)"}
Xr = d[F].copy(); Xr["avg_balance_naira"] = np.log(Xr["avg_balance_naira"])      # tame the skew
Z = StandardScaler().fit_transform(Xr)                                              # put every driver on the same scale
km = KMeans(n_clusters=5, n_init=20, random_state=1).fit(Z)
d["cluster"] = km.labels_
# Name each cluster by its profile (after looking at the medians, analysts name segments)
names = d.groupby("cluster")["true_segment"].agg(lambda s: s.value_counts().index[0]).to_dict()
d["segment"] = d.cluster.map(names)
COL = dict(zip(["Mass-market savers", "Digital youth", "Salary earners", "Affluent", "SME owners"], [SLATE, SKY, TEAL, GOLD, RUST]))

# --- F01 · Raw data: can you see groups? ---------------------------------------------
fig, ax = plt.subplots()
ax.scatter(d.monthly_transactions, d.avg_balance_naira, s=6, alpha=.35, color=NAVY)
ax.set_yscale("log"); ax.yaxis.set_major_formatter(plt.FuncFormatter(naira))
ax.set(title="3,400 customers, no labels: are there natural groups?", xlabel="Transactions per month", ylabel="Average balance (log scale)")
save(fig, "4-2", "f01")

# --- F02 · Choosing k: elbow and silhouette -------------------------------------------
ks = range(2, 9); inert, sil = [], []
for k in ks:
    m = KMeans(n_clusters=k, n_init=20, random_state=1).fit(Z); inert.append(m.inertia_)
    sil.append(silhouette_score(Z, m.labels_, sample_size=2000, random_state=1))
fig, ax = plt.subplots(1, 2, figsize=(12, 4.8))
ax[0].plot(ks, inert, "o-", color=TEAL, lw=2.5); ax[0].axvline(5, color=GOLD, ls="--"); ax[0].set(title="Elbow: within-cluster spread", xlabel="Number of clusters k", ylabel="Total within-cluster sum of squares")
ax[1].plot(ks, sil, "o-", color=TEAL, lw=2.5); ax[1].axvline(5, color=GOLD, ls="--"); ax[1].set(title="Silhouette: how well separated (higher = better)", xlabel="Number of clusters k", ylabel="Average silhouette")
fig.tight_layout(); save(fig, "4-2", "f02")

# --- F03 · Clusters seen through PCA ---------------------------------------------------
pca = PCA().fit(Z); P = pca.transform(Z)
fig, ax = plt.subplots()
for s, c in COL.items():
    k = d.segment == s; ax.scatter(P[k, 0], P[k, 1], s=7, alpha=.5, color=c, label=f"{s} ({k.sum():,})")
ax.legend(markerscale=3, fontsize=11)
ax.set(title="Five segments, viewed on the first two principal components", xlabel=f"PC1 ({pca.explained_variance_ratio_[0]:.0%} of variation)", ylabel=f"PC2 ({pca.explained_variance_ratio_[1]:.0%})")
save(fig, "4-2", "f03")

# --- F04 · Segment profiles heat map -----------------------------------------------------
prof = pd.DataFrame(Z, columns=F).assign(segment=d.segment).groupby("segment").mean()
fig, ax = plt.subplots(figsize=(10, 4.8))
im = ax.imshow(prof.values, cmap="RdBu_r", vmin=-2, vmax=2, aspect="auto")
ax.set_xticks(range(len(F)), [LAB[f] for f in F], rotation=20); ax.set_yticks(range(len(prof)), prof.index); ax.grid(False)
med = d.groupby("segment")[F].median()
for i, s in enumerate(prof.index):
    for j, f in enumerate(F):
        v = med.loc[s, f]
        txt = naira(v) if f == "avg_balance_naira" else f"{v:.0%}" if f == "digital_share" else f"{v:.0f}" if f != "tenure_years" else f"{v:.1f}"
        ax.text(j, i, txt, ha="center", va="center", fontsize=11, color="white" if abs(prof.values[i, j]) > 1 else INK)
fig.colorbar(im, ax=ax, label="standardised average (0 = bank average)")
ax.set_title("Segment profiles: colour = above/below average; numbers = typical (median) values")
save(fig, "4-2", "f04")

# --- F05 · Segment size vs value -------------------------------------------------------------
sz = d.groupby("segment").agg(customers=("customer_id", "count"), balances=("avg_balance_naira", "sum"))
sz["share_cust"] = sz.customers / sz.customers.sum(); sz["share_bal"] = sz.balances / sz.balances.sum(); sz = sz.sort_values("share_bal")
fig, ax = plt.subplots()
y = np.arange(len(sz)); ax.barh(y + .2, sz.share_cust * 100, .4, color="#B8C7D3", label="share of customers")
ax.barh(y - .2, sz.share_bal * 100, .4, color=[COL[s] for s in sz.index], label="share of total balances")
for i, (c, b) in enumerate(zip(sz.share_cust, sz.share_bal)):
    ax.text(c * 100 + .5, i + .2, f"{c:.0%}", va="center", fontsize=11); ax.text(b * 100 + .5, i - .2, f"{b:.0%}", va="center", fontsize=11, fontweight="bold")
ax.set_yticks(y, sz.index); ax.legend(loc="lower right")
ax.set(title="Who holds the money? The Affluent — 10% of customers — hold 43% of balances", xlabel="%")
save(fig, "4-2", "f05")

# --- F06 · PCA: variance explained -----------------------------------------------------------
ev = pca.explained_variance_ratio_
fig, ax = plt.subplots()
ax.bar(range(1, 7), ev * 100, color=TEAL); ax.plot(range(1, 7), np.cumsum(ev) * 100, "o-", color=GOLD, lw=2.5, label="cumulative")
for i, v in enumerate(np.cumsum(ev)): ax.text(i + 1, v * 100 + 2, f"{v:.0%}", ha="center", color=NAVY)
ax.set_ylim(0, 110); ax.legend()
ax.set(title="PCA: two components keep about two-thirds of the information in six drivers", xlabel="Principal component", ylabel="% of total variation")
save(fig, "4-2", "f06")

# --- F07 · PCA loadings: what each component means -----------------------------------------------
L = pd.DataFrame(pca.components_[:2].T, index=[LAB[f] for f in F], columns=["PC1", "PC2"])
fig, ax = plt.subplots(1, 2, figsize=(12, 4.6), sharey=True)
for a, c in zip(ax, ["PC1", "PC2"]):
    a.barh(L.index, L[c], color=[RUST if v < 0 else TEAL for v in L[c]]); a.axvline(0, color=INK, lw=.8); a.set_title(f"{c} loadings")
fig.suptitle("Loadings: PC1 ≈ 'older, longer-tenured, less digital'; PC2 ≈ 'more products, money and activity'", x=.01, ha="left", color=NAVY, fontweight="bold")
fig.tight_layout(); save(fig, "4-2", "f07")

# --- F08 · Hierarchical clustering: a dendrogram of 40 customers ----------------------------------
idx = d.groupby("segment").sample(8, random_state=3).index
Lk = linkage(Z[idx], method="ward")
fig, ax = plt.subplots(figsize=(12, 5))
dn = dendrogram(Lk, labels=d.loc[idx, "segment"].str.split().str[0].values, leaf_rotation=90, ax=ax, color_threshold=5.5, above_threshold_color=SLATE)
ax.axhline(5.5, color=GOLD, ls="--"); ax.text(1, 5.8, "cut here → 5 groups", color=GOLD)
ax.set(title="Hierarchical clustering: merge the most similar customers step by step", ylabel="Distance at which groups merge"); ax.grid(False)
save(fig, "4-2", "f08")
print(sz)
