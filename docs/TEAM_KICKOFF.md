# Day 1 kickoff (five-person MCA team)

Do not start five different projects. Everyone builds ONE branch predictor unit, with clear interfaces and test ownership.

| Person | Owns (specific hardware or analysis) | First PR and acceptance gate |
|---|---|---|
| P1 (you) | 2-bit predictor FSM + 16-entry BHT + independent update/lookup | `rtl/branch_history_table.v`, `rtl/predictor_2bit.v`, `testbench/tb_p1_bht.sv` with `make test-p1` PASS |
| P2 | Tagged 16-entry Branch Target Buffer (BTB) | `rtl/branch_target_buffer.v` + unit test: reset, hit/miss, correct target, index collision/tag replacement |
| P3 | Branch resolution, flush and redirect interface | `rtl/branch_resolution.v` + unit tests for direction and target mispredictions |
| P4 | 1-bit and always-not-taken baselines + trace-driven reference verification | `rtl/predictor_1bit.v` validation; self-checking tests and loop/alternating/BEQ/BNE traces |
| P5 | Hardware synthesis + reproducible experiment/report preparation | Synthesis script and actual Yosys utilization, waveform capture, diagrams; later visual demo |

## Parallel start

1. Everyone agrees to `docs/INTERFACES.md` (pin down signals **before** committing integrations).
2. Create GitHub repository and branch: `feature/p1-bht`, `feature/p2-btb`, `feature/p3-resolution`, `feature/p4-verification`, `feature/p5-synthesis`.
3. Each person adds OWN tests and opens a PR. One reviewer other than the author approves each PR.
4. Day 2 integration merges green PRs only, preserving prediction metadata at resolution.
5. Day 3 comparison/report demo after actual results exist; do not manufacture accuracy, resource counts or CPI.

## Completion checklist

- [ ] `make test-p1` passes, including saturation/reset/aliasing/independent lookup-update.
- [ ] P2 BTB hit/miss and tag collisions pass.
- [ ] P3 redirect and flush tests pass, even for correct direction but wrong target.
- [ ] P4 runs identical traces against all three direction predictors and exports CSV.
- [ ] P5 captures synthesis utilization from Yosys; estimates CPI using stated branch frequency and misprediction penalty; accurately describes timing constraints.
- [ ] Integrated `make test` + additional subsystem tests pass.
