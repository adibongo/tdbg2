# TDBG · Regenerate every R chart and run every R lab / practice paper (from the project root)
files <- sort(Sys.glob("sessions/*/R/*.R"))
ok <- c(); bad <- c()
for (f in files) {
  message("▶ ", f)
  res <- tryCatch({ source(f, local = new.env(), echo = FALSE); TRUE }, error = function(e) { message("  ✗ ", conditionMessage(e)); FALSE })
  if (res) ok <- c(ok, f) else bad <- c(bad, f)
  graphics.off()
}
message(sprintf("\nDone: %d scripts ran, %d failed.", length(ok), length(bad)))
if (length(bad)) print(bad)
