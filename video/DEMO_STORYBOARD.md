# Phase I prototype video storyboard

Target duration: 4:45 (285 seconds). Record all five people introducing
themselves, readable terminals and captions. A real recording and hosted URL
are still pending; this storyboard is not evidence that the video is complete.

| Time | Speaker | Recording and narration |
| --- | --- | --- |
| 0:00–0:20 | Shubhaang | Introduce self and problem; explain this is a branch-predictor prototype |
| 0:20–0:30 | Tanish | Introduce self and tagged BTB responsibility |
| 0:30–0:40 | Tanmay | Introduce self and next-PC/recovery responsibility |
| 0:40–0:50 | Vansh | Introduce self and trace verification responsibility |
| 0:50–1:00 | Lakshya | Introduce self and synthesis/metrics responsibility |
| 1:00–1:35 | Shubhaang | Show BHT state/indexing and real `make test-p1` output |
| 1:35–2:05 | Tanish | Show `make test-btb`, valid/tag hit and alias replacement |
| 2:05–2:40 | Tanmay | Show `make test-p3 test-p3-integrated`; direction miss, BTB miss and wrong target recovery |
| 2:40–3:20 | Vansh | Show `make test-p4-compare`, matching HDL/oracle counts and simulation waveform |
| 3:20–4:20 | Lakshya | Show `make synth-all` logs/summary, `make metrics`, chart and assumed CPI example |
| 4:20–4:45 | Shubhaang | Summarize current scope and remaining device timing/full pipeline work |

## Capture handoff

Each member supplies a short recording with their own introduction, exact command,
current commit ID, uncut passing terminal output and explanation of their part.
Capture commands from the repository root. Long-running synthesis can be prepared
before recording; label any cut and show the actual saved log and tool version.
Preserve original recordings so reviewers can reproduce the demonstration.

| Owner | Command | Evidence to show |
| --- | --- | --- |
| P1 | `make test-p1` | `results/p1_test.log`, `results/p1_bht.vcd` |
| P2 | `make test-btb` | Live test output, `results/btb.vcd` |
| P3 | `make test-p3 test-p3-integrated` | `results/p3_control_test.log`, `results/p3_integrated_test.log`, `results/p3_integrated.vcd` |
| P4 | `make test-p4-compare` | Reconciled CSV and `results/p4_comparison.vcd` |
| P5 | `make synth-all` then `make metrics` | Generic synthesis summary/logs; accuracy SVG/CSV; CPI assumptions |

Use a full simulator/VCD viewer for waveform verification. Existing images under
`evidence/waveforms/` can support narration; the interactive HTML is supplemental.
Do not describe a conceptual diagram as a captured simulator result.

## Lakshya's narration points

“I run each RTL top through checked generic synthesis. These counts describe
Yosys generic cells and do not measure FPGA LUTs or maximum clock frequency.
The direction comparison top is not a full CPU. Our metrics consume the same
P4 counts that match the independent oracle. The loop trace gives 31 correct
2-bit predictions out of 40: 77.5% accuracy and a 0.225 miss rate. Assuming ideal
CPI 1, branch fraction 0.2 and penalty 3 cycles gives illustrative CPI 1.135.
Across all 130 branches the 2-bit accuracy is 42.31%. The alternating workload
shows why dynamic prediction does not always beat the static baseline.”

## Final editing and publication checks

- [ ] Every member's self-introduction is audible and captioned.
- [ ] Commands, commit ID, waveform labels and chart axes are readable.
- [ ] Real tests and synthesis are shown; no fabricated output or timing claims.
- [ ] Final duration is 4:30–4:50, strictly below 5 minutes.
- [ ] Report and chart values match the final committed evidence.
- [ ] Upload the actual video, test access while signed out, then update both
      `video/DEMO_LINK.md` and README with the identical accessible URL.

If `ffprobe` is installed, check the exported recording with:
`ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 demo.mp4`.
A duration check does not replace reviewing introductions, captions and access.
