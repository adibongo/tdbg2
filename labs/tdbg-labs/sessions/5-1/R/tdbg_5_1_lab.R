# =============================================================================
# TDBG · Session 5.1 LAB · Can a neural network predict churn better? (R)
# Data: data/telecom_churn.csv (5,000 subscribers; churned = 1 if they left)
# install.packages(c("nnet", "pROC"))   # once ('nnet' usually comes with R)
# =============================================================================
library(dplyr); library(readr); library(nnet); library(pROC)
d <- read_csv("data/telecom_churn.csv", show_col_types = FALSE) |>
  mutate(postpaid = as.integer(plan == "Postpaid")) |> select(-subscriber_id, -plan)
glimpse(d); mean(d$churned)                                   # about 22% churn

# ---- 1. Split 70/30 and standardise (neural nets need inputs on the same scale) --------------------
set.seed(17)
idx <- sample(nrow(d), 0.7 * nrow(d)); tr <- d[idx, ]; te <- d[-idx, ]
feats <- setdiff(names(d), "churned")
mu <- sapply(tr[feats], mean); s <- sapply(tr[feats], sd)        # use TRAINING means/SDs only
for (f in feats) { tr[[f]] <- (tr[[f]] - mu[f]) / s[f]; te[[f]] <- (te[[f]] - mu[f]) / s[f] }

# ---- 2. Benchmark: logistic regression (Session 3.4) -------------------------------------------------
lg <- glm(churned ~ ., data = tr, family = binomial)
auc(te$churned, predict(lg, te, type = "response"))

# ---- 3. A small neural network: 5 hidden neurons, weight decay = regularisation ----------------------
set.seed(1)
nn <- nnet(churned ~ ., data = tr, size = 5, decay = 1, maxit = 2000, entropy = TRUE, trace = FALSE)
auc(te$churned, as.numeric(predict(nn, te)))
length(nn$wts)                                                  # how many weights did it learn?

# ---- 4. A big network with no penalty: watch it overfit ----------------------------------------------
set.seed(1)
big <- nnet(churned ~ ., data = tr, size = 40, decay = 0, maxit = 2000, entropy = TRUE, trace = FALSE, MaxNWts = 5000)
c(train = auc(tr$churned, as.numeric(fitted(big)))[1], test = auc(te$churned, as.numeric(predict(big, te)))[1])

# ---- 5. What drives the small network? Permutation importance ------------------------------------------
base <- auc(te$churned, as.numeric(predict(nn, te)))
sapply(feats, function(f) { te2 <- te; te2[[f]] <- sample(te2[[f]]); base - auc(te$churned, as.numeric(predict(nn, te2))) }) |>
  sort(decreasing = TRUE) |> round(3)

# ---- 6. GenAI as your assistant (no code) ------------------------------------------------------------------
# Paste the AUC table above into an AI assistant and ask: "Explain these results to a telco
# retention manager in 5 bullet points." Then CHECK every number it quotes against your output.

# ---- YOUR TURN ------------------------------------------------------------------------------------------
# (a) Try size = 2, 10, 20 with decay = 1. Does test AUC change much? What does that tell you?
# (b) The big network: compare training vs test AUC. Explain the gap in one sentence.
# (c) Would you deploy the neural net or the logistic regression? Give two business reasons.
