# =============================================================================
# TDBG · Session 4.4 · Text, Language & Sentiment Analytics
# Replication script — regenerates every chart in the Session 4.4 deck (Python)
# Data: data/ecommerce_reviews.csv (1,200 reviews of a Nigerian e-commerce app)
#       data/sentiment_lexicon.csv (a small business lexicon incl. Pidgin phrases)
# Train/test for the classifier: first 840 reviews / last 360.
# =============================================================================
import sys; sys.path.insert(0, "python")
import re, numpy as np, pandas as pd
import matplotlib.pyplot as plt
from collections import Counter
from sklearn.feature_extraction.text import CountVectorizer, TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import roc_auc_score, confusion_matrix
from tdbg_style import *

set_style()
r = pd.read_csv("data/ecommerce_reviews.csv"); lex = pd.read_csv("data/sentiment_lexicon.csv")
STOP = set("the a an and or but is was were be been to of in on for with my i me it this that at by from as so very again yet".split())
clean = lambda t: re.sub(r"[^a-z\s]", " ", t.lower())
r["tokens"] = r.review_text.map(lambda t: [w for w in clean(t).split() if w not in STOP])

# Lexicon sentiment: sum of matched phrase scores (multi-word phrases first)
def score(text):
    t = " " + clean(text) + " "; s = 0
    for term, val in sorted(zip(lex.term, lex.score), key=lambda x: -len(x[0])):
        n = t.count(" " + term + " ")
        if n: s += n * val; t = t.replace(" " + term + " ", " ")
    return s
r["sentiment"] = r.review_text.map(score)
THEMES = {"Delivery": "deliver|rider|arrived|package|order|delayed|late", "Product quality": "product|item|quality|original|fake|broke|described|value",
          "Payment & refunds": "payment|refund|debited|checkout|transfer|money", "Customer service": "customer care|support|agent|complaint|responded"}
for k, pat in THEMES.items(): r[k] = r.review_text.str.lower().str.contains(pat)

# --- F01 · From text to a table: the text pipeline (word counts) ------------------------------
cnt = Counter(w for ts in r.tokens for w in ts).most_common(15)[::-1]
fig, ax = plt.subplots()
ax.barh([w for w, _ in cnt], [c for _, c in cnt], color=TEAL)
ax.set(title="After cleaning: the 15 most frequent words in 1,200 reviews", xlabel="Number of occurrences")
save(fig, "4-4", "f01")

# --- F02 · Sentiment score vs star rating --------------------------------------------------------
fig, ax = plt.subplots()
data = [r.sentiment[r.rating == k] for k in range(1, 6)]
bp = ax.boxplot(data, patch_artist=True, widths=.5, medianprops=dict(color=GOLD, lw=3))
for p, c in zip(bp["boxes"], [RUST, "#D98B6A", "#DDE3EA", SKY, TEAL]): p.set(facecolor=c, edgecolor=SLATE)
ax.axhline(0, color=INK, lw=.8); ax.set_xticks(range(1, 6), [f"{k} star" for k in range(1, 6)])
ax.set(title=f"Lexicon sentiment tracks star ratings (correlation r = {np.corrcoef(r.sentiment, r.rating)[0,1]:.2f})", xlabel="Customer's star rating", ylabel="Lexicon sentiment score")
save(fig, "4-4", "f02")

# --- F03 · Sentiment by theme -------------------------------------------------------------------
th = pd.DataFrame({k: [(r[k] & (r.sentiment < 0)).sum(), (r[k] & (r.sentiment > 0)).sum()] for k in THEMES}, index=["neg", "pos"]).T
th["net"] = (th.pos - th.neg) / (th.pos + th.neg); th = th.sort_values("net")
fig, ax = plt.subplots()
ax.barh(th.index, -th.neg, color=RUST, label="negative mentions"); ax.barh(th.index, th.pos, color=TEAL, label="positive mentions")
for i, (k, row) in enumerate(th.iterrows()): ax.text(row.pos + 5, i, f"net {row.net:+.0%}", va="center", fontsize=12, color=NAVY)
ax.axvline(0, color=INK); ax.legend(loc="upper left", fontsize=10); ax.set_xlim(-th.neg.max() * 1.15, th.pos.max() * 1.45)
ax.set(title="What drives sentiment? Positive vs negative mentions by theme", xlabel="Number of reviews")
save(fig, "4-4", "f03")

# --- F04 · Distinctive words: TF-IDF of 1–2 star vs 4–5 star reviews ---------------------------------------
grp = pd.Series({"Negative (1–2 star)": " ".join(r.review_text[r.rating <= 2]), "Positive (4–5 star)": " ".join(r.review_text[r.rating >= 4])})
tv = TfidfVectorizer(ngram_range=(1, 2), stop_words=list(STOP)); M = tv.fit_transform(grp.values).toarray(); vocab = np.array(tv.get_feature_names_out())
fig, axes = plt.subplots(1, 2, figsize=(12, 5.2))
for a, i, c in zip(axes, [0, 1], [RUST, TEAL]):
    top = np.argsort(M[i] - M[1 - i])[-10:]
    a.barh(vocab[top], (M[i] - M[1 - i])[top], color=c); a.set_title(grp.index[i]); a.set_xlabel("Distinctiveness (TF-IDF difference)")
fig.suptitle("The words that set unhappy customers apart: refunds, fakes, no-shows", x=.01, ha="left", color=NAVY, fontweight="bold")
fig.tight_layout(); save(fig, "4-4", "f04")

# --- F05 · Text classification: predict a negative review --------------------------------------------
r["negative"] = (r.rating <= 2).astype(int); tr = np.arange(len(r)) < 840
cv = CountVectorizer(min_df=5, stop_words=list(STOP)); X = cv.fit_transform(r.review_text)
clf = LogisticRegression(max_iter=5000, C=0.5).fit(X[tr], r.negative[tr]); p = clf.predict_proba(X[~tr])[:, 1]
coef = pd.Series(clf.coef_[0], cv.get_feature_names_out()).sort_values()
show = pd.concat([coef.head(8), coef.tail(8)])
fig, ax = plt.subplots()
ax.barh(show.index, show.values, color=[TEAL if v < 0 else RUST for v in show.values]); ax.axvline(0, color=INK)
ax.set(title=f"A bag-of-words classifier: words that predict a 1–2 star review (test AUC {roc_auc_score(r.negative[~tr], p):.2f})", xlabel="Logistic coefficient (→ more likely negative)")
save(fig, "4-4", "f05")

# --- F06 · Sentiment by product category -----------------------------------------------------------------
cat = r.groupby("category").agg(avg_sent=("sentiment", "mean"), pct_neg=("negative", "mean"), n=("review_id", "count")).sort_values("pct_neg")
fig, ax = plt.subplots()
b = ax.barh(cat.index, cat.pct_neg * 100, color=TEAL); ax.bar_label(b, labels=[f"{v:.0%}  (n={n})" for v, n in zip(cat.pct_neg, cat.n)], padding=4)
ax.set_xlim(0, cat.pct_neg.max() * 130)
ax.set(title="Share of 1–2 star reviews by category — similar everywhere: the problems are operational", xlabel="% of reviews that are negative")
save(fig, "4-4", "f06")
cm = confusion_matrix(r.negative[~tr], (p >= .5).astype(int)); print("AUC", roc_auc_score(r.negative[~tr], p), cm, th, cat, sep="\n")
