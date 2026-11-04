`timescale 1ns/1ps
`default_nettype none

// ============================================================================
// Testbench: tb_comparison
// Project: Dynamic Branch Prediction Subsystem (MCA Project #5)
// Author: Vansh (P4 — Baseline Predictors, Branch Traces and Verification)
//
// Description:
//   Independent, self-checking comparative verification suite for:
//     1. Baseline (Always Not Taken)
//     2. 1-bit BHT Predictor (parameterized)
//     3. 2-bit Saturating Counter Predictor (parameterized)
//   Also integrates with P2 BTB and P3 Pipeline Control to verify recovery
//   behavior on direction vs target mispredictions.
//
// Trace Inputs Verified:
//   - traces/loop_trace.csv: Loop-dominated (TTTTN), demonstrating 1-bit loop
//     exit penalty vs 2-bit hysteresis.
//   - traces/alternating_trace.csv: Pathological alternation (TNTN), demonstrating
//     0% dynamic accuracy counterexample where Baseline (50%) wins.
//   - traces/beq_bne_trace.csv: Mixed BEQ/BNE branches with operand evaluation
//     and intentional index aliasing.
//
// Features:
//   - Zero data leakage: pre-update prediction capture strictly separated from
//     post-resolution training.
//   - Architectural operand checking: BEQ taken if rs1==rs2, BNE taken if rs1!=rs2.
//   - Independent golden reference scoreboard for all predictors.
//   - Exports machine-readable CSV summary (evidence/metrics/comparison_summary.csv).
//   - Dumps genuine simulation waveform to results/p4_comparison.vcd.
//   - Strict error assertions: fails nonzero on any discrepancy.
// ============================================================================

