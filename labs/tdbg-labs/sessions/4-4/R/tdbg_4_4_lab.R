# =============================================================================
# TDBG · Session 4.4 LAB · What are customers saying about the app? (R)
# Data: data/ecommerce_reviews.csv, data/sentiment_lexicon.csv
# install.packages(c("tidytext", "stringr", "glmnet", "pROC"))   # once
# =============================================================================
library(dplyr); library(readr); library(stringr); library(tidytext); library(glmnet); library(pROC)
r <- read_csv("data/ecommerce_reviews.csv", show_col_types = FALSE)
lex <- read_csv("data/sentiment_lexicon.csv", show_col_types = FALSE)
head(r$review_text, 10)                                         # ALWAYS read some raw text first

# ---- 1. Clean and tokenise: one row per word ----------------------------------------------------
words <- r |> mutate(text = str_to_lower(review_text)) |> unnest_tokens(word, text) |> anti_join(stop_words, by = "word")
words |> count(word, sort = TRUE) |> head(20)

# ---- 2. Lexicon sentiment: add up the scores of matched words/phrases ------------------------------
score <- function(t) { t <- paste0(" ", str_to_lower(str_replace_all(t, "[^A-Za-z ]", " ")), " ")
  sum(sapply(seq_len(nrow(lex)), function(i) str_count(t, fixed(paste0(" ", lex$term[i], " "))) * lex$score[i])) }
r$sentiment <- sapply(r$review_text, score)
cor(r$sentiment, r$rating)                                      # does the lexicon agree with stars?
r |> arrange(sentiment) |> select(rating, sentiment, review_text) |> head(5)

# ---- 3. Themes: simple keyword rules ---------------------------------------------------------------
r <- r |> mutate(delivery = str_detect(str_to_lower(review_text), "deliver|rider|arrived|delayed|late"),
                 payment = str_detect(str_to_lower(review_text), "payment|refund|debited|money"))
r |> group_by(payment) |> summarise(avg_sentiment = mean(sentiment), pct_1_2_star = mean(rating <= 2))

# ---- 4. Distinctive words with TF-IDF ----------------------------------------------------------------
words |> mutate(group = ifelse(rating <= 2, "negative", ifelse(rating >= 4, "positive", "neutral"))) |>
  count(group, word) |> bind_tf_idf(word, group, n) |> group_by(group) |> slice_max(tf_idf, n = 8)

# ---- 5. A text classifier: predict 1–2 star reviews from words ----------------------------------------
r$id <- seq_len(nrow(r)); r$negative <- as.integer(r$rating <= 2)
dtm <- words |> count(id = match(review_id, r$review_id), word) |> cast_sparse(id, word, n)
tr <- intersect(1:840, as.integer(rownames(dtm))); te <- intersect(841:1200, as.integer(rownames(dtm)))
fit <- cv.glmnet(dtm[as.character(tr), ], r$negative[tr], family = "binomial", alpha = 0)
auc(r$negative[te], as.numeric(predict(fit, dtm[as.character(te), ], type = "response")))

# ---- YOUR TURN ------------------------------------------------------------------------------------------
# (a) Which theme should the COO fix first? Use counts AND net sentiment.
# (b) Find three reviews where lexicon sentiment and star rating disagree. Why do they disagree?
# (c) Add two Nigerian Pidgin phrases to the lexicon. Does the rating correlation improve?
