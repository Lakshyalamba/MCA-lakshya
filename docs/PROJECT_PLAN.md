# Project plan: Dynamic Branch Prediction Unit

Deadline: **16 Nov 2026, 11:59 PM IST**. Phase I report (10), video (15), repo (5).

## Architecture
Fetch PC -> (P1 BHT and P2 BTB parallel) -> P3 Next-PC -> resolution -> P3 compare and recover -> P1/P2 trained state. P4 provides fair traces; P5 analyzes reproducible results.

## Individual roles
- **Shubhaang (Leader) / P1:** 2-bit predictor and Branch History Table; branch `feature/shubhaang-bht`.
- **Tanish / P2:** Tagged Branch Target Buffer (BTB); branch `feature/tanish-btb`.
- **Tanmay / P3:** Next-PC selection, branch resolution, flush/redirect; branch `feature/tanmay-control`.
- **Vansh / P4:** Baseline predictors, branch traces and verification; branch `feature/vansh-baselines-verification`.
- **Lakshya / P5:** Synthesis, metrics, report integration and video; branch `feature/lakshya-evaluation`.

## Milestones
- **3–4 Nov:** Repository created; everyone clones, reads interface contract; assign PRs and open issues.
- **5–7 Nov:** P1 extended verification, P2 BTB RTL, P3 control RTL, P4 trace suite, P5 scripts and report shell.
- **8–10 Nov:** Merge independently passing modules; integrated correct/wrong branch/target cases and regression.
- **11–12 Nov:** Freeze working demo; capture real waveforms, accuracy tables, synthesis logs; draft report.
- **13–14 Nov:** IEEE Phase I report review; record/edit video; all five explain their own code.
- **15 Nov:** Full clean-checkout rehearsal; verify links/video length/access; final submission review.
- **16 Nov:** Submit BEFORE 11:59 PM IST (aim for evening buffer); archive evidence and submission receipt.

## Submission checks
- [ ] IEEE abstract, literature review, proposed solution, individual contributions, references.
- [ ] All five introduced and visible/heard in video of less than five minutes.
- [ ] Report and video link in repo.
- [ ] Actual working Verilog, testbenches, verified waveforms, metrics and synthesis evidence.
- [ ] Authentic individual Git commits and reviewed PRs.
- [ ] Phase I form submitted before deadline.

## Project restrictions
Do not claim a full CPU, measured CPU speedup, target FPGA operating frequency, or passing tests that have not been run.
