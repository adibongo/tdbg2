# =============================================================================
# use_practice.R: rehearse with the practice organisation (Trans-Sahel Distribution Ltd)
#   Rscript use_practice.R            copy ONLY the practice data into data/ (you do the stages yourself)
#   Rscript use_practice.R answers    also copy the reference answers (sources, SQL, tests, metrics, brief)
# Afterwards, run:  Rscript run_pipeline.R   and   quarto serve dashboard.qmd
# =============================================================================
answers <- identical(commandArgs(trailingOnly = TRUE)[1], "answers")
copy_tree <- function(from, to) {
  for (f in list.files(from, recursive = TRUE, all.files = FALSE)) {
    dir.create(dirname(file.path(to, f)), showWarnings = FALSE, recursive = TRUE)
    file.copy(file.path(from, f), file.path(to, f), overwrite = TRUE)
  }
}
copy_tree("practice/data", "data")
message("Practice data copied into data/raw and data/systems.")
if (answers) {
  copy_tree("practice/sql", "sql"); copy_tree("practice/tests", "tests"); copy_tree("practice/semantic", "semantic")
  file.copy(c("practice/sources.yml", "practice/brief.md"), ".", overwrite = TRUE)
  cfg <- readLines("config.yml"); cfg <- sub('project: ".*"', 'project: "Trans-Sahel Distribution: commercial cockpit"', cfg)
  writeLines(cfg, "config.yml")
  message("Reference answers copied: sources.yml, brief.md, sql/, tests/, semantic/.")
} else message("Now follow the prompt book from Stage 2. The reference answers are in practice/ when you need them.")
