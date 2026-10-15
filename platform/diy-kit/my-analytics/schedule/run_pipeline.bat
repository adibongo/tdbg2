@echo off
REM Windows Task Scheduler: Program = this file. Change the folder and the R version to yours.
cd /d "C:\Users\me\Documents\my-analytics"
"C:\Program Files\R\R-4.4.1\bin\Rscript.exe" run_pipeline.R >> logs\scheduler.log 2>&1
