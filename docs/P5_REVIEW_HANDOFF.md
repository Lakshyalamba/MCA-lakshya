# P5 maintainer review handoff

Reviewed on 6 November 2026. PRs #5, #6 and #7 are still open; no merge is claimed.
Continue with these PRs in the requested order: synthesis, metrics, then docs.
The leader retains final review and merge responsibility.

## Confirmed CI and artifact evidence

| PR | Tested implementation commit | Successful P5 run | Existing RTL regression |
| --- | --- | --- | --- |
| [#5 synthesis](https://github.com/S-h-u-b-h-1/MCA/pull/5) | `17c2e9e` | [42062136317](https://github.com/S-h-u-b-h-1/MCA/actions/runs/42062136317) | P1, BTB, P3 and P4 workflows passed on this commit |
| [#6 metrics](https://github.com/S-h-u-b-h-1/MCA/pull/6) | `af0fadc` | [42062184522](https://github.com/S-h-u-b-h-1/MCA/actions/runs/42062184522) | P1, BTB, P3 and P4 workflows passed on this commit |
| [#7 integration](https://github.com/S-h-u-b-h-1/MCA/pull/7) | `fb61134` | Documentation PR; no P5 implementation added | [P1](https://github.com/S-h-u-b-h-1/MCA/actions/runs/42062285547), [BTB](https://github.com/S-h-u-b-h-1/MCA/actions/runs/42062285136), [P3](https://github.com/S-h-u-b-h-1/MCA/actions/runs/42062284870) and [P4](https://github.com/S-h-u-b-h-1/MCA/actions/runs/42062285066) passed |

These links identify the verified runs before the review documentation changes.
For newer commits, inspect the PR's latest checks before merging; old successful
runs do not certify a newer head. Earlier `action_required` runs are superseded
by successful runs on the tested commits above.

The synthesis artifact contains six full logs, six netlists and a manifest.
Inspection confirmed matching netlist totals/cell-type counts and all seven
source hashes. CI uses Yosys 0.33; Mac evidence uses 0.70+post. Different generic
counts are retained without forcing equality. PR #5's synthesis guide records
the two result sets and the target-specific timing investigation.

The metrics artifact matches every committed file under `evidence/metrics/`
byte for byte. The CI log confirms reconciliation of all 130 branches, three
workloads, 12 result rows, ten passing tests and a clean evidence diff.
Weighted accuracies are 36.923077%, 36.153846% and 42.307692%; overall illustrative
CPIs are 1.378462, 1.383077 and 1.346154. Assumptions remain ideal CPI 1, branch
fraction 0.2 and direction-miss penalty 3 cycles. BTB target and other pipeline
costs are excluded. The same metrics command and clean-diff checks passed again
locally on the existing metrics branch during review.

## Team inputs needed to finish the report and video

The existing repository contains first names and roles, but no confirmed full
author/affiliation block, five approved final sections, or five recorded clips.
The source-to-section handoff is in `report/PHASE1_REPORT_OUTLINE.md`.
The following requests are prepared for team coordination; receipt, review and
recording are not claimed to have happened.

| Member | Report review and material requested | Recording requested |
| --- | --- | --- |
| Shubhaang | Full author/affiliation details; approve Abstract, Introduction and BHT description; confirm final assembly | Self-introduction, BHT/2-bit demonstration, opening and closing |
| Tanish | Review BTB architecture against `docs/P2_BTB_DESIGN.md`; supply final prose | Self-introduction and tagged hit/miss/replacement proof |
| Tanmay | Review the preserved P3 section and integration/recovery description | Self-introduction and actual next-PC/recovery simulation |
| Vansh | Review the preserved P4 section, synthetic-workload scope and literature claims against original papers | Self-introduction, HDL/oracle comparison and waveform |
| Lakshya | Assemble reviewed sections in the official IEEE template; verify evaluation and evidence attribution | Self-introduction, synthesis logs, graph and assumed CPI example |

For each author, confirm the displayed full name, affiliation, technical section
approval and the exact commit used for their clip. Record original speech with
readable captions and preserve source clips. Use `video/DEMO_STORYBOARD.md` for
the 4:45 allocation; check final duration and signed-out hosted access before
adding the identical URL to README and `video/DEMO_LINK.md`.

No final PDF, recorded introduction, uploaded video or author approval is claimed
by these preparation documents. The final report must be visually inspected on
every page before adding `report/Phase1_IEEE_Report.pdf`.

## Timing decision for the leader

Maximum operating frequency remains unmeasured. A supported Yosys/nextpnr flow
is a candidate, but no target device/package, speed grade or timing constraints
are agreed in the repository, and nextpnr is not installed locally. Confirm the
target and resources, or ask faculty whether the disclosed limitation is accepted.
A 10 ns simulation clock does not establish a 100 MHz implementation.

## Merge and final verification

After #5 merges, update #6/#7 against main only if needed and rerun relevant
checks. After #6 merges, update README merge status in #7 using actual PR state.
Do not mark any PR merged based solely on passing checks.

After all three merge, use a fresh checkout of main:

```bash
make test
make synth-all
make metrics test-p5-metrics
git diff --exit-code -- evidence/metrics/
git diff --check
```

Preserve real logs and tool versions. Compare synthesis resources within the
same tool/flow; different Yosys versions may change the regenerated summary.
The final clean-main run remains pending the leader's merges.
