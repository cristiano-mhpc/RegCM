import matplotlib.pyplot as plt
import numpy as np
from mpl_toolkits.axes_grid1.inset_locator import inset_axes
# Data
labels = ["512x1024x60"]
boost = [5795.80 / 3600]
dcgp = [1772.71 / 3600]
gpu4 = [1013.72 / 3600]
gpu8 = [638.16 / 3600]
gpu16 = [488.89 / 3600]

# Speedups relative to DCGP
speedup_gpu4 = dcgp[0] / gpu4[0]
speedup_gpu8 = dcgp[0] / gpu8[0]
speedup_gpu16 = dcgp[0] / gpu16[0]

x = np.arange(len(labels))
width = 0.1
spacing = 0.15

fig, ax = plt.subplots(figsize=(10, 6))
colors = ['#1b9e77', '#1f78b4', '#b2df8a', '#33a02c', '#006400']
# Plot bars
bar_boost = ax.bar(x - 2*spacing, boost, width, label='8Booster nodes-256CPUcores-0GPUs', color=colors[0])  # light blue
bar_dcgp = ax.bar(x - spacing, dcgp, width, label='8DCGP nodes-896CPUcores-0GPUs', color=colors[1])  # darker blue
bar4 = ax.bar(x, gpu4, width, label='1Booster node-4CPUcores-4GPUs', color=colors[2])  # light green
bar8 = ax.bar(x + spacing, gpu8, width, label='2Booster nodes-8CPUcores-8GPUs', color=colors[3])  # green
bar16 = ax.bar(x + 2*spacing, gpu16, width, label='4Booster nodes-16CPUcores-16GPUs', color=colors[4])  # dark green
# Labels and formatting
ax.set_ylabel("Wall Clock Time (hours)", fontsize=16)
ax.set_title("Performance of the RegCM5 with no I/O and 512x1024x60 grid size", fontsize=25)
ax.set_xticks(x)
ax.tick_params(axis='x', which='both', bottom=False, top=False, labelbottom=False)
# ax.set_xticklabels(labels)
ax.legend(loc="upper center", fontsize=10)
ax.grid(axis='y', linestyle='--', alpha=0.7)
ax.yaxis.set_tick_params(labelsize=12)

# Add speedup labels centered inside GPU bars
# def annotate_speedup_centered(bars, speedup):
#     for bar in bars:
#         height = bar.get_height()
#         ax.text(bar.get_x() + bar.get_width() / 2, height / 2,
#                 f"{speedup:.2f}×", ha='center', va='center',
#                 fontsize=13, fontweight='bold', color='black')

def annotate_speedup_centered(bars, speedup, offset=0.01):
    for b in bars:
        height = b.get_height()
        ax.text(b.get_x() + b.get_width() / 2, height + offset, f"{speedup:.2f}× speedup",
                 ha='center', va='bottom', fontsize=13, fontweight='bold', color='black')


annotate_speedup_centered(bar4, speedup_gpu4)
annotate_speedup_centered(bar8, speedup_gpu8)
annotate_speedup_centered(bar16, speedup_gpu16)

# Add partition labels on top
def label_partition(bar, name, offset=0.01):
    for b in bar:
        height = b.get_height()
        ax.text(b.get_x() + b.get_width() / 2, height + offset,
                name, ha='center', va='bottom', fontsize=10, fontweight='bold')

# label_partition([ax.containers[0][0]], "Booster")
# label_partition([ax.containers[1][0]], "DCGP")
# label_partition(bar4, "Booster")
# label_partition(bar8, "Booster")
# label_partition(bar16, "Booster")

# Compute core-hours for inset
multiplier=8
core_hours_boost = boost[0] * 256
core_hours_dcgp = dcgp[0] * 896
core_hours_gpu4 = gpu4[0] * (4 + multiplier * 4)
core_hours_gpu8 = gpu8[0] * (8 + multiplier * 8)
core_hours_gpu16 = gpu16[0] * (16 + multiplier * 16)

# Inset plot
axins = inset_axes(ax, width="60%", height="60%",
    bbox_to_anchor=(0.5, 0.5, 0.5, 0.7),
    bbox_transform=ax.transAxes,
    loc='lower right'
)

core_hour_values = [core_hours_boost, core_hours_dcgp, core_hours_gpu4, core_hours_gpu8, core_hours_gpu16]
labels_inset = ["Booster", "DCGP", "4GPU", "8GPU", "16GPU"]
bars_inset = axins.bar(labels_inset, core_hour_values, width=0.4, color='tab:orange')

# Formatting inset

# put the definition of a core in the inset plot
axins.text(
    0.68, 0.7,
    "core = no. of CPU cores + 8 × no. of GPUs",
    ha='center', va='top', fontsize=8, transform=axins.transAxes
)

axins.set_title("Simulation Cost in core-hours", fontsize=12)
axins.set_ylabel("core-hours", fontsize=12)
axins.tick_params(axis='x', which='both', bottom=False, top=False, labelbottom=False)  # <--- suppress x-ticks
axins.set_ylim(0, max(core_hour_values) * 1.2)
bars_inset = axins.bar(labels_inset, core_hour_values, width=0.4, color=colors)

# Add core-hour values on top of the inset bars
for bar, ch in zip(bars_inset, core_hour_values):
    height = bar.get_height()
    axins.text(bar.get_x() + bar.get_width() / 2, height + max(core_hour_values) * 0.03,
               f"{ch:.1f}", ha='center', va='bottom', fontsize=9, fontweight='bold', color='black')

# Caption
fig.subplots_adjust(bottom=0.25)
plt.figtext(
    0.01, 0.02,
    r"$\mathbf{Booster}$ partition (BullSequana X2135 'Da Vinci'): 3456 nodes, each with a single-socket 32-core "
    "Intel Xeon Platinum 8358 CPU (2.60 GHz), 512 GB DDR4 RAM,\n"
    "        4× NVIDIA A100 GPUs (64 GB HBM2e, NVLink 3.0, 200 GB/s), "
    "network: 2× dual-port HDR100 per node (400 Gbps/node).\n\n"
    r"$\mathbf{DCGP}$ partition (BullSequana X2140): 1536 nodes, each with 2×56-core Intel Sapphire Rapids CPUs "
    "(2.0 GHz), 512 GB DDR5 RAM, network: 1×100 Gbps HDR per node.\n\n"
    r"$\mathbf{Performance\,\,Comparison}$" "\n"
    "Speedups are relative to the " r"$\mathbf{896\,\,CPU\,\,cores\,\,on\,\,8\,\,DCGP\,\,booster\,\,nodes}$ (blue bar),showing the benefit of GPU acceleration." "\n\n"
    r"$\mathbf{Resource\,\,Efficiency}$" "\n"
    "The inset plot shows total core-hour cost ((no. of physical CPU cores + 8 × no. of GPU cores)× execution time), reflecting real compute usage. ",
    ha='left', va='bottom',
    fontsize=10,
    linespacing=1.5,
    fontfamily='monospace'
)


# Save the plot 
plt.savefig("consolidated_timings.png", format='png', dpi=300, bbox_inches='tight')
plt.show()
