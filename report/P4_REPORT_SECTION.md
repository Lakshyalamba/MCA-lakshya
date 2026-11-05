# P4 IEEE Report Contribution — Vansh

**Section:** II. Literature Review — Branch Prediction Strategies & Baseline History Schemes
**Section:** IV. Verification and Comparative Evaluation — Traces, Baselines, and Aliasing
**Section:** V. Individual Contributions — Vansh (P4)
**Author:** Vansh (Roll No: P4)
**Date:** 5 November 2026

---

## Section II: Literature Review — Dynamic Branch Prediction Strategies

Instruction pipelining in modern computer architectures introduces control hazards whenever the execution path depends on an unresolved conditional branch. In high-performance RISC pipelines, stalling the instruction fetch stage until branch condition evaluation in the execution stage introduces a latency penalty of several clock cycles per branch. To mitigate this penalty, branch prediction units predict branch direction and target address speculatively.

### 1. Static and Baseline Prediction
The simplest architectural baseline is the **Always Not Taken** strategy, which speculatively fetches along the sequential path ($PC + 4$) without dedicating any hardware state registers. While effective for forward conditional branches guarding rare exceptions or error checks, it exhibits poor accuracy (often below 30%) on iterative loops, where backward branches are taken repeatedly until termination [1].

### 2. One-Bit History Prediction
To capture dynamic program behavior, early dynamic schemes associate a 1-bit memory cell with each branch address [1]. The 1-bit predictor records the most recent branch outcome (Taken = 1, Not Taken = 0). When the branch is encountered again, the hardware speculates that the branch will repeat its previous direction.

However, 1-bit predictors suffer from an inherent double-misprediction penalty on loops. For an $N$-iteration loop that executes $N-1$ taken branches followed by 1 not-taken exit:
1. **Loop Exit Penalty:** The loop exit is mispredicted as Taken, causing a pipeline flush and training the 1-bit table entry to Not Taken.
2. **Loop Re-Entry Penalty:** Upon the next invocation of the loop, the first branch is predicted as Not Taken (reflecting the exit outcome), resulting in a second misprediction.
Thus, a 1-bit predictor incurs 2 mispredictions per loop execution regardless of loop length $N$, constraining its theoretical upper bound accuracy to $(N-2)/N$.

### 3. Two-Bit Saturating Counter Predictors
To address the fragility of 1-bit history, J. E. Smith (1981) proposed the 2-bit saturating counter scheme [1]. By incorporating hysteresis, the counter requires two consecutive counter-directional outcomes to invert its prediction bias. As formalized by Yeh and Patt [2], 2-bit predictors absorb single loop-exit anomalies without leaving the Taken state, eliminating the re-entry misprediction penalty and achieving $(N-1)/N$ accuracy on counted loops.

---

## Section IV: Verification & Comparative Evaluation

### 1. Verification Methodology & Anti-Data-Leakage Design
Fair comparison among branch prediction strategies requires that all candidate predictors receive the identical dynamic branch sequence in identical order. Furthermore, the verification harness must prevent data leakage: the speculative prediction for branch $i$ must be captured *before* the predictor state is updated with the architectural outcome of branch $i$.

The developed SystemVerilog verification suite (`tb_comparison.sv`) instantiates the Baseline, 1-bit BHT, and 2-bit BHT predictors, driving them through three deterministic workload traces generated and validated by an independent Python reference oracle (`scripts/reference_predictors.py`). An independent reconciliation audit (`scripts/compare_p4_results.py`) verifies exact 100% agreement between the Verilog simulation and the Python software oracle before metrics are published.

*Note on Evaluation Scope:* All accuracy figures are evaluated on deterministic synthetic branch traces designed to expose specific microarchitectural phenomena (loops, alternations, aliasing). They do not represent measured CPU workloads. Similarly, synthesis results represent generic gate-level technology mappings from Yosys, not FPGA LUTs or physical maximum clock frequencies.

### 2. Benchmark Workload Traces & Measured Accuracy

```
+-------------------------------------------------------------------------------------------------------------+
| Trace Workload              | Dynamic Branches | Baseline (Always NT) | 1-Bit BHT        | 2-Bit BHT        |
+-------------------------------------------------------------------------------------------------------------+
| 1. Loop-Dominated (TTTTN)   | 40 branches      | 20.00% (8/40)        | 60.00% (24/40)   | 77.50% (31/40)   |
| 2. Strict Alternating (TNTN)| 40 branches      | 50.00% (20/40)       | 0.00% (0/40)     | 0.00% (0/40)     |
| 3. Mixed BEQ/BNE Aliased    | 50 branches      | 40.00% (20/50)       | 46.00% (23/50)   | 48.00% (24/50)   |
+-------------------------------------------------------------------------------------------------------------+
| Consolidated Overall        | 130 branches     | 36.92% (48/130)      | 36.15% (47/130)  | 42.31% (55/130)  |
+-------------------------------------------------------------------------------------------------------------+
```

