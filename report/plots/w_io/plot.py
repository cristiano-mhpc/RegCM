import matplotlib.pyplot as plt
import numpy as np
from mpl_toolkits.axes_grid1.inset_locator import inset_axes

# --- Data (seconds) ---
data = {
    0: {
        "HDF5 Parallel":   {400: 24472.32, 800: 27553.40},
        "HDF5 Sequential": {400: 18359.64, 800: 13410.56},
        "PnetCDF":         {400: 20673.89, 800: 14497.63},
    },
    8: {
        "HDF5 Parallel":   {"match": 65531.64},
        "HDF5 Sequential": {"match": 59195.91},
        "PnetCDF":         {"match": 81728.16},
    },
    16: {
        "HDF5 Parallel":   {"match": 29912.89},
        "HDF5 Sequential": {"match": 26285.34},
        "PnetCDF":         {"match": 32386.16},
    },
    32: {
        "HDF5 Parallel":   {"match": 19318.43},
        "HDF5 Sequential": {"match": 13882.23},
        "PnetCDF":         {"match": 20705.00},
    },
    64: {
        "HDF5 Parallel":   {"match": 14049.66},
        "HDF5 Sequential": {"match":  9639.82},
        "PnetCDF":         {"match": 14525.84},
    },
}

methods = ["HDF5 Parallel", "HDF5 Sequential", "PnetCDF"]
colors  = {"HDF5 Parallel": "#1f77b4", "HDF5 Sequential": "#2ca02c", "PnetCDF": "#ff7f0e"}
to_hours = lambda s: None if s is None else s/3600.0

# --- Core-hour calculator ---
def core_hours(cpu_key, gpus, hours):
    if hours is None or np.isnan(hours): return np.nan
    if cpu_key == "match":
        cpu_cores = gpus
    else:
        cpu_cores = cpu_key
    total_cores = cpu_cores + 8 * gpus
    return total_cores * hours

# ======================
# Flatten data for plotting (multi-line labels)
# ======================
plot_labels = []   # x-axis labels
plot_hours  = {m: [] for m in methods}
plot_costs  = {m: [] for m in methods}

# GPU=0 → two entries (400/800 CPUs)
for cpu_key in (400, 800):
    if cpu_key == 400:
        plot_labels.append("0 GPUs\n400 CPUs on DCGP")
    else:
        plot_labels.append("0 GPUs\n800 CPUs on DCGP")
    for m in methods:
        secs = data[0][m][cpu_key]
        hrs = to_hours(secs)
        plot_hours[m].append(hrs)
        plot_costs[m].append(core_hours(cpu_key, 0, hrs))

# GPUs=8,16,32,64 → CPUs=GPUs
for g in (8, 16, 32, 64):
    plot_labels.append(f"{g} GPUs\n{g} CPUs on Booster")
    for m in methods:
        secs = data[g][m]["match"]
        hrs = to_hours(secs)
        plot_hours[m].append(hrs)
        plot_costs[m].append(core_hours("match", g, hrs))

x = np.arange(len(plot_labels))
bar_width = 0.25

# ======================
# Main plot (taller figure)
# ======================
fig, ax = plt.subplots(figsize=(12, 15))  # taller

for j, m in enumerate(methods):
    ax.bar(x + (j-1)*bar_width, plot_hours[m], bar_width,
           label=m, color=colors[m], alpha=0.85)
    for xi, yi in zip(x, plot_hours[m]):
        ax.text(xi + (j-1)*bar_width, yi*1.01, f"{yi:.1f}h",
                ha="center", va="bottom", fontsize=9)  # bigger bar labels

ax.set_xticks(x)
ax.set_xticklabels(plot_labels, fontsize=15)  # bigger x labels
ax.set_ylabel("Wall time (hours)", fontsize=19)  # bigger y-label
ax.set_title("RegCM5 Performance with I/O on 1003x1003x50 Grid and 4day simulation time.", fontsize=14, fontweight="bold")
ax.grid(True, alpha=0.3, axis='y')

# Collect handles/labels from the bars
handles, labels = ax.get_legend_handles_labels()

# Define your preferred display names (same order as `methods`)
custom_labels = ["HDF5 Parallel Write", "HDF5 Sequential Write", "PnetCDF Parallel Write"]

ax.legend(
    handles, custom_labels,
    loc="upper center",
    bbox_to_anchor=(0.5, 1.15),   # (x, y) relative to axes
    ncol=3,
    fontsize=14,
    frameon=False
)

# ======================
# Inset: core-hour cost (scaled up)
# ======================
# inset_ax = inset_axes(ax, width="43%", height="40%", loc="upper right", borderpad=3)
inset_ax = inset_axes(
    ax,
    width="43%", height="40%",
    loc="upper right",
    bbox_to_anchor=(0.05, 0.05, 0.93, 0.90),  # (x0, y0, x1, y1) in axes fraction
    bbox_transform=ax.transAxes,              # relative to main axes
    borderpad=0
)


for j, m in enumerate(methods):
    inset_ax.bar(x + (j-1)*bar_width, plot_costs[m], bar_width,
                 label=m, color=colors[m], alpha=0.85)
    for xi, yi in zip(x, plot_costs[m]):
        inset_ax.text(xi + (j-1)*bar_width, yi*1.01, f"{yi:,.0f}",
                      ha="center", va="bottom", fontsize=5)

inset_ax.set_title("Core-hour cost", fontsize=11, fontweight="bold")
inset_ax.set_xticks(x)
inset_ax.set_xticklabels(plot_labels, fontsize=5.5)  # inset labels slightly smaller
inset_ax.tick_params(axis='y', labelsize=9)
inset_ax.grid(True, alpha=0.2, axis='y')

# Caption (leave space below)
fig.subplots_adjust(bottom=0.20)
plt.figtext(
    0.01, 0.02,
    r"$\mathbf{Booster}$ partition (BullSequana X2135 'Da Vinci'): 3456 nodes, 1×32-core Xeon 8358, 512 GB DDR4, "
    "4× A100 64 GB, fabric: 2× dual-port HDR100 per node.\n"
    r"$\mathbf{DCGP}$ partition (BullSequana X2140): 1536 nodes, 2×56-core Sapphire Rapids, 512 GB DDR5, "
    "fabric: 1×100 Gbps HDR per node.\n\n"
    r"$\mathbf{Resource\ Efficiency}$: inset shows total core-hour cost "
    r"$(\mathrm{CPU\ cores} + 8 \times \mathrm{GPUs}) \times \mathrm{time}$. ",
    ha='left', va='bottom',
    fontsize=12,  # caption text a bit bigger too
    linespacing=1.4,
    fontfamily='monospace'
)

plt.show()

