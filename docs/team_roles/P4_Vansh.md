# P4 — Vansh: Baseline predictors, branch traces and verification

**Personal responsibility:** Implement/strengthen fair baseline comparisons and build reproducible self-checking branch traces for the full project.

**Timeline:** 4 Nov: traces and reference model; 5–8 Nov: verified comparison suite; 9–11 Nov: regression and reports.

## Files owned
- rtl/predictor_1bit.v (starter exists; review, improve and verify)
- testbench/tb_predictor.v (starter demonstration; expand with assertions)
- testbench/tb_comparison.sv (new independent self-checking comparison)
- traces/loop_trace.csv, traces/alternating_trace.csv, traces/beq_bne_trace.csv (new reproducible inputs)
- scripts/reference_predictors.py (new independent Python oracle, if useful)
- docs/P4_TEST_PLAN.md (oracle rules, trace schema and coverage)

## Interface contract
- Always-not-taken predicts 0 for every conditional branch.
- 1-bit BHT predicts using the last outcome for the indexed branch, reset to Not Taken.
- All predictors receive the same dynamic branch trace in the same order.
- Record the prediction BEFORE updating the corresponding predictor with its actual outcome.
- A BEQ is Taken when two input operands are equal; BNE is Taken when they are unequal.
- Trace schema should include sequence number, PC, operation, operands, target and actual outcome.

## Implementation steps
1. Read existing 1-bit predictor and demo; do not count them as newly authored work until you add genuine improvements.
2. Design three deterministic trace classes: loop-dominated (TTTTN), alternating (TNTN), and mixed BEQ/BNE with two branch PCs; add a seeded random pattern optionally.
3. Build a small reference model or manual expected table that does not reuse the RTL internals.
4. Write a self-checking comparison testbench that compares pre-update predictions to expected outcomes and fails on mismatches.
5. Generate per-strategy correct count, total, accuracy, and misprediction count; export machine-readable CSV for P5.
6. Add tests for cold start, counter hysteresis, 1-bit weakness at loop exit, alternation, and index aliasing.
7. Coordinate with P3 on integrated recovery traces and show one direction vs one target misprediction separately.
8. Submit a PR with a trace-generation method, expected values, and a waveform screenshot.

## Tests / evidence
- Baseline correctness (always 0).
- 1-bit learns last outcome for same BHT entry.
- Same test trace used for each predictor; no early update or look-ahead.
- BEQ and BNE operands correctly produce actual_taken.
- Zero-bias from warm-up: disclose cold-start state and whether warm-up excluded.
- 2-bit predictor is not assumed to beat 1-bit on every possible trace; show counterexample if observed.

## Acceptance checklist
- [x] Repeatable traces and independently validated results CSV (evidence/metrics/comparison_summary.csv).
- [x] Testbench fails nonzero on mismatches (tb_comparison.sv & tb_predictor.v).
- [x] Evidence includes representative loop and alternating cases (traces/ & evidence/waveforms/).
- [x] PR has meaningful code authored by Vansh and clear explanations (feature/vansh-baselines-verification).

## Viva questions
**Q: Why compare with always-not-taken?**

A: It is a simple reference with essentially no dynamic hardware state.

**Q: What does 1-bit history remember?**

A: The most recent observed branch direction for the indexed entry.

**Q: Why are loop exits hard for 1-bit?**

A: One Not Taken exit flips next prediction; first Taken on re-entry can be missed.

**Q: How do we avoid data leakage?**

A: We record a prediction before training on its actual outcome.

**Q: Can 2-bit lose to 1-bit?**

A: Yes, on some patterns; comparing identical traces is what matters.

**Q: What is a self-checking testbench?**

A: It independently computes expected outputs and fails automatically on mismatches.


## GitHub branch
`feature/vansh-baselines-verification`

**Authenticity note:** Commit only your actual work; do not claim authorship of the original shared starter files if you did not write them.
