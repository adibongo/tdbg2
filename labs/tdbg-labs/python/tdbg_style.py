"""
tdbg_style.py — shared chart style for every TDBG Python script.

Usage (from the project root, e.g. in RStudio with reticulate or in a terminal):
    import sys; sys.path.insert(0, "python")
    from tdbg_style import *
    set_style()
    ...
    save(fig, "2-2", "f03")   # -> sessions/2-2/figures/python/2-2_f03.png
"""
from pathlib import Path
import matplotlib
matplotlib.use("Agg")            # draws to files; works in RStudio, terminals and servers
import matplotlib.pyplot as plt

# Lagos Business School deck palette (matches the slides and the R theme)
NAVY, TEAL, TEAL2, GOLD = "#141B4D", "#0B5E82", "#1C7293", "#D99A2B"
RUST, SLATE, INK, LIGHT, GRID = "#B5541A", "#5C6B7A", "#1A2233", "#F3F6F9", "#E1E7EE"
OLIVE, SKY = "#8C8A4E", "#7FB3C8"
PALETTE = [TEAL, GOLD, NAVY, RUST, TEAL2, OLIVE, SKY, SLATE]

def set_style():
    plt.rcParams.update({
        "figure.figsize": (10, 5.6), "figure.dpi": 100, "savefig.dpi": 200,
        "font.family": "sans-serif",
        "font.sans-serif": ["Calibri", "Carlito", "Arial", "DejaVu Sans"],
        "font.size": 13, "axes.titlesize": 16, "axes.titleweight": "bold", "axes.titlecolor": NAVY,
        "axes.titlelocation": "left", "axes.titlepad": 14,
        "axes.labelsize": 13, "axes.labelcolor": INK, "axes.edgecolor": "#B8C2CE",
        "axes.spines.top": False, "axes.spines.right": False,
        "axes.grid": True, "grid.color": GRID, "grid.linewidth": 0.8, "axes.axisbelow": True,
        "xtick.color": SLATE, "ytick.color": SLATE, "legend.frameon": False,
        "axes.prop_cycle": matplotlib.cycler(color=PALETTE),
    })

def naira(x, pos=None):
    """Axis formatter: 12500 -> ₦12.5k ; 2500000 -> ₦2.5m"""
    if abs(x) >= 1e6: return f"₦{x/1e6:.1f}m"
    if abs(x) >= 1e3:
        k = x / 1e3
        return f"₦{k:.0f}k" if abs(k - round(k)) < 1e-9 or abs(x) >= 1e5 else f"₦{k:.1f}k"
    return f"₦{x:.0f}"

def save(fig, session, fig_id):
    """Save a figure to sessions/<session>/figures/python/<session>_<fig_id>.png"""
    out = Path("sessions") / session / "figures" / "python"
    out.mkdir(parents=True, exist_ok=True)
    path = out / f"{session}_{fig_id}.png"
    fig.savefig(path, bbox_inches="tight", facecolor="white")
    plt.close(fig)
    print("saved", path)
    return path
