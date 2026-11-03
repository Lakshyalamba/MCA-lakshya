# P5 — Lakshya: Synthesis, metrics, report integration and video

**Personal responsibility:** Make hardware results reproducible, analyze performance fairly, and assemble submission evidence without replacing others’ authored work.

**Timeline:** 4–6 Nov: scripts and report shell; 9–12 Nov: data and draft; 13–15 Nov: video and release check.

## Files owned
- scripts/synth_all.sh or scripts/synth_all.ys (new reproducible synthesis)
- scripts/collect_metrics.py (new parsing and chart generation)
- evidence/synthesis/summary.md (from real tool logs)
- evidence/metrics/accuracy.csv and evidence/metrics/cpi_assumptions.md
- report/PHASE1_REPORT_OUTLINE.md (coordinate author sections, not sole author)
- video/DEMO_STORYBOARD.md and final video link in README

## Interface contract
- Consume the same P4 trace counts: total, correct, mispredict count per predictor.
- Accuracy = correct / total * 100; misprediction rate = 1 - accuracy/100.
- Illustrative CPI = ideal CPI + branch frequency * misprediction rate * penalty cycles.
- Explicitly label ideal CPI, branch fraction, and penalty as assumed parameters.
- Yosys stat is GENERIC logic/gate/register usage, not a measured FPGA LUT count or maximum frequency.
- Do not fabricate screenshots, external timing results, benchmark speedups, or simulation outcomes.

## Implementation steps
1. Read IEEE Phase I rubric and use the official IEEE conference Word or LaTeX template if the instructor has not given a variant.
2. Write a reproducible synthesis script that processes P1, P2, P3 and integrated top only after their modules arrive; preserve raw logs under generated results.
3. Write a small metrics script that parses P4 CSV counts and computes accuracy, misprediction rate and CPI under printed assumptions.
4. Create a clean comparison chart with explicit labels and workload names; show all predictors on identical trace sets.
5. Collaborate with the group on IEEE Abstract, Related Work, Proposed Architecture, Individual Contributions and References. Each member writes/reviews their real section.
6. Collect waveform screenshots and exact commands from each member for the video; record the full simulator and the interactive HTML only as a supplemental visualization.
7. Edit a 4:30–4:50 video including all five member introductions, live prototype verification, and final results; captions and readable terminals.
8. Upload or host the video where reviewers can open it; add the actual link to README and submit only after testing access.

## Tests / evidence
- Recalculate a result independently from raw counts and validate CSV column order.
- Yosys script exits nonzero on failed parsing/synthesis; output marked generic vs target-specific.
- Video duration < 5 minutes and introductions explicitly cover all five people.
- Report has actual sourced citations and no invented experiment data.
- All GitHub links (report/video/evidence) work without permissions errors.

## Acceptance checklist
- [ ] Synthesis and metrics reproducible from a clean checkout.
- [ ] Video 4:30-4:50 with real verification + all member introductions.
- [ ] IEEE Phase I report and repo artefacts complete; contributions verified by leader.
- [ ] PR contains authored code/scripts, rather than only document formatting.

## Viva questions
**Q: What does RTL synthesis do?**

A: It turns described hardware processes and logic into a gate/register representation for the selected mapping flow.

**Q: How do you calculate accuracy?**

A: Correct predictions divided by number of dynamic branches, times 100.

**Q: What causes CPI penalties?**

A: Mispredicted branches may waste fetch/execution work before redirect.

**Q: Why is predicted CPI not measured CPU CPI?**

A: Our study uses a parametric penalty model without a complete execution pipeline.

**Q: Why might more hardware not always improve accuracy?**

A: Branch access patterns and aliasing determine effectiveness; costs and accuracy trade off.

**Q: What must be in Phase I IEEE report?**

A: Abstract, literature review, proposed solution, individual contributions and references.


## GitHub branch
`feature/lakshya-evaluation`

**Authenticity note:** Commit only your actual work; do not claim authorship of the original shared starter files if you did not write them.
