# P5 report contribution by Lakshya

Status: section draft for team review, to integrate after the P5 synthesis and
metrics PRs. This is not the final IEEE-formatted report.

## Reproducible synthesis and evaluation methodology

The evaluation uses three deterministic synthetic workloads provided by P4:
loop-dominated TTTTN (40 branches), strict alternation (40), and mixed BEQ/BNE
with index aliasing (50). P4's Verilog simulation and independent Python oracle
are reconciled before P5 derives additional metrics. Each predictor receives the
same resolved sequence, predicts before updating, and begins with the specified
cold state. These traces demonstrate predictor behavior rather than represent
an application benchmark suite.

The metrics collector validates CSV column order, integer count consistency,
published accuracy, workload uniqueness and aggregate totals. Direction accuracy
is `100 * correct / total`; direction miss rate is `mispredict / total`.
Aggregate accuracy is calculated from summed counts rather than averaging the
three percentages. The generated SVG includes workload names, branch counts,
predictor labels and a shared percentage axis.

Across 130 branches the always-not-taken, 1-bit and 2-bit predictors correctly
predict 48, 47 and 55 branches respectively: 36.92%, 36.15% and 42.31% accuracy.
On the loop trace the 2-bit predictor reaches 77.50% versus 60.00% for 1-bit.
On strict alternation both dynamic predictors obtain 0%, compared with 50% for
the static baseline. This workload dependence limits claims of universal benefit.
The counts are P4's results, independently rerun during P5 integration.

For illustration, assume ideal CPI of 1, branch frequency of 0.2 branches per
instruction, and a penalty of 3 cycles per direction misprediction. The model is
`CPI = ideal_CPI + branch_frequency * miss_rate * penalty`.
Using aggregate counts gives CPI estimates of 1.378462, 1.383077 and 1.346154
for always-not-taken, 1-bit and 2-bit respectively. These parameters are assumed;
branch-only traces cannot measure branch frequency among all instructions.
Target misses, pipeline stalls and other processor costs are not included.
These values do not establish measured CPU CPI or application speedup.

The synthesis driver runs each existing synthesizable RTL top in a fresh Yosys
process, checks hierarchy, flattens generic synthesis and executes `check -assert`.
Full logs, netlists, tool version, cell-type breakdowns and RTL source hashes
are retained under `results/synthesis/`. The summary is published only after
all six tops succeed. Default parameters are used. Results describe generic
logic and registers; FPGA LUT utilization and maximum frequency require a
device, constraints and an appropriate technology/timing flow and remain unmeasured.
`predictor_top` is the direction-comparison wrapper; the combined P1/P2/P3
harness is simulation-only. Counts from separate tops must not be added as a
whole-CPU resource result.

## Individual contribution for review

Lakshya added the reproducible synthesis driver, validated metrics/CPI collector,
deterministic comparison chart, focused regression checks, CI workflows,
evaluation methodology section and report/video assembly handoff. P1–P4 retain
authorship of their RTL, testbenches, trace generator, oracle and reconciler.
Commit/PR links will be inserted after publication. The final report still
requires all authors' review, and the video requires actual recordings and an
accessible hosted link.

## Evidence to include after the P5 PRs merge

- `evidence/synthesis/summary.md`: generic counts and tool version; regenerate with `make synth-all`.
- `evidence/metrics/comparison_summary.csv`: P4 reconciled source counts.
- `evidence/metrics/accuracy.csv` and `accuracy.svg`: derived table and chart.
- `evidence/metrics/cpi_assumptions.md`: assumptions, formulas and source SHA-256.
- Commands: `make test`, `make synth-all`, `make metrics test-p5-metrics`.

The primary experimental sources are the committed RTL, P4 reconciled counts
and fresh tool outputs. Literature citations remain with the relevant authors'
sections and must be checked before final report assembly.
