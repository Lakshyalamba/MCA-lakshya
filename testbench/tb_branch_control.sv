`timescale 1ns/1ps
// Person 3 (Tanmay): Directed assertions for next_pc_mux and branch_resolution.
//
// Test matrix covers every row of the P3 truth table from the role guide:
//   1. valid=0 => no recovery signals
//   2. Predicted NT, actual NT => no flush, sequential PC
//   3. Predicted T + BTB hit + correct target, actual T => no flush
//   4. Predicted NT, actual T => flush, redirect to actual_target
//   5. Predicted T, actual NT => flush, redirect to branch_pc+4
//   6. Predicted T + BTB miss, actual T => redirect on resolution
//   7. Predicted T + BTB hit + wrong target, actual T => flush + target redirect
//
// Additional coverage:
//   8. next_pc_mux: Taken + BTB miss => PC+4 fallback
//   9. next_pc_mux: Not-taken => PC+4 regardless of BTB
//  10. Boundary: branch_pc = 0 and branch_pc = max-aligned address
//  11. Back-to-back resolutions with alternating outcomes
module tb_branch_control;

    // ------- next_pc_mux DUT signals -------
    reg  [31:0] pc;
    reg         predicted_taken;
    reg         btb_hit;
    reg  [31:0] predicted_target;
    wire [31:0] predicted_next_pc;

    next_pc_mux u_npc (
        .pc(pc),
        .predicted_taken(predicted_taken),
        .btb_hit(btb_hit),
        .predicted_target(predicted_target),
        .predicted_next_pc(predicted_next_pc)
    );

    // ------- branch_resolution DUT signals -------
    reg         valid;
    reg  [31:0] branch_pc;
    reg         saved_predicted_taken;
    reg         saved_btb_hit;
    reg  [31:0] saved_predicted_target;
    reg         actual_taken;
    reg  [31:0] actual_target;
    wire        mispredict;
    wire        flush;
    wire        redirect;
    wire [31:0] redirect_pc;

    branch_resolution u_res (
        .valid(valid),
        .branch_pc(branch_pc),
        .predicted_taken(saved_predicted_taken),
        .btb_hit(saved_btb_hit),
        .predicted_target(saved_predicted_target),
        .actual_taken(actual_taken),
        .actual_target(actual_target),
        .mispredict(mispredict),
        .flush(flush),
        .redirect(redirect),
        .redirect_pc(redirect_pc)
    );

    // ------- Counters -------
    integer passes = 0;
    integer fails  = 0;
    integer total  = 0;

    task check(input cond, input [8*80-1:0] name);
        begin
            total = total + 1;
            if (cond === 1'b1) begin
                passes = passes + 1;
                $display("PASS [%0d]: %0s", total, name);
            end else begin
                fails = fails + 1;
                $display("FAIL [%0d]: %0s", total, name);
                $display("  mispredict=%b flush=%b redirect=%b redirect_pc=0x%08h",
                         mispredict, flush, redirect, redirect_pc);
            end
        end
    endtask

    // Helper to apply resolution inputs and let combinational logic settle
    task apply_resolution(
        input        v,
        input [31:0] bpc,
        input        p_taken,
        input        p_hit,
        input [31:0] p_target,
        input        a_taken,
        input [31:0] a_target_val
    );
        begin
            valid                = v;
            branch_pc            = bpc;
            saved_predicted_taken  = p_taken;
            saved_btb_hit          = p_hit;
            saved_predicted_target = p_target;
            actual_taken         = a_taken;
            actual_target        = a_target_val;
            #1; // let combinational logic settle
        end
    endtask

    initial begin
        $dumpfile("results/p3_branch_control.vcd");
        $dumpvars(0, tb_branch_control);

        // ===================================================================
        // Part A: next_pc_mux directed tests
        // ===================================================================
        $display("");
        $display("======== Part A: next_pc_mux tests ========");

        // A1: Not-taken prediction => PC+4
        pc = 32'h0000_1000; predicted_taken = 0; btb_hit = 0; predicted_target = 32'h0;
        #1;
        check(predicted_next_pc == 32'h0000_1004,
              "NPC-A1: NT prediction => PC+4");

        // A2: Taken prediction + BTB hit => predicted target
        pc = 32'h0000_1000; predicted_taken = 1; btb_hit = 1; predicted_target = 32'h0000_2000;
        #1;
        check(predicted_next_pc == 32'h0000_2000,
              "NPC-A2: Taken+BTB hit => predicted_target");

        // A3: Taken prediction + BTB miss => fallback PC+4
        pc = 32'h0000_1000; predicted_taken = 1; btb_hit = 0; predicted_target = 32'h0000_2000;
        #1;
        check(predicted_next_pc == 32'h0000_1004,
              "NPC-A3: Taken+BTB miss => PC+4 fallback");

        // A4: NT prediction, BTB hit irrelevant => PC+4
        pc = 32'h0000_3000; predicted_taken = 0; btb_hit = 1; predicted_target = 32'h0000_4000;
        #1;
        check(predicted_next_pc == 32'h0000_3004,
              "NPC-A4: NT prediction ignores BTB hit, gives PC+4");

        // A5: Edge case — PC = 0
        pc = 32'h0000_0000; predicted_taken = 1; btb_hit = 1; predicted_target = 32'hFFFF_FF00;
        #1;
        check(predicted_next_pc == 32'hFFFF_FF00,
              "NPC-A5: PC=0 with taken+hit => target");

        // A6: Edge case — near-max PC
        pc = 32'hFFFF_FFF8; predicted_taken = 0; btb_hit = 0; predicted_target = 32'h0;
        #1;
        check(predicted_next_pc == 32'hFFFF_FFFC,
              "NPC-A6: near-max PC => wraps to FFFFFFFC");

        // A7: Taken + hit with zero target
        pc = 32'h0000_0100; predicted_taken = 1; btb_hit = 1; predicted_target = 32'h0000_0000;
        #1;
        check(predicted_next_pc == 32'h0000_0000,
              "NPC-A7: Taken+hit target=0x0 => target 0x0");

        // ===================================================================
        // Part B: branch_resolution directed tests (truth table)
        // ===================================================================
        $display("");
        $display("======== Part B: branch_resolution tests ========");

        // B1: valid=0 => no recovery (all outputs deasserted)
        apply_resolution(0, 32'h1000, 1, 1, 32'h2000, 0, 32'h3000);
        check(!mispredict && !flush && !redirect && redirect_pc == 32'd0,
              "RES-B1: valid=0 => no recovery");

        // B2: Predicted NT + actual NT => correct, no flush
        apply_resolution(1, 32'h1000, 0, 0, 32'h0, 0, 32'h0);
        check(!mispredict && !flush && !redirect,
              "RES-B2: pred NT, actual NT => no flush");

        // B3: Predicted T + BTB hit + correct target + actual T => correct
        apply_resolution(1, 32'h1000, 1, 1, 32'h2000, 1, 32'h2000);
        check(!mispredict && !flush && !redirect,
              "RES-B3: pred T+hit+correct target, actual T => no flush");

        // B4: Predicted NT + actual T => direction mismatch, flush + redirect
        apply_resolution(1, 32'h1000, 0, 0, 32'h0, 1, 32'h2000);
        check(mispredict && flush && redirect && redirect_pc == 32'h2000,
              "RES-B4: pred NT, actual T => flush, redirect to 0x2000");

        // B5: Predicted T + actual NT => direction mismatch, redirect to PC+4
        apply_resolution(1, 32'h1000, 1, 1, 32'h2000, 0, 32'h0);
        check(mispredict && flush && redirect && redirect_pc == 32'h1004,
              "RES-B5: pred T, actual NT => flush, redirect to PC+4");

        // B6: Predicted T + BTB miss + actual T => target miss, redirect
        apply_resolution(1, 32'h1000, 1, 0, 32'h0, 1, 32'h2000);
        check(mispredict && flush && redirect && redirect_pc == 32'h2000,
              "RES-B6: pred T+BTB miss, actual T => redirect to actual target");

        // B7: Predicted T + BTB hit + wrong target + actual T => target wrong
        apply_resolution(1, 32'h1000, 1, 1, 32'h3000, 1, 32'h2000);
        check(mispredict && flush && redirect && redirect_pc == 32'h2000,
              "RES-B7: pred T+hit+wrong target, actual T => flush+redirect");

        // ===================================================================
        // Part C: Additional directed checks
        // ===================================================================
        $display("");
        $display("======== Part C: Additional edge cases ========");

        // C1: Predicted NT + BTB hit + actual NT => still correct
        //     (BTB hit is irrelevant when direction is NT)
        apply_resolution(1, 32'h4000, 0, 1, 32'hABCD_0000, 0, 32'h0);
        check(!mispredict && !flush && !redirect,
              "RES-C1: pred NT+BTB hit, actual NT => no flush (hit irrelevant)");

        // C2: Predicted T + BTB hit + correct target, actual T but different
        //     actual_target vs predicted (targets match) => no mispredict
        apply_resolution(1, 32'h5000, 1, 1, 32'h6000, 1, 32'h6000);
        check(!mispredict,
              "RES-C2: matching targets, taken correct => no mispredict");

        // C3: branch_pc = 0, predicted NT, actual T => redirect to target
        apply_resolution(1, 32'h0000, 0, 0, 32'h0, 1, 32'hDEAD_BEE0);
        check(mispredict && redirect_pc == 32'hDEAD_BEE0,
              "RES-C3: branch_pc=0, pred NT, actual T => redirect to target");

        // C4: branch_pc = 0, predicted T, actual NT => redirect to PC+4 = 4
        apply_resolution(1, 32'h0000, 1, 1, 32'hBEEF_0000, 0, 32'h0);
        check(mispredict && redirect_pc == 32'h0004,
              "RES-C4: branch_pc=0, pred T, actual NT => redirect to 0x4");

        // C5: Back-to-back: first correct, then mispredict
        apply_resolution(1, 32'h2000, 1, 1, 32'h3000, 1, 32'h3000);
        check(!mispredict,
              "RES-C5a: first resolution correct");
        apply_resolution(1, 32'h2004, 0, 0, 32'h0, 1, 32'h4000);
        check(mispredict && redirect_pc == 32'h4000,
              "RES-C5b: second resolution is mispredict");

        // C6: Back-to-back: first mispredict, then correct
        apply_resolution(1, 32'hA000, 1, 1, 32'hB000, 0, 32'h0);
        check(mispredict && redirect_pc == 32'hA004,
              "RES-C6a: first is direction mispredict");
        apply_resolution(1, 32'hA004, 0, 0, 32'h0, 0, 32'h0);
        check(!mispredict,
              "RES-C6b: second is correct NT");

        // C7: Predicted T + BTB hit + target matches, but actual NT
        //     => direction mismatch regardless of target match
        apply_resolution(1, 32'h8000, 1, 1, 32'h9000, 0, 32'h9000);
        check(mispredict && redirect_pc == 32'h8004,
              "RES-C7: direction wrong overrides target match");

        // C8: Predicted NT, actual T with actual_target = branch_pc+4
        //     => still a misprediction (direction was wrong)
        apply_resolution(1, 32'hC000, 0, 0, 32'h0, 1, 32'hC004);
        check(mispredict && redirect_pc == 32'hC004,
              "RES-C8: NT->T mispredict even if target == PC+4");

        // ===================================================================
        // Summary
        // ===================================================================
        $display("");
        $display("======== P3 Branch Control Results ========");
        $display("  %0d passed, %0d failed out of %0d total checks", passes, fails, total);

        if (fails != 0)
            $fatal(1, "P3 branch control verification FAILED: %0d failures", fails);

        $display("ALL P3 BRANCH CONTROL TESTS PASSED: %0d checks", passes);
        $finish;
    end

endmodule
