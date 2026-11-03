# P1 evidence ledger — honest status

- **22 Oct 2026, prior Mac run:** 22/22 directed checks passed; VCD opened in
  Surfer; Yosys produced 192 generic cells and reported 0 design-check issues.
  These facts come from the owner's terminal output, not a new run.
- **3 Nov 2026, new verification suite:** Adds an independent reference
  scoreboard and checked-synthesis command. **No Mac execution is yet shown**;
  these are not passing results until `make verify-p1` succeeds.
- **To create genuine current evidence:** Execute
  `bash scripts/capture_p1_evidence.sh` on the Mac. The script stops if a
  test/compile/synthesis step fails and copies the actual result logs.
- **Do not claim** FPGA-specific LUTs, maximum MHz, measured CPI, a complete
  processor, or finished BTB/flush integration from this P1-only evidence.
