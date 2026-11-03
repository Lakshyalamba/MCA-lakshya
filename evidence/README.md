# Evidence policy and status

Commit genuine reproducible logs and presentation-ready waveforms, not generated simulator binaries or fabricated results.

**P1 Mac run, 3 November 2026:** 22 directed + 184 extended + 8,443 (4-entry) + 9,163 (16-entry) + 10,123 (32-entry) = **27,935 passing checks**. Yosys reported 192 generic cells (32 state flip-flops), zero design-check problems. Logs and tool versions: `evidence/P1_20261103_185000/`.

The run summary contains a pre-rebase local Git SHA; this is historically accurate and must not be edited. See `evidence/P1_EVIDENCE_STATUS.md` for its relation to the published P1 commit.

Still missing: repository waveform screenshot, P2/P3 unit and integrated testing, reproducible BEQ/BNE benchmark, full-system synthesis/timing target, Phase I report/video.

Generic Yosys cells are **not** measured FPGA LUT utilization or maximum operating frequency.
