# =============================================================================
# TDBG · Session 5.1 · Neural Networks, Deep Learning & Generative AI
# Replication script — regenerates every chart in the Session 5.1 deck (R)
# Data: data/telecom_churn.csv (5,000 subscribers, 22% churned)
# Neural networks use the 'nnet' package (one hidden layer, fitted with BFGS).
# R's nnet differs from Python's MLPClassifier (one hidden layer only, different optimiser),
# so numbers differ slightly — the conclusions are the same.
# =============================================================================
source("R/theme_tdbg.R")
suppressPackageStartupMessages({ library(dplyr); library(readr); library(tidyr); library(nnet); library(pROC); library(gbm); library(patchwork) })
set.seed(17)
d <- read_csv("data/telecom_churn.csv", show_col_types = FALSE) |>
  mutate(postpaid = as.integer(plan == "Postpaid")) |> select(-subscriber_id, -plan)
idx <- unlist(lapply(split(seq_len(nrow(d)), d$churned), function(i) sample(i, round(0.7 * length(i)))))
tr <- d[idx, ]; te <- d[-idx, ]
feats <- setdiff(names(d), "churned")
mu <- sapply(tr[feats], mean); sdv <- sapply(tr[feats], sd)
std <- function(df) { df[feats] <- sweep(sweep(as.matrix(df[feats]), 2, mu), 2, sdv, "/"); df }
A <- std(tr); B <- std(te)
auc <- function(y, p) as.numeric(pROC::auc(pROC::roc(y, as.numeric(p), quiet = TRUE)))

# --- F01 · Anatomy of a neural network (diagram) -------------------------------------------------
nodes <- bind_rows(
  tibble(layer = 0, name = feats, y = seq(0.9, 0.1, length.out = length(feats))),
  tibble(layer = 1, name = paste0("h", 1:5), y = seq(0.9, 0.1, length.out = 5)),
  tibble(layer = 2, name = "P(churn)", y = 0.5))
edges <- bind_rows(lapply(0:1, function(l) {
  a <- filter(nodes, layer == l); b <- filter(nodes, layer == l + 1)
  expand_grid(x = l, y = a$y, yend = b$y) |> mutate(xend = l + 1) }))
p1 <- ggplot() + geom_segment(data = edges, aes(x, y, xend = xend, yend = yend), colour = tdbg[["grid"]], linewidth = 0.3) +
  geom_point(data = nodes, aes(layer, y, colour = factor(layer)), size = 9) +
  scale_colour_manual(values = c(tdbg[["teal"]], tdbg[["gold"]], tdbg[["navy"]]), guide = "none") +
  geom_text(data = filter(nodes, layer == 0), aes(layer - 0.08, y, label = name), hjust = 1, size = 3.4) +
  geom_text(data = filter(nodes, layer == 2), aes(layer + 0.1, y, label = name), hjust = 0, size = 4, fontface = "bold") +
  annotate("text", x = 0:2, y = -0.05, label = c("Input layer\n(8 customer facts)", "Hidden layer\n(5 neurons learn patterns)", "Output layer\n(probability)"),
           colour = tdbg[["navy"]], fontface = "bold", size = 3.6, vjust = 1) +
  coord_cartesian(xlim = c(-0.8, 2.6), ylim = c(-0.2, 1)) + theme_void(base_family = Sys.getenv("TDBG_FONT", "sans")) +
  labs(title = "A small neural network: every line is a weight the model learns from data") +
  theme(plot.title = element_text(face = "bold", colour = tdbg[["navy"]]))
save_fig(p1, "5-1", "f01")

# --- F02 · Activation functions ------------------------------------------------------------------
z <- seq(-5, 5, length.out = 300)
act <- bind_rows(tibble(z, f = 1 / (1 + exp(-z)), fn = "Sigmoid: squashes to 0–1"),
                 tibble(z, f = pmax(0, z), fn = "ReLU: zero if negative"),
                 tibble(z, f = tanh(z), fn = "Tanh: squashes to −1 to 1"))
p2 <- ggplot(act, aes(z, f)) + geom_hline(yintercept = 0, colour = "grey60") + geom_vline(xintercept = 0, colour = "grey60") +
  geom_line(colour = tdbg[["teal"]], linewidth = 1.3) + facet_wrap(~fn, scales = "free_y") +
  labs(title = "Activation functions: the 'bend' that lets networks learn curves", x = "weighted sum of inputs (z)", y = NULL) + theme_tdbg()
save_fig(p2, "5-1", "f02", width = 11, height = 4)

# --- F03 · Straight line vs curved boundary (illustration) ---------------------------------------
set.seed(18)
u <- tibble(x1 = runif(600, -3, 3), x2 = runif(600, -3, 3)) |>
  mutate(resp = as.integer(x1^2 + x2^2 < 3.2), resp = ifelse(runif(600) < 0.08, 1 - resp, resp))
