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
