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

## Confirmed GitHub synthesis evidence

[Successful CI run 42062136317](https://github.com/S-h-u-b-h-1/MCA/actions/runs/42062136317)
built commit `17c2e9e6645774535cac366796b78ed7d6a0fb3a` with
`Yosys 0.33 (git sha1 2584903a060)` on Ubuntu. The six-top synthesis,
failed-tool propagation check and artifact upload all passed. Download the
`p5-generic-synthesis` artifact from that run, or use:

```bash
gh run download 42062136317 --repo S-h-u-b-h-1/MCA --name p5-generic-synthesis --dir results/ci-synthesis-42062136317
```

The downloaded artifact was independently inspected: all six full logs contain
successful design checks; each netlist's cell count matches the manifest's total
and cell-type breakdown; all seven RTL SHA-256 hashes match the source checkout.
It includes the actual version and complete logs/netlists, not screenshots alone.

| Top | Mac Yosys 0.70+post | Ubuntu CI Yosys 0.33 |
| --- | ---: | ---: |
| predictor_2bit | 193 | 162 |
| predictor_1bit | 92 | 88 |
| branch_target_buffer | 2404 | 2498 |
| next_pc_mux | 91 | 112 |
| branch_resolution | 225 | 214 |
| predictor_top | 278 | 226 |

Both columns are generic cells from the same RTL with different tool versions.
Keep the original Mac summary and the CI artifact separately; these are not
technology-mapped resource results or a controlled comparison of tool quality.
CI artifacts have finite retention: preserve the downloaded evidence with the
submission before expiry. A later rerun should retain its own run ID/version.

## Maximum-frequency feasibility review

As of 6 November 2026, no agreed FPGA part/package, speed grade, board constraint
file or clock/I/O timing specification is recorded in this repository. Locally,
Yosys is available but `nextpnr-ice40` and `nextpnr-ecp5` are not on PATH. The
current CI installs Yosys and Icarus, without a place-and-route/timing flow.
Consequently **maximum operating frequency has not been measured**. A 10 ns
simulation stimulus is not evidence of a 100 MHz implementation.

A supported route is feasible in principle: [nextpnr's official documentation](https://github.com/YosysHQ/nextpnr#readme)
describes timing-driven place and route for Lattice iCE40 and ECP5, and an
example pairing `synth_ice40` with nextpnr and IceStorm. Yosys documents
[device-specific synthesis commands](https://yosyshq.readthedocs.io/projects/yosys/en/latest/using_yosys/synthesis/synth.html).
This establishes a candidate flow, not a timing result for our design.

Before implementing a target flow, the team must agree on:

- Exact device, package and speed grade, plus available tool/device databases.
- RTL top and parameter values; a timing wrapper if needed, with its added
  registers and I/O assumptions disclosed. The simulation harness is not a CPU top.
- Board pin/clock constraints, required clock period, input/output delays and
  treatment of reset and unconstrained paths.
- Mapping and place-and-route commands, tool versions and seed; archived timing
  reports with critical paths, slack and unconstrained-path checks.

Report only the resulting scope-specific post-route timing estimate after those
checks. Device timing estimates also differ from an on-board frequency measurement.
Until the team chooses the target, ask the leader to confirm with faculty whether
the explicitly disclosed unmeasured-Fmax limitation is acceptable. Do not choose
an arbitrary part merely to generate a MHz number.
