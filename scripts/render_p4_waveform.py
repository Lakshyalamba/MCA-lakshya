#!/usr/bin/env python3
"""
scripts/render_p4_waveform.py
Author: Vansh (P4 — Baseline Predictors, Branch Traces and Verification)

Renders genuine simulation waveform screenshot from results/p4_comparison.vcd.
Matches the professional dark theme of modern digital waveform viewers (Surfer / GTKWave).

Features:
  - Dynamic VCD header resolution: parses $scope and $var definitions to resolve
    signal identifiers at runtime rather than relying on hardcoded symbols.
  - Verifies presence of all required signals and fails cleanly if any are missing.
  - Visualizes loop-exit misprediction and 2-bit hysteresis protection on re-entry.
  - Clearly labels simulation clock period (10 ns) as simulation timing rather than
    an FPGA hardware frequency claim.
"""

import os
import sys
import matplotlib.pyplot as plt
import matplotlib.patches as patches

vcd_path = 'results/p4_comparison.vcd'
output_img = 'evidence/waveforms/p4_comparison.png'

if not os.path.exists(vcd_path):
    print(f"Error: {vcd_path} not found. Run simulation first.", file=sys.stderr)
    sys.exit(1)

with open(vcd_path, 'r') as f:
    lines = f.readlines()

# Required target signals from tb_comparison scope: (signal_name, is_bus, color)
REQUIRED_SIGNALS = [
    ('clk', False, '#00ffcc'),
    ('lookup_pc', True, '#00d4ff'),
    ('actual_taken', False, '#33ff99'),
    ('baseline_taken', False, '#888888'),
    ('one_bit_taken', False, '#ffaa00'),
    ('two_bit_taken', False, '#33ccff'),
    ('two_bit_state', True, '#cc88ff'),
    ('predicted_next_pc', True, '#00ffaa'),
    ('update_valid', False, '#ffff00'),
    ('res_mispredict', False, '#ff3366'),
    ('res_redirect', False, '#ff3366'),
    ('res_redirect_pc', True, '#ff99bb'),
]

# Dynamically parse VCD header declarations ($scope, $var, $upscope, $enddefinitions)
symbol_map = {}
scope_stack = []
data_start_idx = 0

for idx, line in enumerate(lines):
    line = line.strip()
    if not line:
        continue
    if line.startswith('$scope'):
        parts = line.split()
        if len(parts) >= 3:
            scope_stack.append(parts[2])
    elif line.startswith('$upscope'):
        if scope_stack:
            scope_stack.pop()
    elif line.startswith('$var'):
        parts = line.split()
        if len(parts) >= 5:
            sym = parts[3]
            var_name = parts[4]
            current_scope = ".".join(scope_stack)
            if current_scope.endswith('tb_comparison') or 'tb_comparison' in scope_stack:
                symbol_map[var_name] = sym
    elif line.startswith('$enddefinitions'):
        data_start_idx = idx + 1
        break

# Verify all required signals were resolved from the VCD header
target_vars = []
missing_signals = []
for name, is_bus, color in REQUIRED_SIGNALS:
    if name in symbol_map:
        sym = symbol_map[name]
        target_vars.append((name, sym, is_bus, color))
    else:
        missing_signals.append(name)

if missing_signals:
    print(f"ERROR: Missing required signals in VCD header: {missing_signals}", file=sys.stderr)
    print(f"Discovered symbols in tb_comparison: {list(symbol_map.keys())}", file=sys.stderr)
    sys.exit(1)

print(f"[P4 Waveform] Successfully resolved {len(target_vars)} signals dynamically from VCD header.")

transitions = {sym: [] for _, sym, _, _ in target_vars}
current_time = 0

for line in lines[data_start_idx:]:
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

# Time window: 35,000 ps to 95,000 ps (35 ns to 95 ns)
# Captures:
#   - Steady-state taken iterations (35-55 ns)
#   - Loop exit (55-65 ns, actual=0, exit misprediction)
#   - Loop re-entry (65-75 ns, actual=1: 1-bit misses, 2-bit hits!)
#   - Subsequent taken iterations (75-95 ns)
t_min_ps = 35000
t_max_ps = 95000
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

def fmt_hex(val_str, is_state=False):
    try:
        val_int = int(val_str, 2)
        if is_state:
            names = ["00 (SN)", "01 (WN)", "10 (WT)", "11 (ST)"]
            return names[val_int] if val_int < 4 else f"{val_int:02b}"
        return f"0x{val_int:08X}"
    except Exception:
        return val_str

fig, ax = plt.subplots(figsize=(16, 9.5), dpi=180)
fig.patch.set_facecolor('#10121a')
ax.set_facecolor('#161822')

y_spacing = 2.0
n_sigs = len(target_vars)

# Background row bands
for i in range(n_sigs):
    y_base = (n_sigs - 1 - i) * y_spacing
    if i % 2 == 0:
        ax.axhspan(y_base - 0.4, y_base + 1.4, color='#1c1f2e', alpha=0.6, zorder=0)

