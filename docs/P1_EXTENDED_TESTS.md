# P1 extended verification (additive testbench)

This package adds `testbench/tb_p1_extended.sv` and does **not** replace or edit existing RTL. It expects the existing `predictor_2bit` module and its `branch_history_table` dependency.

## On Mac

From the MCA repository root, with Icarus Verilog and Yosys installed:

```bash
make verify-p1
surfer results/p1_extended.vcd
```

The extended testbench is already tracked in the repository. Do not unzip
an older standalone test archive over maintained source files.

Expect `ALL EXTENDED P1 CHECKS PASSED (184 checks)` only if every assertion succeeds. A failing assertion calls `$fatal(1, ...)`.

## Verified behaviors (if the test passes)

- All 16 entries start at weak-not-taken (`01`)
- Every entry transitions `01 -> 10 -> 11 -> 11 -> 10 -> 01 -> 00 -> 00`
- Entries are independent
- Updates are ignored when `update_valid=0`
- PCs 64 bytes apart alias in this 16-entry direct-mapped BHT
- Independent lookup PC and update PC operate correctly
- Same-index read/write state changes only after the rising edge
- Synchronous reset takes priority over update

## Interpretation

A passing directed testbench is evidence for its exercised cases, not formal proof of all possible designs, processor-level behavior, target prediction, or FPGA timing. Keep the original 22-check test and the new extended test as separate evidence.

## Verified Mac evidence

The 184-check extended suite and all three scoreboards passed on 3 November 2026. See `evidence/P1_20261103_185000/`.
