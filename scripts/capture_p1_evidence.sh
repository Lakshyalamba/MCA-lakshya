#!/usr/bin/env bash
set -euo pipefail

# Run from any directory; save real evidence only after tests pass.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

make verify-p1
make demo

OUT="evidence/P1_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUT"
for f in \
  p1_test.log p1_extended_test.log \
  p1_scoreboard_2.log p1_scoreboard_4.log p1_scoreboard_5.log \
  p1_synthesis_checked.log simulation.log; do
  test -s "results/$f" || { echo "Missing evidence: results/$f" >&2; exit 1; }
  cp "results/$f" "$OUT/$f"
done

{
  echo '# P1 verified run evidence'
  echo
  echo "- UTC timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
  echo "- Git commit: $(git rev-parse HEAD 2>/dev/null || echo 'not under git')"
  echo "- Host: $(uname -srm)"
  echo "- Icarus Verilog: $(iverilog -V 2>&1 | sed -n '1p')"
  echo "- Yosys: $(yosys -V 2>&1 | sed -n '1p')"
  echo
  echo '## Test summaries'
  grep -hE 'ALL P1 CHECKS PASSED|ALL EXTENDED P1 CHECKS PASSED|P1 SCOREBOARD PASS' "$OUT"/*.log
  echo
  echo '## Generic synthesis'
  echo 'See p1_synthesis_checked.log for post-synthesis design stats.'
  echo 'No FPGA timing/frequency claims have been made.'
} > "$OUT/RUN_SUMMARY.md"

printf '\nP1 EVIDENCE CAPTURED: %s\n' "$OUT"
cat "$OUT/RUN_SUMMARY.md"
printf '\nOpen results/p1_bht.vcd in Surfer and manually save a waveform screenshot into the evidence folder.\n'
