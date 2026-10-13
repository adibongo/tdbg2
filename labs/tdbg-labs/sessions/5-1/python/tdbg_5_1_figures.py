# =============================================================================
# TDBG · Session 5.1 · Neural Networks, Deep Learning & Generative AI
# Replication script — regenerates every chart in the Session 5.1 deck (Python)
# Data: data/telecom_churn.csv (5,000 subscribers of a Nigerian telco, 22% churned)
# Train/test: 70/30 stratified split, random_state = 17. Features are standardised.
# F03 and F07 use small illustrative datasets generated inside this script.
# =============================================================================
import sys; sys.path.insert(0, "python")
import warnings; warnings.filterwarnings("ignore")
import numpy as np, pandas as pd
import matplotlib.pyplot as plt
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.linear_model import LogisticRegression
from sklearn.neural_network import MLPClassifier
from sklearn.ensemble import HistGradientBoostingClassifier
from sklearn.metrics import roc_auc_score, log_loss
from sklearn.inspection import permutation_importance
from tdbg_style import *

set_style()
d = pd.read_csv("data/telecom_churn.csv")
d["postpaid"] = (d.plan == "Postpaid").astype(int)
X = d.drop(columns=["subscriber_id", "plan", "churned"]); y = d.churned
Xtr, Xte, ytr, yte = train_test_split(X, y, test_size=0.3, random_state=17, stratify=y)
sc = StandardScaler().fit(Xtr); A, B = sc.transform(Xtr), sc.transform(Xte)

# --- F01 · Anatomy of a neural network (diagram) -------------------------------------------------
fig, ax = plt.subplots(figsize=(11, 6))
layers = [list(X.columns), ["h1", "h2", "h3", "h4", "h5"], ["P(churn)"]]
xs = [0, 1, 2]; pos = {}
for li, (x, nodes) in enumerate(zip(xs, layers)):
    ys = np.linspace(0.9, 0.1, len(nodes)) if len(nodes) > 1 else [0.5]
    for n, yy in zip(nodes, ys): pos[(li, n)] = (x, yy)
for (l1, n1), (x1, y1) in pos.items():
    for (l2, n2), (x2, y2) in pos.items():
        if l2 == l1 + 1: ax.plot([x1, x2], [y1, y2], color=GRID, lw=0.8, zorder=1)
colors = [TEAL, GOLD, NAVY]
for (li, n), (x, yy) in pos.items():
    ax.scatter(x, yy, s=900 if li else 500, color=colors[li], zorder=3, edgecolor="white", lw=2)
    if li == 0: ax.text(x - 0.07, yy, n, ha="right", va="center", fontsize=10)
    if li == 2: ax.text(x + 0.12, yy, n, ha="left", va="center", fontsize=12, weight="bold")
for x, lab in zip(xs, ["Input layer\n(8 customer facts)", "Hidden layer\n(5 neurons learn patterns)", "Output layer\n(probability)"]):
    ax.text(x, -0.05, lab, ha="center", va="top", fontsize=11, color=NAVY, weight="bold")
ax.set_xlim(-0.8, 2.6); ax.set_ylim(-0.2, 1.0); ax.axis("off")
ax.set_title("A small neural network: every line is a weight the model learns from data")
save(fig, "5-1", "f01")

# --- F02 · Activation functions ------------------------------------------------------------------
z = np.linspace(-5, 5, 300)
fig, axs = plt.subplots(1, 3, figsize=(12, 4), sharey=False)
for ax, (name, f, desc) in zip(axs, [("Sigmoid", 1 / (1 + np.exp(-z)), "squashes to 0–1 (like logistic regression)"),
                                     ("ReLU", np.maximum(0, z), "zero if negative, else pass through"),
                                     ("Tanh", np.tanh(z), "squashes to −1 to 1")]):
    ax.plot(z, f, color=TEAL, lw=3); ax.axhline(0, color=SLATE, lw=0.6); ax.axvline(0, color=SLATE, lw=0.6)
    ax.set_title(f"{name}\n{desc}", fontsize=11); ax.set_xlabel("weighted sum of inputs (z)")
fig.suptitle("Activation functions: the 'bend' that lets networks learn curves", fontsize=14, color=NAVY, weight="bold")
fig.tight_layout()
save(fig, "5-1", "f02")

