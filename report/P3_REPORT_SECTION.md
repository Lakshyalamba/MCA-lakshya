# P3 IEEE Report Contribution — Tanmay

**Section:** III. Proposed Solution — Subsection C: Next-PC Selection and Pipeline Recovery  
**Section:** V. Individual Contributions — Tanmay (P3)  
**Author:** Tanmay (Roll No: P3)  
**Date:** 4 November 2026  

---

## Section III-C: Next-PC Selection and Pipeline Recovery

### 1. Speculative Fetch-Stage Next-PC Selection
In a pipelined processor, instruction fetch cannot stall until branch condition evaluation without incurring severe throughput penalties. The Branch Prediction Unit must supply a speculative next program counter ($PC_{next}$) in the same cycle the current instruction address ($PC$) is presented.

The combinational `next_pc_mux` module evaluates the direction prediction from the 2-bit BHT ($P_{taken} \in \{0, 1\}$) and the Branch Target Buffer status ($BTB_{hit} \in \{0, 1\}$) to select between sequential fetch and speculative target redirection:

$$PC_{pred\_next} = \begin{cases} Target_{BTB}, & \text{if } P_{taken} = 1 \land BTB_{hit} = 1 \\ PC + 4, & \text{otherwise} \end{cases}$$

When the predictor indicates a branch is taken but the BTB experiences a capacity or conflict miss ($BTB_{hit} = 0$), the hardware conservatively defaults to the sequential path ($PC + 4$). The correct target is subsequently resolved and recovered in the execution stage.

### 2. Execute-Stage Branch Resolution and Recovery
During branch execution, the architectural branch condition ($A_{taken} \in \{0, 1\}$) and calculated target address ($Target_{actual}$) are resolved. Crucially, the resolution logic does not query current predictor states; rather, it evaluates against the *saved fetch-time prediction metadata* ($P_{taken}, BTB_{hit}, Target_{pred}$) captured in pipeline registers at fetch time.

A misprediction signal is asserted whenever:
1. The predicted direction differs from the architectural outcome ($P_{taken} \neq A_{taken}$).
2. The branch was taken ($A_{taken} = 1$), but either the BTB missed ($BTB_{hit} = 0$) or the predicted target did not match the resolved target ($Target_{pred} \neq Target_{actual}$).

Formally, the recovery condition is:

$$\text{Mispredict} = \text{Valid} \land \Big( (P_{taken} \neq A_{taken}) \lor \big( A_{taken} \land (\neg BTB_{hit} \lor (Target_{pred} \neq Target_{actual})) \big) \Big)$$

When $\text{Mispredict} = 1$, the module asserts:
- $\text{Flush} = 1$: Invalidation signal for younger wrong-path instructions.
- $\text{Redirect} = 1$: Control signal steering the fetch unit to the corrected architectural PC.
- $\text{Redirect\_PC} = A_{taken} \; ? \; Target_{actual} : (PC_{branch} + 4)$.

### 3. Hardware Complexity and Synthesis
Both modules are purely combinational:
- `next_pc_mux`: Synthesized to 91 generic gate cells (27 AND, 32 MUX, 28 XOR/XNOR) with zero internal sequential state.
- `branch_resolution`: Synthesized to 223 generic gate cells (110 AND, 22 MUX, 55 XOR/XNOR/OR) with 0 assertion warnings under Yosys 0.70.

---

## Section V: Individual Contributions — Tanmay (P3)

**Tanmay (P3)** was solely responsible for designing, implementing, and verifying the pipeline control interface:
- **RTL Architecture:** Authored synthesizable Verilog modules `rtl/next_pc_mux.v` (speculative fetch multiplexer) and `rtl/branch_resolution.v` (execute-stage comparison and flush/redirect generation).
- **Unit Verification:** Developed `testbench/tb_branch_control.sv` containing 24 directed assertions verifying all combinations of the branch control truth table, edge cases (PC=0, boundary wrap-around, zero targets), and back-to-back alternations.
- **Subsystem Integration:** Authored `testbench/tb_integrated.sv`, creating the closed-loop integration testbench connecting P1 (2-bit BHT), P2 (tagged BTB), and P3 (control) in a realistic fetch-predict-resolve cycle with metadata preservation. Demonstrated 26/26 passing checks covering correct branches, direction mispredictions, target mismatches, alias evictions, recovery redirect priority, squashed branches, and loop backward jumps.
- **Tool Automation & Evidence:** Extended the project `Makefile` with `test-p3`, `test-p3-integrated`, `synth-p3-checked`, and `verify-p3` targets; captured simulation logs, Yosys synthesis reports, and timing waveforms in `evidence/control_logs/`, `evidence/waveforms/p3_control.png` (conceptual timing diagram), and `evidence/waveforms/p3_integrated_simulation.png` (genuine simulation waveform from VCD).
- **Documentation:** Authored comprehensive architectural specification `docs/P3_PIPELINE_CONTROL.md`.
