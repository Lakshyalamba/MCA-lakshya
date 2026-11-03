# MCA — Dynamic Branch Prediction Unit (Project 5)

**Team:** Shubhaang (leader / P1), Tanish (P2), Tanmay (P3), Vansh (P4), Lakshya (P5).  
**Phase I deadline:** 16 November 2026, 11:59 PM IST.  
**Phase I rubric:** IEEE report (10), prototype video under five minutes (15), GitHub (5).  
**Phase II:** final IEEE report, continuing Git history and interview (70% of overall grading).

## Scope

This is a **Verilog branch predictor prototype** with a 2-bit Branch History Table, 1-bit and static baselines, planned tagged Branch Target Buffer, next-PC and branch-resolution control, and a trace-driven simulation harness. **It is not a complete pipelined CPU.**

## Verified starting point (22 Oct shared Mac log)

- `make test-p1`: 22/22 directed checks passed.
- `make synth-p1`: generic Yosys synthesis succeeded; 192 generic cells in the reported hierarchy, 0 check problems.
- `make demo`: one synthetic 32-branch trace; correct predictions 10 (always NT), 12 (1-bit), 15 (2-bit).
- `make test-p1-extended` is supplied but its full run on the team's Mac is **not yet confirmed**. A new independent scoreboard also needs a Mac run.
- P2 BTB, P3 recovery, broader P4 tests, P5 full metrics and integrated top are **pending team implementation**.

## Mac setup

Install Icarus Verilog, Yosys and Surfer (Homebrew). In the project root:

```bash
make test-p1
make test-p1-extended
make test-p1-scoreboard
make verify-p1
make demo
make synth-p1
surfer results/p1_bht.vcd
```

Generated outputs in `results/` are ignored by Git. Capture selected verified artefacts under `evidence/` for report/video.

## Working guides and roles

Read `docs/INTERFACES.md` first, then `docs/PROJECT_PLAN.md`, then your own guide in `docs/team_roles/`. Make authentic contributions through a personal Git branch and PR.

| Person | Role | New work required |
|---|---|---|
| Shubhaang | P1: BHT and 2-bit prediction | Strengthen verification, document state/indexing, review integration |
| Tanish | P2: tagged BTB | Implement valid/tag/target cache + tests |
| Tanmay | P3: next-PC + resolution | Implement next-PC, mispredict/flush/redirect and integrated harness |
| Vansh | P4: baseline and verification | Extend 1-bit baseline testing; BEQ/BNE traces + independent comparison |
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
22-check Mac-tested starting point. New tests are **not yet verified on Mac**.
