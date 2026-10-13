# =============================================================================
# TDBG · Session 4.4 LAB · What are customers saying about the app? (Python)
# Data: data/ecommerce_reviews.csv, data/sentiment_lexicon.csv
# =============================================================================
import re, numpy as np, pandas as pd
from collections import Counter
from sklearn.feature_extraction.text import CountVectorizer, TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import roc_auc_score

r = pd.read_csv("data/ecommerce_reviews.csv"); lex = pd.read_csv("data/sentiment_lexicon.csv")
print(r.review_text.head(10).to_list())                 # ALWAYS read some raw text first

# ---- 1. Clean and tokenise --------------------------------------------------------------------
clean = lambda t: re.sub(r"[^a-z\s]", " ", t.lower())
stop = {"the", "a", "an", "and", "or", "is", "was", "to", "of", "in", "on", "for", "my", "i", "it", "this"}
print(Counter(w for t in r.review_text for w in clean(t).split() if w not in stop).most_common(20))

# ---- 2. Lexicon sentiment ------------------------------------------------------------------------
def score(t):
    t = " " + clean(t) + " "
    return sum(t.count(" " + term + " ") * s for term, s in zip(lex.term, lex.score))
r["sentiment"] = r.review_text.map(score)
print("correlation with stars:", r[["sentiment", "rating"]].corr().iloc[0, 1])

# ---- 3. Themes -------------------------------------------------------------------------------------
r["payment"] = r.review_text.str.lower().str.contains("payment|refund|debited|money")
print(r.groupby("payment").agg(avg_sentiment=("sentiment", "mean"), pct_1_2_star=("rating", lambda x: (x <= 2).mean())))

# ---- 4. TF-IDF distinctive words ----------------------------------------------------------------------
grp = [" ".join(r.review_text[r.rating <= 2]), " ".join(r.review_text[r.rating >= 4])]
tv = TfidfVectorizer(stop_words="english"); M = tv.fit_transform(grp).toarray(); v = np.array(tv.get_feature_names_out())
print("negative:", v[np.argsort(M[0] - M[1])[-10:]]); print("positive:", v[np.argsort(M[1] - M[0])[-10:]])

# ---- 5. Text classifier ---------------------------------------------------------------------------------
r["negative"] = (r.rating <= 2).astype(int); tr = np.arange(len(r)) < 840
cv = CountVectorizer(min_df=5); X = cv.fit_transform(r.review_text)
clf = LogisticRegression(max_iter=5000, C=0.5).fit(X[tr], r.negative[tr])
print("test AUC:", roc_auc_score(r.negative[~tr], clf.predict_proba(X[~tr])[:, 1]))

# ---- YOUR TURN ----------------------------------------------------------------------------------------
# (a) Which theme should the COO fix first? (b) Find 3 reviews where sentiment and stars disagree.
# (c) Add two Pidgin phrases to the lexicon — does the correlation improve?
