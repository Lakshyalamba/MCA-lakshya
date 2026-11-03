`timescale 1ns/1ps
module tb_predictor;
    reg clk = 0;
    always #5 clk = ~clk;
    reg reset = 1;
    reg [31:0] lookup_pc = 0, update_pc = 0;
    reg update_valid = 0, actual_taken = 0;
    wire baseline_taken, one_bit_taken, two_bit_taken;
    wire [1:0] two_bit_state;
    integer total = 0, correct_base = 0, correct_one = 0, correct_two = 0;
    predictor_top dut(.*);

    task branch;
        input [31:0] pc;
        input taken;
        begin
            @(negedge clk);
            lookup_pc = pc;
            update_pc = pc;
            actual_taken = taken;
            update_valid = 1;
            #1; // read pre-update predictions, not post-update state
            total = total + 1;
            if (baseline_taken == taken) correct_base = correct_base + 1;
            if (one_bit_taken == taken) correct_one = correct_one + 1;
            if (two_bit_taken == taken) correct_two = correct_two + 1;
            $display("branch pc=%h actual=%b baseline=%b one=%b two=%b state=%b", pc, taken, baseline_taken, one_bit_taken, two_bit_taken, two_bit_state);
            @(posedge clk);
            #1; // allow nonblocking assignments to settle
            update_valid = 0;
        end
    endtask

    integer i;
    initial begin
        $dumpfile("results/predictor.vcd");
        $dumpvars(0,tb_predictor);
        repeat (2) @(posedge clk);
        @(negedge clk); reset = 0;
        // First loop: T T T T N repeated; branch exit rarely taken differently.
        for (i=0; i<4; i=i+1) begin
            branch(32'h00000100, 1);
            branch(32'h00000100, 1);
            branch(32'h00000100, 1);
            branch(32'h00000100, 1);
            branch(32'h00000100, 0);
        end
        // Another branch at a different BHT index, alternates.
        for (i=0; i<12; i=i+1) branch(32'h00000104, (i % 2) == 0);
        $display("TOTAL=%0d BASE_CORRECT=%0d ONE_CORRECT=%0d TWO_CORRECT=%0d", total, correct_base, correct_one, correct_two);
        $finish;
    end
endmodule
