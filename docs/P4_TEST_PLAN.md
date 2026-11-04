# P4 Verification & Test Plan: Baseline Predictors, Branch Traces, and Comparative Evaluation

**Module:** P4 — Baselines, Branch Traces and Verification  
**Author:** Vansh (Roll No: P4)  
**Project:** Dynamic Branch Prediction Subsystem (MCA Project #5)  
**Date:** 4 November 2026  
**Status:** Complete & Verified  

---

## 1. Scope & Verification Objectives

The primary objective of P4 is to build an independent, reproducible, and self-checking verification environment that rigorously evaluates branch prediction accuracy and control interactions without data leakage or architectural bias.

Key deliverables verified:
1. **RTL Module:** Improved and parameterized 1-bit BHT predictor (`rtl/predictor_1bit.v`).
2. **Predictor Top Demonstration:** Enhanced `testbench/tb_predictor.v` with 113 assertions verifying cold start, 32-branch benchmark, disabled updates, reset priority, and index aliasing.
3. **Comparative Verification Suite:** Multi-trace self-checking testbench (`testbench/tb_comparison.sv`) with 523 assertions comparing Baseline (Always Not Taken), 1-bit BHT, and 2-bit BHT across identical dynamic instruction sequences.
4. **Reproducible Trace Suite:** Deterministic benchmark traces with full architectural schemas (`traces/loop_trace.csv`, `traces/alternating_trace.csv`, `traces/beq_bne_trace.csv`).
5. **Independent Python Oracle:** Standalone behavioral simulator (`scripts/reference_predictors.py`) computing mathematical expected predictions and summary metrics for P5 synthesis and CPI analysis.
6. **Pipeline Recovery Coordination:** Directed checks in `tb_comparison.sv` verifying execute-stage pipeline control signals (`mispredict`, `flush`, `redirect`, `redirect_pc`) on direction vs target mispredictions in coordination with P3.

---

## 2. Standardized Trace Schema

Every dynamic branch event is represented in a machine-readable CSV format with architectural operand data:

```csv
seq,pc,op,rs1_val,rs2_val,target,actual_taken
```

| Field | Type | Description |
|---|---|---|
| `seq` | Integer | Monotonically increasing dynamic execution sequence counter |
| `pc` | 32-bit Hex (`0x...`) | Program Counter address of the conditional branch instruction |
| `op` | String (`BEQ` / `BNE`) | Branch instruction opcode determining the architectural condition |
| `rs1_val` | 32-bit Hex (`0x...`) | Source register 1 operand value at evaluation time |
| `rs2_val` | 32-bit Hex (`0x...`) | Source register 2 operand value at evaluation time |
| `target` | 32-bit Hex (`0x...`) | Resolved target destination address if branch is taken |
| `actual_taken` | Binary (0 or 1) | Architectural outcome: `1` = Taken, `0` = Not Taken |

### Architectural Evaluation Rule
To ensure branch outcomes are derived from valid register states:
- For `BEQ` (Branch Equal):
  $$\text{actual\_taken} = (\text{rs1\_val} == \text{rs2\_val}) \; ? \; 1 : 0$$
- For `BNE` (Branch Not Equal):
  $$\text{actual\_taken} = (\text{rs1\_val} \neq \text{rs2\_val}) \; ? \; 1 : 0$$

Both the SystemVerilog testbench (`tb_comparison.sv`) and the Python oracle (`reference_predictors.py`) assert this invariant on every cycle before presenting the branch to the predictor hardware.

---

## 3. Predictor Contracts & Reference Oracle Rules

All three predictors are evaluated in parallel on the identical dynamic stream in identical order.

### A. Baseline (Always Not Taken)
- **Predict Rule:** Always outputs `predict_taken = 0`.
- **State Storage:** 0 bits (stateless).
- **Update Rule:** None. Serves as the minimal hardware control baseline.

### B. 1-Bit BHT Predictor (`predictor_1bit.v`)
- **Indexing:** $PC[\text{INDEX\_BITS}+1 : 2]$ (word-aligned 4-byte boundaries). Default 4 bits $\implies$ 16 entries.
- **Initial State:** All entries reset to `1'b0` (Not Taken).
- **Predict Rule:** `predict_taken = history[lookup_idx]`.
- **Update Rule:** On rising clock edge with `update_valid = 1`:
  $$\text{history}[\text{update\_idx}] \leftarrow \text{actual\_taken}$$
- **Architectural Weakness:** Lacks hysteresis. On loop exits, it transitions to Not Taken, thereby mispredicting both the loop exit and the subsequent loop re-entry (double misprediction penalty).

### C. 2-Bit Saturating Counter BHT (`predictor_2bit.v`)
- **Indexing:** $PC[\text{INDEX\_BITS}+1 : 2]$. Default 4 bits $\implies$ 16 entries.
- **Initial State:** All entries reset to `2'b01` (Weakly Not Taken) per P1 contract.
- **Counter States:**
  - `00`: Strongly Not Taken
  - `01`: Weakly Not Taken
  - `10`: Weakly Taken
  - `11`: Strongly Taken
- **Predict Rule:** `predict_taken = counter[1]` (MSB: 1 if state $\ge 2$, 0 if state $\le 1$).
- **Update Rule:** Saturating increment on Taken (max `2'b11`), saturating decrement on Not Taken (min `2'b00`).
- **Advantage:** Absorbs transient anomalies (e.g., a single loop exit does not flip prediction from Taken to Not Taken).

---

## 4. Workload Trace Suite Definitions

### Workload 1: Loop-Dominated Workload (`traces/loop_trace.csv`)
- **Structure:** Counted loop with 5 iterations per invocation (4 Taken, 1 Not Taken: `T T T T N`) repeated across 8 invocations ($40$ dynamic branches).
- **Instruction:** `BNE r1, r2, loop_target` where `r1` counts from 1 to 5 and `r2 = 5`.
- **Target:** `0x00001000` (backward jump).
- **Verification Focus:** Loop-exit hysteresis.
  - In steady state (state `11`), iteration 4 exit (actual = 0) decrements the 2-bit counter to `10` (Weakly Taken).
  - On loop re-entry (iteration 0, actual = 1), the 2-bit predictor maintains `predict_taken = 1` and achieves a **correct hit**.
  - Conversely, the 1-bit predictor is updated to `0` on exit, causing it to mispredict the re-entry as Not Taken.
- **Measured Accuracy:**
  - Baseline: 8 / 40 (20.00%)
  - 1-Bit BHT: 24 / 40 (60.00%)
  - 2-Bit BHT: 31 / 40 (77.50%)

### Workload 2: Strict Alternating Workload (`traces/alternating_trace.csv`)
- **Structure:** Strict alternation of outcomes (`T N T N T N...`) across $40$ dynamic branches.
- **Instruction:** `BEQ r1, r2, alt_target` at PC `0x00002000`.
- **Verification Focus:** Pathological counterexample proving requirement: *"2-bit predictor is not assumed to beat 1-bit on every possible trace; show counterexample if observed."*
  - 1-Bit Predictor: Always predicts the previous outcome, resulting in an exact 180° phase error $\implies$ **0% accuracy**.
  - 2-Bit Predictor: Continuously oscillates between states `01` (Weakly Not Taken) and `10` (Weakly Taken), predicting Taken when Not Taken and vice-versa $\implies$ **0% accuracy**.
  - Baseline Predictor: Always predicts Not Taken, correctly predicting all even iterations $\implies$ **50.00% accuracy**.
- **Measured Accuracy:**
  - Baseline: 20 / 40 (50.00%)
  - 1-Bit BHT: 0 / 40 (0.00%)
  - 2-Bit BHT: 0 / 40 (0.00%)

### Workload 3: Mixed BEQ/BNE Aliased Workload (`traces/beq_bne_trace.csv`)
- **Structure:** Realistic multi-branch execution across 3 distinct branch PCs ($50$ dynamic branches):
  1. `PC = 0x00001010` (BHT index 4, tag `0x000040`): `BEQ`, outer loop check (`T T T N`).
  2. `PC = 0x00001024` (BHT index 9, tag `0x000040`): `BNE`, error condition check (85% Taken).
  3. `PC = 0x00001050` (BHT index 4, tag `0x000041`): `BEQ`, mostly Not Taken.
- **Verification Focus:** Index aliasing and destructive interference.
  - Both `0x00001010` and `0x00001050` map to BHT index 4:
    $$\text{Index} = \frac{0\text{x}1010}{4} \pmod{16} = 4, \quad \frac{0\text{x}1050}{4} \pmod{16} = 4$$
  - When Branch 1 trains index 4 towards Taken and Branch 3 updates index 4 towards Not Taken, cross-branch destructive interference degrades accuracy.
- **Measured Accuracy:**
  - Baseline: 20 / 50 (40.00%)
  - 1-Bit BHT: 23 / 50 (46.00%)
  - 2-Bit BHT: 24 / 50 (48.00%)

---

## 5. Timing Protocol & Anti-Data-Leakage Guarantee

A critical architectural pitfall in branch predictor verification is training on the resolved branch direction before sampling the speculative prediction for that same dynamic branch.

Our testbenches strictly enforce a two-phase protocol:
1. **Phase 1: Combinational Pre-Update Sampling (`#1` after negedge clk)**
   - `lookup_pc` is driven with the target branch address.
   - The combinational prediction (`predict_taken`, `two_bit_state`, `predicted_next_pc`) is sampled and compared against expected values and the scoreboard.
   - Predictions are recorded in performance tally registers.
2. **Phase 2: Synchronous Resolution Update (`@(posedge clk)`)**
   - `update_valid = 1`, `update_pc = lookup_pc`, `actual_taken = actual`.
   - On the rising edge of clock, table registers update non-blockingly (`<=`).
   - `update_valid` is deasserted.

This guarantees mathematical zero data leakage.

---

## 6. Pipeline Recovery Coordination (Step 7)

In coordination with P3 (Pipeline Control), `tb_comparison.sv` includes integrated checks proving:
1. **Direction Misprediction (Predicted Taken $\implies$ Actual Not Taken):**
   - Fetch: Predicts Taken, BTB hits with Target `0x00003000`. Next PC = `0x00003000`.
   - Execute Resolution: Condition evaluates to Not Taken (`actual_taken = 0`).
   - Control Output: `mispredict = 1`, `flush = 1`, `redirect = 1`, `redirect_pc = 0x00001004` (PC+4 sequential fallback).
2. **Target Misprediction (Predicted Taken $\implies$ Actual Taken, Target Mismatch):**
   - Fetch: Predicts Taken, BTB hits with Target `0x00003000`. Next PC = `0x00003000`.
   - Execute Resolution: Condition evaluates to Taken (`actual_taken = 1`), but actual target is `0x00005000`.
   - Control Output: `mispredict = 1`, `flush = 1`, `redirect = 1`, `redirect_pc = 0x00005000` (Architectural target).

---

## 7. Automated Test Matrix & Results Summary

| Test Target | Suite | Description | Checks | Errors | Result |
|---|---|---|---|---|---|
| `make test-p4-unit` | `tb_predictor.v` | 32-branch benchmark, cold-start, aliasing, reset priority | 113 | 0 | **PASS** |
| `make test-p4-comparison` | `tb_comparison.sv` | 130 dynamic branches across 3 trace files + P3 recovery | 523 | 0 | **PASS** |
| `make synth-p4-checked` | Yosys 0.70 | Formal assertion check on `predictor_1bit` & `predictor_top` | 0 problems | 0 | **PASS** |

### Benchmark Results Table (`evidence/metrics/comparison_summary.csv`)

| Trace Name | Branches | Baseline Acc | 1-Bit Acc | 2-Bit Acc |
|---|---|---|---|---|
| Loop-dominated (`TTTTN`) | 40 | 20.00% (8/40) | 60.00% (24/40) | **77.50% (31/40)** |
| Strict Alternating (`TNTN`) | 40 | **50.00% (20/40)** | 0.00% (0/40) | 0.00% (0/40) |
| Mixed BEQ/BNE Aliased | 50 | 40.00% (20/50) | 46.00% (23/50) | **48.00% (24/50)** |
| **Consolidated Overall** | **130** | **36.92% (48/130)** | **36.15% (47/130)** | **42.31% (55/130)** |