module tb_comparison;
    parameter integer INDEX_BITS = 4;
    localparam integer ENTRIES = (1 << INDEX_BITS);

    // Clock and reset
    reg clk = 0;
    always #5 clk = ~clk;

    reg reset = 1;

    // Predictor signals
    reg  [31:0] lookup_pc = 0;
    wire        baseline_taken;
    wire        one_bit_taken;
    wire        two_bit_taken;
    wire [1:0]  two_bit_state;

    reg         update_valid = 0;
    reg  [31:0] update_pc = 0;
    reg         actual_taken = 0;

    // BTB signals (P2)
    wire        btb_hit;
    wire [31:0] btb_target;
    reg         btb_update_valid = 0;
    reg  [31:0] btb_update_pc = 0;
    reg  [31:0] btb_update_target = 0;

    // Next-PC Mux signals (P3)
    wire [31:0] predicted_next_pc;

    // Resolution signals (P3)
    reg         res_valid = 0;
    reg  [31:0] res_branch_pc = 0;
    reg         res_saved_taken = 0;
    reg         res_saved_hit = 0;
    reg  [31:0] res_saved_target = 0;
    reg         res_actual_taken = 0;
    reg  [31:0] res_actual_target = 0;

    wire        res_mispredict;
    wire        res_flush;
    wire        res_redirect;
    wire [31:0] res_redirect_pc;

    // Instantiate Predictor Subsystem under test
    predictor_top #(.INDEX_BITS(INDEX_BITS)) dut_predictors (
        .clk(clk),
        .reset(reset),
        .lookup_pc(lookup_pc),
        .baseline_taken(baseline_taken),
        .one_bit_taken(one_bit_taken),
        .two_bit_taken(two_bit_taken),
        .two_bit_state(two_bit_state),
        .update_valid(update_valid),
        .update_pc(update_pc),
        .actual_taken(actual_taken)
    );

    // Instantiate P2 Tagged BTB
    branch_target_buffer #(.INDEX_BITS(INDEX_BITS)) dut_btb (
        .clk(clk),
        .reset(reset),
        .lookup_pc(lookup_pc),
        .update_valid(btb_update_valid),
        .update_pc(btb_update_pc),
        .update_target(btb_update_target),
        .hit(btb_hit),
        .target(btb_target)
    );

    // Instantiate P3 Next-PC Selector
    next_pc_mux dut_next_pc (
        .pc(lookup_pc),
        .predicted_taken(two_bit_taken),
        .btb_hit(btb_hit),
        .predicted_target(btb_target),
        .predicted_next_pc(predicted_next_pc)
    );

    // Instantiate P3 Branch Resolution Logic
    branch_resolution dut_resolution (
        .valid(res_valid),
        .branch_pc(res_branch_pc),
        .predicted_taken(res_saved_taken),
        .btb_hit(res_saved_hit),
        .predicted_target(res_saved_target),
        .actual_taken(res_actual_taken),
        .actual_target(res_actual_target),
        .mispredict(res_mispredict),
        .flush(res_flush),
        .redirect(res_redirect),
        .redirect_pc(res_redirect_pc)
    );

    // ========================================================================
    // Golden Reference Model (Scoreboard)
    // ========================================================================
    reg       ref_1bit [0:ENTRIES-1];
    reg [1:0] ref_2bit [0:ENTRIES-1];
    integer   check_count = 0;
    integer   error_count = 0;

    task reset_reference;
        integer k;
        begin
            for (k = 0; k < ENTRIES; k = k + 1) begin
                ref_1bit[k] = 1'b0;      // 0 = Not Taken
                ref_2bit[k] = 2'b01;     // 01 = Weakly Not Taken
            end
        end
    endtask

    function [INDEX_BITS-1:0] get_idx(input [31:0] pc);
        get_idx = pc[INDEX_BITS+1:2];
    endfunction

    // ========================================================================
    // Trace Execution Task
    // ========================================================================
    integer csv_summary_fd;

    task automatic run_trace(
        input [8*64-1:0] trace_title,
        input [8*128-1:0] trace_path,
        output integer out_total,
        output integer out_base_corr,
        output integer out_one_corr,
        output integer out_two_corr
    );
        integer fd, dummy, cnt;
        reg [8*256-1:0] line;
        integer seq, act_taken;
        reg [31:0] pc, rs1, rs2, target;
        reg [7:0] c1, c2, c3;
        reg [INDEX_BITS-1:0] idx;

        reg exp_act;
        reg exp_base;
        reg exp_one;
        reg exp_two;
        reg [1:0] exp_state;

        integer t_total;
        integer t_base_corr;
        integer t_one_corr;
        integer t_two_corr;

        begin
            t_total     = 0;
            t_base_corr = 0;
            t_one_corr  = 0;
            t_two_corr  = 0;
            $display("\n------------------------------------------------------------");
            $display(" RUNNING TRACE: %0s", trace_title);
            $display(" File: %0s", trace_path);
            $display("------------------------------------------------------------");

            // Hardware & Reference Reset
            @(negedge clk);
            reset = 1;
            update_valid = 0;
            btb_update_valid = 0;
            res_valid = 0;
            @(posedge clk);
            #1;
            reset = 0;
            reset_reference();

            fd = $fopen(trace_path, "r");
            if (fd == 0) begin
                $display("ERROR: Cannot open trace file: %0s", trace_path);
                error_count = error_count + 1;
                $fatal(1, "Trace file not found");
            end

            // Discard header line
            dummy = $fgets(line, fd);

            while ($fgets(line, fd) > 0) begin
                // Schema: seq,0xpc,OP,0xrs1,0xrs2,0xtarget,actual_taken
                cnt = $sscanf(line, "%d,0x%x,%c%c%c,0x%x,0x%x,0x%x,%d",
                              seq, pc, c1, c2, c3, rs1, rs2, target, act_taken);
                if (cnt != 9) begin
                    $display("PARSE ERROR on line: %0s (parsed %0d items)", line, cnt);
                    error_count = error_count + 1;
                end else begin
                    // 1. Verify architectural branch evaluation from operands
                    if (c1 == "B" && c2 == "E" && c3 == "Q") begin
                        exp_act = (rs1 == rs2) ? 1'b1 : 1'b0;
                    end else if (c1 == "B" && c2 == "N" && c3 == "E") begin
                        exp_act = (rs1 != rs2) ? 1'b1 : 1'b0;
                    end else begin
                        $display("UNKNOWN OP %c%c%c at seq %0d", c1, c2, c3, seq);
                        exp_act = 1'b0;
                        error_count = error_count + 1;
                    end

                    check_count = check_count + 1;
                    if (act_taken[0] !== exp_act) begin
                        $display("ASSERTION FAILED [seq %0d]: Operand mismatch! op=%c%c%c rs1=%h rs2=%h actual=%0d exp=%0d",
                                 seq, c1, c2, c3, rs1, rs2, act_taken, exp_act);
                        error_count = error_count + 1;
                    end

                    // 2. Sample predictions PRE-UPDATE
                    idx = get_idx(pc);
                    exp_base  = 1'b0;
                    exp_one   = ref_1bit[idx];
                    exp_state = ref_2bit[idx];
                    exp_two   = exp_state[1];

                    @(negedge clk);
                    lookup_pc    = pc;
                    update_pc    = pc;
                    actual_taken = exp_act;
                    update_valid = 1;

                    #1; // Read combinational pre-update outputs
                    check_count = check_count + 1;
                    if (baseline_taken !== exp_base) begin
                        $display("ASSERTION FAILED [seq %0d]: baseline=%b exp=%b", seq, baseline_taken, exp_base);
                        error_count = error_count + 1;
                    end

                    check_count = check_count + 1;
                    if (one_bit_taken !== exp_one) begin
                        $display("ASSERTION FAILED [seq %0d]: one_bit=%b exp=%b (idx=%0d)", seq, one_bit_taken, exp_one, idx);
                        error_count = error_count + 1;
                    end

                    check_count = check_count + 1;
                    if (two_bit_taken !== exp_two || two_bit_state !== exp_state) begin
                        $display("ASSERTION FAILED [seq %0d]: two_bit=%b(exp %b) state=%b(exp %b) idx=%0d",
                                 seq, two_bit_taken, exp_two, two_bit_state, exp_state, idx);
                        error_count = error_count + 1;
                    end

                    // Tally predictions
                    t_total = t_total + 1;
                    if (baseline_taken == exp_act) t_base_corr = t_base_corr + 1;
                    if (one_bit_taken  == exp_act) t_one_corr  = t_one_corr  + 1;
                    if (two_bit_taken  == exp_act) t_two_corr  = t_two_corr  + 1;

                    // 3. Update reference model synchronously with hardware
                    ref_1bit[idx] = exp_act;
                    if (exp_act && ref_2bit[idx] != 2'b11)
                        ref_2bit[idx] = ref_2bit[idx] + 2'b01;
                    else if (!exp_act && ref_2bit[idx] != 2'b00)
                        ref_2bit[idx] = ref_2bit[idx] - 2'b01;

                    @(posedge clk);
                    #1;
                    update_valid = 0;
                end
            end

            $fclose(fd);

            out_total     = t_total;
            out_base_corr = t_base_corr;
            out_one_corr  = t_one_corr;
            out_two_corr  = t_two_corr;

            $display(" Trace Results for: %0s", trace_title);
            $display("   Total Branches: %0d", t_total);
            $display("   Baseline Correct: %0d / %0d (%0.2f%%)", t_base_corr, t_total, (t_base_corr*100.0)/t_total);
            $display("   1-Bit BHT Correct: %0d / %0d (%0.2f%%)", t_one_corr, t_total, (t_one_corr*100.0)/t_total);
            $display("   2-Bit BHT Correct: %0d / %0d (%0.2f%%)", t_two_corr, t_total, (t_two_corr*100.0)/t_total);

            // Append to CSV summary
            $fdisplay(csv_summary_fd, "%0s,%0s,%0d,%0d,%0d,%0.2f,%0d,%0d,%0.2f,%0d,%0d,%0.2f",
                      trace_title, trace_path, t_total,
                      t_base_corr, (t_total - t_base_corr), (t_base_corr * 100.0) / t_total,
                      t_one_corr, (t_total - t_one_corr), (t_one_corr * 100.0) / t_total,
                      t_two_corr, (t_total - t_two_corr), (t_two_corr * 100.0) / t_total);
        end
    endtask

    // ========================================================================
    // Directed Pipeline Recovery Coordination Checks (Step 7)
    // ========================================================================
    task test_pipeline_recovery;
        begin
            $display("\n------------------------------------------------------------");
            $display(" P4+P3 PIPELINE RECOVERY COORDINATION CHECKS");
            $display("------------------------------------------------------------");

            // Reset Subsystems
            @(negedge clk);
            reset = 1;
            update_valid = 0;
            btb_update_valid = 0;
            res_valid = 0;
            @(posedge clk);
            #1;
            reset = 0;

            // Scenario 1: Direction Misprediction (Predicted Taken -> Actual Not Taken)
            // Fetch Time: Train BHT to taken, BTB to 0x00003000
            @(negedge clk);
            update_pc = 32'h00001000;
            actual_taken = 1;
            update_valid = 1;
            btb_update_pc = 32'h00001000;
            btb_update_target = 32'h00003000;
            btb_update_valid = 1;
            @(posedge clk);
            #1;
            // Now fetch at 0x1000
            lookup_pc = 32'h00001000;
            update_valid = 0;
            btb_update_valid = 0;
            #1;
            check_count = check_count + 1;
            if (two_bit_taken !== 1'b1 || btb_hit !== 1'b1 || predicted_next_pc !== 32'h00003000) begin
                $display("ASSERTION FAILED: Speculative fetch failed! taken=%b hit=%b npc=%h",
                         two_bit_taken, btb_hit, predicted_next_pc);
                error_count = error_count + 1;
            end

            // Execute Stage Resolution: Actually NOT TAKEN (e.g. BEQ failed)
            res_valid = 1;
            res_branch_pc = 32'h00001000;
            res_saved_taken = 1'b1;
            res_saved_hit = 1'b1;
            res_saved_target = 32'h00003000;
            res_actual_taken = 1'b0; // NOT TAKEN
            res_actual_target = 32'h00003000;
            #1;
            check_count = check_count + 1;
            if (res_mispredict !== 1'b1 || res_flush !== 1'b1 || res_redirect !== 1'b1 || res_redirect_pc !== 32'h00001004) begin
                $display("ASSERTION FAILED: Direction mispredict recovery failed! mis=%b flush=%b red=%b pc=%h",
                         res_mispredict, res_flush, res_redirect, res_redirect_pc);
                error_count = error_count + 1;
            end else begin
                $display("  PASS: Direction Mispredict (T->NT) asserts Flush=1, Redirect=1 to PC+4 (0x%h)", res_redirect_pc);
            end

            // Scenario 2: Target Misprediction (Direction Correctly Taken, Target Mismatch)
            // Execute Stage Resolution: Taken, but resolved target is 0x00005000 (BTB predicted 0x00003000)
            res_saved_taken = 1'b1;
            res_saved_hit = 1'b1;
            res_saved_target = 32'h00003000;
            res_actual_taken = 1'b1; // TAKEN
            res_actual_target = 32'h00005000; // Resolved to different target!
            #1;
            check_count = check_count + 1;
            if (res_mispredict !== 1'b1 || res_flush !== 1'b1 || res_redirect !== 1'b1 || res_redirect_pc !== 32'h00005000) begin
                $display("ASSERTION FAILED: Target mispredict recovery failed! mis=%b flush=%b red=%b pc=%h",
                         res_mispredict, res_flush, res_redirect, res_redirect_pc);
                error_count = error_count + 1;
            end else begin
                $display("  PASS: Target Mispredict (T->T, Target 0x3000->0x5000) asserts Flush=1, Redirect=1 to Actual Target (0x%h)", res_redirect_pc);
            end

            // Clean up
            res_valid = 0;
            #1;
        end
    endtask

    // ========================================================================
    // Main Verification Process
    // ========================================================================
    integer tot1, bcorr1, ocorr1, tcorr1;
    integer tot2, bcorr2, ocorr2, tcorr2;
    integer tot3, bcorr3, ocorr3, tcorr3;
    integer tot_all, bcorr_all, ocorr_all, tcorr_all;

    initial begin
        $dumpfile("results/p4_comparison.vcd");
        $dumpvars(0, tb_comparison);

        // Open summary CSV file for P5 metrics
        csv_summary_fd = $fopen("evidence/metrics/comparison_summary.csv", "w");
        $fdisplay(csv_summary_fd, "trace_name,trace_file,total_branches,base_correct,base_mispredict,base_accuracy_pct,one_bit_correct,one_bit_mispredict,one_bit_accuracy_pct,two_bit_correct,two_bit_mispredict,two_bit_accuracy_pct");

        $display("================================================================================");
        $display(" P4 BRANCH PREDICTOR COMPARISON & VERIFICATION SUITE");
        $display(" Author: Vansh (P4 — Baselines, Branch Traces and Verification)");
        $display("================================================================================");

        // Run Trace 1: Loop-dominated
        run_trace("Loop-dominated (TTTTN)", "traces/loop_trace.csv", tot1, bcorr1, ocorr1, tcorr1);

        // Run Trace 2: Strict Alternating
        run_trace("Strict Alternating (TNTN)", "traces/alternating_trace.csv", tot2, bcorr2, ocorr2, tcorr2);

        // Run Trace 3: Mixed BEQ/BNE Aliased
        run_trace("Mixed BEQ/BNE Aliased", "traces/beq_bne_trace.csv", tot3, bcorr3, ocorr3, tcorr3);

        // Consolidated Overall Tally
        tot_all   = tot1 + tot2 + tot3;
        bcorr_all = bcorr1 + bcorr2 + bcorr3;
        ocorr_all = ocorr1 + ocorr2 + ocorr3;
        tcorr_all = tcorr1 + tcorr2 + tcorr3;

        $fdisplay(csv_summary_fd, "%0s,%0s,%0d,%0d,%0d,%0.2f,%0d,%0d,%0.2f,%0d,%0d,%0.2f",
                  "Consolidated Overall", "ALL_TRACES", tot_all,
                  bcorr_all, (tot_all - bcorr_all), (bcorr_all * 100.0) / tot_all,
                  ocorr_all, (tot_all - ocorr_all), (ocorr_all * 100.0) / tot_all,
                  tcorr_all, (tot_all - tcorr_all), (tcorr_all * 100.0) / tot_all);
        $fclose(csv_summary_fd);

        // Step 7: Pipeline Recovery Integration Verification
        test_pipeline_recovery();

        // Final Report
        $display("\n================================================================================");
        $display(" CONSOLIDATED BENCHMARK SUMMARY (%0d dynamic branches)", tot_all);
        $display("================================================================================");
        $display("   Baseline (Always Not Taken): %0d / %0d (%0.2f%%)", bcorr_all, tot_all, (bcorr_all*100.0)/tot_all);
        $display("   1-Bit BHT Predictor:         %0d / %0d (%0.2f%%)", ocorr_all, tot_all, (ocorr_all*100.0)/tot_all);
        $display("   2-Bit BHT Predictor:         %0d / %0d (%0.2f%%)", tcorr_all, tot_all, (tcorr_all*100.0)/tot_all);
        $display("--------------------------------------------------------------------------------");
        $display(" TOTAL ASSERTIONS EVALUATED: %0d", check_count);
        $display(" TOTAL ASSERTION FAILURES:   %0d", error_count);
        $display("================================================================================");

        if (error_count == 0) begin
            $display("ALL P4 COMPARISON CHECKS PASSED (%0d checks)\n", check_count);
            $finish(0);
        end else begin
            $display("P4 VERIFICATION FAILED WITH %0d ERRORS!\n", error_count);
            $fatal(1, "tb_comparison test failed");
        end
    end

endmodule

`default_nettype wire
