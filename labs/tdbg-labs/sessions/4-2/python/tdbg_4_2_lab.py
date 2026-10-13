# =============================================================================
# TDBG · Session 4.2 LAB · Segmenting a bank's retail customers (Python)
# Data: data/bank_customers_segmentation.csv — 3,400 customers
# =============================================================================
import numpy as np, pandas as pd
import matplotlib.pyplot as plt
from sklearn.preprocessing import StandardScaler
from sklearn.cluster import KMeans, AgglomerativeClustering
from sklearn.decomposition import PCA
from sklearn.metrics import silhouette_score

d = pd.read_csv("data/bank_customers_segmentation.csv")
F = ["avg_balance_naira", "monthly_transactions", "digital_share", "age", "products_held", "tenure_years"]

# ---- 1. Prepare -------------------------------------------------------------------------
X = d[F].copy(); X["avg_balance_naira"] = np.log(X["avg_balance_naira"])
Z = StandardScaler().fit_transform(X)

# ---- 2. Choose k -------------------------------------------------------------------------
for k in range(2, 9):
    m = KMeans(n_clusters=k, n_init=20, random_state=1).fit(Z)
    print(k, round(m.inertia_), round(silhouette_score(Z, m.labels_, sample_size=2000, random_state=1), 3))

# ---- 3. k = 5 and profile ----------------------------------------------------------------
d["cluster"] = KMeans(n_clusters=5, n_init=20, random_state=1).fit_predict(Z)
print(d.groupby("cluster")[F].median().assign(customers=d.cluster.value_counts()))

# ---- 4. PCA --------------------------------------------------------------------------------
pca = PCA().fit(Z); print(pca.explained_variance_ratio_.round(3))
print(pd.DataFrame(pca.components_[:2].T, index=F, columns=["PC1", "PC2"]).round(2))
P = pca.transform(Z); plt.scatter(P[:, 0], P[:, 1], c=d.cluster, s=4); plt.show()

# ---- 5. Check against true labels (synthetic data only) ---------------------------------------
print(pd.crosstab(d.cluster, d.true_segment))

# ---- 6. Hierarchical clustering ------------------------------------------------------------------
d["hc"] = AgglomerativeClustering(n_clusters=5, linkage="ward").fit_predict(Z)
print(pd.crosstab(d.cluster, d.hc))

# ---- YOUR TURN -----------------------------------------------------------------------------------
# (a) Name each segment, describe it in one line, and propose ONE product for it.
# (b) Re-run without StandardScaler. What changes and why?
# (c) Which segment is the biggest growth opportunity? Argue it.
