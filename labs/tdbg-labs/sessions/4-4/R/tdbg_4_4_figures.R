# =============================================================================
# TDBG · Session 4.4 · Text, Language & Sentiment Analytics
# Replication script — regenerates every chart in the Session 4.4 deck (R)
# Data: data/ecommerce_reviews.csv and data/sentiment_lexicon.csv
# =============================================================================
source("R/theme_tdbg.R")
suppressPackageStartupMessages({ library(dplyr); library(readr); library(tidyr); library(stringr); library(tidytext); library(glmnet); library(pROC); library(patchwork) })
r <- read_csv("data/ecommerce_reviews.csv", show_col_types = FALSE)
lex <- read_csv("data/sentiment_lexicon.csv", show_col_types = FALSE) |> arrange(desc(nchar(term)))
STOP <- c("the","a","an","and","or","but","is","was","were","be","been","to","of","in","on","for","with","my","i","me","it","this","that","at","by","from","as","so","very","again","yet")
clean <- function(t) str_squish(str_replace_all(str_to_lower(t), "[^a-z\\s]", " "))
score <- function(t) { t <- paste0(" ", clean(t), " "); s <- 0
  for (i in seq_len(nrow(lex))) { pat <- paste0(" ", lex$term[i], " "); n <- str_count(t, fixed(pat))
    if (n > 0) { s <- s + n * lex$score[i]; t <- str_replace_all(t, fixed(pat), " ") } }; s }
r$sentiment <- sapply(r$review_text, score)
r$negative <- as.integer(r$rating <= 2)
THEMES <- c(Delivery = "deliver|rider|arrived|package|order|delayed|late", `Product quality` = "product|item|quality|original|fake|broke|described|value",
            `Payment & refunds` = "payment|refund|debited|checkout|transfer|money", `Customer service` = "customer care|support|agent|complaint|responded")
toks <- r |> mutate(text = clean(review_text)) |> unnest_tokens(word, text) |> filter(!word %in% STOP)

# --- F01 · Top words ---------------------------------------------------------------------------
p1 <- toks |> count(word, sort = TRUE) |> slice_head(n = 15) |> ggplot(aes(n, reorder(word, n))) + geom_col(fill = tdbg[["teal"]]) +
  labs(title = "After cleaning: the 15 most frequent words in 1,200 reviews", x = "Number of occurrences", y = NULL) + theme_tdbg()
save_fig(p1, "4-4", "f01")

# --- F02 · Sentiment vs rating -------------------------------------------------------------------
p2 <- ggplot(r, aes(factor(rating), sentiment, fill = factor(rating))) + geom_boxplot(width = .5) + geom_hline(yintercept = 0) +
  scale_fill_manual(values = c(tdbg[["rust"]], "#D98B6A", "#DDE3EA", tdbg[["sky"]], tdbg[["teal"]]), guide = "none") +
  scale_x_discrete(labels = paste(1:5, "star")) +
  labs(title = sprintf("Lexicon sentiment tracks star ratings (correlation r = %.2f)", cor(r$sentiment, r$rating)), x = "Customer's star rating", y = "Lexicon sentiment score") + theme_tdbg()
save_fig(p2, "4-4", "f02")

# --- F03 · Theme sentiment --------------------------------------------------------------------------
th <- bind_rows(lapply(names(THEMES), function(k) { m <- str_detect(str_to_lower(r$review_text), THEMES[[k]])
  tibble(theme = k, neg = sum(m & r$sentiment < 0), pos = sum(m & r$sentiment > 0)) })) |> mutate(net = (pos - neg) / (pos + neg))
p3 <- ggplot(th, aes(y = reorder(theme, net))) + geom_col(aes(x = -neg, fill = "negative mentions")) + geom_col(aes(x = pos, fill = "positive mentions")) +
  geom_text(aes(x = pos + 5, label = sprintf("net %+.0f%%", 100 * net)), hjust = 0) + geom_vline(xintercept = 0) +
  scale_fill_manual(values = c(`negative mentions` = tdbg[["rust"]], `positive mentions` = tdbg[["teal"]]), name = NULL) + expand_limits(x = max(th$pos) * 1.4) +
  labs(title = "What drives sentiment? Positive vs negative mentions by theme", x = "Number of reviews", y = NULL) + theme_tdbg()
