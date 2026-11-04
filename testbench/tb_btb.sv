`timescale 1ns/1ps
module tb_btb;
    reg clk = 0, reset = 1, update_valid = 0;
    reg [31:0] lookup_pc = 0, update_pc = 0, update_target = 0;
    wire hit;
    wire [31:0] target;
    integer passes = 0, fails = 0;

    branch_target_buffer dut (.clk(clk), .reset(reset), .lookup_pc(lookup_pc),
        .update_valid(update_valid), .update_pc(update_pc),
        .update_target(update_target), .hit(hit), .target(target));

    always #5 clk = ~clk;

    task check(input cond, input [8*44-1:0] name);
        begin
            if (cond) begin passes = passes + 1; $display("PASS: %0s", name); end
            else begin fails = fails + 1; $display("FAIL: %0s (hit=%b target=%h)", name, hit, target); end
        end
    endtask

    task train(input [31:0] pc, input [31:0] tgt);
        begin
            @(negedge clk);
            update_valid = 1; update_pc = pc; update_target = tgt;
            @(negedge clk);
            update_valid = 0;
        end
    endtask

    task look(input [31:0] pc);
        begin lookup_pc = pc; #1; end
    endtask

    initial begin
        $dumpfile("results/btb.vcd");
        $dumpvars(0, tb_btb);

        repeat (2) @(posedge clk);
        @(negedge clk); reset = 0;
        look(32'h100); check(!hit, "cold miss 0x100");
        look(32'h140); check(!hit, "cold miss 0x140");
        look(32'h000); check(!hit, "cold miss 0x000");

        train(32'h100, 32'h200);
        look(32'h100); check(hit && target == 32'h200, "trained 0x100 hits, target 0x200");

        look(32'h104); check(!hit, "other PC 0x104 misses");

        look(32'h140); check(!hit, "alias 0x140 misses (tag differs)");
        train(32'h140, 32'h300);
        look(32'h140); check(hit && target == 32'h300, "0x140 replaces, hits 0x300");
        look(32'h100); check(!hit, "0x100 evicted by 0x140");

        train(32'h104, 32'h400);
        train(32'h108, 32'h500);
        look(32'h104); check(hit && target == 32'h400, "0x104 independent");
        look(32'h108); check(hit && target == 32'h500, "0x108 independent");
        look(32'h140); check(hit && target == 32'h300, "0x140 untouched");

        train(32'h140, 32'h350);
        look(32'h140); check(hit && target == 32'h350, "target updated to 0x350");

        @(negedge clk);
        update_valid = 0; update_pc = 32'h10C; update_target = 32'h999;
        repeat (2) @(negedge clk);
        look(32'h10C); check(!hit, "no update when update_valid=0");

        @(negedge clk);
        update_valid = 1; update_pc = 32'h110; update_target = 32'h600;
        look(32'h110); check(!hit, "same-cycle lookup sees old (miss)");
        @(negedge clk); update_valid = 0; #1;
        check(hit && target == 32'h600, "after clock edge it hits");

        @(negedge clk); reset = 1;
        @(negedge clk); reset = 0;
        look(32'h104); check(!hit, "miss after reset 0x104");
        look(32'h110); check(!hit, "miss after reset 0x110");

        $display("---- %0d passed, %0d failed ----", passes, fails);
        if (fails == 0) $display("ALL TESTS PASSED"); else $display("TESTS FAILED");
        $finish;
    end
endmodule
