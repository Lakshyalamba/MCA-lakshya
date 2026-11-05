# Phase I IEEE report — working outline, not the final IEEE-formatted file

Use the **official IEEE conference A4/Word or LaTeX template** unless the instructor provides a different IEEE template. Do not submit this Markdown outline as the formatted report.

1. **Title, author names and affiliations** — confirm all five names spelling.
2. **Abstract** — control-hazard problem, compact BHT/BTB solution, method and *verified* prototype status.
3. **I. Introduction** — why control hazards impact pipelined processors.
4. **II. Literature Review** — static prediction, 1-bit history, 2-bit saturating counters, BTB, prior branch prediction work; cite primary sources.
5. **III. Proposed Solution** — 16-entry BHT, BTB tag/index/valid, next-PC mux, resolution/flush/redirect, interface assumptions and block diagram.
6. **IV. Prototype Implementation** (optional but useful) — tools, RTL hierarchy, directed testbenches, simulation waveform evidence.
7. **V. Individual Contributions** — every member describes actual code/tests/scripts and links to real Git commits/PRs; update after merges.
8. **References** — IEEE numbered style; cite only verified, read literature.

**Phase II adds:** Results and Discussion, Conclusion and final evidence.

Suggested primary sources to consult:
- J. E. Smith, “A Study of Branch Prediction Strategies,” Proc. ISCA, pp. 135–148, 1981.
- T.-Y. Yeh and Y. N. Patt, “Two-Level Adaptive Training Branch Prediction,” Proc. MICRO, pp. 51–61, 1991, doi:10.1145/123465.123475.

Official templates: https://conferences.ieeeauthorcenter.ieee.org/write-your-paper/authoring-tools-and-templates/

## Assembly handoff for 5 November 2026

P1–P4 are merged through PR #4. P5 synthesis, metrics and submission-integration
changes are being proposed separately; include their files after those PRs merge.
The final IEEE PDF is still pending author review and formatting.

| Section | Author or reviewer | Source and remaining action |
| --- | --- | --- |
| Title and affiliations | All five; leader assembles | Confirm full names, rolls and affiliations |
| Abstract and Introduction | Leader; all review | Describe the branch-predictor prototype and verified scope |
| Literature Review | Vansh and leader | Review `P4_REPORT_SECTION.md`; read cited papers and qualify general claims before submission |
| Proposed Architecture: BHT | Shubhaang | `docs/P1_IMPLEMENTATION_NOTES.md`; obtain author's final prose |
| Proposed Architecture: BTB | Tanish | `docs/P2_BTB_DESIGN.md`; obtain author's final prose |
| Proposed Architecture: control | Tanmay | `P3_REPORT_SECTION.md`; preserve authored section and request review |
| Verification | Vansh | `P4_REPORT_SECTION.md`; preserve HDL/oracle attribution |
| Evaluation methodology | Lakshya | `P5_REPORT_SECTION.md`, generated accuracy, assumptions and generic synthesis summary |
| Individual Contributions | Each member; leader verifies | Link actual commits/PRs after merge; do not attribute P1–P4 RTL to P5 |
| References | All section authors | Verify each cited claim against its primary source; unify numbering |

Use [IEEE's conference template guidance](https://conferences.ieeeauthorcenter.ieee.org/write-your-paper/authoring-tools-and-templates/)
for the final Word or LaTeX file. The official guidance provides both formats;
this outline remains an assembly aid, not a submission-ready report.

Before exporting `Phase1_IEEE_Report.pdf`, reconcile synthesis results by tool
version. Earlier P3 evidence and the new flattened P5 flow need not yield
identical generic counts. Do not overwrite the original author evidence or
present counts from different flows as a controlled hardware comparison.

The [maintainer review handoff](../docs/P5_REVIEW_HANDOFF.md) lists the exact
outstanding author details, section approvals and recordings required from each
member. Collect those inputs before treating an assembled manuscript as final.
