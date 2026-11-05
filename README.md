# MCA — Dynamic Branch Prediction Unit (Project 5)

- **Team:** Shubhaang (leader / P1), Tanish (P2), Tanmay (P3), Vansh (P4), Lakshya (P5).
- **Phase I deadline:** 16 November 2026, 11:59 PM IST.
- **Phase I rubric:** IEEE report (10), prototype video under five minutes (15), GitHub (5).
- **Phase II:** final IEEE report, continuing Git history and interview (70% of overall grading).

## Scope

This is a **Verilog branch predictor prototype** with a 2-bit Branch History Table, 1-bit and static baselines, implemented tagged Branch Target Buffer, next-PC and branch-resolution control, and a trace-driven simulation harness. **It is not a complete pipelined CPU.**

## Verified starting point (22 Oct shared Mac log)

- `make test-p1`: 22/22 directed checks passed.
- `make synth-p1`: generic Yosys synthesis succeeded; 192 generic cells in the reported hierarchy, 0 check problems.
- `make demo`: one synthetic 32-branch trace; correct predictions 10 (always NT), 12 (1-bit), 15 (2-bit).
- `make test-p1-extended`: 184/184 checks passed on 3 November 2026.
- `make test-p1-scoreboard`: 8,443 + 9,163 + 10,123 checks passed across 4-, 16-, and 32-entry configurations.
- `make synth-p1-checked`: generic synthesis and design checks passed.
- `make test-btb`: P2 tagged BTB unit and parameter sweeps verified (merged in PR #2).
- `make test-p3`: 24/24 directed checks passed for next-PC mux and branch resolution (merged in PR #3).
- `make test-p3-integrated`: 26/26 integration checks passed for P1 BHT + P2 BTB + P3 control pipeline harness.
- `make verify-p3`: simulation (50/50 checks) and generic Yosys synthesis passed (0 errors; next_pc_mux 91 cells, branch_resolution 223 cells).
- `make check-traces`: validates schemas, monotonic sequence numbers, and operand conditions on committed traces.
- `make test-p4-unit`: 113/113 checks passed for expanded predictor assertion harness (cold start on 4 representative entries, 32-branch benchmark, reset priority, aliasing).
- `make test-p4-comparison`: 541/541 checks passed across 3 deterministic trace workloads (130 dynamic branches), P3 recovery coordination, and 16 vs 32-entry capacity sensitivity (48% vs 74%).
- `make test-p4-oracle`: independent Python reference model verifies 100% agreement with explicit benchmark regression assertions.
- `make test-p4-compare`: automated reconciliation script guarantees Verilog simulation and Python oracle parity across all counts and fields before publishing evidence.
- `make verify-p4`: full P4 simulation suite (654 checks), Yosys checked synthesis (0 problems, 92 cells for 1-bit, 284 cells for top), and dynamic VCD waveform generation completed.
- P5 synthesis automation, validated metrics/CPI and report/video integration are proposed in Lakshya’s contribution branches; merge and rerun before submission. Final report PDF and recorded video remain pending.

## Mac setup

Install Icarus Verilog, Yosys and Surfer (Homebrew). In the project root:

```bash
make test-p1
make test-p1-extended
make test-p1-scoreboard
make verify-p1
make test-btb
make test-p3
make test-p3-integrated
make verify-p3
make check-traces
make test-p4-unit
make test-p4-comparison
make test-p4-oracle
make test-p4-compare
make verify-p4
make test
make demo
make synth-p1
surfer results/p1_bht.vcd
```

Generated outputs in `results/` are ignored by Git. Capture selected verified artefacts under `evidence/` for report/video.

## Working guides and roles

Read `docs/INTERFACES.md` first, then `docs/PROJECT_PLAN.md`, then your own guide in `docs/team_roles/`. Make authentic contributions through a personal Git branch and PR.

| Person | Role | New work required |
|---|---|---|
| Shubhaang | P1: BHT and 2-bit prediction | Strengthen verification, document state/indexing, review integration (Merged PR #1) |
| Tanish | P2: tagged BTB | Implement valid/tag/target cache + tests (Merged PR #2) |
| Tanmay | P3: next-PC + resolution | Implement next-PC, mispredict/flush/redirect and integrated harness (Merged PR #3) |
| Vansh | P4: baseline and verification | Extend 1-bit baseline; BEQ/BNE traces + independent comparison suite (Merged PR #4) |
| Lakshya | P5: synthesis, metrics and video | Automated synthesis + result analysis + final evidence and report assembly |

## Submission

- Use the [official IEEE conference templates](https://conferences.ieeeauthorcenter.ieee.org/write-your-paper/authoring-tools-and-templates/) unless faculty provides a specific local variant.
- Put the real final report at `report/Phase1_IEEE_Report.pdf` when ready.
- Put a public/accessible video link in `video/DEMO_LINK.md` and README; don't commit a large MP4 to Git.
- Confirm every team member appears in the video and has substantive commits and a report contribution.
- Submission form: https://docs.google.com/forms/d/e/1FAIpQLSc6Cx8OrOQLGj_X2ZMkyG5jc8mokq36mGRq2x8jGRNV1sbegA/viewform

## P1 independent verification handoff (3 Nov 2026)

See [P1 quickstart](docs/P1_QUICKSTART.md) and
[P1 implementation/viva notes](docs/P1_IMPLEMENTATION_NOTES.md).
The additional reference scoreboard tests `INDEX_BITS=2`, `4`, and `5`,
including all 8 direction/state transitions per entry, randomized updates,
reset priority, aliasing and concurrent lookup/update PCs.
The two existing P1 RTL files were intentionally **left unchanged** from the
22-check Mac-tested starting point. Extended tests and independent scoreboards **passed on Mac on 3 November 2026**.

## Faculty alignment and team onboarding

- [Faculty Project 5 and Phase I/II checklist](docs/FACULTY_REQUIREMENTS.md): completed evidence versus outstanding deliverables.
- [Start here for all teammates](docs/TEAM_START_HERE.md): forking, cloning, assigned branches and integration requirements; no collaborator invitation required.
- P1–P4 RTL and tests are merged through PR #4, including P2/P3 simulation integration and BEQ/BNE traces. Target-specific timing, the final IEEE report and recorded video remain pending. This is a branch-predictor prototype.

## P5 evaluation and submission handoff

P5 contributions are open for review:
[synthesis #5](https://github.com/S-h-u-b-h-1/MCA/pull/5),
[metrics #6](https://github.com/S-h-u-b-h-1/MCA/pull/6), and
[report/video handoff #7](https://github.com/S-h-u-b-h-1/MCA/pull/7).

After merging the P5 synthesis and metrics PRs:

```bash
make test
make synth-all
make metrics test-p5-metrics
```

- Generic synthesis: `evidence/synthesis/summary.md`; raw logs/netlists in `results/synthesis/`.
- Accuracy/CPI: `evidence/metrics/accuracy.csv`, `accuracy.svg`, and `cpi_assumptions.md`.
- [P5 report contribution](report/P5_REPORT_SECTION.md) and [author handoff](report/PHASE1_REPORT_OUTLINE.md).
- [Video capture plan](video/DEMO_STORYBOARD.md) and [submission checklist](docs/P5_SUBMISSION_CHECKLIST.md).

The final PDF and public demo URL are pending. Add the tested hosted video URL
here and in `video/DEMO_LINK.md` after recording; no final video is currently claimed.
