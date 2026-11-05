# P5 integration status and submission handoff

Reviewed on 5 November 2026 against main at `734c04b` and the P5 working branches.
P1–P4 are merged through PR #4. P5 adds evaluation/integration work; it does not
claim authorship of the existing team RTL or tests.

## Checked locally during P5 work

- `make test`: existing P1/P2/P3/P4 regression and HDL/oracle reconciliation passed.
- `make synth-all`: all six synthesizable tops passed checked generic synthesis.
- Failed Yosys invocation: nonzero exit with no stale success summary.
- `make metrics test-p5-metrics`: counts reconciled; 12 derived predictor rows;
  10 focused tests passed, including independent arithmetic and corrupt CSV rejection.

New targets are supplied by the separate P5 synthesis and metrics PRs. The report
and storyboard can be reviewed independently, then commands rerun after merging.
Generic counts vary by tool version; retain version and hashes with each run.

## Before submission

- [ ] Merge the P5 synthesis and metrics PRs and rerun their CI on main.
- [ ] Run `make test`, `make synth-all`, `make metrics test-p5-metrics` from a clean checkout.
- [ ] Preserve selected real tool logs and CI artifact links with the final commit.
- [ ] Obtain all five authors' section review and confirm names/affiliations.
- [ ] Check literature claims against the original sources and unify references.
- [ ] Format the reviewed report in the official IEEE template and export
      `report/Phase1_IEEE_Report.pdf`; check every page visually.
- [ ] Record each member and assemble the 4:30–4:50 video using the storyboard.
- [ ] Verify duration, introductions, readable captions and actual prototype proof.
- [ ] Upload the real video; check signed-out access and add its URL to README
      and `video/DEMO_LINK.md`.
- [ ] Test GitHub report/evidence links and the video link as a reviewer.
- [ ] Leader verifies actual contribution links and submits before
      16 November 2026, 11:59 PM IST.

The final report, team recordings, hosted video and leader signoff need team input.
Maximum operating frequency is still unmeasured; decide a device/constraints flow
with the team or explicitly state that limitation in the report.

## Maintainer review follow-up

The original PR-head CI runs are now successful, including P5 synthesis and
metrics. See [the review handoff](P5_REVIEW_HANDOFF.md) for tested commits, actual
run links, artifact verification, timing prerequisites and the member-by-member
report/recording requests. Check the latest head's CI again after new commits.
The README scope now identifies the BTB as implemented. All three PRs remain
under review; the final PDF, video and clean merged-main regression remain pending.
