# Illustrative CPI assumptions

Source: `evidence/metrics/comparison_summary.csv` (P4 HDL/oracle reconciled counts).
SHA-256: `f2c2df6e2641a4b1bc3634b4b30069cf626e8409d57ff4f72b9b38d0501ca804`.

Assumed ideal CPI = 1 cycles/instruction.
Assumed branch fraction = 0.2 branches/instruction.
Assumed misprediction penalty = 3 cycles/misprediction.

Accuracy (%) = 100 * correct / total.
Misprediction rate = mispredict / total = 1 - correct / total.
Illustrative CPI = ideal CPI + branch fraction * misprediction rate * penalty cycles.

These parameters are assumptions, not measurements. The branch-only traces do
not measure the fraction of all CPU instructions that are branches. The model
uses direction misses only; BTB target misses, pipeline stalls and other CPU
costs are excluded. It does not establish measured CPU CPI or speedup.
All predictors see identical workloads, with cold starts and 16-entry BHTs.
Overall counts are summed across workloads before computing ratios.

Independent example from Loop-dominated (TTTTN): 2-bit correct = 31 of 40,
so accuracy = 77.5%, miss rate = 9/40 = 0.225. Under the assumptions above,
illustrative CPI = 1 + 0.2 * 0.225 * 3
= 1.135000.

Reproduce defaults: `make metrics`. Override with
`python3 scripts/collect_metrics.py --ideal-cpi 1 --branch-fraction 0.2 --penalty-cycles 3`.
Outputs: `accuracy.csv`, `accuracy.svg`, and this assumptions file.
