# P3 — Pipeline Control: Next-PC Selection and Branch Resolution

**Author:** Tanmay (P3)
**Date:** 4 November 2026
**Status:** Unit-verified; integration with P1/P2 pending

## 1. Overview

This document describes the two combinational modules authored for the
branch-prediction subsystem's pipeline control interface:

| Module | File | Purpose |
|---|---|---|
| `next_pc_mux` | `rtl/next_pc_mux.v` | Fetch-stage next-PC selection |
| `branch_resolution` | `rtl/branch_resolution.v` | Execute-stage misprediction detection and recovery |

These modules sit between the P1 direction predictor (BHT) and P2 target
predictor (BTB), connecting their outputs to pipeline control signals.

> [!IMPORTANT]
> This is a **branch-prediction unit prototype with a test harness**, not a
> complete five-stage pipelined CPU. The `flush` and `redirect` signals
> demonstrate the recovery interface that a real pipeline would consume.

## 2. Architecture and Data Flow

```
  ┌─────────────────── FETCH STAGE ───────────────────┐
  │                                                     │
  │  PC ──┬──► P1 BHT ──► predicted_taken              │
  │       │                     │                       │
  │       ├──► P2 BTB ──► btb_hit, predicted_target     │
  │       │                     │         │             │
  │       └──► next_pc_mux ◄───┘─────────┘             │
  │                │                                    │
  │         predicted_next_pc                           │
  │                │                                    │
  │   ┌────────────┘                                    │
  │   │  Save: predicted_taken, btb_hit,                │
  │   │         predicted_target, branch_pc             │
  └───┼─────────────────────────────────────────────────┘
      │
      │  ... pipeline stages (decode, execute) ...
      │
  ┌───┼─────────── EXECUTE / RESOLUTION STAGE ──────────┐
  │   │                                                  │
  │   └──► branch_resolution                             │
  │          Inputs: saved predictions + actual outcome   │
  │          Outputs: mispredict, flush, redirect,        │
  │                   redirect_pc                         │
  │                                                      │
  │   If mispredict:                                     │
  │     flush younger instructions                       │
  │     redirect fetch to redirect_pc                    │
  │     Update P1 BHT with actual_taken                  │
  │     Update P2 BTB with actual_target (if taken)      │
  └──────────────────────────────────────────────────────┘
```

## 3. Next-PC Selection Truth Table

| `predicted_taken` | `btb_hit` | `predicted_next_pc` | Rationale |
|:-:|:-:|---|---|
| 0 | 0 | `pc + 4` | Not-taken prediction → sequential |
| 0 | 1 | `pc + 4` | Not-taken prediction → sequential (BTB hit ignored) |
| 1 | 0 | `pc + 4` | Taken but no target available → fallback; recovered at resolution |
| 1 | 1 | `predicted_target` | Taken with valid target → speculative redirect |

## 4. Branch Resolution Truth Table

All entries assume `valid = 1`. When `valid = 0`, all outputs are deasserted.

| # | `pred_taken` | `btb_hit` | `pred_target` | `actual_taken` | `actual_target` | `mispredict` | `redirect_pc` | Case |
|:-:|:-:|:-:|:-:|:-:|:-:|:-:|---|---|
| 1 | 0 | × | × | 0 | × | 0 | — | Correct: not-taken |
| 2 | 1 | 1 | T | 1 | T | 0 | — | Correct: taken, target match |
| 3 | 0 | × | × | 1 | A | 1 | A | Direction miss: NT → T |
| 4 | 1 | × | × | 0 | × | 1 | `branch_pc+4` | Direction miss: T → NT |
| 5 | 1 | 0 | × | 1 | A | 1 | A | BTB miss on taken branch |
| 6 | 1 | 1 | T≠A | 1 | A | 1 | A | Wrong BTB target |

**Legend:** T = predicted target, A = actual target, × = don't care, — = ignored.

### Formal misprediction condition

```
mispredict = valid & (
    (predicted_taken != actual_taken)          // direction mismatch
    | (actual_taken & (                        // target mismatch (taken only)
        ~btb_hit                               //   BTB had no entry
        | (predicted_target != actual_target)  //   BTB target was wrong
    ))
)
```

## 5. Signal Timing and Metadata Preservation

### Why save predictions at fetch time?

The BHT and BTB are shared resources updated by every resolving branch.
Between the time a branch is fetched (predicted) and when it resolves
(execute stage), other branches may update the BHT/BTB entries. If the
resolution logic re-reads the *current* BHT/BTB state instead of the
*saved* fetch-time predictions, it would compare against stale or
corrupted values, producing incorrect misprediction signals.

