# P1 — 2-bit Direction Predictor and Branch History Table

**Owner:** Shubhaang (team leader)
**Project:** MCA Dynamic Branch Prediction Unit
**Scope:** Synthesizable direction-prediction RTL; not an entire CPU or target predictor.
**Phase I deadline:** 16 November 2026, 11:59 PM IST.

## 1. Architecture and exact interface

`rtl/predictor_2bit.v` is the external P1 module. It instantiates
`rtl/branch_history_table.v`. The interfaces are **frozen for P2/P3 integration**.

| Signal | Direction | Meaning |
| --- | --- | --- |
| `clk` | in | Rising-edge update clock |
| `reset` | in | Active-high **synchronous** reset |
| `lookup_pc[31:0]` | in | Address of branch currently being predicted |
| `predict_taken` | out | Direction prediction, `1` means Taken |
| `prediction_state[1:0]` | out | Raw confidence counter of `lookup_pc` entry |
| `update_valid` | in | A valid, resolved, nonsquashed branch should train the BHT |
| `update_pc[31:0]` | in | PC of the *resolved* branch (possibly different from lookup PC) |
| `actual_taken` | in | Actual resolved direction used only to **train** the BHT |

The P1 module **does not** output a branch target address, check BTB tags, or
flush a pipeline. Tanish (P2) owns target prediction; Tanmay (P3) owns recovery.

### Flow

1. **Fetch:** `lookup_pc` selects a two-bit BHT entry with `PC[5:2]` (for `INDEX_BITS=4`).
2. **Predict:** A combinational read returns `prediction_state`. Its MSB is `predict_taken`.
3. **Resolve:** A later branch provides `update_pc`, `actual_taken`, and `update_valid`.
4. **Train:** On the next rising clock edge, the resolved branch's counter increments for Taken or decrements for Not Taken, saturating at both ends.
5. **Repeat:** A subsequent lookup sees the newly stored history after that edge.

**Important timing property:** `actual_taken` must not influence the prediction
of the same in-flight branch before it resolves. The BHT's output is independent
of `actual_taken` between clock edges. `lookup_pc` and `update_pc` can and often
do refer to **different** dynamic instructions.

## 2. Counter state diagram / truth table

| Current | Meaning | Prediction | Next if Taken | Next if Not Taken |
| --- | --- | --- | --- | --- |
| `00` | Strongly Not Taken | NT | `01` | `00` |
| `01` | Weakly Not Taken | NT | `10` | `00` |
| `10` | Weakly Taken | T | `11` | `01` |
| `11` | Strongly Taken | T | `11` | `10` |

The counter is initialized to `01` on the first clock edge with `reset=1`.
One unusual outcome can reduce confidence without changing direction (hysteresis).
For example, `11` followed by Not Taken becomes `10`, so the next prediction is
still Taken. The counter must *not* wrap from `11` to `00` or vice versa.

## 3. Addressing, size and aliasing

For `INDEX_BITS=4`, the BHT has `2^4 = 16` independent entries. Each stores
2 bits, so the state-storage requirement is **32 bits**. The selected entry is
`lookup_pc[5:2]`; the resolved branch updates `update_pc[5:2]`. Bits `[1:0]`
are ignored because the study design assumes aligned 32-bit instructions.

`0x00000100` and `0x00000140` both map to index 0: they differ in a higher
address bit but share bits `[5:2]`. This is **aliasing**: multiple branches
share one counter and can interfere with each other's predictions. This is a
**tagless BHT**, not a tagged BTB. It is intentionally not capable of detecting
whether two PC addresses belong to distinct branches.

The RTL is parameterized by `INDEX_BITS`. The new scoreboard tests the
configuration at 2 bits (4 entries), 4 bits (16 entries) and 5 bits (32 entries).
The evaluated project configuration remains the default 16-entry table.

## 4. Clock-cycle example

Assume BHT[0] initially contains `01`, and an actual Taken branch at PC=0x100
resolves while a different branch is being fetched.

| Moment | `lookup_pc` | `update_pc` | `actual_taken` | BHT[0] |
| --- | --- | --- | --- | --- |
| Immediately before update edge | `0x104` | `0x100` | `1` | `01` |
| Rising edge with `update_valid=1` | `0x104` | `0x100` | `1` | transitions to `10` |
| After edge | `0x100` | no new update | — | `10` → predicts Taken |

The prediction for PC `0x104` is read from **its own index**, not index 0,
and is not affected by the PC `0x100` update. If `update_pc=0x140`, the same
entry *would* be updated due to aliasing.

### Read/write to the same entry

Combinational lookup shows the **old** state before the active clock edge.
After that edge and nonblocking-assignment settlement, lookup shows the **new**
state. P3 must latch the prediction alongside the branch PC as instructions
move through simulated pipeline stages; simply comparing a fresh lookup after
updating the BHT would be incorrect.

### Reset priority

An active `reset` at a rising edge sets **every** counter to `01`, even if
`update_valid=1` at the same time. `update_valid=0` must not train the table;
it represents no valid resolved instruction (including squashed younger wrong-
path branches). The actual mispredicted-but-valid resolved branch *does* train.

## 5. Verification plan and evidence honesty

