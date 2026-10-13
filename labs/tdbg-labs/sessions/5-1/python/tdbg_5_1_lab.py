# =============================================================================
# TDBG · Session 5.1 LAB · Can a neural network predict churn better? (Python)
# Data: data/telecom_churn.csv (5,000 subscribers; churned = 1 if they left)
# pip install pandas scikit-learn   # once
# =============================================================================
import warnings; warnings.filterwarnings("ignore")
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.linear_model import LogisticRegression
from sklearn.neural_network import MLPClassifier
from sklearn.metrics import roc_auc_score
from sklearn.inspection import permutation_importance

d = pd.read_csv("data/telecom_churn.csv")
d["postpaid"] = (d.plan == "Postpaid").astype(int)
X = d.drop(columns=["subscriber_id", "plan", "churned"]); y = d.churned
print(d.head()); print("churn rate:", y.mean())                 # about 22%

# ---- 1. Split 70/30 and standardise (neural nets need inputs on the same scale) --------------------
Xtr, Xte, ytr, yte = train_test_split(X, y, test_size=0.3, random_state=17, stratify=y)
sc = StandardScaler().fit(Xtr)                                    # fit on TRAINING data only
A, B = sc.transform(Xtr), sc.transform(Xte)

# ---- 2. Benchmark: logistic regression (Session 3.4) -------------------------------------------------
lg = LogisticRegression(max_iter=1000).fit(A, ytr)
print("Logistic AUC:", round(roc_auc_score(yte, lg.predict_proba(B)[:, 1]), 3))

# ---- 3. A small neural network: 5 hidden neurons, alpha = regularisation ------------------------------
nn = MLPClassifier(hidden_layer_sizes=(5,), alpha=1, max_iter=3000, random_state=1).fit(A, ytr)
print("Small NN AUC:", round(roc_auc_score(yte, nn.predict_proba(B)[:, 1]), 3))
print("weights learned:", sum(w.size for w in nn.coefs_) + sum(b.size for b in nn.intercepts_))

# ---- 4. A big network with no penalty: watch it overfit ----------------------------------------------
big = MLPClassifier(hidden_layer_sizes=(64, 64), alpha=1e-4, max_iter=2000, random_state=1).fit(A, ytr)
print("Big NN  train AUC:", round(roc_auc_score(ytr, big.predict_proba(A)[:, 1]), 3),
      "| test AUC:", round(roc_auc_score(yte, big.predict_proba(B)[:, 1]), 3))

# ---- 5. What drives the small network? Permutation importance ------------------------------------------
pi = permutation_importance(nn, B, yte, scoring="roc_auc", n_repeats=10, random_state=1)
print(pd.Series(pi.importances_mean, index=X.columns).sort_values(ascending=False).round(3))

# ---- 6. GenAI as your assistant (no code) ------------------------------------------------------------------
# Paste the AUC results above into an AI assistant and ask: "Explain these results to a telco
# retention manager in 5 bullet points." Then CHECK every number it quotes against your output.

# ---- YOUR TURN ------------------------------------------------------------------------------------------
# (a) Try hidden_layer_sizes=(2,), (10,), (20,) with alpha=1. Does test AUC change much?
# (b) The big network: compare training vs test AUC. Explain the gap in one sentence.
# (c) Would you deploy the neural net or the logistic regression? Give two business reasons.
