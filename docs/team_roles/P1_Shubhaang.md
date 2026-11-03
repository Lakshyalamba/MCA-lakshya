# P1 — Shubhaang (Leader): 2-bit predictor and Branch History Table

**Personal responsibility:** Own the central prediction algorithm and lead technical reviews while keeping individual member commits authentic.

**Timeline:** 4–7 Nov: extended checks and design notes; 8–10 Nov: P1 integration support; 11–15 Nov: evidence and viva rehearsal.

## Files owned
- rtl/branch_history_table.v (existing starter; validate and improve)
- rtl/predictor_2bit.v (existing starter; validate and improve)
- testbench/tb_p1_bht.sv (existing 22 directed checks)
- testbench/tb_p1_extended.sv (new 184-check suite; run before claiming PASS)
- docs/P1_IMPLEMENTATION_NOTES.md (new explanatory notes)

## Interface contract
- Inputs: clk, reset, lookup_pc[31:0], update_valid, update_pc[31:0], actual_taken.
- Outputs: predict_taken and prediction_state[1:0].
- 16 entries, indexed by PC[5:2]; reset each counter to 01 on an active clock edge.
- Read the indexed counter combinationally; on update_valid=1 update the resolved branch entry at the rising clock edge.
- Counter mapping: 00/01 => not taken; 10/11 => taken. Saturate at 00 and 11.

## Implementation steps
1. Read docs/INTERFACES.md and trace every input and output to the current RTL. Explain why lookup_pc and update_pc can differ.
2. On a Mac with Icarus, run make test-p1; save the full pass/fail log and do not edit RTL just to silence a failing test.
3. Run make test-p1-extended. This added testbench is not yet confirmed on your Mac; debug any failing test or timing race before marking complete.
4. Open results/p1_bht.vcd in Surfer. Display clock, reset, lookup_pc, update_pc, update_valid, actual_taken, prediction_state and predict_taken. Capture clear transitions.
5. Review and extend test cases: all 16 entries; reset-vs-update priority; update_valid=0; aliasing 0x100 vs 0x140; read/write same entry; random sequence checked against reference counters.
6. Run make synth-p1 and report generic flip-flops and gates. Do not report FPGA MHz without a target technology/timing analysis.
7. Document one worked example and open a P1 pull request with exact logs, waveform screenshot, and a short explanation of architectural limitations.

## Tests / evidence
- 22 existing directed checks: reported PASS on 22 October; rerun on final files.
- 184 extended checks: included but execution is not yet verified; do not assume pass.
- Check reset priority and same-cycle read/write semantics at clock boundaries.
- Check each of 16 indices and aliasing: 0x100 and 0x140 share PC[5:2].
- Check that a wrong-path/squashed branch never trains the BHT (update_valid=0).

## Acceptance checklist
- [ ] Current RTL and extended suite pass on macOS after clean checkout.
- [ ] Predictions are based on pre-resolution state, not the answer to the same dynamic branch.
- [ ] Waveform exhibits 01 -> 10 -> 11 -> 10 -> 01 -> 00 and saturation.
- [ ] P1 PR is reviewed, documented and integration interfaces are stable.

## Viva questions
**Q: Why 2-bit rather than 1-bit?**

A: The second bit provides hysteresis: a single unexpected outcome can weaken confidence without flipping direction.

**Q: Explain the 16-entry BHT index.**

A: With aligned 4-byte instructions, PC[5:2] selects 16 entries. Low two address bits are zero.

**Q: What is aliasing?**

A: Different PCs can have the same index, so a tagless BHT shares their history and may lose accuracy.

**Q: Why separate lookup_pc and update_pc?**

A: Fetch and branch resolution can refer to different in-flight branches.

**Q: When does the predictor update?**

A: At an active clock edge when a valid, resolved, nonsquashed branch supplies actual_taken.

**Q: Can the BHT predict target PC?**

A: No. It only predicts Taken/Not Taken; the BTB provides a target address.

**Q: What was actually measured?**

A: 22 directed P1 checks passed on the shared Mac log; generic Yosys synthesis gave 192 generic cells, not a measured clock frequency.


## GitHub branch
`feature/shubhaang-bht`

**Authenticity note:** Commit only your actual work; do not claim authorship of the original shared starter files if you did not write them.