**Required saved metadata per in-flight branch:**
- `branch_pc` — the PC of the branch instruction
- `predicted_taken` — BHT direction prediction at fetch
- `btb_hit` — BTB hit/miss status at fetch
- `predicted_target` — BTB target at fetch (valid only if hit)

In a full pipeline, these would be carried in pipeline registers or a
branch checkpoint buffer. In our test harness, the testbench explicitly
saves and supplies these values.

### Timing diagram (conceptual)

```
Cycle 1 (Fetch):
  lookup_pc = branch_pc
  → BHT outputs: predicted_taken
  → BTB outputs: btb_hit, predicted_target
  → next_pc_mux outputs: predicted_next_pc
  → Pipeline registers save: {branch_pc, predicted_taken, btb_hit, predicted_target}

Cycle 2..N (Decode/Execute):
  Branch operands are resolved

Cycle N+1 (Resolution):
  actual_taken, actual_target are known
  → branch_resolution compares saved predictions vs actual
  → If mispredict: assert flush, redirect, redirect_pc
  → Update BHT (always) and BTB (if taken) with actual values
```

## 6. Port Specifications

### `next_pc_mux` (combinational, zero-cycle)

| Port | Direction | Width | Description |
|---|:-:|:-:|---|
| `pc` | in | 32 | Current fetch PC |
| `predicted_taken` | in | 1 | P1 BHT direction prediction |
| `btb_hit` | in | 1 | P2 BTB valid tag match |
| `predicted_target` | in | 32 | P2 BTB predicted target |
| `predicted_next_pc` | out | 32 | Selected next fetch address |

### `branch_resolution` (combinational)

| Port | Direction | Width | Description |
|---|:-:|:-:|---|
| `valid` | in | 1 | A branch is resolving this cycle |
| `branch_pc` | in | 32 | PC of the resolving branch |
| `predicted_taken` | in | 1 | Saved direction prediction |
| `btb_hit` | in | 1 | Saved BTB hit status |
| `predicted_target` | in | 32 | Saved BTB target |
| `actual_taken` | in | 1 | True branch direction |
| `actual_target` | in | 32 | True branch target address |
| `mispredict` | out | 1 | Recovery needed |
| `flush` | out | 1 | Kill younger wrong-path work |
| `redirect` | out | 1 | Redirect fetch unit |
| `redirect_pc` | out | 32 | Corrected fetch address |

## 7. Verification Summary

| Test | Checks | Status | Command |
|---|:-:|---|---|
| `tb_branch_control.sv` — next_pc_mux | 7 | ✅ PASS | `make test-p3` |
| `tb_branch_control.sv` — resolution truth table | 7 | ✅ PASS | `make test-p3` |
| `tb_branch_control.sv` — edge cases | 10 | ✅ PASS | `make test-p3` |
| `tb_integrated.sv` — P1+P2+P3 workflow | 12 | ✅ PASS | `make test-p3-integrated` |
| **Total** | **24 + 12** | **36 PASS** | |

## 8. Limitations and Scope

1. **Not a complete CPU:** The `flush` signal demonstrates the recovery
   interface but does not actually kill pipeline stage registers. A real
   implementation would require per-stage kill/valid logic.

2. **No branch delay slots:** The prototype assumes a simple predict-and-
   redirect model. MIPS-style branch delay slots are not modeled.

3. **No speculative state rollback:** Only fetch redirection is modeled.
   A real CPU would need to restore register rename maps, reorder buffer
   entries, and store buffer state on misprediction.

4. **Single outstanding branch:** The test harness resolves one branch at
   a time. A superscalar or deeply pipelined machine may have multiple
   branches in flight simultaneously.

5. **No operating frequency claims:** These are combinational modules.
   Critical path timing depends on the target technology and synthesis
   constraints, which are beyond P3 scope (see P5).

## 9. Files Authored

| File | Type | Description |
|---|---|---|
| `rtl/next_pc_mux.v` | RTL | Combinational next-PC selector |
| `rtl/branch_resolution.v` | RTL | Misprediction detection and recovery signals |
| `testbench/tb_branch_control.sv` | Test | 24 directed assertions for P3 modules |
| `testbench/tb_integrated.sv` | Test | 12-check P1+P2+P3 integration harness |
| `docs/P3_PIPELINE_CONTROL.md` | Doc | This document |
