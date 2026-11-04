`timescale 1ns/1ps
module tb_btb_param;
    parameter INDEX_BITS = 4;
    localparam ENTRIES = 1 << INDEX_BITS;
    localparam [31:0] PC_A     = 32'h100;
    localparam [31:0] PC_ALIAS = PC_A + ((1 << INDEX_BITS) * 4);
    localparam [31:0] T1 = 32'hAAAA0010, T2 = 32'hBBBB0020;

    reg clk = 0, reset = 1, update_valid = 0;
    reg [31:0] lookup_pc = 0, update_pc = 0, update_target = 0;
    wire hit; wire [31:0] target;
    integer passes = 0, fails = 0, i;

    branch_target_buffer #(.INDEX_BITS(INDEX_BITS)) dut (
        .clk(clk), .reset(reset), .lookup_pc(lookup_pc),
        .update_valid(update_valid), .update_pc(update_pc),
        .update_target(update_target), .hit(hit), .target(target));

    always #5 clk = ~clk;

    task check(input cond, input [8*44-1:0] msg);
        begin
            if (cond === 1'b1) passes = passes + 1;
            else begin fails = fails + 1; $display("FAIL [IB=%0d]: %0s", INDEX_BITS, msg); end
        end
    endtask

    task do_reset;
        begin
            @(negedge clk); reset = 1; update_valid = 0;
            @(negedge clk); reset = 0;
        end
    endtask

    task train(input [31:0] pc, input [31:0] tgt);
        begin
            @(negedge clk); update_pc = pc; update_target = tgt; update_valid = 1;
            @(negedge clk); update_valid = 0;
        end
    endtask

    task look(input [31:0] pc);
        begin lookup_pc = pc; #1; end
    endtask

    task expect_hit(input [31:0] pc, input [31:0] tgt, input [8*44-1:0] msg);
        begin look(pc); check(hit === 1'b1 && target === tgt, msg); end
    endtask

    task expect_miss(input [31:0] pc, input [8*44-1:0] msg);
        begin look(pc); check(hit === 1'b0, msg); end
    endtask

    task all_miss(input [8*44-1:0] msg);
        integer k;
        begin
            for (k = 0; k < ENTRIES; k = k + 1) begin
                look(32'h1000 + k*4); check(hit === 1'b0, msg);
            end
            look(PC_A); check(hit === 1'b0, msg);
        end
    endtask

    initial begin
        $dumpfile("results/btb_param.vcd");
        $dumpvars(0, tb_btb_param);

        // 1. Reset priority: reset and update_valid together
        @(negedge clk);
        reset = 1; update_valid = 1; update_pc = PC_A; update_target = T1;
        @(negedge clk);
        reset = 0; update_valid = 0;
        expect_miss(PC_A, "reset priority: PC_A must miss");
        all_miss("reset priority: all entries miss");

        // 2. All entries: independent targets
        for (i = 0; i < ENTRIES; i = i + 1) train(32'h1000 + i*4, 32'hA0000000 + i*32'h111);
        for (i = 0; i < ENTRIES; i = i + 1)
            expect_hit(32'h1000 + i*4, 32'hA0000000 + i*32'h111, "all entries return own target");

        // 3. Disabled updates leave tag and target unchanged
        do_reset;
        train(PC_A, T1);
        @(negedge clk);
        update_pc = PC_A; update_target = T2; update_valid = 0;
        @(negedge clk);
        update_pc = PC_ALIAS; update_target = T2;
        @(negedge clk);
        expect_hit(PC_A, T1, "update_valid=0 keeps target");
        expect_miss(PC_ALIAS, "update_valid=0 no alias write");

        // 4. Tag collision: newer replaces older, no false hit
        do_reset;
        train(PC_A, T1);
        train(PC_ALIAS, T2);
        expect_hit(PC_ALIAS, T2, "alias replaces old entry");
        expect_miss(PC_A, "old PC evicted, no false hit");

        // 5. Same-cycle lookup/update: old state before edge, new after
        do_reset;
        @(negedge clk);
        update_pc = PC_A; update_target = T1; update_valid = 1; lookup_pc = PC_A;
        #1; check(hit === 1'b0, "same-cycle: miss before clock edge");
        @(posedge clk); #1;
        check(hit === 1'b1 && target === T1, "same-cycle: hit after clock edge");
        @(negedge clk); update_valid = 0;

        // 6. Target replacement
        train(PC_A, T2);
        expect_hit(PC_A, T2, "changed target returned");

        // 7. Reset recovery
        do_reset;
        all_miss("after reset all miss");
        train(PC_A, T1);
        expect_hit(PC_A, T1, "retrain after reset hits");

        $display("---- IB=%0d (%0d entries): %0d passed, %0d failed ----",
                 INDEX_BITS, ENTRIES, passes, fails);
        if (fails != 0)
            $fatal(1, "BTB param verification failed: %0d failures", fails);
        $display("ALL TESTS PASSED: %0d checks", passes);
        $finish;
    end
endmodule