### 3. Key Architectural Observations

1. **Loop-Exit Hysteresis Proof:**
   On the loop-dominated workload (8 invocations of a 5-iteration loop), the 2-bit predictor achieves 77.50% accuracy versus 60.00% for the 1-bit predictor (an improvement of 17.50 percentage points). Waveform analysis (`evidence/waveforms/p4_comparison.png`) confirms that upon loop re-entry, the 2-bit counter resides in the Weakly Taken state (`10`), correctly predicting Taken, whereas the 1-bit predictor predicts Not Taken (`0`) and incurs a misprediction.

2. **Counterexample (Alternating Pathological Workload):**
   Under strict alternation (`T N T N...`), the 1-bit predictor exhibits a complete phase inversion, achieving 0.00% accuracy. The 2-bit predictor continuously oscillates between `01` and `10`, likewise achieving 0.00% accuracy. In contrast, the stateless Always Not Taken baseline achieves 50.00% accuracy, demonstrating that more complex dynamic hardware does not universally outperform simple baselines on all workloads.

3. **Index Aliasing Sensitivity Analysis:**
   In the mixed BEQ/BNE workload, branches at `PC = 0x00001010` and `PC = 0x00001050` both index into entry 4 of the 16-entry table ($PC[5:2] = 4$), causing destructive interference and limiting accuracy to 48.00% (24/50). When evaluated on a 32-entry BHT ($PC[6:2]$), Branch 1 maps to entry 4 and Branch 3 maps to entry 20. With aliasing resolved, HDL simulation accuracy increases to **74.00% (37/50)**, demonstrating a **+26.00 percentage point** accuracy improvement.

4. **Pipeline Recovery Coordination:**
   Integrating the predictors with P2 (BTB) and P3 (Next-PC and Branch Resolution) verified that direction mispredictions trigger `redirect_pc = branch_pc + 4` while target mispredictions assert `redirect_pc = actual_target`, both asserting single-cycle pipeline flush signals.

---

## Section V: Individual Contributions — Vansh (P4)

**Vansh (P4)** was solely responsible for baseline predictor RTL, reproducible trace generation, and self-checking comparative verification:
- **RTL Implementation:** Refactored and improved `rtl/predictor_1bit.v`, implementing a fully parameterized, synthesizable 1-bit BHT module with strict `` `default_nettype none `` discipline, clean register-array reset loops, and combinational pre-update lookup semantics.
- **Unit Assertion Testbench:** Expanded `testbench/tb_predictor.v` with 113 automated assertions, verifying cold-start initialization across 4 representative entries, reset priority, disabled update stability, intentional aliasing, and cycle-by-cycle predictions on the 32-branch benchmark.
- **Self-Checking Comparison Suite:** Developed `testbench/tb_comparison.sv` containing 541 assertions evaluating Baseline, 1-bit BHT, 2-bit BHT, and 16 vs 32-entry aliasing sensitivity across 130 dynamic branches without data leakage. Integrated P2 BTB and P3 control logic to demonstrate direction vs. target recovery behavior.
- **Trace Architecture & Independent Oracle:** Authored `scripts/reference_predictors.py` to validate committed trace files (`traces/loop_trace.csv`, `traces/alternating_trace.csv`, `traces/beq_bne_trace.csv`) and provide independent software reference simulation with explicit benchmark regression assertions.
- **Reconciliation Audit:** Authored `scripts/compare_p4_results.py` to independently reconcile Verilog HDL and Python oracle metrics across all fields, publishing `evidence/metrics/comparison_summary.csv` only upon 100% agreement.
- **Waveform Analysis:** Authored `scripts/render_p4_waveform.py` with dynamic VCD header parsing and generated simulation waveform evidence (`evidence/waveforms/p4_comparison.png`) demonstrating loop-exit hysteresis and 1-bit double penalty.
- **Tool Automation & CI:** Added `check-traces`, `test-p4-unit`, `test-p4-comparison`, `test-p4-oracle`, `test-p4-compare`, `synth-p4-checked`, and `verify-p4` targets to `Makefile`; authored `.github/workflows/p4.yml` and `docs/P4_TEST_PLAN.md`.

---

## References

[1] J. E. Smith, “A Study of Branch Prediction Strategies,” in *Proceedings of the 8th Annual Symposium on Computer Architecture (ISCA)*, 1981, pp. 135–148.
[2] T.-Y. Yeh and Y. N. Patt, “Two-Level Adaptive Training Branch Prediction,” in *Proceedings of the 24th Annual International Symposium on Microarchitecture (MICRO)*, 1991, pp. 51–61, doi: 10.1145/123465.123475.
