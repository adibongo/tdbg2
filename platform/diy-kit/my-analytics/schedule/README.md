# Scheduling the pipeline

Run `Rscript run_pipeline.R` on a schedule. It is safe to run at any time: it builds a fresh copy,
tests it and swaps it in only if the gate passes, and a lock stops two runs overlapping.
An open dashboard notices the new warehouse within `refresh_seconds` and updates itself.

| Where it runs | How |
|---|---|
| A laptop or office PC (macOS / Linux) | `crontab -e`, then add the line in `cron.txt` |
| A Windows PC or server | Task Scheduler → Create Basic Task → run `run_pipeline.bat` daily |
| GitHub (data that may live in GitHub) | copy `github-actions.yml` to `.github/workflows/pipeline.yml` |
| Posit Connect | publish `run_pipeline.R` as a scheduled job (Connect's "Schedule" tab) |

Failures are written to `logs/alerts.log` and, if `ALERT_WEBHOOK_URL` is set in `.Renviron`,
posted to that Microsoft Teams or Slack channel.
