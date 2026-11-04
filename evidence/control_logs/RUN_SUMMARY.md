# P3 Verification Run Summary

**Date:** 4 November 2026  
**Author:** Tanmay (P3)  
**Host:** Darwin arm64 (macOS)  
**Simulators:** Icarus Verilog 13.0, Yosys 0.70+post  

## 1. Test Suite Results

| Test Target | Testbench | Checks | Result | Log File |
|---|---|:---:|:---:|---|
| `make test-p3` | `testbench/tb_branch_control.sv` | 24 | ✅ **24/24 PASS** | `p3_control_test.log` |
| `make test-p3-integrated` | `testbench/tb_integrated.sv` | 26 | ✅ **26/26 PASS** | `p3_integrated_test.log` |
| `make synth-p3-checked` | `rtl/next_pc_mux.v`, `rtl/branch_resolution.v` | — | ✅ **0 problems** | `p3_synthesis_checked.log` |
| **Total** | | **50** | ✅ **ALL PASS** | |

## 2. Test Coverage Breakdown

### `tb_branch_control.sv` (24 checks)
- **Part A (7 checks):** `next_pc_mux` combinational selection:
  - NT prediction → PC+4
  - Taken prediction + BTB hit → predicted target
  - Taken prediction + BTB miss → fallback PC+4
  - NT prediction ignores BTB hit
  - Edge cases: PC = 0, near-max PC (0xFFFFFFF8), target = 0x0
- **Part B (7 checks):** `branch_resolution` complete truth table:
  - `valid=0` → no recovery signals
  - Predicted NT, actual NT → no flush
  - Predicted T + BTB hit + correct target, actual T → no flush
  - Predicted NT, actual T → flush + redirect to actual target
  - Predicted T, actual NT → flush + redirect to PC+4
  - Predicted T + BTB miss, actual T → redirect to actual target
  - Predicted T + BTB hit + wrong target, actual T → flush + redirect
- **Part C (10 checks):** Boundary and alternation edge cases:
  - BTB hit irrelevance on NT direction
  - Matching targets on taken branch
  - Zero-address branch PC redirections
  - Back-to-back correct/mispredict alternation
  - Direction wrong overriding target match

### `tb_integrated.sv` (26 checks)
- P1 BHT (`predictor_2bit`) + P2 BTB (`branch_target_buffer`) + P3 (`next_pc_mux`, `branch_resolution`)
- **Deterministic Sampling:** Samples all recovery signals (`sampled_mispredict`, `sampled_flush`, `sampled_redirect`, `sampled_redirect_pc`, `sampled_selected_pc`) while `res_valid=1`, eliminating simulator race conditions.
- **Deactivation Verification:** Explicitly verifies that live recovery signals (`res_mispredict`, `res_flush`, `res_redirect`, `res_redirect_pc`) deactivate when `res_valid=0`.
- **Redirect Priority:** Demonstrates `selected_pc = res_redirect ? res_redirect_pc : predicted_next_pc`, verifying recovery redirect overrides speculative fetch.
- **Scenarios Tested:**
  - T1: Cold start NT branch (0x1000)
  - T2: Train taken + BTB, verify correct fetch redirect (0x1004)
  - T3: Direction misprediction NT → T with target redirect (0x1008)
  - T4: Direction misprediction T → NT with PC+4 redirect (0x1004)
  - T5: Target misprediction with wrong BTB target (0x100C)
  - T6: BTB miss via alias eviction on taken branch (0x1010 evicted by 0x1050)
  - T7: 2-bit counter FSM adaptation across multiple updates (0x1018)
  - T8: Independent branches without aliasing cross-contamination (0x1020, 0x1024)
  - T9: Stable prediction after training
  - T10: Reset clears all BHT/BTB state
  - T11: Backward branch target in loop pattern (0x1028 → 0x1000)
  - T12: Correct next PC computation for NT resolution (0x102C → 0x1030)
  - T13: Squashed/invalid branch resolution (`res_valid=0`), confirming no recovery asserted and BHT/BTB states remain completely untaught.

## 3. Generic Synthesis Statistics (Yosys 0.70)

### `next_pc_mux`
- Generic cells: 91
  - `$_AND_`: 27
  - `$_MUX_`: 32
  - `$_NAND_`: 2
  - `$_NOT_`: 1
  - `$_XNOR_`: 1
  - `$_XOR_`: 28
- Problems reported by `check -assert`: **0**

### `branch_resolution`
- Generic cells: 223
  - `$_AND_`: 110
  - `$_MUX_`: 22
  - `$_NAND_`: 2
  - `$_NOT_`: 1
  - `$_ORNOT_`: 22
  - `$_OR_`: 11
  - `$_XNOR_`: 27
  - `$_XOR_`: 28
- Problems reported by `check -assert`: **0**

## 4. Waveform Artifacts
- `evidence/waveforms/p3_integrated_simulation.png`: Genuine simulation waveform generated directly from `results/p3_integrated.vcd`, displaying real simulation time axis (in ns/ps), digital signal transitions, and annotations for T2 (correct prediction), T3 (direction misprediction), and T4 (redirect to PC+4).
- `evidence/waveforms/p3_control.png`: Conceptual timing diagram showing signal transitions across all truth-table scenarios.
