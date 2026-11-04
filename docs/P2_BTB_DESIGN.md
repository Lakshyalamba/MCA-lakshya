# P2: Tagged Branch Target Buffer (BTB)

Owner: Tanish. Complements P1 direction prediction (BHT predicts direction, BTB predicts target).

## 1. Table fields
16 direct-mapped entries. Each entry stores:

| Field  | Width   | Meaning                             |
|--------|---------|-------------------------------------|
| valid  | 1 bit   | Entry holds a trained branch        |
| tag    | 26 bits | PC[31:6], identifies the branch     |
| target | 32 bits | Resolved target of the taken branch |

## 2. Tag / index diagram

    31                    6 5      2 1  0
    +-----------------------+--------+----+
    |      tag (26 bits)    | index  | -- |
    +-----------------------+--------+----+
                             (4 bits)  ignored

- Index = PC[5:2] selects one of 16 entries.
- Tag = PC[31:6] is compared on every lookup.

## 3. Behaviour
- Lookup is combinational: hit = valid[index] && (tag[index] == lookup_pc[31:6]).
- Update is synchronous: on the rising edge with update_valid=1, write tag, target and set valid.
- Reset is synchronous and clears all valid bits. Tags and targets are not reset.
- The caller asserts update_valid only for resolved TAKEN branches.

## 4. Interface
Inputs: clk, reset, lookup_pc[31:0], update_valid, update_pc[31:0], update_target[31:0]
Outputs: hit, target[31:0] (target is ignored when hit=0)

## 5. Hit / miss cases
| Case            | Condition                                   | Result                       |
|-----------------|---------------------------------------------|------------------------------|
| Cold miss       | Entry invalid (after reset)                 | hit=0                        |
| Hit             | valid and tag matches                       | hit=1, target returned       |
| Alias miss      | Same index, different tag (0x100 vs 0x140)  | hit=0                        |
| Replacement     | New update to the same index                | Old entry is overwritten     |
| Changed target  | Update to the same PC with a new target     | Stored target is replaced    |
| update_valid=0  | No write on the clock edge                  | Table unchanged              |

## 6. Test results
Directed tests in testbench/tb_btb.sv: cold miss, learn taken branch, target hit,
different-PC miss, alias conflict, replacement, update_valid=0, changed target, reset.
Result: 17 passed, 0 failed (ALL TESTS PASSED).
Synthesis (Yosys): 0 problems found.

Waveform: ![BTB waveform](../evidence/waveforms/btb.png)

## 7. Notes for P3
Use only `hit` and `target`. Ignore `target` when `hit=0`. If the predicted target
is wrong, P3 redirects to the correct resolved PC.

## 8. Parameterization
INDEX_BITS (default 4) gives ENTRIES = 2^INDEX_BITS and TAG_BITS = 30 - INDEX_BITS.
Verified with INDEX_BITS = 2 (4 entries), 4 (16 entries) and 5 (32 entries).
Alias PC = PC_A + (ENTRIES * 4), so aliasing is computed per configuration.

## 9. Complete test coverage
- tb_btb.sv (default 16 entries): 17 checks, covering cold miss, learn, hit, other-PC miss, alias, replacement, independent indices, changed target, update_valid=0, same-cycle lookup/update and reset.
- tb_btb_param.sv: reset priority over update_valid, all entries trained with unique targets, disabled updates, tag collision, same-cycle lookup/update, target replacement and reset recovery.
- Results: 17 checks passed (default); 23 (4 entries), 59 (16 entries) and 107 (32 entries) checks passed, 0 failed.
- Run with `make test-btb`. A failed check calls $fatal, so make exits nonzero (verified by temporarily breaking one expected value: exit code 2).
- Log: evidence/btb_logs/btb_test.log

## 10. Synthesis (Yosys, check -assert)
Run with `make synth-btb-checked`. Result: check found 0 problems.
Default 16-entry resource counts: 2404 cells, including 928 $_DFFE_PP_, 16 $_DFF_P_, 675 $_MUX_, 259 $_AND_, 180 $_NAND_, 125 $_ORNOT_, 115 $_OR_.
Tools: Icarus Verilog 13.0, Yosys 0.70. Logs and versions: evidence/btb_logs/

## 11. Integration contract (P3 / Tanmay)
The BTB does not know whether a branch was taken. Tanmay's resolution logic must assert update_valid only for a valid, resolved TAKEN branch that should be trained, with update_pc = branch PC and update_target = resolved target.
P3 uses only hit and target, and ignores target when hit=0. A wrong target is corrected by redirecting to the resolved PC.

## 12. Known limitations
Direct-mapped, so aliasing PCs evict each other. Reset clears valid bits only; tags and targets are not cleared. Lookup is combinational; updates become visible after the clock edge.