| Verification target | Test or evidence | Status |
| --- | --- | --- |
| Four-state increments/decrements, saturation, aliasing | `make test-p1` (22 checks) | **Passed on user's Mac, 22 Oct 2026** |
| All 16 entries; reset priority; simultaneous fetch/update | `make test-p1-extended` (184 checks in supplied suite) | **Passed: 184/184 on 3 Nov 2026** |
| Exhaustive 8 outcome/state combinations for each entry | `make test-p1-scoreboard` | **Passed on Mac, 3 Nov 2026** |
| Deterministic randomized read/update/reset model checking | `make test-p1-scoreboard` (several thousand operations per configuration) | **Passed on Mac, 3 Nov 2026** |
| Configurations `INDEX_BITS=2,4,5` | `make test-p1-scoreboard` | **Passed on Mac, 3 Nov 2026** |
| Generic synthesis + consistency checking | `make synth-p1-checked` | **Passed on Mac, 3 Nov 2026** |
| Baseline generic synthesis | `make synth-p1` | **Previously passed on Mac: 192 generic cells, 0 reported problems** |

On 3 November 2026, the extended tests and all three independent
scoreboards passed on macOS using Icarus Verilog 13.0. Checked generic
synthesis completed using Yosys 0.70. See
`evidence/P1_20261103_185000/` for the recorded test logs.
The previously verified RTL modules remain unchanged.

### Run locally on macOS

```bash
cd ~/Downloads/MCA_Team_Kit/MCA_Project_Repository
make verify-p1
make demo
surfer results/p1_bht.vcd
```

`make verify-p1` stops on test assertion failures, simulator errors or a
failed `check -assert` synthesis. It writes logs to `results/`. A passed test
means **the exercised behaviors passed**, not that the entire CPU project
or final FPGA timing is proven.

For readable viva evidence, open `results/p1_bht.vcd` in Surfer and add:
`clk`, `reset`, `lookup_pc`, `update_pc`, `update_valid`, `actual_taken`,
`prediction_state` and `predict_taken`. Display `prediction_state` in binary.
Capture the `01 → 10 → 11 → 10 → 01 → 00` sequence and the reset interval.

## 6. What to give the team

- **To Tanmay (P3):** The exact `predictor_2bit` port contract. Read the BHT
  at fetch and carry the predicted Taken bit/target/branch PC alongside the
  in-flight branch. Send a valid resolved branch to `update_pc` and
  `actual_taken`; suppress updates for squashed younger branches.
- **To Tanish (P2):** The same PC indexing scheme `PC[5:2]`. The BTB **must**
  use tags and valid bits; the BHT purposely does not have them.
- **To Vansh (P4):** Compare direction accuracy on identical instruction
  traces, counting predictions *before* updates. No outcome leakage.
- **To Lakshya (P5):** Synthesis resource reports must identify target and
  tool flow. Generic Yosys counts are not FPGA LUT utilization or MHz.

## 7. Viva-ready explanations

**Q1. What did you implement personally?**
The 16-entry, two-bit branch direction predictor and its verification
contract: BHT indexing, saturating state updates, combinational prediction,
reset semantics, and self-checking testcases.

**Q2. What is a branch?**
A control-flow instruction whose next PC depends on a condition (BEQ/BNE);
the processor doesn't know the outcome until the condition is evaluated.

**Q3. Why predict?**
To choose a speculative next PC before branch resolution and avoid waiting
at every branch; wrong guesses require pipeline recovery.

**Q4. Why 2 bits?**
The extra state provides hysteresis. A single unusual outcome weakens a strong
prediction without immediately reversing it.

**Q5. Why 16 entries?**
This small, parametrized teaching design makes every entry easy to verify.
With 2 bits each, it uses 32 storage bits; the table size is not a performance
optimum established by measurements.

**Q6. Why PC[5:2]?**
The two lowest bits are zero for aligned 4-byte instructions; four more bits
choose one of 16 counters.

**Q7. Explain aliasing.**
PC=0x100 and PC=0x140 map to the same BHT entry, so their training history
can collide. A tagless BHT can't tell them apart.

**Q8. How does the BHT differ from the BTB?**
The BHT predicts direction; the BTB predicts destination address with
valid/tag checking.

**Q9. Why two PC ports?**
One branch is being fetched while an older branch may be resolving; those PCs
can differ in a pipeline.

**Q10. What if `update_valid=0`?**
No counter changes on that edge. The actual outcome is irrelevant until a valid
resolved branch enables training.

**Q11. Does this implement a whole pipeline?**
No. P1 supplies the direction predictor. P3 emulates/implements next-PC and
misprediction recovery. The team must not claim a completed CPU.

**Q12. Why isn't 2-bit always more accurate?**
Accuracy depends on branch patterns, initialization, table aliasing and
training. For some alternating traces, a simple 2-bit predictor can do poorly.

**Q13. What have you measured so far?**
The user's previously shared Mac logs report 22 passing directed checks,
and generic Yosys synthesis yielding 192 generic cells. Additional scoreboard
checks and timing/resource characterization still require new runs.

**Q14. What is a meaningful performance comparison?**
For each trace, count predictions before training, then compare always-NT,
1-bit and 2-bit accuracy. P5 may estimate CPI with an explicitly assumed
branch frequency and misprediction penalty; that is not a measured CPU CPI.

## 8. P1 acceptance / handoff checklist

- [ ] `make verify-p1` returns exit code zero on the Mac (all checks + Yosys).
- [ ] Record pass counts, tool versions, and full logs from the **current** RTL.
- [ ] Save a Surfer screenshot showing counter transitions and reset.
- [ ] Review P3 use of `lookup_pc` versus `update_pc` for outcome leakage.
- [ ] Commit **only your actual P1 work** to `feature/shubhaang-bht`.
- [ ] Include a clear caveat that BTB/flush, video, and CPU integration belong
      to later team deliverables.
