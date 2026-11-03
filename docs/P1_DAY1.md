# P1 — Your first coding milestone

You own the 2-bit saturating counter and indexed BHT. Do **not** build a full CPU.

1. Run `make test-p1`. It should check reset, saturation at 00 and 11, independent table entries, aliasing, and separation of update and lookup PCs. If it fails, fix RTL first.
2. Read `rtl/branch_history_table.v` carefully. Explain line-by-line how `lookup_index` and `update_index` are calculated and why updates occur on the clock edge.
3. Read `rtl/predictor_2bit.v`: it is a wrapper; `prediction_state[1]` is the direction prediction.
4. Open `results/p1_bht.vcd` using Surfer and observe `clk`, `reset`, `lookup_pc`, `update_pc`, `actual_taken`, `update_valid`, `prediction_state`, `predict_taken`.
5. Run `make synth-p1` once Yosys is available. Save the log; generic hardware synthesis is not equivalent to timing analysis.
6. Commit these three files on `feature/p1-bht`; open a PR with your console PASS output and 1 waveform screenshot.

## Signals you must be able to explain

- `lookup_pc`: fetch-stage PC, used to make a *new* prediction.
- `update_pc`: older branch PC, used to update its *own* BHT entry when resolved.
- `update_valid`: resolution event gate; no update otherwise.
- `actual_taken`: resolved branch truth, supplied after execution.
- `prediction_state`: 2-bit counter value before/after updates, depending on the clock instant.
- `predict_taken`: the most significant bit of prediction_state.

## Immediate viva questions

- Why is `01` a sensible initialization?  Why not `00`?
- Explain all four states and saturation at 00/11.
- Why do we ignore `PC[1:0]` for aligned 32-bit instructions?
- Why do `0x100` and `0x140` map to the same BHT index?
- What is aliasing, and what problem can it cause?
- Why should `lookup_pc` and `update_pc` be different signals?
- Explain why a BHT alone does NOT predict branch target address.
- What happens to the fetched pipeline instructions on a misprediction?