save_fig(p3, "4-4", "f03")

# --- F04 · TF-IDF distinct words ----------------------------------------------------------------------
# With only two "documents", plain TF-IDF zeroes every shared word, so we use the
# difference in each word's share of all words (the same idea as Python's smoothed TF-IDF difference).
tf <- r |> mutate(group = ifelse(rating <= 2, "Negative (1-2 star)", ifelse(rating >= 4, "Positive (4-5 star)", NA))) |> filter(!is.na(group)) |>
  mutate(text = clean(review_text)) |> unnest_tokens(word, text) |> filter(!word %in% STOP) |> count(group, word) |>
  group_by(group) |> mutate(share = n / sum(n)) |> ungroup() |> select(-n) |>
  pivot_wider(names_from = group, values_from = share, values_fill = 0) |>
  mutate(`Negative (1-2 star)_d` = `Negative (1-2 star)` - `Positive (4-5 star)`, `Positive (4-5 star)_d` = -`Negative (1-2 star)_d`) |>
  select(word, ends_with("_d")) |> pivot_longer(-word, names_to = "group", values_to = "diff") |> mutate(group = sub("_d$", "", group)) |>
  group_by(group) |> slice_max(diff, n = 10, with_ties = FALSE) |> ungroup()
p4 <- ggplot(tf, aes(diff, reorder_within(word, diff, group), fill = group)) + geom_col() + facet_wrap(~group, scales = "free") + scale_y_reordered() +
  scale_fill_manual(values = c(tdbg[["rust"]], tdbg[["teal"]]), guide = "none") +
  labs(title = "The words that set unhappy customers apart: refunds, fakes, no-shows", x = "Distinctiveness (difference in word share)", y = NULL) + theme_tdbg()
save_fig(p4, "4-4", "f04", width = 12, height = 5.2)

# --- F05 · Bag-of-words classifier (penalised logistic regression) ----------------------------------------
dtm <- r |> mutate(id = row_number(), text = clean(review_text)) |> unnest_tokens(word, text) |> filter(!word %in% STOP) |>
  count(id, word) |> group_by(word) |> filter(n() >= 5) |> ungroup() |> cast_sparse(id, word, n)
X <- dtm[as.character(seq_len(nrow(r)))[as.character(seq_len(nrow(r))) %in% rownames(dtm)], ]
tr <- 1:840; te <- 841:1200
set.seed(1); fit <- cv.glmnet(X[tr, ], r$negative[tr], family = "binomial", alpha = 0, nfolds = 5)
p <- as.numeric(predict(fit, X[te, ], s = "lambda.min", type = "response"))
co <- coef(fit, s = "lambda.min")[-1, 1]; show <- c(sort(co)[1:8], sort(co, decreasing = TRUE)[1:8])
p5 <- ggplot(tibble(w = names(show), v = show), aes(v, reorder(w, v), fill = v > 0)) + geom_col() + geom_vline(xintercept = 0) +
  scale_fill_manual(values = c(`TRUE` = tdbg[["rust"]], `FALSE` = tdbg[["teal"]]), guide = "none") +
  labs(title = sprintf("A bag-of-words classifier: words that predict a 1-2 star review (test AUC %.2f)", auc(r$negative[te], p, quiet = TRUE)),
       x = "Coefficient (→ more likely negative)", y = NULL) + theme_tdbg()
save_fig(p5, "4-4", "f05")

# --- F06 · By category -----------------------------------------------------------------------------------
cat_ <- r |> group_by(category) |> summarise(pct_neg = mean(negative), n = n())
p6 <- ggplot(cat_, aes(pct_neg, reorder(category, pct_neg))) + geom_col(fill = tdbg[["teal"]]) +
  geom_text(aes(label = sprintf("%.0f%%  (n=%d)", 100 * pct_neg, n)), hjust = -.1) + scale_x_continuous(labels = scales::percent, expand = expansion(mult = c(0, .3))) +
  labs(title = "Share of 1-2 star reviews by category — similar everywhere", subtitle = "the problems are operational, not product-specific", x = NULL, y = NULL) + theme_tdbg()
save_fig(p6, "4-4", "f06")
