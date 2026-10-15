# DIY starter kit: from your raw data to a live dashboard

The companion to **Appendix F** of *The Governed Analytics Platform* (Prof. Bongo Adi, Lagos Business School).
The appendix is a prompt book: each stage gives you a prompt to paste into your AI assistant, what you should
see, and how to check it. This folder is the skeleton those prompts fill in.

```
my-analytics/
├── 00_setup.R            run once: installs packages, creates folders, checks tools
├── brief.md              Stage 1: your organisation, decisions, audience and key numbers
├── config.yml            WHERE things are (safe to share)        .Renviron  WHO you are (never share)
├── data/raw/             Stage 2: drop CSV, Excel, Parquet and JSON files here (sub-folders welcome)
├── sources.yml           Stage 3: databases, web APIs and per-file read options
├── sql/silver/*.sql      Stage 5: cleaning rules, one file per table, run in name order
├── sql/gold/*.sql        Stage 6: facts, dimensions, marts and ONE wide view for the dashboard
├── tests/tests.yml       Stage 7: the publish gate
├── semantic/metrics.yml  Stage 8: one definition per number; the dashboard reads only this
├── run_pipeline.R        Stage 9: one command: bronze → silver → gold → tests → gate → publish
├── dashboard.qmd         Stage 10: the Quarto + Shiny dashboard (no editing needed)
├── deploy.R              Stage 11: publish to Posit Connect / shinyapps.io
├── schedule/             Stage 12: cron, Windows Task Scheduler, GitHub Actions
├── R/platform.R          the engine (you should not need to edit it)
└── practice/             a complete practice organisation: data AND reference answers
```

## Five commands

```bash
Rscript 00_setup.R                      # once
Rscript use_practice.R                  # optional: load the practice organisation's data
Rscript run_pipeline.R --to=bronze      # land everything; writes ai_context.md for your prompts
Rscript run_pipeline.R                  # full run, after silver/gold/tests/metrics exist
quarto serve dashboard.qmd              # open the live dashboard in your browser
```

`Rscript use_practice.R answers` loads the practice organisation **with** all reference answers, so you can
see the finished result in two minutes before you start on your own data.

## Rules the kit enforces

- **Bronze is faithful.** Files land exactly as delivered (text), with `_source_file`, `_row` and `_loaded_at`.
- **Data flows one way.** Silver reads bronze, gold reads silver, the dashboard reads gold.
- **Nothing is published unless the tests pass.** A failed run leaves the last good warehouse live and raises an alert.
- **One definition per number.** The dashboard computes every figure from `semantic/metrics.yml`.
- **Secrets never live in files you share.** `config.yml` says where; `.Renviron` says who.
- **The AI sees descriptions, not records.** `ai_context.md` holds table structures and summary statistics;
  set `ai_context_samples: false` in `config.yml` when the data is personal.
