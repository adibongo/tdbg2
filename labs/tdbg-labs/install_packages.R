# TDBG · Install every R package used in the programme (run once, from the project root)
pkgs <- c("dplyr", "readr", "tidyr", "stringr", "lubridate", "ggplot2", "scales", "patchwork", "broom", "tibble",
          "glmnet", "pROC", "rpart", "rpart.plot", "ranger", "gbm", "xgboost", "cluster", "forecast",
          "tidytext", "arules", "nnet")
missing <- setdiff(pkgs, rownames(installed.packages()))
if (length(missing)) install.packages(missing, dependencies = TRUE) else message("All packages already installed.")
invisible(lapply(pkgs, function(p) suppressPackageStartupMessages(library(p, character.only = TRUE))))
message("Ready: ", length(pkgs), " packages loaded.")
