`timescale 1ns/1ps

// ============================================================================
// Testbench: tb_predictor
// Project: Dynamic Branch Prediction Subsystem (MCA Project #5)
// Author: Vansh (P4 — Baseline Predictors, Branch Traces and Verification)
//
// Description:
//   Expanded self-checking verification for predictor_top containing:
//     - Baseline (Always Not Taken)
//     - 1-bit BHT Predictor
//     - 2-bit Saturating Counter Predictor
//
// Verification Coverage:
//   1. Rigorous cycle-by-cycle assertions for all three predictors.
//   2. Verification of the 32-branch synthetic benchmark (10/32 base, 12/32 one, 15/32 two).
//   3. Cold-start zero-bias validation (1-bit = 0, 2-bit = 01 / weakly NT).
//   4. Loop-exit hysteresis and 1-bit double penalty analysis.
//   5. Strict alternation behavior (counterexample where baseline beats dynamic).
//   6. Reset priority over enabled update.
//   7. Disabled update stability (update_valid=0 leaves state unchanged).
//   8. Intentional index aliasing (PC 0x100 vs PC 0x140 at BHT index 0).
// ============================================================================

module tb_predictor;
    reg clk = 0;
    always #5 clk = ~clk;

    reg reset = 1;
    reg [31:0] lookup_pc = 0;
    reg [31:0] update_pc = 0;
    reg update_valid = 0;
    reg actual_taken = 0;

    wire baseline_taken;
    wire one_bit_taken;
    wire two_bit_taken;
    wire [1:0] two_bit_state;

    integer total = 0;
    integer correct_base = 0;
    integer correct_one = 0;
    integer correct_two = 0;
    integer check_count = 0;
    integer error_count = 0;

    predictor_top #(.INDEX_BITS(4)) dut (
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

    // Reference tracking variables for directed checks
    reg ref_1bit [0:15];
    reg [1:0] ref_2bit [0:15];
    integer idx_init;

    task init_reference;
        begin
            for (idx_init = 0; idx_init < 16; idx_init = idx_init + 1) begin
                ref_1bit[idx_init] = 1'b0;
                ref_2bit[idx_init] = 2'b01; // Weakly Not Taken
            end
        end
    endtask

    task branch;
        input [31:0] pc;
        input taken;
        reg [3:0] idx;
        reg exp_base;
        reg exp_one;
        reg exp_two;
        reg [1:0] exp_state;
        begin
            idx = pc[5:2];
            exp_base = 1'b0;
            exp_one  = ref_1bit[idx];
            exp_state = ref_2bit[idx];
            exp_two  = exp_state[1];

            @(negedge clk);
            lookup_pc    = pc;
            update_pc    = pc;
            actual_taken = taken;
            update_valid = 1;

            #1; // Read pre-update predictions, not post-update state
            check_count = check_count + 1;
            if (baseline_taken !== exp_base) begin
                $display("ASSERTION FAILED [check %0d]: pc=%h baseline_taken=%b expected=%b",
                         check_count, pc, baseline_taken, exp_base);
                error_count = error_count + 1;
            end

            check_count = check_count + 1;
            if (one_bit_taken !== exp_one) begin
                $display("ASSERTION FAILED [check %0d]: pc=%h one_bit_taken=%b expected=%b (idx=%0d)",
                         check_count, pc, one_bit_taken, exp_one, idx);
                error_count = error_count + 1;
            end

            check_count = check_count + 1;
            if (two_bit_taken !== exp_two || two_bit_state !== exp_state) begin
                $display("ASSERTION FAILED [check %0d]: pc=%h two_bit_taken=%b(exp %b) state=%b(exp %b)",
                         check_count, pc, two_bit_taken, exp_two, two_bit_state, exp_state);
                error_count = error_count + 1;
            end

            total = total + 1;
            if (baseline_taken == taken) correct_base = correct_base + 1;
            if (one_bit_taken == taken) correct_one = correct_one + 1;
            if (two_bit_taken == taken) correct_two = correct_two + 1;

            $display("branch pc=%h actual=%b baseline=%b one=%b two=%b state=%b",
                     pc, taken, baseline_taken, one_bit_taken, two_bit_taken, two_bit_state);

            // Update reference models synchronously
            ref_1bit[idx] = taken;
            if (taken && ref_2bit[idx] != 2'b11)
                ref_2bit[idx] = ref_2bit[idx] + 2'b01;
            else if (!taken && ref_2bit[idx] != 2'b00)
                ref_2bit[idx] = ref_2bit[idx] - 2'b01;

            @(posedge clk);
            #1; // Allow nonblocking assignments to settle
            update_valid = 0;
        end
    endtask

    integer i;
    initial begin
        $dumpfile("results/predictor.vcd");
        $dumpvars(0, tb_predictor);
        init_reference();

        // -------------------------------------------------------------
        // Phase 1: Reset and cold start checks
        // -------------------------------------------------------------
        repeat (2) @(posedge clk);
        @(negedge clk);
        reset = 0;

        // Verify cold start state across 4 distinct indices
        for (i = 0; i < 4; i = i + 1) begin
            lookup_pc = 32'h00000100 + (i * 4);
            #1;
            check_count = check_count + 1;
            if (baseline_taken !== 1'b0 || one_bit_taken !== 1'b0 || two_bit_taken !== 1'b0 || two_bit_state !== 2'b01) begin
                $display("ASSERTION FAILED: Cold-start entry %0d not reset properly! one=%b two=%b state=%b",
                         i, one_bit_taken, two_bit_taken, two_bit_state);
                error_count = error_count + 1;
            end
        end

        // -------------------------------------------------------------
        // Phase 2: 32-branch synthetic benchmark
        // First loop: T T T T N repeated 4 times; demonstrates loop exit penalty.
        // -------------------------------------------------------------
        for (i = 0; i < 4; i = i + 1) begin
            branch(32'h00000100, 1);
            branch(32'h00000100, 1);
            branch(32'h00000100, 1);
            branch(32'h00000100, 1);
            branch(32'h00000100, 0);
        end

        // Second loop: 12 alternating branches at different BHT index.
        for (i = 0; i < 12; i = i + 1) begin
            branch(32'h00000104, (i % 2) == 0);
        end

        $display("TOTAL=%0d BASE_CORRECT=%0d ONE_CORRECT=%0d TWO_CORRECT=%0d",
                 total, correct_base, correct_one, correct_two);

        // Assert exact benchmark totals
        check_count = check_count + 1;
        if (total !== 32 || correct_base !== 10 || correct_one !== 12 || correct_two !== 15) begin
            $display("ASSERTION FAILED: Benchmark counts mismatch! Expected 32/10/12/15, got %0d/%0d/%0d/%0d",
                     total, correct_base, correct_one, correct_two);
            error_count = error_count + 1;
        end

        // -------------------------------------------------------------
        // Phase 3: Disabled update assertion (update_valid = 0)
        // -------------------------------------------------------------
        @(negedge clk);
        lookup_pc = 32'h00000100;
        update_pc = 32'h00000100;
        actual_taken = 1;
        update_valid = 0; // DISABLED
        @(posedge clk);
        #1;
        lookup_pc = 32'h00000100;
        #1;
        check_count = check_count + 1;
        // PC 0x100 ended Phase 2 with one_bit=0, state=10. Should remain unchanged.
        if (one_bit_taken !== ref_1bit[0] || two_bit_state !== ref_2bit[0]) begin
            $display("ASSERTION FAILED: update_valid=0 modified state!");
            error_count = error_count + 1;
        end

        // -------------------------------------------------------------
        // Phase 4: Reset priority over enabled update
        // -------------------------------------------------------------
        @(negedge clk);
        reset = 1;
        update_valid = 1;
        actual_taken = 1;
        update_pc = 32'h00000100;
        @(posedge clk);
        #1;
        reset = 0;
        update_valid = 0;
        init_reference();
        lookup_pc = 32'h00000100;
        #1;
        check_count = check_count + 1;
        if (one_bit_taken !== 1'b0 || two_bit_state !== 2'b01) begin
            $display("ASSERTION FAILED: Reset did not override update_valid!");
            error_count = error_count + 1;
        end

        // -------------------------------------------------------------
        // Phase 5: Intentional Aliasing Check (PC 0x100 vs PC 0x140)
        // Both PCs map to index 0 (0x100[5:2]=0, 0x140[5:2]=0)
        // -------------------------------------------------------------
        branch(32'h00000100, 1); // trains index 0 to taken (1 / 10)
        branch(32'h00000140, 1); // accesses index 0: should see taken!
        branch(32'h00000140, 0); // updates index 0 with not-taken
        // Now lookup PC 0x100: should reflect aliased update from PC 0x140!
        lookup_pc = 32'h00000100;
        #1;
        check_count = check_count + 1;
        if (one_bit_taken !== 1'b0) begin
            $display("ASSERTION FAILED: Expected aliased PC 0x100 to observe 1-bit value 0 from PC 0x140!");
            error_count = error_count + 1;
        end

        // -------------------------------------------------------------
        // Final Status Reporting
        // -------------------------------------------------------------
        $display("\n=======================================================");
        $display(" tb_predictor Verification Summary");
        $display("   Total Checks:  %0d", check_count);
        $display("   Total Errors:  %0d", error_count);
        $display("=======================================================");

        if (error_count == 0) begin
            $display("ALL TB_PREDICTOR CHECKS PASSED (%0d checks)\n", check_count);
            $finish(0);
        end else begin
            $display("TB_PREDICTOR FAILED WITH %0d ERRORS!\n", error_count);
            $fatal(1, "tb_predictor test failed");
        end
    end

endmodule
