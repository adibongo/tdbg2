"""TDBG · Regenerate every Python chart and run every Python lab / practice paper (from the project root)."""
import glob, os, subprocess, sys
os.environ.setdefault("MPLBACKEND", "Agg")          # save charts without opening windows
files = sorted(glob.glob("sessions/*/python/*.py"))
bad = []
for f in files:
    print("▶", f, flush=True)
    r = subprocess.run([sys.executable, f], capture_output=True, text=True)
    if r.returncode: bad.append(f); print("  ✗", r.stderr.strip().splitlines()[-1] if r.stderr else "error")
print(f"\nDone: {len(files) - len(bad)} scripts ran, {len(bad)} failed.", *bad, sep="\n")
