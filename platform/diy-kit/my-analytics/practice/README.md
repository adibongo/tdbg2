# Practice organisation: Trans-Sahel Distribution Ltd

A Nigerian FMCG distributor (the running example of the book) with sources in every shape you will meet at work:

| Source | Where | Shape | What is wrong with it (on purpose) |
|---|---|---|---|
| Weekly sell-out | `data/raw/sales/fmcg_sell_out.csv` | CSV, 55k rows | 214 re-sent rows; blank units that mean "stockout" |
| Product master | `data/raw/master/fmcg_products.csv` | CSV | numbers stored as text |
| Finance's regional report | `data/raw/finance/regional_report.xlsx` | "presentation" Excel | title rows, merged cells, ₦-formatted text, a total row and a footnote |
| Marketing spend | `data/raw/marketing/marketing_spend.json` | JSON export | runs three months past the sales data |
| Depots | `data/systems/erp.sqlite` (table `depots`) | a database | DP04 listed twice: a rename |
| Inflation | World Bank API | web API | needs the data part of a two-part response |

The reference answers (`sources.yml`, `brief.md`, `sql/`, `tests/`, `semantic/`) are what the prompts in Appendix F
should produce for this organisation. Use them to check your own attempt, not instead of it.
