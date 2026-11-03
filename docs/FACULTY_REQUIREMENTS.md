# Faculty requirements and evidence gates — MCA Project 5

**Faculty source:** [Modern Computer Architecture Project 5: Dynamic Branch Prediction Unit](https://docs.google.com/document/d/1CoQOY3T4p0qY1B9qR3WPh8I93aCyN-zIs9VF17kBMNU/edit). Evaluation rubric: team notice shared 3 November 2026.

## Project 5 technical scope

Implement and evaluate branch direction/target prediction to reduce control-hazard penalties. Faculty suggests BHT, 1-/2-bit prediction logic, update logic, branch-target storage, and a flush/control interface. Test loop-oriented BEQ and BNE branch traces; compare always-not-taken, 1-bit and 2-bit accuracy; estimate CPI impact with stated assumptions.

| Faculty requirement | Evidence and current status (3 Nov) |
| --- | --- |
| System/microarchitecture diagram | `docs/system_workflow.png` and `docs/interactive_workflow.html`: conceptual; update after integration |
| Synthesizable modular RTL | P1 predictor synthesized; P2 tagged BTB and P3 recovery modules pending |
| Directed tests and simulation waveforms | P1 27,935 checks passed, VCD created; repository screenshot pending |
| Baseline strategy comparison | Synthetic 32-branch test present; P4's BEQ/BNE trace suite and independent results pending |
| Quantitative metrics and estimated CPI | Accuracy from synthetic trace exists; P5 larger experiments and explicit CPI assumptions pending |
| Synthesis resources and **maximum operating frequency** | P1 generic 192 cells, 32 FF; **no target-specific timing or MHz yet** |
| Technical report and live demonstration | Phase I/II preparation and video pending |

A common faculty requirement calls for resource utilization and maximum operating frequency. A real frequency number requires a chosen device/library, clock constraints, and timing/place-and-route analysis. A generic Yosys cell count cannot establish MHz or FPGA LUTs. Document any tool/device limitations if a measured Fmax is not feasible.

## Phase I: 30% of grade, due 16 November 2026, 11:59 PM IST

| Deliverable | Marks | Required content | Status |
| --- | ---: | --- | --- |
| IEEE project report | 10 | Abstract, literature review, proposed solution, individual contributions, references | Working outline only; final formatted PDF pending |
| Prototype demo video | 15 | Project idea, **all five members introduced**, working prototype/progress, **at most 5 minutes** | Storyboard present; actual video/link pending |
| GitHub repository | 5 | Report PDF, demo-video link, prototype/source files, supporting artefacts and authentic individual history | Repository exists; P1 PR only so far |

Report outline: `report/PHASE1_REPORT_OUTLINE.md`. Final PDF: `report/Phase1_IEEE_Report.pdf`. Video link: `video/DEMO_LINK.md`. Submission: https://docs.google.com/forms/d/e/1FAIpQLSc6Cx8OrOQLGj_X2ZMkyG5jc8mokq36mGRq2x8jGRNV1sbegA/viewform

### Remaining Phase I signoff

- [ ] Merge tested P2 BTB, P3 next-PC/recovery, P4 baseline/BEQ-BNE evaluation and P5 metric/report work.
- [ ] Run integrated demonstration including correct prediction, wrong direction, BTB miss and wrong target.
- [ ] Capture waveform screenshots, accuracy table and synthesis/resource evidence; state timing limitations.
- [ ] Write/format IEEE report and accurately attribute all five members' real work.
- [ ] Record a video of **no more than 5:00**, introduce all five, demonstrate actual progress, upload with accessible URL.
- [ ] Verify every contributor's Git history, report and video URL in main and submit the form before the deadline.

## Phase II: 70% of grade

The **final IEEE report** must add Results and Discussion and Conclusion to the Phase I sections. Maintain meaningful Git history throughout the project. All members must defend the full architecture and their personal parts at the interview; exact interview slots have not been announced.

**Do not claim:** a finished pipelined CPU, full-system integration, measured CPI improvement, target FPGA LUT use, or measured maximum MHz from P1-only evidence.
