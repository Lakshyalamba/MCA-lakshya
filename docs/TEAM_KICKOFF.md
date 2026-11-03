# MCA team kickoff — one predictor, five contributors

P1 is unit-tested; P2–P5 must implement their own assigned parts. Read `docs/INTERFACES.md` before coding.

| Owner | Technical role | Branch | Acceptance gate |
| --- | --- | --- | --- |
| Shubhaang (P1) | 2-bit saturating BHT + verification | `feature/shubhaang-bht` | 27,935 checks and generic synthesis passed; screenshot still pending |
| Tanish (P2) | Tagged Branch Target Buffer | `feature/tanish-btb` | Cold miss, hit, wrong tag, replacement, valid gating |
| Tanmay (P3) | Next-PC select and misprediction/flush/redirect | `feature/tanmay-control` | Direction/target mistakes, valid gating, integration tests |
| Vansh (P4) | Static and 1-bit baselines, BEQ/BNE trace verification | `feature/vansh-baselines-verification` | Pre-update comparison and independent trace expectations |
| Lakshya (P5) | Resource/timing evaluation, CPI assumptions, report/video | `feature/lakshya-evaluation` | Reproducible charts and reports; no fabricated MHz |

## How each person starts

1. Fork and clone the public central repository (no collaborator invitation needed): `docs/TEAM_START_HERE.md`.
2. Read your own `docs/team_roles/` guide; use `docs/INTERFACES.md` for signal conventions.
3. Build and unit-test only your assigned work. Commit genuinely under your own Git identity.
4. Open a PR from your fork to `S-h-u-b-h-1/MCA:main`. The leader reviews actual tests and merges.
5. After the parts are independently verified, run integration and collect common branch traces.

**Phase I deadline:** 16 November 2026, 11:59 PM IST. All five must be named in the IEEE report, introduced in the sub-5-minute video, and represented by meaningful Git history. See `docs/FACULTY_REQUIREMENTS.md`.

**Not yet done:** P2/P3 RTL, P4 trace suite, full design synthesis/timing, integrated waveform, final report/video and submission.
