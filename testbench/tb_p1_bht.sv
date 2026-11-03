`timescale 1ns/1ps
// Self-checking Person 1 tests: nonzero exit on failed assertions via $fatal.
module tb_p1_bht;
    reg clk = 1'b0;
    always #5 clk = ~clk;
    reg reset = 1'b1;
    reg [31:0] lookup_pc = 32'h00000100;
    reg [31:0] update_pc = 32'h00000100;
    reg update_valid = 1'b0;
    reg actual_taken = 1'b0;
    wire predict_taken;
    wire [1:0] prediction_state;
    integer checks = 0;

    localparam [31:0] PC_A = 32'h00000100;
    localparam [31:0] PC_B = 32'h00000104;  // different BHT index
    localparam [31:0] PC_C = 32'h00000108;  // another index
    localparam [31:0] PC_ALIAS = 32'h00000140; // PC_A + 64: same BHT index

    predictor_2bit #(.INDEX_BITS(4)) dut (
        .clk(clk), .reset(reset), .lookup_pc(lookup_pc),
        .predict_taken(predict_taken), .prediction_state(prediction_state),
        .update_valid(update_valid), .update_pc(update_pc),
        .actual_taken(actual_taken)
    );

    task automatic check_state;
        input [31:0] pc;
        input [1:0] expected;
        begin
            lookup_pc = pc;
            #1; // Allow combinational read to settle.
            checks = checks + 1;
            if (prediction_state !== expected || predict_taken !== expected[1]) begin
                $display("FAIL pc=%h expected=%b/%b observed=%b/%b time=%0t",
                         pc, expected, expected[1], prediction_state, predict_taken, $time);
                $fatal(1, "Person 1 BHT test failed");
            end
            $display("PASS pc=%h state=%b predicted_taken=%b", pc, prediction_state, predict_taken);
        end
    endtask

    task automatic do_update;
        input [31:0] pc;
        input taken;
        begin
            @(negedge clk);
            update_pc = pc;
            actual_taken = taken;
            update_valid = 1'b1;
            @(posedge clk);
            #1; // Wait for nonblocking assignment to settle.
            update_valid = 1'b0;
        end
    endtask

    initial begin
        $dumpfile("results/p1_bht.vcd");
        $dumpvars(0, tb_p1_bht);
        repeat (2) @(posedge clk);
        #1;
        reset = 1'b0;

        // Reset values: weakly not taken everywhere.
        check_state(PC_A, 2'b01);
        check_state(PC_B, 2'b01);
        check_state(PC_C, 2'b01);

        // Taken increments through weak taken -> strong taken, then saturates.
        do_update(PC_A, 1'b1); check_state(PC_A, 2'b10);
        do_update(PC_A, 1'b1); check_state(PC_A, 2'b11);
        do_update(PC_A, 1'b1); check_state(PC_A, 2'b11);

        // Not-taken decrements through 10 -> 01 -> 00, then saturates.
        do_update(PC_A, 1'b0); check_state(PC_A, 2'b10);
        do_update(PC_A, 1'b0); check_state(PC_A, 2'b01);
        do_update(PC_A, 1'b0); check_state(PC_A, 2'b00);
        do_update(PC_A, 1'b0); check_state(PC_A, 2'b00);

        // Two different BHT indexes should not affect one another.
        do_update(PC_B, 1'b1); check_state(PC_B, 2'b10);
        check_state(PC_A, 2'b00);
        check_state(PC_C, 2'b01);

        // Aliasing: PC_A and PC_ALIAS share bits [5:2].
        check_state(PC_ALIAS, 2'b00);
        do_update(PC_ALIAS, 1'b1); check_state(PC_A, 2'b01);
        check_state(PC_ALIAS, 2'b01);

        // An update to PC_B should not change a concurrent lookup to PC_A.
        lookup_pc = PC_A;
        do_update(PC_B, 1'b0);
        check_state(PC_A, 2'b01);
        check_state(PC_B, 2'b01);

        // update_valid=0 inhibits all changes.
        @(negedge clk);
        update_valid = 1'b0;
        update_pc = PC_A;
        actual_taken = 1'b1;
        @(posedge clk);
        #1;
        check_state(PC_A, 2'b01);

        // Reset returns every entry to weakly not taken.
        do_update(PC_B, 1'b1);
        check_state(PC_B, 2'b10);
        @(negedge clk);
        reset = 1'b1;
        @(posedge clk);
        #1;
        reset = 1'b0;
        check_state(PC_A, 2'b01);
        check_state(PC_B, 2'b01);

        $display("ALL P1 CHECKS PASSED (%0d checks)", checks);
        $finish;
    end
endmodule
