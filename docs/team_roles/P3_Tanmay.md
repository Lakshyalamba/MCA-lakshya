# P3 — Tanmay: Next-PC selection, branch resolution, flush/redirect

**Personal responsibility:** Connect direction and target predictions to a small pipeline-control interface, preserving fetch-time metadata until resolution.

**Timeline:** 4 Nov: truth table; 5–7 Nov: RTL and tests; 8–10 Nov: lead integration with P1/P2.

## Files owned
- rtl/next_pc_mux.v (new combinational next-PC selector)
- rtl/branch_resolution.v (new comparison / recovery signals)
- testbench/tb_branch_control.sv (new directed assertions)
- testbench/tb_integrated.sv (joint with P1/P2 for full workflow)
- docs/P3_PIPELINE_CONTROL.md (timing, outcome truth table, limitations)

## Interface contract
- Next-PC: inputs pc, predicted_taken, btb_hit, predicted_target; output predicted_next_pc.
- Prediction phase: if predicted_taken AND btb_hit => predicted_target, otherwise pc+4 (chosen fallback on BTB miss).
- Resolution phase inputs: valid, branch_pc, saved predicted_taken, saved btb_hit, saved predicted_target, actual_taken, actual_target.
- actual_next_pc = actual_taken ? actual_target : branch_pc+4.
- mispredict = valid AND (direction differs OR (actual Taken AND (no BTB hit OR target differs))).
- Outputs: mispredict, flush, redirect, redirect_pc. On mismatch redirect_pc=actual_next_pc.
- IMPORTANT: save prediction metadata at fetch time; never re-read the updated BHT when resolving that same branch.

## Implementation steps
1. Draw the branch timeline: fetch/predict -> several cycles -> execute/resolve -> optional redirect.
2. Write a combinational next-PC module; cover Not Taken, Taken+BTB hit, Taken+BTB miss.
3. Write branch_resolution.v with a default no-branch (valid=0) behavior and a correct-next-PC computation.
4. Add tests for direction mismatch, wrong target with correct Taken direction, BTB miss, no mismatch, and invalid branch.
5. Check that flush/redirect are asserted only when required, and redirect_pc equals the actual next PC.
6. Define how the test harness saves predicted_taken, btb_hit, target and PC until the resolution event; do not use current lookup outputs for an older branch.
7. Create tb_integrated.sv connecting P1 predictor and P2 BTB; simulate a correct branch, a wrong-direction branch and a wrong-target branch.
8. Record the interface-level scope accurately: this is a branch-control test harness, not a complete five-stage CPU implementation.

## Tests / evidence
- valid=0 => no recovery.
- Predicted NT + actual NT => no flush; sequential PC.
- Predicted T + BTB hit + correct target + actual T => no flush.
- Predicted NT + actual T => flush and correct target redirect.
- Predicted T + actual NT => flush and PC+4 redirect.
- Predicted T + actual T but BTB miss => redirect on resolution.
- Predicted T + actual T but wrong target => flush and target redirect.
- Ensure stale or squashed branch updates cannot corrupt learning.

## Acceptance checklist
- [ ] All branch-control truth-table cases pass.
- [ ] Integration tests demonstrate both correct fetch and recovery cases with saved metadata.
- [ ] Flush/redirect timing and scope are clearly documented, without claiming full CPU execution.
- [ ] PR passes review and has reproducible commands.

## Viva questions
**Q: What is a control hazard?**

A: Fetch cannot know the correct next instruction until the branch outcome and target are resolved.

**Q: What is the job of next-PC mux?**

A: It selects sequential PC+4 or a valid predicted branch target.

**Q: What is a misprediction?**

A: Wrong direction, or for a Taken branch, missing or incorrect predicted target.

**Q: What is flushing?**

A: Invalidating younger wrong-path instructions so they do not commit side effects.

**Q: Why save predictions at fetch?**

A: The BHT/BTB may change before the branch resolves; judging with a later prediction would be incorrect.


## GitHub branch
`feature/tanmay-control`

**Authenticity note:** Commit only your actual work; do not claim authorship of the original shared starter files if you did not write them.
