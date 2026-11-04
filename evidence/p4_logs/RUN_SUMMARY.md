# P4 Verification Run Summary

**Date:** 4 November 2026  
**Author:** Vansh (P4 — Baseline Predictors, Branch Traces and Verification)  
**Host:** Darwin arm64 (macOS)  
**Simulators & Tools:** Icarus Verilog 13.0, Yosys 0.70+post, Python 3.12 / uv  

---

## 1. Test Suite Execution Summary

| Test Target | Testbench / Script | Checks | Result | Log File |
|---|---|:---:|:---:|---|
| `make test-p4-unit` | `testbench/tb_predictor.v` | 113 | ✅ **113/113 PASS** | `evidence/p4_logs/p4_predictor_test.log` |
| `make test-p4-comparison` | `testbench/tb_comparison.sv` | 523 | ✅ **523/523 PASS** | `evidence/p4_logs/p4_comparison_test.log` |
| `make test-p4-oracle` | `scripts/reference_predictors.py` | 130 branches | ✅ **100% MATCH** | `evidence/metrics/comparison_summary.csv` |
| `make synth-p4-checked` | Yosys Generic Synthesis | Formal check | ✅ **0 problems** | `evidence/p4_logs/p4_synthesis_checked.log` |
| **Total Assertions** | | **636 checks** | ✅ **ALL PASS** | |

---

## 2. Benchmark Accuracy Results (`evidence/metrics/comparison_summary.csv`)

| Workload Name | Dynamic Branches | Baseline (Always NT) | 1-Bit BHT Predictor | 2-Bit BHT Predictor | Key Phenomenon Observed |
|---|:---:|:---:|:---:|:---:|---|
| **Loop-dominated (`TTTTN`)** | 40 | 20.00% (8/40) | 60.00% (24/40) | **77.50% (31/40)** | 2-bit hysteresis prevents re-entry misprediction |
| **Strict Alternating (`TNTN`)** | 40 | **50.00% (20/40)** | 0.00% (0/40) | 0.00% (0/40) | Baseline beats dynamic predictors (counterexample) |
| **Mixed BEQ/BNE Aliased** | 50 | 40.00% (20/50) | 46.00% (23/50) | **48.00% (24/50)** | Destructive aliasing at entry 4 (`0x1010` vs `0x1050`) |
| **Consolidated Overall** | **130** | **36.92% (48/130)** | **36.15% (47/130)** | **42.31% (55/130)** | Zero discrepancies between Python oracle & Verilog |

---

## 3. Coverage Breakdown

### `tb_predictor.v` (113 checks)
- **Cold Start (4 checks):** Verifies all 16 entries reset cleanly to `0` (1-bit) and `01` (2-bit Weakly Not Taken).
- **32-Branch Demonstration (96 checks):** Cycle-by-cycle assertions of baseline, 1-bit, and 2-bit predictions against golden reference model across 4 iterations of loop `TTTTN` and 12 alternating branches.
- **Benchmark Totals (1 check):** Asserts exact matching of historical totals: `TOTAL=32`, `BASE=10`, `ONE=12`, `TWO=15`.
- **Disabled Update (1 check):** Verifies `update_valid=0` guarantees no internal state mutation.
- **Reset Priority (1 check):** Verifies active-high `reset` dominates concurrent `update_valid=1`.
- **Intentional Aliasing (2 checks):** Verifies cross-talk between `0x00000100` and `0x00000140` mapping to table index 0.

### `tb_comparison.sv` (523 checks)
- **Architectural Operand Validation (130 checks):** Evaluates `BEQ` (`rs1 == rs2`) and `BNE` (`rs1 != rs2`) operands to guarantee `actual_taken` matches architectural specifications.
- **Pre-Update Prediction Sampling (390 checks):** Evaluates Baseline, 1-bit, and 2-bit outputs combinational at `#1` before posedge clock update, proving zero data leakage.
- **P3 Recovery Coordination (3 checks):**
  - Direction misprediction (Predicted Taken $\implies$ Actual Not Taken) asserts `flush=1`, `redirect=1`, `redirect_pc=0x00001004` (PC+4).
  - Target misprediction (Predicted Taken $\implies$ Actual Taken with target mismatch) asserts `flush=1`, `redirect=1`, `redirect_pc=0x00005000` (resolved target).

---

## 4. Hardware Synthesis Statistics (`evidence/p4_logs/p4_synthesis_checked.log`)

Under Yosys 0.70 with generic gate mapping (`check -assert`):
- `predictor_1bit`: Synthesized to **92 cells** (16 `$_SDFFCE_PN0P_` DFFs, 29 AND, 10 MUX, 17 OR) with **0 reported problems**.
- `predictor_top`: Synthesized to **284 cells** (16 DFFs for 1-bit, 32 DFFs for 2-bit BHT, 73 AND, 53 MUX, 42 OR) with **0 reported problems**.

---

## 5. Waveform Evidence

High-resolution waveform image rendered at `evidence/waveforms/p4_comparison.png` via `scripts/render_p4_waveform.py`, visually documenting the loop exit penalty at 60 ns and the hysteresis protection on loop re-entry at 70 ns.