grid <- expand_grid(x1 = seq(-3, 3, length.out = 150), x2 = seq(-3, 3, length.out = 150))
lg <- glm(resp ~ x1 + x2, data = u, family = binomial)
nn <- nnet(resp ~ x1 + x2, data = u, size = 8, decay = 1e-3, maxit = 2000, trace = FALSE, entropy = TRUE)
mk <- function(p_grid, p_obs, ttl) {
  acc <- mean((p_obs > 0.5) == u$resp)
  ggplot() + geom_raster(data = mutate(grid, cls = p_grid > 0.5), aes(x1, x2, fill = cls)) +
    scale_fill_manual(values = c(`FALSE` = "#EEF2F6", `TRUE` = "#F6E3BF"), guide = "none") +
    geom_point(data = u, aes(x1, x2, colour = factor(resp)), size = 0.9) +
    scale_colour_manual(values = c(`0` = tdbg[["slate"]], `1` = tdbg[["rust"]]), labels = c("No", "Yes"), name = "Responded") +
    labs(title = sprintf("%s\naccuracy %.0f%%", ttl, 100 * acc), x = NULL, y = NULL) + theme_tdbg() +
    theme(axis.text = element_blank(), plot.title = element_text(size = 11)) }
p3 <- mk(predict(lg, grid, type = "response"), fitted(lg), "Logistic regression: a straight line") +
  mk(predict(nn, grid), fitted(nn), "Neural network (8 hidden neurons): a curve") +
  plot_layout(guides = "collect") + plot_annotation(title = "When the pattern is curved, a neural network can follow it", theme = theme_tdbg())
save_fig(p3, "5-1", "f03", width = 11, height = 5.2)

# --- F04 · Training vs test loss: overfitting a big network ---------------------------------------
set.seed(1)
logloss <- function(y, p) { p <- pmin(pmax(p, 1e-6), 1 - 1e-6); -mean(y * log(p) + (1 - y) * log(1 - p)) }
fit <- nnet(churned ~ ., data = A, size = 40, decay = 0, maxit = 1, trace = FALSE, entropy = TRUE, MaxNWts = 5000)
curve <- tibble()
for (it in 1:150) {
  fit <- nnet(churned ~ ., data = A, size = 40, decay = 0, maxit = 5, Wts = fit$wts, trace = FALSE, entropy = TRUE, MaxNWts = 5000)
  curve <- bind_rows(curve, tibble(it = it * 5, Training = logloss(A$churned, fitted(fit)), Test = logloss(B$churned, predict(fit, B))))
}
best <- curve$it[which.min(curve$Test)]
p4 <- curve |> pivot_longer(-it) |> ggplot(aes(it, value, colour = name)) + geom_line(linewidth = 1.2) +
  geom_vline(xintercept = best, linetype = 2, colour = tdbg[["gold"]]) +
  annotate("text", x = best + 15, y = max(curve$Test), label = paste("best stopping point ≈ iteration", best), hjust = 0, colour = tdbg[["gold"]]) +
  scale_colour_manual(values = c(Training = tdbg[["teal"]], Test = tdbg[["rust"]]), labels = c(Test = "Test data (unseen)", Training = "Training data (seen)"), name = NULL) +
  labs(title = "A big network (40 neurons, no penalty) keeps improving on data it has seen",
       subtitle = "…while its error on new data starts rising: overfitting", x = "Optimiser iteration", y = "Log loss (lower is better)") + theme_tdbg()
save_fig(p4, "5-1", "f04")

# --- F05 · Does deep learning win on a customer table? -------------------------------------------
set.seed(1)
m_lg  <- glm(churned ~ ., data = A, family = binomial)
m_sm  <- nnet(churned ~ ., data = A, size = 5,  decay = 1,    maxit = 2000, trace = FALSE, entropy = TRUE)
m_big <- nnet(churned ~ ., data = A, size = 40, decay = 0,    maxit = 2000, trace = FALSE, entropy = TRUE, MaxNWts = 5000)
m_reg <- nnet(churned ~ ., data = A, size = 40, decay = 5,    maxit = 2000, trace = FALSE, entropy = TRUE, MaxNWts = 5000)
m_gb  <- gbm(churned ~ ., data = tr, distribution = "bernoulli", n.trees = 300, interaction.depth = 3, shrinkage = 0.05, verbose = FALSE)
res <- tibble(model = c("Logistic regression", "Small neural net (5 neurons)", "Big neural net, no regularisation", "Big neural net, regularised", "Gradient boosting (Session 3.5)"),
              auc = c(auc(B$churned, predict(m_lg, B, type = "response")), auc(B$churned, predict(m_sm, B)), auc(B$churned, predict(m_big, B)),
                      auc(B$churned, predict(m_reg, B)), auc(te$churned, predict(m_gb, te, n.trees = 300, type = "response"))))
print(res)
p5 <- ggplot(res, aes(auc, reorder(model, auc), fill = ifelse(grepl("no regular", model), "bad", ifelse(grepl("Logistic", model), "lg", "o")))) +
  geom_col() + geom_text(aes(label = sprintf("%.2f", auc)), hjust = -0.2) +
  scale_fill_manual(values = c(bad = tdbg[["rust"]], lg = tdbg[["gold"]], o = tdbg[["teal"]]), guide = "none") +
  coord_cartesian(xlim = c(0.5, 0.82)) +
  labs(title = "Churn prediction, test AUC", subtitle = "The simple model is as good as the neural networks", x = "Test AUC (0.5 = coin flip, 1 = perfect)", y = NULL) + theme_tdbg()