# --- F03 · Straight line vs curved boundary (illustration) ---------------------------------------
rng = np.random.default_rng(18)
n = 600
u = rng.uniform(-3, 3, (n, 2))
lab = ((u[:, 0] ** 2 + u[:, 1] ** 2) < 3.2).astype(int)          # customers inside a 'ring' respond
flip = rng.random(n) < 0.08; lab[flip] = 1 - lab[flip]
gx, gy = np.meshgrid(np.linspace(-3, 3, 200), np.linspace(-3, 3, 200)); G = np.c_[gx.ravel(), gy.ravel()]
fig, axs = plt.subplots(1, 2, figsize=(12, 5.4))
for ax, (name, m) in zip(axs, [("Logistic regression: a straight line", LogisticRegression()),
                                ("Neural network (8 hidden neurons): a curve", MLPClassifier((8,), max_iter=3000, random_state=1))]):
    m.fit(u, lab); acc = (m.predict(u) == lab).mean()
    ax.contourf(gx, gy, m.predict_proba(G)[:, 1].reshape(gx.shape), levels=[0, .5, 1], colors=["#EEF2F6", "#F6E3BF"])
    ax.scatter(u[lab == 0, 0], u[lab == 0, 1], s=10, color=SLATE, alpha=.6, label="No")
    ax.scatter(u[lab == 1, 0], u[lab == 1, 1], s=10, color=RUST, alpha=.8, label="Yes")
    ax.set_title(f"{name}\naccuracy {acc:.0%}", fontsize=11); ax.set_xticks([]); ax.set_yticks([])
axs[0].legend(title="Responded", loc="lower left", markerscale=3, frameon=True)
fig.suptitle("When the pattern is curved, a neural network can follow it", fontsize=14, color=NAVY, weight="bold")
fig.tight_layout()
save(fig, "5-1", "f03")

# --- F04 · Training vs validation loss: overfitting a big network ---------------------------------
big = MLPClassifier((64, 64), alpha=1e-4, random_state=1, learning_rate_init=1e-3)
tr_loss, te_loss = [], []
for ep in range(150):
    big.partial_fit(A, ytr, classes=[0, 1])
    tr_loss.append(log_loss(ytr, big.predict_proba(A))); te_loss.append(log_loss(yte, big.predict_proba(B)))
best = int(np.argmin(te_loss))
fig, ax = plt.subplots(figsize=(10, 5.2))
ax.plot(range(1, 151), tr_loss, color=TEAL, lw=2.5, label="Training data (seen)")
ax.plot(range(1, 151), te_loss, color=RUST, lw=2.5, label="Test data (unseen)")
ax.axvline(best + 1, color=GOLD, ls="--"); ax.text(best + 3, max(te_loss) * 0.98, f"best stopping point ≈ epoch {best + 1}", color=GOLD, fontsize=11)
ax.set(title="A big network (2 × 64 neurons) keeps improving on data it has seen — and gets worse on new data",
       xlabel="Epoch (one pass through the training data)", ylabel="Log loss (lower is better)")
ax.legend()
save(fig, "5-1", "f04")

# --- F05 · Does deep learning win on a customer table? -------------------------------------------
models = {
    "Logistic regression": LogisticRegression(max_iter=1000),
    "Small neural net (5 neurons)": MLPClassifier((5,), alpha=1, max_iter=3000, random_state=1),
    "Big neural net, no regularisation": MLPClassifier((64, 64), alpha=1e-4, max_iter=2000, random_state=1),
    "Big neural net, regularised": MLPClassifier((64, 64), alpha=1, max_iter=2000, random_state=1),
}
auc = {k: roc_auc_score(yte, m.fit(A, ytr).predict_proba(B)[:, 1]) for k, m in models.items()}
auc["Gradient boosting (Session 3.5)"] = roc_auc_score(yte, HistGradientBoostingClassifier(random_state=1).fit(Xtr, ytr).predict_proba(Xte)[:, 1])
print({k: round(v, 3) for k, v in auc.items()})
s = pd.Series(auc).sort_values()
fig, ax = plt.subplots(figsize=(10, 5))
ax.barh(s.index, s.values, color=[RUST if "no regular" in k else (GOLD if "Logistic" in k else TEAL) for k in s.index])
for i, v in enumerate(s.values): ax.text(v + 0.003, i, f"{v:.2f}", va="center")
ax.set_xlim(0.5, 0.82)
ax.set(title="Churn prediction, test AUC: the simple model is as good as the neural networks", xlabel="Test AUC (0.5 = coin flip, 1 = perfect)")
save(fig, "5-1", "f05")

