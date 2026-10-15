# Shiny Dashboard Lab: from files to a live, multi-source Quarto dashboard

A teaching kit for *Turning Data into Business Growth* and *AI-Powered Data Analytics*.
Every code chunk sits under the prompt that generated it, so students can recreate the work
with Claude, Positron Assistant or Copilot and then review the output.

## Run it in 3 steps

```r
# 1. Open this folder in Positron/RStudio as a project (or setwd() here)
# 2. Build the data layer (installs any missing packages, ~1 minute)
quarto::quarto_render("01-build-data-layer.qmd")      # or click Render
# 3. Start the dashboard
quarto::quarto_serve("02-dashboard.qmd")               # or click Run Document
```

From a terminal: `quarto render 01-build-data-layer.qmd && quarto serve 02-dashboard.qmd`

Needs R ≥ 4.1 and Quarto ≥ 1.4. The databases in `data/db/` come pre-built, so step 3 also works on its own.

## What's inside

| File | What it is |
|---|---|
| `01-build-data-layer.qmd` → `.html` | Step-by-step notebook with 20 prompts. It reads CSV, messy Excel and Parquet; builds SQLite and DuckDB; adds a semantic layer, a vector-search index, Harvard Dataverse, Microsoft Dataverse and PostgreSQL; then runs the data tests, automation and deployment. |
| `02-dashboard.qmd` | Quarto dashboard + Shiny server. Seven pages, a live source switcher and auto-refresh. Each chunk carries its prompt (D1 to D11). |
| `config.yml` | Where every source lives. Add your own folders under `data_roots`. |
| `.Renviron.example` | Template for secrets (PostgreSQL, Microsoft Dataverse, Anthropic, Hugging Face). |
| `semantic/metrics.yml` | Business definitions: revenue, margin, stockout rate, and so on. |
| `R/helpers.R` | Shared functions: connections, `get_sales()`, the metric compiler, vector search, safe SQL, and the LLM and Dataverse clients. |
| `refresh.R` | Rebuild + test + log, with cron, launchd, Task Scheduler and GitHub Actions snippets. |

## Sources the dashboard can switch between

CSV · Excel workbook · Parquet · SQLite · DuckDB · PostgreSQL (once `.Renviron` is filled in)

The warehouse also holds: every data file found in your `data_roots` folders (the `landing` schema),
GDP from **Harvard Dataverse** (live, with an offline cache), and **Microsoft Dataverse** tables
(live once an Entra app is registered; ready-to-import CSVs are in `data/dataverse/`).

## Data findings the notebook teaches

The tests found three problems planted in the course data:
1. About 211 exact duplicate rows in `fmcg_sell_out.csv`.
2. Stockout weeks recorded as blanks.
3. Depot `DP04` listed twice in `fmcg_depots.csv`, which double-counts Abuja if joined naively.

After cleaning, CSV, Excel, Parquet, SQLite and DuckDB all return ₦46.853bn, and the Excel
regional report and the board pack reconcile to the warehouse within 1%.

## Update: architecture v2 and the master tutorial
- **Architecture v2** (`www/architecture.svg`): sources → ingest → DuckDB bronze/silver/gold → **test gate** → govern (semantic layer, vector index, catalogue) → serve, with an operations and security plane underneath. The notebook now publishes the **SQLite serving mart from gold, only after the gate passes**. Freshness is treated as a warning, not a blocker.
- **Master tutorial** (`mastery/`): a Quarto book that takes a novice to mastery. It has 16 chapters in four levels, nine sector playbooks (HR, education, supply chain, retail, oil and gas, power, banking, pensions, telecoms), a capstone with a rubric, and an auto-collected prompt library. Open `mastery/_book/index.html`, or rebuild it with `cd mastery && quarto render`.

## Run or deploy the Shiny edition
- **Locally:** open this folder in Positron or RStudio and run `quarto::quarto_serve("02-dashboard.qmd")`. The warehouse in `data/db/` is pre-built; render `01-build-data-layer.qmd` to rebuild it.
- **Posit Connect Cloud:** Publish → Shiny → repository `adibongo/tdbg2`, branch `main`, primary file `platform/lab/02-dashboard.qmd`. `manifest.json` pins every package. Add `ANTHROPIC_API_KEY` as a secret to turn on the AI SQL assistant.
- **Static edition:** `static-dashboard/` holds the browser-only version that is served at `markanalytics.online/tdbg/platform/dashboard/`. Refresh its data with `Rscript static-dashboard/export_data.R`, then `quarto render static-dashboard/index.qmd`.
- **Official statistics:** `R/open_data.R` pulls World Bank WDI, IMF WEO and UN Comtrade (UNCTADstat once its credentials are in `.Renviron`) and caches them in `data/open/`.