save_fig(p5, "5-1", "f05")

# --- F06 · What drives the network's predictions? (permutation importance) -----------------------
base <- auc(B$churned, predict(m_sm, B)); set.seed(1)
imp <- sapply(feats, function(f) mean(replicate(20, { Bp <- B; Bp[[f]] <- sample(Bp[[f]]); base - auc(B$churned, predict(m_sm, Bp)) })))
p6 <- tibble(f = names(imp), v = imp) |> ggplot(aes(v, reorder(f, v))) + geom_col(fill = tdbg[["teal"]]) +
  labs(title = "Permutation importance: drop in test AUC when each fact is scrambled", x = "Drop in AUC", y = NULL) + theme_tdbg()
save_fig(p6, "5-1", "f06")

# --- F07 · How a convolution 'sees' an image (illustration) -------------------------------------
img <- matrix(0, 24, 24); img[6:19, 7:9] <- 1; img[6:8, 7:18] <- 1; img[17:19, 7:18] <- 1
k <- matrix(c(-1, -2, -1, 0, 0, 0, 1, 2, 1), 3)
fm <- matrix(0, 22, 22); for (i in 1:22) for (j in 1:22) fm[i, j] <- sum(img[i:(i + 2), j:(j + 2)] * k)
tomat <- function(m, nm) as_tibble(which(!is.na(m), arr.ind = TRUE)) |> mutate(v = as.vector(m), panel = nm)
pi1 <- ggplot(tomat(img, "a"), aes(col, -row, fill = v)) + geom_raster() + scale_fill_gradient(low = "white", high = "black", guide = "none") +
  coord_equal() + theme_void() + labs(title = "Input image (24 × 24 pixels)")
pi2 <- ggplot(tomat(k, "b"), aes(col, -row, fill = v)) + geom_tile(colour = "white") + geom_text(aes(label = v), size = 6, fontface = "bold") +
  scale_fill_gradient2(low = "#2166AC", high = "#B2182B", guide = "none") + coord_equal() + theme_void() + labs(title = "3 × 3 filter (vertical edges)")
pi3 <- ggplot(tomat(fm, "c"), aes(col, -row, fill = v)) + geom_raster() + scale_fill_gradient2(low = "#2166AC", high = "#B2182B", guide = "none") +
  coord_equal() + theme_void() + labs(title = "Feature map: edges light up")
p7 <- (pi1 | pi2 | pi3) + plot_layout(widths = c(1, 0.6, 1)) +
  plot_annotation(title = "How a convolutional network sees an image", subtitle = "Small filters slide over the pixels to find edges, then shapes, then objects", theme = theme_tdbg())
save_fig(p7, "5-1", "f07", width = 11, height = 4.4)

# --- F08 · Where generative AI fits (a judgement map) --------------------------------------------
tasks <- tribble(~task, ~value, ~risk,
  "Draft retention SMS variants", 3.8, 1.5, "Summarise call-centre notes", 4.2, 2.0, "Write first-draft R/Python code", 4.0, 2.6,
  "Tag complaint themes", 3.6, 2.2, "Explain a churn model to staff", 3.0, 2.0, "Decide who gets a loan", 4.3, 4.6,
  "Quote exact KPIs from memory", 2.2, 4.3, "Give legal or tax advice", 3.0, 4.5, "Translate to Pidgin / Yoruba", 3.4, 3.0) |>
  mutate(zone = ifelse(risk < 3.2, "use", ifelse(risk >= 4, "human", "careful")))
p8 <- ggplot(tasks, aes(risk, value)) + annotate("rect", xmin = 1, xmax = 3.2, ymin = -Inf, ymax = Inf, fill = "#F3F6F9") +
  geom_hline(yintercept = 3.2, linetype = 3) + geom_vline(xintercept = 3.2, linetype = 3) +
  geom_point(aes(colour = zone), size = 5) + geom_text(aes(label = task), hjust = 0, nudge_x = 0.08, nudge_y = 0.07, size = 3.4) +
  scale_colour_manual(values = c(use = tdbg[["teal"]], careful = tdbg[["gold"]], human = tdbg[["rust"]]), guide = "none") +
  annotate("text", x = 1.1, y = 4.8, label = "USE NOW, with review", colour = tdbg[["teal"]], fontface = "bold", hjust = 0) +
  annotate("text", x = 3.3, y = 4.8, label = "HUMAN DECIDES; AI assists at most", colour = tdbg[["rust"]], fontface = "bold", hjust = 0) +
  coord_cartesian(xlim = c(1, 5.6), ylim = c(1.8, 5)) +
  labs(title = "Where generative AI fits in a telco: high value, low risk-of-error tasks first",
       x = "Risk if the AI is wrong (1 = low, 5 = high)", y = "Business value (1 = low, 5 = high)") + theme_tdbg()
save_fig(p8, "5-1", "f08")
message("Session 5.1 figures saved.")
