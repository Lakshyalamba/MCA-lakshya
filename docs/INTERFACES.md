# Interface contract — freeze on Day 1

## Shared conventions
- 32-bit byte PC addresses; normal sequential next PC is `pc + 4`.
- Single clock (`clk`) and active-HIGH **synchronous** `reset`.
- Lookup ports are combinational. Update ports apply on the rising clock edge only when `update_valid=1`.
- The lookup branch and updated/resolved branch are NOT necessarily the same instruction: separate `lookup_pc` and `update_pc` are essential.
- We assume only aligned 32-bit instructions for the study project; a full RISC-V compressed instruction frontend requires other handling.
- The actual branch outcome is known only at resolution. Never feed it into prediction for that same dynamic branch instance (future-information leakage).

## P1 direction predictor — implemented in starter
`predictor_2bit`: inputs `clk, reset, lookup_pc[31:0], update_valid, update_pc[31:0], actual_taken`; outputs `predict_taken`, `prediction_state[1:0]`.

BHT starts with 16 independent entries, indexed by `PC[5:2]`, initialized to `01` on reset. State transition on update:
- Taken: `00 -> 01 -> 10 -> 11 -> 11`.
- Not taken: `11 -> 10 -> 01 -> 00 -> 00`.
- Prediction is the MSB: `00/01` not-taken, `10/11` taken.
- Distinct PCs that share these index bits alias; a tagless BHT **cannot** distinguish them.

## P2 Branch Target Buffer (BTB) — implementation pending
Proposed ports: inputs `clk, reset, lookup_pc[31:0], update_valid, update_pc[31:0], update_target[31:0]`; outputs `hit, target[31:0]`. Each of 16 entries should hold `valid`, `tag` (upper PC bits), and `target`. Index `PC[5:2]`; tag PC[31:6]. Initialize valid bits to zero. On update set valid+tag+target. On alias collision, newest valid tagged entry replaces prior entry. When `hit=0`, consumers must not use `target`.

## P3 branch resolution — implementation pending
Proposed combinational inputs: `valid, branch_pc[31:0], predicted_taken, btb_hit, predicted_target[31:0], actual_taken, actual_target[31:0]`. Outputs: `mispredict, flush, redirect, redirect_pc[31:0]`.

Define `actual_next_pc = actual_taken ? actual_target : (branch_pc + 4)`. A resolved branch requires recovery if direction mismatches OR if both directions are Taken but target lookup is missing/incorrect. `mispredict=valid && (predicted_taken != actual_taken || (actual_taken && (!btb_hit || predicted_target != actual_target)))`. Then `flush=mispredict`, `redirect=mispredict`, `redirect_pc=actual_next_pc` when redirecting. P3 must explicitly test all four direction combinations, BTB hit/miss and wrong targets. An actual pipeline would also manage staged metadata and instruction kills; a `flush` signal alone is not a full CPU.

## P4 metrics
Compare predictors on identical, *resolved* dynamic branch sequences. Count each prediction before applying that branch's update. Report trace size, correct predictions, total, accuracy, and misprediction rate. For illustration: CPI estimation uses `CPI ~= ideal_CPI + branch_frequency * misprediction_rate * misprediction_penalty`, with all assumptions printed. No fabricated clock MHz or measured CPU speedup.

## P5 synthesis
Use Yosys to report generic logic/resources. Yosys `stat` alone does not establish maximum clock speed for a particular FPGA; a suitable technology mapping/constraints/timing tool is needed to quote frequency.