# Vertical grid lines (every 5 ns)
for t_ns in range(int(t_min_ns), int(t_max_ns) + 1, 5):
    ax.axvline(t_ns, color='#282b3d', linestyle=':', linewidth=0.8, zorder=1)

# Annotate Test Highlights
ax.axvspan(55, 65, color='#ff3366', alpha=0.10, zorder=0)
ax.text(60, (n_sigs) * y_spacing + 0.1,
        "LOOP EXIT (Iter 4: actual=0)\n1-bit & 2-bit both mispredict\n2-bit decrements 11->10 (Weakly Taken)",
        color='#ff6688', fontsize=8.5, fontweight='bold', ha='center', va='bottom',
        bbox=dict(boxstyle='round,pad=0.35', facecolor='#3d1822', edgecolor='#ff3366', alpha=0.9))

ax.axvspan(65, 75, color='#00ff99', alpha=0.12, zorder=0)
ax.text(70, (n_sigs) * y_spacing + 0.1,
        "LOOP RE-ENTRY (Iter 0: actual=1)\n1-bit: predicts 0 -> MISPREDICT (Double Penalty!)\n2-bit: predicts 1 -> HIT (Protected by Hysteresis!)",
        color='#00ffaa', fontsize=8.5, fontweight='bold', ha='center', va='bottom',
        bbox=dict(boxstyle='round,pad=0.35', facecolor='#162e24', edgecolor='#00ff66', alpha=0.9))

# Draw signals
for i, (name, sym, is_bus, color) in enumerate(target_vars):
    y_base = (n_sigs - 1 - i) * y_spacing
    sig_trans = [(ct / 1000.0, val) for ct, val in transitions[sym] if t_min_ps <= ct <= t_max_ps]

    val_start = get_val_at(sym, t_min_ps)
    full_trans = [(t_min_ns, val_start)] + sig_trans + [(t_max_ns, get_val_at(sym, t_max_ps))]

    ax.text(t_min_ns - 1.2, y_base + 0.45, name, color='#d8dde8', fontsize=9.5,
            fontweight='bold', fontfamily='monospace', ha='right', va='center')

    if not is_bus:
        pts = []
        for j in range(len(full_trans) - 1):
            t_curr, val_curr = full_trans[j]
            t_next, _ = full_trans[j + 1]
            y_val = y_base + (1.0 if val_curr == '1' else 0.0)

            pts.append((t_curr, y_val))
            pts.append((t_next, y_val))

        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        ax.plot(xs, ys, color=color, linewidth=1.6, zorder=2)
        ax.fill_between(xs, y_base, ys, color=color, alpha=0.15, zorder=1)
    else:
        for j in range(len(full_trans) - 1):
            t_curr, val_curr = full_trans[j]
            t_next, _ = full_trans[j + 1]
            if t_next <= t_curr:
                continue

            dt = t_next - t_curr
            bevel = min(0.3, dt * 0.2)

            poly_x = [t_curr, t_curr + bevel, t_next - bevel, t_next, t_next - bevel, t_curr + bevel, t_curr]
            poly_y = [y_base + 0.5, y_base + 1.0, y_base + 1.0, y_base + 0.5, y_base, y_base, y_base + 0.5]
            ax.fill(poly_x, poly_y, facecolor='#1f2335', edgecolor=color, linewidth=1.2, zorder=2)

            is_st = (name == 'two_bit_state')
            txt = fmt_hex(val_curr, is_state=is_st)
            if dt > 3.0:
                ax.text(t_curr + dt / 2.0, y_base + 0.5, txt, color='#ffffff', fontsize=8,
                        fontfamily='monospace', fontweight='bold', ha='center', va='center', zorder=3)

# Formatting axes
ax.set_xlim(t_min_ns - 12.0, t_max_ns + 1.0)
ax.set_ylim(-0.8, n_sigs * y_spacing + 2.4)
ax.set_xlabel("Simulation Time (ns) [1 cycle = 10 ns simulation clock period; not a measured FPGA operating frequency]",
              color='#a0a6b8', fontsize=10, labelpad=8)
ax.set_xticks(range(int(t_min_ns), int(t_max_ns) + 1, 5))
ax.tick_params(axis='x', colors='#a0a6b8', labelsize=9)
ax.tick_params(axis='y', left=False, labelleft=False)

for spine in ax.spines.values():
    spine.set_color('#282b3d')

plt.title("MCA Project #5 — P4 Branch Predictor Verification Waveform (tb_comparison)\n"
          "Comparison of Baseline, 1-bit BHT, and 2-bit BHT on Loop-Dominated Workload (TTTTN)",
          color='#ffffff', fontsize=12, fontweight='bold', pad=18)

os.makedirs(os.path.dirname(output_img), exist_ok=True)
plt.tight_layout()
plt.savefig(output_img, dpi=180, facecolor=fig.get_facecolor(), edgecolor='none')
plt.close()
print(f"[P4 Waveform] Rendered high-resolution waveform image: {output_img}")
