`timescale 1ns/1ps
// Person 3 (Tanmay): Integration test — P1 BHT + P2 BTB + P3 control.
//
// Simulates a minimal fetch-predict-resolve pipeline loop:
//   1. Fetch stage: lookup BHT + BTB at current PC, select next PC.
//   2. Save prediction metadata (as a real pipeline register would).
//   3. Resolution stage: compare saved predictions with actual outcome.
//   4. Control multiplexer: redirect_pc has priority over speculative next-PC.
//   5. Output sampling: capture recovery signals deterministically while res_valid=1.
//   6. Verify live recovery signals deassert when res_valid=0.
//   7. If mispredict: redirect to corrected PC; update BHT + BTB.
//   8. If correct: continue with predicted next PC; update BHT.
//   9. If squashed/invalid (res_valid=0): no recovery, no predictor training.
//
// PC addressing note: BHT and BTB index = PC[5:2] (INDEX_BITS=4, 16 entries).
// Each test uses PCs with DISTINCT indices to avoid aliasing side effects:
//   T1  => PC 0x1000 (index 0)     T7  => PC 0x1018 (index 6)
//   T2  => PC 0x1004 (index 1)     T8  => PC 0x1020/0x1024 (index 8/9)
//   T3  => PC 0x1008 (index 2)     T9  => reuses T2 PC (trained)
//   T4  => reuses T2 PC (trained)  T10 => reset, then reuse T2 PC
//   T5  => PC 0x100C (index 3)     T11 => PC 0x1028 (index 10)
//   T6  => PC 0x1010/0x1050 (idx 4) T12 => PC 0x102C (index 11)
//   T13 => PC 0x1030 (index 12, invalid/squashed branch test)
module tb_integrated;

    // ---- Clock and reset ----
    reg clk = 0;
    reg reset = 1;
    always #5 clk = ~clk;

    // ---- P1: 2-bit direction predictor ----
    reg  [31:0] p1_lookup_pc;
    reg         p1_update_valid;
    reg  [31:0] p1_update_pc;
    reg         p1_actual_taken;
    wire        p1_predict_taken;
    wire [1:0]  p1_prediction_state;

    predictor_2bit #(.INDEX_BITS(4)) u_p1 (
        .clk(clk), .reset(reset),
        .lookup_pc(p1_lookup_pc),
        .predict_taken(p1_predict_taken),
        .prediction_state(p1_prediction_state),
        .update_valid(p1_update_valid),
        .update_pc(p1_update_pc),
        .actual_taken(p1_actual_taken)
    );

    // ---- P2: Tagged BTB ----
    reg  [31:0] p2_lookup_pc;
    reg         p2_update_valid;
    reg  [31:0] p2_update_pc;
    reg  [31:0] p2_update_target;
    wire        p2_hit;
    wire [31:0] p2_target;

    branch_target_buffer #(.INDEX_BITS(4)) u_p2 (
        .clk(clk), .reset(reset),
        .lookup_pc(p2_lookup_pc),
        .hit(p2_hit), .target(p2_target),
        .update_valid(p2_update_valid),
        .update_pc(p2_update_pc),
        .update_target(p2_update_target)
    );

    // ---- P3: Next-PC mux (speculative fetch selection) ----
    wire [31:0] predicted_next_pc;

    next_pc_mux u_npc (
        .pc(p1_lookup_pc),
        .predicted_taken(p1_predict_taken),
        .btb_hit(p2_hit),
        .predicted_target(p2_target),
        .predicted_next_pc(predicted_next_pc)
    );

    // ---- P3: Branch resolution (execute-stage comparison) ----
    reg         res_valid;
    reg  [31:0] res_branch_pc;
    reg         res_saved_taken;
    reg         res_saved_hit;
    reg  [31:0] res_saved_target;
    reg         res_actual_taken;
    reg  [31:0] res_actual_target;
    wire        res_mispredict;
    wire        res_flush;
    wire        res_redirect;
    wire [31:0] res_redirect_pc;

    branch_resolution u_res (
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

    // -------------------------------------------------------------------------
    // Control-path next fetch address selection:
    // Demonstrates actual redirect priority over speculative next-PC:
    // When a resolving branch asserts redirect, redirect_pc has PRIORITY and
    // overrides the speculative predicted_next_pc for the frontend fetch unit.
    // -------------------------------------------------------------------------
    wire [31:0] selected_pc = res_redirect ? res_redirect_pc : predicted_next_pc;

    // ---- Saved prediction metadata (simulates pipeline register at fetch) ----
    reg  [31:0] saved_pc;
    reg         saved_taken;
    reg         saved_hit;
    reg  [31:0] saved_target;
    reg  [31:0] saved_next_pc;

    // ---- Deterministically sampled resolution outputs (captured while res_valid=1) ----
    reg        sampled_mispredict;
    reg        sampled_flush;
    reg        sampled_redirect;
    reg [31:0] sampled_redirect_pc;
    reg [31:0] sampled_selected_pc;
    reg        sampled_live_deactivated;

    // ---- Score tracking ----
    integer passes = 0;
    integer fails  = 0;
    integer total  = 0;

    task check(input cond, input [8*120-1:0] name);
        begin
            total = total + 1;
            if (cond === 1'b1) begin
                passes = passes + 1;
                $display("PASS [%0d]: %0s", total, name);
            end else begin
                fails = fails + 1;
                $display("FAIL [%0d]: %0s", total, name);
                $display("  sampled: mispredict=%b flush=%b redirect=%b rpc=0x%08h sel_pc=0x%08h live_deact=%b",
                         sampled_mispredict, sampled_flush, sampled_redirect, sampled_redirect_pc, sampled_selected_pc, sampled_live_deactivated);
                $display("  live:    res_valid=%b mispredict=%b flush=%b redirect=%b rpc=0x%08h sel_pc=0x%08h",
                         res_valid, res_mispredict, res_flush, res_redirect, res_redirect_pc, selected_pc);
            end
        end
    endtask

    // Fetch: set lookup PCs and capture predictions into pipeline registers
    task fetch(input [31:0] fetch_pc);
        begin
            p1_lookup_pc = fetch_pc;
            p2_lookup_pc = fetch_pc;
            #1; // combinational settle
            saved_pc      = fetch_pc;
            saved_taken   = p1_predict_taken;
            saved_hit     = p2_hit;
            saved_target  = p2_target;
            saved_next_pc = predicted_next_pc;
        end
    endtask

    // Resolve: apply saved predictions and actual outcome, sample outputs, then update BHT/BTB
    task resolve(input actual_t, input [31:0] actual_tgt);
        begin
            // 1. Assert resolution inputs from saved pipeline registers
            res_valid          = 1'b1;
            res_branch_pc      = saved_pc;
            res_saved_taken    = saved_taken;
            res_saved_hit      = saved_hit;
            res_saved_target   = saved_target;
            res_actual_taken   = actual_t;
            res_actual_target  = actual_tgt;
            #1; // combinational settle for resolution and selected_pc mux

            // 2. Deterministically sample recovery and control outputs while res_valid=1
            sampled_mispredict  = res_mispredict;
            sampled_flush       = res_flush;
            sampled_redirect    = res_redirect;
            sampled_redirect_pc = res_redirect_pc;
            sampled_selected_pc = selected_pc;

            // 3. Update BHT with actual direction (always on valid branch)
            @(negedge clk);
            p1_update_valid = 1'b1;
            p1_update_pc    = saved_pc;
            p1_actual_taken = actual_t;

            // 4. Update BTB only for taken branches (per interface contract)
            if (actual_t) begin
                p2_update_valid  = 1'b1;
                p2_update_pc     = saved_pc;
                p2_update_target = actual_tgt;
            end else begin
                p2_update_valid = 1'b0;
            end

            // 5. Deassert update and resolution valid signals
            @(negedge clk);
            p1_update_valid = 1'b0;
            p2_update_valid = 1'b0;
            res_valid       = 1'b0;
            #1; // combinational settle after deasserting res_valid

            // 6. Verify live recovery outputs are inactive after res_valid=0
            sampled_live_deactivated = (res_mispredict === 1'b0) &&
                                       (res_flush === 1'b0) &&
                                       (res_redirect === 1'b0) &&
                                       (res_redirect_pc === 32'd0);
        end
    endtask

    // Resolve an invalid or squashed branch (res_valid=0):
    // Verifies no recovery signals are generated and predictors are NOT updated.
    task resolve_invalid(input [31:0] inv_pc, input inv_actual_t, input [31:0] inv_actual_tgt);
        begin
            res_valid          = 1'b0; // squashed/invalid branch
            res_branch_pc      = inv_pc;
            res_saved_taken    = 1'b0;
            res_saved_hit      = 1'b0;
            res_saved_target   = 32'd0;
            res_actual_taken   = inv_actual_t;
            res_actual_target  = inv_actual_tgt;
            #1; // combinational settle

            // Sample outputs with res_valid=0
            sampled_mispredict  = res_mispredict;
            sampled_flush       = res_flush;
            sampled_redirect    = res_redirect;
            sampled_redirect_pc = res_redirect_pc;
            sampled_selected_pc = selected_pc;

            // Confirm predictor update enables remain deasserted
            p1_update_valid = 1'b0;
            p2_update_valid = 1'b0;
            @(negedge clk);
            #1;

            sampled_live_deactivated = (res_mispredict === 1'b0) &&
                                       (res_flush === 1'b0) &&
                                       (res_redirect === 1'b0) &&
                                       (res_redirect_pc === 32'd0);
        end
    endtask

    initial begin
        $dumpfile("results/p3_integrated.vcd");
        $dumpvars(0, tb_integrated);

        // Initialize update ports
        p1_update_valid = 0; p1_update_pc = 0; p1_actual_taken = 0;
        p2_update_valid = 0; p2_update_pc = 0; p2_update_target = 0;
        res_valid = 0; res_branch_pc = 0;
        res_saved_taken = 0; res_saved_hit = 0; res_saved_target = 0;
        res_actual_taken = 0; res_actual_target = 0;
        sampled_mispredict = 0; sampled_flush = 0; sampled_redirect = 0;
        sampled_redirect_pc = 0; sampled_selected_pc = 0; sampled_live_deactivated = 1;

        // Release reset
        repeat (3) @(posedge clk);
        @(negedge clk); reset = 0;
        @(posedge clk); #1;

        $display("");
        $display("======== P3 Integration Tests: P1 BHT + P2 BTB + P3 Control ========");

        // =================================================================
        // T1: Cold start — BHT=01 (weakly NT), BTB miss
        //     PC 0x1000 (BHT index 0, first use)
        // =================================================================
        $display("");
        $display("--- T1: Cold start, branch at 0x1000, actually NT ---");
        fetch(32'h0000_1000);
        check(saved_taken === 1'b0 && saved_hit === 1'b0 && saved_next_pc === 32'h0000_1004,
              "T1-fetch: cold BHT=NT, BTB miss, npc=PC+4");
        resolve(0, 32'h0);
        check(sampled_mispredict === 1'b0 && sampled_flush === 1'b0 && sampled_redirect === 1'b0
              && sampled_selected_pc === 32'h0000_1004 && sampled_live_deactivated === 1'b1,
              "T1-resolve: correct NT, no flush, selected_pc=predicted_next_pc");

        // =================================================================
        // T2: Train predictor to taken, train BTB, verify correct prediction
        //     PC 0x1004 (BHT index 1, fresh entry)
        // =================================================================
        $display("");
        $display("--- T2: Train predictor taken, then correct prediction ---");
        // Train twice: BHT 01 -> 10 -> 11 (strongly taken)
        fetch(32'h0000_1004);
        resolve(1, 32'h0000_2000); // BHT: 01 -> 10, BTB trained
        fetch(32'h0000_1004);
        resolve(1, 32'h0000_2000); // BHT: 10 -> 11, BTB confirmed
        // Now fetch: BHT should predict taken, BTB should hit
        fetch(32'h0000_1004);
        check(saved_taken === 1'b1 && saved_hit === 1'b1 && saved_target === 32'h0000_2000
              && saved_next_pc === 32'h0000_2000,
              "T2-fetch: trained BHT=T, BTB hit, npc=target");
        resolve(1, 32'h0000_2000);
        check(sampled_mispredict === 1'b0 && sampled_flush === 1'b0 && sampled_redirect === 1'b0
              && sampled_selected_pc === 32'h0000_2000 && sampled_live_deactivated === 1'b1,
              "T2-resolve: correct taken+target, no flush, selected_pc=target");

        // =================================================================
        // T3: Direction misprediction — predicted NT, actually T
        //     PC 0x1008 (BHT index 2, cold entry)
        //     Verify that redirect_pc overrides speculative PC+4
        // =================================================================
        $display("");
        $display("--- T3: Direction misprediction NT -> T ---");
        fetch(32'h0000_1008);
        check(saved_taken === 1'b0 && saved_next_pc === 32'h0000_100C,
              "T3-fetch: cold BHT=NT, speculative npc=PC+4");
        resolve(1, 32'h0000_3000);
        check(sampled_mispredict === 1'b1 && sampled_flush === 1'b1 && sampled_redirect === 1'b1
              && sampled_redirect_pc === 32'h0000_3000 && sampled_selected_pc === 32'h0000_3000
              && sampled_live_deactivated === 1'b1,
              "T3-resolve: direction miss, redirect overrides speculative PC to target");

        // =================================================================
        // T4: Direction misprediction — predicted T, actually NT
        //     Reuse PC 0x1004 (trained strongly taken in T2)
        //     Verify that redirect_pc overrides speculative target to branch_pc+4
        // =================================================================
        $display("");
        $display("--- T4: Direction misprediction T -> NT ---");
        fetch(32'h0000_1004);
        check(saved_taken === 1'b1 && saved_next_pc === 32'h0000_2000,
              "T4-fetch: trained BHT=T, speculative npc=target (0x2000)");
        resolve(0, 32'h0);
        check(sampled_mispredict === 1'b1 && sampled_flush === 1'b1 && sampled_redirect === 1'b1
              && sampled_redirect_pc === 32'h0000_1008 && sampled_selected_pc === 32'h0000_1008
              && sampled_live_deactivated === 1'b1,
              "T4-resolve: direction miss, redirect overrides speculative target to PC+4");

        // =================================================================
        // T5: Target misprediction — predicted T + BTB hit + wrong target
        //     PC 0x100C (BHT index 3, fresh entry)
        //     Train to taken with target 0x4000, then resolve with target 0x5000
        // =================================================================
        $display("");
        $display("--- T5: Target misprediction (wrong BTB target) ---");
        fetch(32'h0000_100C);
        resolve(1, 32'h0000_4000); // BHT: 01->10, BTB: target=0x4000
        fetch(32'h0000_100C);
        resolve(1, 32'h0000_4000); // BHT: 10->11
        fetch(32'h0000_100C);
        check(saved_taken === 1'b1 && saved_hit === 1'b1 && saved_target === 32'h0000_4000
              && saved_next_pc === 32'h0000_4000,
              "T5-fetch: BHT=T, BTB hit target=0x4000, speculative npc=0x4000");
        resolve(1, 32'h0000_5000); // actual target differs!
        check(sampled_mispredict === 1'b1 && sampled_flush === 1'b1 && sampled_redirect === 1'b1
              && sampled_redirect_pc === 32'h0000_5000 && sampled_selected_pc === 32'h0000_5000
              && sampled_live_deactivated === 1'b1,
              "T5-resolve: wrong target, redirect overrides predicted target with resolved target");

        // =================================================================
        // T6: BTB miss on taken branch (alias eviction)
        //     PC 0x1010 (BHT index 4)
        //     Train taken + BTB, then evict BTB with aliasing PC 0x1050
        // =================================================================
        $display("");
        $display("--- T6: BTB miss on taken branch (alias eviction) ---");
        // Train 0x1010 strongly taken with BTB target
        fetch(32'h0000_1010);
        resolve(1, 32'h0000_6000); // BHT 01->10, BTB trained
        fetch(32'h0000_1010);
        resolve(1, 32'h0000_6000); // BHT 10->11
        // Evict BTB entry using alias PC 0x1050 (same BTB index, different tag)
        @(negedge clk);
        p2_update_valid  = 1'b1;
        p2_update_pc     = 32'h0000_1050;
        p2_update_target = 32'h0000_FFFF;
        @(negedge clk);
        p2_update_valid  = 1'b0;
        // Now fetch 0x1010: BHT still strongly taken, but BTB evicted
        fetch(32'h0000_1010);
        check(saved_taken === 1'b1 && saved_hit === 1'b0 && saved_next_pc === 32'h0000_1014,
              "T6-fetch: BHT=T but BTB miss (evicted), speculative fallback=PC+4");
        resolve(1, 32'h0000_6000);
        check(sampled_mispredict === 1'b1 && sampled_flush === 1'b1 && sampled_redirect === 1'b1
              && sampled_redirect_pc === 32'h0000_6000 && sampled_selected_pc === 32'h0000_6000
              && sampled_live_deactivated === 1'b1,
              "T6-resolve: BTB miss on taken => redirect recovers to actual target");

        // =================================================================
        // T7: Predictor adapts after misprediction
        //     PC 0x1018 (BHT index 6, fresh entry)
        // =================================================================
        $display("");
        $display("--- T7: Predictor adapts after misprediction ---");
        fetch(32'h0000_1018);
        check(saved_taken === 1'b0, "T7a: cold BHT=NT");
        resolve(1, 32'h0000_7000); // BHT: 01->10
        fetch(32'h0000_1018);
        check(saved_taken === 1'b1, "T7b: after 1 taken update, BHT=T (state 10)");
        resolve(1, 32'h0000_7000); // BHT: 10->11
        fetch(32'h0000_1018);
        check(saved_taken === 1'b1 && saved_hit === 1'b1 && saved_next_pc === 32'h0000_7000,
              "T7c: strongly taken, BTB hit, npc=target");

        // =================================================================
        // T8: Two distinct branches resolve in sequence — no interference
        //     Branch A: PC 0x1020 (BHT index 8)
        //     Branch B: PC 0x1024 (BHT index 9)
        // =================================================================
        $display("");
        $display("--- T8: Two distinct branches, no interference ---");
        // Train A taken
        fetch(32'h0000_1020);
        resolve(1, 32'h0000_8000); // BHT: 01->10
        fetch(32'h0000_1020);
        resolve(1, 32'h0000_8000); // BHT: 10->11
        // Train B not-taken
        fetch(32'h0000_1024);
        resolve(0, 32'h0); // BHT: 01->00
        // Verify A is taken, B is NT — no cross-contamination
        fetch(32'h0000_1020);
        check(saved_taken === 1'b1, "T8a: branch A predicts taken (independent)");
        resolve(1, 32'h0000_8000);
        fetch(32'h0000_1024);
        check(saved_taken === 1'b0, "T8b: branch B predicts NT (independent)");

        // =================================================================
        // T9: Stable correct prediction (reuse T2 trained PC 0x1004)
        // =================================================================
        $display("");
        $display("--- T9: Stable correct prediction ---");
        // Re-train 0x1004 back to strongly taken
        fetch(32'h0000_1004);
        resolve(1, 32'h0000_2000);
        fetch(32'h0000_1004);
        resolve(1, 32'h0000_2000);
        fetch(32'h0000_1004);
        check(saved_taken === 1'b1 && saved_hit === 1'b1 && saved_next_pc === 32'h0000_2000,
              "T9: stable taken+hit+correct target prediction");

        // =================================================================
        // T10: Reset clears all state
        // =================================================================
        $display("");
        $display("--- T10: Reset clears all state ---");
        @(negedge clk); reset = 1'b1;
        @(posedge clk);
        @(negedge clk); reset = 1'b0;
        @(posedge clk); #1;
        fetch(32'h0000_1004);
        check(saved_taken === 1'b0 && saved_hit === 1'b0,
              "T10: after reset, BHT=NT and BTB miss on previously trained PC");

        // =================================================================
        // T11: Backward branch target (loop pattern)
        //      PC 0x1028 (BHT index 10) -> jumps back to 0x1000
        // =================================================================
        $display("");
        $display("--- T11: Backward branch target (loop pattern) ---");
        fetch(32'h0000_1028);
        resolve(1, 32'h0000_1000); // train backward taken
        fetch(32'h0000_1028);
        resolve(1, 32'h0000_1000); // reinforce
        fetch(32'h0000_1028);
        check(saved_taken === 1'b1 && saved_hit === 1'b1 && saved_target === 32'h0000_1000,
              "T11-fetch: backward branch predicts taken to loop top");
        resolve(1, 32'h0000_1000);
        check(sampled_mispredict === 1'b0 && sampled_redirect === 1'b0 && sampled_selected_pc === 32'h0000_1000,
              "T11-resolve: correct backward branch, selected_pc=loop top, no flush");

        // =================================================================
        // T12: Verify actual_next_pc for NT resolution
        //      PC 0x102C (BHT index 11)
        // =================================================================
        $display("");
        $display("--- T12: actual_next_pc for NT resolution ---");
        fetch(32'h0000_102C);
        resolve(1, 32'h0000_9000); // BHT: 01->10
        fetch(32'h0000_102C);
        resolve(1, 32'h0000_9000); // BHT: 10->11
        fetch(32'h0000_102C);
        check(saved_taken === 1'b1, "T12-fetch: BHT predicts taken");
        resolve(0, 32'h0);
        check(sampled_mispredict === 1'b1 && sampled_redirect_pc === 32'h0000_1030
              && sampled_selected_pc === 32'h0000_1030 && sampled_live_deactivated === 1'b1,
              "T12-resolve: NT actual => redirect overrides to branch_pc+4");

        // =================================================================
        // T13: Squashed / invalid branch resolution (res_valid=0)
        //      PC 0x1030 (BHT index 12, cold entry)
        //      Verifies:
        //        1. No recovery signals asserted (mispredict=flush=redirect=0).
        //        2. Speculative next-PC is NOT overridden (selected_pc = predicted_next_pc).
        //        3. Predictor update-enable signals remain disabled (0).
        //        4. Learned state in BHT and BTB is completely unchanged.
        // =================================================================
        $display("");
        $display("--- T13: Squashed/invalid branch resolution (res_valid=0) ---");
        fetch(32'h0000_1030);
        check(saved_taken === 1'b0 && saved_hit === 1'b0 && saved_next_pc === 32'h0000_1034,
              "T13-fetch: cold branch PC=0x1030, BHT=NT, BTB miss");

        // Attempt resolution with res_valid=0 and mismatched actuals
        resolve_invalid(32'h0000_1030, 1'b1, 32'hDEAD_BEE0);
        check(sampled_mispredict === 1'b0 && sampled_flush === 1'b0 && sampled_redirect === 1'b0
              && sampled_redirect_pc === 32'd0 && sampled_selected_pc === 32'h0000_1034
              && sampled_live_deactivated === 1'b1,
              "T13-invalid: res_valid=0 asserts no recovery, selected_pc unchanged");

        // Verify predictor state was NOT updated (remains cold 01, BTB miss)
        fetch(32'h0000_1030);
        check(p1_prediction_state === 2'b01 && saved_taken === 1'b0 && saved_hit === 1'b0,
              "T13-untrained: BHT state unchanged (01) and BTB untaught after invalid branch");

        // ===============================================================
        // Summary
        // ===============================================================
        $display("");
        $display("======== P3 Integration Results ========");
        $display("  %0d passed, %0d failed out of %0d total checks", passes, fails, total);

        if (fails != 0)
            $fatal(1, "P3 integration verification FAILED: %0d failures", fails);

        $display("ALL P3 INTEGRATION TESTS PASSED: %0d checks", passes);
        $finish;
    end

endmodule
