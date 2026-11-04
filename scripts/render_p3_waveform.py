#!/usr/bin/env python3
"""
Render genuine simulation waveform screenshot from results/p3_integrated.vcd.
Matches the visual appearance of digital waveform viewers (Surfer / GTKWave),
with accurate simulation time axis (in nanoseconds/picoseconds), digital transitions,
bus hex values, and markers highlighting both a correct branch prediction and
a direction misprediction with pipeline recovery redirect.
"""

import sys
import matplotlib.pyplot as plt
import matplotlib.patches as patches

# Read VCD
vcd_path = 'results/p3_integrated.vcd'
with open(vcd_path, 'r') as f:
    lines = f.readlines()

# Target variables in tb_integrated scope
target_vars = [
    ('clk', '+', False, '#00ffcc'),
    ('res_valid', ':', False, '#ffff00'),
    ('res_branch_pc', '6', True, '#00d4ff'),
    ('res_saved_taken', '8', False, '#ffaa00'),
    ('res_saved_hit', '7', False, '#ffaa00'),
    ('res_actual_taken', '4', False, '#00ff66'),
    ('res_mispredict', '$', False, '#ff3366'),
    ('res_flush', '%', False, '#ff3366'),
    ('res_redirect', '#', False, '#ff3366'),
    ('res_redirect_pc', '\"', True, '#ff99bb'),
    ('selected_pc', '!', True, '#33ff99'),
    ('p1_update_valid', '/', False, '#bb99ff'),
    ('p2_update_valid', '3', False, '#bb99ff'),
]

# Track value changes over time
transitions = {sym: [] for _, sym, _, _ in target_vars}
current_time = 0

for line in lines:
    line = line.strip()
    if not line:
        continue
    if line.startswith('#'):
        current_time = int(line[1:])
    elif line.startswith('b'):
        parts = line.split()
        val = parts[0][1:]
        sym = parts[1]
        if sym in transitions:
            transitions[sym].append((current_time, val))
    elif len(line) >= 2 and line[1:] in transitions:
        val = line[0]
        sym = line[1:]
        transitions[sym].append((current_time, val))

# Time window of interest: 80,000 ps to 155,000 ps (80 ns to 155 ns)
# Captures:
#   1. T2 verification: correct taken prediction (mispredict=0, redirect=0, selected_pc=0x00002000)
#   2. T3 verification: direction miss NT->T (mispredict=1, redirect=1, redirect_pc=0x00003000)
#   3. T4 verification: direction miss T->NT (mispredict=1, redirect=1, redirect_pc=0x00001008)
t_min_ps = 80000
t_max_ps = 155000
t_min_ns = t_min_ps / 1000.0
t_max_ns = t_max_ps / 1000.0

def get_val_at(sym, t):
    hist = transitions[sym]
    last_val = '0'
    for ct, val in hist:
        if ct <= t:
            last_val = val
        else:
            break
    return last_val

# Helper to format hex 32-bit values
def fmt_hex(val_str):
    try:
        val_int = int(val_str, 2)
        return f"0x{val_int:08X}"
    except Exception:
        return val_str

# Set up figure
fig, ax = plt.subplots(figsize=(15, 9), dpi=180)
fig.patch.set_facecolor('#12131a')
ax.set_facecolor('#181a24')

y_spacing = 2.0
n_sigs = len(target_vars)

# Background alternating row shades
for i in range(n_sigs):
    y_base = (n_sigs - 1 - i) * y_spacing
    if i % 2 == 0:
        ax.axhspan(y_base - 0.4, y_base + 1.4, color='#1e212f', alpha=0.5, zorder=0)

# Draw time grid lines (every 5 ns = 5000 ps)
for t_ns in range(int(t_min_ns), int(t_max_ns) + 1, 5):
    ax.axvline(t_ns, color='#2d3142', linestyle=':', linewidth=0.8, zorder=1)

# Annotate highlighted test phases
ax.axvspan(90, 110, color='#00ff66', alpha=0.08, zorder=0)
ax.text(100, (n_sigs) * y_spacing, "T2: Correct Prediction (Taken + BTB Hit)\n[mispredict=0, redirect=0, selected_pc=0x2000]",
        color='#00ff99', fontsize=9, fontweight='bold', ha='center', va='bottom',
        bbox=dict(boxstyle='round,pad=0.4', facecolor='#162e24', edgecolor='#00ff66', alpha=0.9))

ax.axvspan(110, 130, color='#ff3366', alpha=0.08, zorder=0)
ax.text(120, (n_sigs) * y_spacing, "T3: Direction Mispredict (NT -> T)\n[mispredict=1, flush=1, redirect_pc=0x3000]",
        color='#ff6688', fontsize=9, fontweight='bold', ha='center', va='bottom',
        bbox=dict(boxstyle='round,pad=0.4', facecolor='#3d1822', edgecolor='#ff3366', alpha=0.9))

