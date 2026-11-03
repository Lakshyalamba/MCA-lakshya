# P2 — Tanish: Tagged Branch Target Buffer (BTB)

**Personal responsibility:** Build and verify independent target-address prediction hardware that complements P1 direction prediction.

**Timeline:** 4 Nov: interface + memory layout; 5–7 Nov: module and tests; 8–10 Nov: integrate and fix.

## Files owned
- rtl/branch_target_buffer.v (new synthesizable Verilog)
- testbench/tb_btb.sv (new self-checking testbench)
- docs/P2_BTB_DESIGN.md (table fields, tag/index diagram, hit/miss cases)
- evidence/waveforms/btb.png (after verified test run)

## Interface contract
- Inputs: clk, reset, lookup_pc[31:0], update_valid, update_pc[31:0], update_target[31:0].
- Outputs: hit and target[31:0] (target may be ignored if hit=0).
- 16 direct-mapped BTB entries: valid bit, PC tag PC[31:6], 32-bit target; index PC[5:2].
- Lookup: hit only if valid[index] and tag[index] matches lookup_pc[31:6].
- On rising edge with update_valid=1, write tag, valid=1 and target at update_pc index; caller asserts update_valid for resolved TAKEN branches only.
- On reset, clear valid bits; contents of uninitialized tags and targets are irrelevant until valid is set.

## Implementation steps
1. Read the shared interface contract, then write a one-page memory-layout table (valid, tag, target, index) before coding.
2. Create rtl/branch_target_buffer.v as a parameterizable 16-entry direct-mapped BTB with combinational lookup and synchronous update.
3. Implement a synchronous reset clearing valid bits, and ensure a lookup after reset is a miss.
4. Implement index and tag comparisons; check full tag before asserting hit.
5. Write tb_btb.sv with assertions for cold miss, learning a taken branch, target hit, another-PC miss, alias conflict, replacement, update_valid=0 and reset.
6. Compile and run after `mkdir -p results`: iverilog -g2012 -Wall -s tb_btb -o results/btb_sim rtl/branch_target_buffer.v testbench/tb_btb.sv; vvp results/btb_sim.
7. Generate results/btb.vcd, capture hit/miss and collision waveform, and prepare a PR with tests and design notes.
8. Work with P3 to connect target and hit outputs; do not edit P1 code without a reviewed integration reason.

## Tests / evidence
- Cold reset: every lookup misses until a valid branch has trained the BTB.
- Update on taken branch: same PC hits and returns exact resolved target.
- Alias: 0x100 and 0x140 share index but have different tags; replacing one invalidates the other.
- Distinct indices remain independent.
- Wrong target/changed target: subsequent valid update replaces the stored target.
- No update during update_valid=0; simultaneous lookup/update honors clock edge semantics.

## Acceptance checklist
- [ ] No false hits on tag collisions or uninitialized entries.
- [ ] All directed BTB tests and synthesis checks pass.
- [ ] P3 can use hit and target without knowing BTB internals.
- [ ] PR has an explanatory waveform and genuine authored commits.

## Viva questions
**Q: What does a BTB store?**

A: A valid bit, identifying branch PC tag and predicted target PC.

**Q: Why does BHT not replace BTB?**

A: BHT predicts direction; BTB predicts the destination of a Taken branch.

**Q: Why is a tag necessary?**

A: Different PCs can map to the same index; the tag avoids returning an unrelated branch target.

**Q: What does a cold miss mean?**

A: The entry is invalid or absent after reset, so no trusted target can be supplied.

**Q: How is the BTB trained?**

A: When an actual Taken branch resolves, its PC and target are stored at the mapped entry.

**Q: How does a wrong target affect the pipeline?**

A: P3 detects the mismatch and redirects to the correct resolved PC.


## GitHub branch
`feature/tanish-btb`

**Authenticity note:** Commit only your actual work; do not claim authorship of the original shared starter files if you did not write them.
