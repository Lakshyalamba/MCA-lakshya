# P1 Evidence Status

## Verified on 3 November 2026

- Directed testbench: 22/22 passed.
- Extended BHT testbench: 184/184 passed.
- 4-entry scoreboard: 8,443 checks passed.
- 16-entry scoreboard: 9,163 checks passed.
- 32-entry scoreboard: 10,123 checks passed.
- Total: 27,935 checks passed, zero reported failures.
- Generic Yosys synthesis and design checks completed.

Evidence: `evidence/P1_20261103_185000/`.

**Provenance:** Its unmodified machine-generated summary refers to pre-rebase
local commit `2f4b146b24c8bc651622e7d3336535e969f3cb5e`. The P1
verification files were published as GitHub commit
`43efe12317c2c5ede08bcd0ea96f77299b92f2b6`; later PR edits changed
only documentation. A second local Mac run at that commit was reported
under `evidence/P1_20261103_185812/` but was not published to avoid
duplicating the original logs. Do not rewrite raw execution evidence.

**Remaining:** Save a genuine waveform screenshot; P2–P5 and integrated
project claims must be independently tested.

The results verify the tested P1 behaviors only. They do not establish FPGA timing, full CPU integration, or measured CPI improvements.