# --- F06 · What drives the network's predictions? ------------------------------------------------
small = models["Small neural net (5 neurons)"]
pi = permutation_importance(small, B, yte, scoring="roc_auc", n_repeats=20, random_state=1)
imp = pd.Series(pi.importances_mean, index=X.columns).sort_values()
fig, ax = plt.subplots(figsize=(10, 5))
ax.barh(imp.index, imp.values, color=TEAL)
ax.set(title="Permutation importance: how much test AUC drops when each fact is scrambled", xlabel="Drop in AUC")
save(fig, "5-1", "f06")

# --- F07 · How a convolution 'sees' an image (illustration) -------------------------------------
img = np.zeros((24, 24)); img[5:19, 6:9] = 1; img[5:8, 6:18] = 1; img[16:19, 6:18] = 1   # a letter 'C'-like shape
k = np.array([[-1, 0, 1], [-2, 0, 2], [-1, 0, 1]])                                          # vertical-edge filter
fm = np.zeros((22, 22))
for i in range(22):
    for j in range(22): fm[i, j] = (img[i:i + 3, j:j + 3] * k).sum()
fig, axs = plt.subplots(1, 3, figsize=(12, 4.4), gridspec_kw={"width_ratios": [1, 0.6, 1]})
axs[0].imshow(img, cmap="Greys"); axs[0].set_title("Input image (24 × 24 pixels)", fontsize=11)
axs[1].imshow(k, cmap="RdBu_r", vmin=-2, vmax=2)
for (i, j), v in np.ndenumerate(k): axs[1].text(j, i, v, ha="center", va="center", fontsize=14, weight="bold")
axs[1].set_title("3 × 3 filter\n(detects vertical edges)", fontsize=11)
axs[2].imshow(fm, cmap="RdBu_r"); axs[2].set_title("Feature map: edges light up", fontsize=11)
for a in axs: a.set_xticks([]); a.set_yticks([])
fig.suptitle("A convolutional network slides small filters over an image to find edges, then shapes, then objects", fontsize=13, color=NAVY, weight="bold")
fig.tight_layout()
save(fig, "5-1", "f07")

# --- F08 · Where generative AI fits (a judgement map) --------------------------------------------
tasks = pd.DataFrame([
    ("Draft retention SMS variants", 3.8, 1.5), ("Summarise call-centre notes", 4.2, 2.0), ("Write first-draft R/Python code", 4.0, 2.6),
    ("Tag complaint themes", 3.6, 2.2), ("Explain a churn model to staff", 3.0, 2.0), ("Decide who gets a loan", 4.3, 4.6),
    ("Quote exact KPIs from memory", 2.2, 4.3), ("Give legal or tax advice", 3.0, 4.5), ("Translate to Pidgin / Yoruba", 3.4, 3.0)],
    columns=["task", "value", "risk"])
fig, ax = plt.subplots(figsize=(10.5, 6))
ax.axvspan(1, 3.2, ymin=0, ymax=1, color="#F3F6F9"); ax.axhline(3.2, color=SLATE, ls=":"); ax.axvline(3.2, color=SLATE, ls=":")
col = [TEAL if r < 3.2 else (RUST if r >= 4 else GOLD) for r in tasks.risk]
ax.scatter(tasks.risk, tasks.value, s=160, color=col, zorder=3)
for _, t in tasks.iterrows(): ax.text(t.risk + 0.08, t.value + 0.07, t.task, fontsize=10)
ax.text(1.1, 4.75, "USE NOW, with review", color=TEAL, weight="bold"); ax.text(3.3, 4.75, "HUMAN DECIDES; AI assists at most", color=RUST, weight="bold")
ax.set(xlim=(1, 5.6), ylim=(1.8, 5), xlabel="Risk if the AI is wrong (1 = low, 5 = high)", ylabel="Business value (1 = low, 5 = high)",
       title="Where generative AI fits in a telco: high value, low risk-of-error tasks first")
save(fig, "5-1", "f08")
print("Session 5.1 figures saved.")
