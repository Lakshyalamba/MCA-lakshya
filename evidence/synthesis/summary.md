# P5 generic synthesis evidence

Tool: `Yosys 0.70+post (git sha1 0c11ea098be065e585a90a06e7b7da49936cf231, Release, AppleClang clang++ 21.0.0.21000334)`.

Command: `make synth-all`. Each top runs in a separate Yosys process with
`hierarchy -check`, `synth -flatten`, `check -assert`, and default RTL parameters.
All six synthesis/check commands succeeded in this run.

| RTL top | Generic cells after flattening |
| --- | ---: |
| `predictor_2bit` | 193 |
| `predictor_1bit` | 92 |
| `branch_target_buffer` | 2404 |
| `next_pc_mux` | 91 |
| `branch_resolution` | 225 |
| `predictor_top` | 278 |

These are generic logic/register cells, not FPGA LUT counts. No device, clock
constraint, placement/routing or timing analysis is included; maximum MHz is unmeasured.
Counts are not additive across tops. `predictor_top` combines direction predictors only;
P1/P2/P3 integration is currently a simulation testbench, not a synthesizable CPU top.

Raw logs, netlists, tool version, per-type counts and RTL SHA-256 hashes: `results/synthesis/`.
Generated results are ignored by Git; reproduce locally or download the CI artifact.