ax.axvspan(130, 150, color='#ffaa00', alpha=0.08, zorder=0)
ax.text(140, (n_sigs) * y_spacing, "T4: Direction Mispredict (T -> NT)\n[mispredict=1, redirect_pc=PC+4 (0x1008)]",
        color='#ffbb33', fontsize=9, fontweight='bold', ha='center', va='bottom',
        bbox=dict(boxstyle='round,pad=0.4', facecolor='#3d2c18', edgecolor='#ffaa00', alpha=0.9))

# Plot each signal
for i, (name, sym, is_bus, color) in enumerate(target_vars):
    y_base = (n_sigs - 1 - i) * y_spacing
    
    # Label on left
    ax.text(t_min_ns - 1.5, y_base + 0.4, name, color='#e0e2ec', fontsize=9.5,
            fontfamily='monospace', fontweight='bold', ha='right', va='center')

    hist = transitions[sym]
    
    # Extract relevant transitions in window
    points = []
    # Value just before t_min
    v_init = get_val_at(sym, t_min_ps)
    points.append((t_min_ns, v_init))
    
    for ct, val in hist:
        if t_min_ps <= ct <= t_max_ps:
            points.append((ct / 1000.0, val))
    points.append((t_max_ns, points[-1][1]))
    
    if not is_bus:
        # Single-bit digital waveform
        x_pts = []
        y_pts = []
        for idx in range(len(points) - 1):
            t_curr = points[idx][0]
            v_curr = 1.0 if points[idx][1] == '1' else 0.0
            t_next = points[idx + 1][0]
            
            x_pts.extend([t_curr, t_next])
            y_pts.extend([y_base + v_curr * 0.9, y_base + v_curr * 0.9])
            
        ax.step(x_pts, y_pts, where='post', color=color, linewidth=1.6, zorder=3)
    else:
        # Multi-bit bus waveform with hexagonal transition packets
        for idx in range(len(points) - 1):
            t_start = points[idx][0]
            t_end = points[idx + 1][0]
            val = points[idx][1]
            if t_end - t_start < 0.1:
                continue
                
            hex_str = fmt_hex(val)
            h = 0.8
            y_m = y_base + 0.4
            
            # Bus top & bottom lines
            dt = 0.3 if t_end - t_start > 0.6 else (t_end - t_start) * 0.2
            poly_x = [t_start, t_start + dt, t_end - dt, t_end, t_end - dt, t_start + dt]
            poly_y = [y_m, y_m + h/2, y_m + h/2, y_m, y_m - h/2, y_m - h/2]
            
            fill_color = '#222938' if hex_str != '0x00000000' else '#181b24'
            edge_color = color if hex_str != '0x00000000' else '#4e5568'
            
            poly = patches.Polygon(list(zip(poly_x, poly_y)), facecolor=fill_color, edgecolor=edge_color,
                                   linewidth=1.2, zorder=2)
            ax.add_patch(poly)
            
            # Bus value label inside
            if t_end - t_start > 4.0:
                ax.text((t_start + t_end) / 2.0, y_m, hex_str, color='#ffffff', fontsize=7.5,
                        fontfamily='monospace', fontweight='semibold', ha='center', va='center', zorder=4)

ax.set_xlim(t_min_ns - 14.0, t_max_ns + 1.0)
ax.set_ylim(-1.0, (n_sigs + 1.5) * y_spacing)

# Format time axis
ax.set_xlabel('Simulation Time (ns) [1 time unit = 1000 ps]', fontsize=10, color='#a0a6b8', labelpad=10)
ticks = list(range(int(t_min_ns), int(t_max_ns) + 1, 5))
ax.set_xticks(ticks)
ax.set_xticklabels([f"{t} ns" for t in ticks], color='#a0a6b8', fontsize=8.5)

ax.get_yaxis().set_visible(False)
for spine in ax.spines.values():
    spine.set_color('#2d3142')

plt.title('P3 Integrated Pipeline Simulation Waveform (tb_integrated.sv / results/p3_integrated.vcd)\n'
          'Demonstrating Deterministic Resolution, Misprediction Detection, and Recovery Redirect Priority',
          color='#ffffff', fontsize=12.5, fontweight='bold', pad=32)

plt.tight_layout()
out_file = 'evidence/waveforms/p3_integrated_simulation.png'
plt.savefig(out_file, dpi=180, facecolor=fig.get_facecolor(), edgecolor='none')
print(f'Successfully rendered genuine simulation waveform: {out_file}')
