# Reproducing P5 generic synthesis

Install Python 3 and Yosys, then run `make synth-all` from a clean checkout.
The shell entry point also works from other directories. Override executable
names using `make synth-all YOSYS=/path/to/yosys PYTHON=/path/to/python3`.

Each of P1's 2-bit predictor, P4's 1-bit predictor, P2's tagged BTB,
P3's next-PC mux and branch resolution, and the direction comparison top
runs in a fresh process. All RTL dependencies are read, hierarchy is checked,
and `synth -flatten`, `check -assert`, `stat`, and `write_json` run in order.
A nonzero Yosys exit stops the flow and no success summary is published.
A previous summary is invalidated at the start of a rerun to prevent stale claims.

`results/synthesis/` retains the full tool logs and JSON netlists. Its manifest
records tool version, exact RTL source hashes, cell totals and cell-type counts.
`evidence/synthesis/summary.md` is generated only after every top succeeds.
CI uploads the raw generated directory even if a later step fails.
Different Yosys/ABC versions may produce different generic cell counts.

The current `predictor_top` is a direction-comparison wrapper. The P1/P2/P3
combined harness is in `testbench/tb_integrated.sv`, which is not a synthesis top.
Do not sum separately synthesized tops to claim whole-system resources.
There is no device-specific LUT or maximum-frequency result in this flow.
