# P1 quickstart — Shubhaang

The two existing RTL modules (`branch_history_table.v`, `predictor_2bit.v`)
remain **unchanged** from the previously Mac-tested starter. This update adds
an independent scoreboard, three table sizes, a checked synthesis target, and
a detailed implementation/viva guide.

**1. Open the repository directory you actually use on your Mac.**

```bash
cd ~/Downloads/MCA_Team_Kit/MCA_Project_Repository
```

**2. Run full P1 verification:**

```bash
make verify-p1
```

This runs existing 22-check directed tests; the 184-check extended suite;
a new independent, deterministic reference scoreboard for BHT table sizes
4, 16 and 32; and a generic Yosys synthesis with `check -assert`.
Any failing assertion or compiler/synthesizer error should stop the target.

**3. Run the comparison demo and inspect signals:**

```bash
make demo
surfer results/p1_bht.vcd
```

Display `clk`, `reset`, `lookup_pc`, `update_pc`, `update_valid`,
`actual_taken`, `prediction_state` and `predict_taken` in Surfer.

**4. Archive evidence:**

```bash
bash scripts/capture_p1_evidence.sh
```

This command reruns the full P1 acceptance, makes an evidence folder with
actual passing logs and a machine-generated run summary. Add a readable Surfer
screenshot manually. Do not commit generated simulator binaries or large
`.vcd` files by default.

**5. Reuse the published P1 contribution:**

P1's feature branch and PR #1 already exist. Do not recreate the branch,
rewrite history, or reapply old ZIP files. After PR #1 is merged, a fresh
checkout of `main` has the verified P1 baseline. Other members should follow
`docs/TEAM_START_HERE.md` to submit authentically authored PRs from forks.


For every concept you will need in viva, read `docs/P1_IMPLEMENTATION_NOTES.md`.
