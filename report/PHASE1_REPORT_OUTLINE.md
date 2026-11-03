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
