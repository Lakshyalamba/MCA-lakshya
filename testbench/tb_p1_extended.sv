`timescale 1ns/1ps
`default_nettype none

// Expanded P1 verification for the existing predictor_2bit RTL.
// This is additive: no changes to the hardware modules are required.
module tb_p1_extended;
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
    integer i;

    predictor_2bit #(.INDEX_BITS(4)) dut (
        .clk(clk),
        .reset(reset),
        .lookup_pc(lookup_pc),
        .predict_taken(predict_taken),
        .prediction_state(prediction_state),
        .update_valid(update_valid),
        .update_pc(update_pc),
        .actual_taken(actual_taken)
    );

    function automatic [31:0] pc_for(input integer index);
        pc_for = 32'h00000100 + (index * 4);
    endfunction

    task automatic expect_state(input [31:0] pc, input [1:0] expected);
        begin
            lookup_pc = pc;
            #1;  // Wait for asynchronous lookup to settle.
            checks = checks + 1;
            if (prediction_state !== expected || predict_taken !== expected[1]) begin
                $display("FAIL check=%0d pc=%h expected=%b/%b got=%b/%b time=%0t",
                         checks, pc, expected, expected[1], prediction_state,
                         predict_taken, $time);
                $fatal(1, "P1 extended BHT verification failed");
            end
        end
    endtask

    task automatic update_branch(input [31:0] pc, input bit taken);
        begin
            @(negedge clk);
            update_pc = pc;
            actual_taken = taken;
            update_valid = 1'b1;
            @(posedge clk);
            #1;  // Wait for the nonblocking register update.
            update_valid = 1'b0;
        end
    endtask

    initial begin
        $dumpfile("results/p1_extended.vcd");
        $dumpvars(0, tb_p1_extended);

        repeat (2) @(posedge clk);
        #1;
        reset = 1'b0;

        // 1. Initial state of all 16 BHT entries.
        for (i = 0; i < 16; i = i + 1)
            expect_state(pc_for(i), 2'b01);
        $display("PASS: all 16 entries reset to 01");

        // 2. Complete transition path and saturation for every entry.
        for (i = 0; i < 16; i = i + 1) begin
            expect_state(pc_for(i), 2'b01);
            update_branch(pc_for(i), 1'b1); expect_state(pc_for(i), 2'b10);
            update_branch(pc_for(i), 1'b1); expect_state(pc_for(i), 2'b11);
            update_branch(pc_for(i), 1'b1); expect_state(pc_for(i), 2'b11);
            update_branch(pc_for(i), 1'b0); expect_state(pc_for(i), 2'b10);
            update_branch(pc_for(i), 1'b0); expect_state(pc_for(i), 2'b01);
            update_branch(pc_for(i), 1'b0); expect_state(pc_for(i), 2'b00);
            update_branch(pc_for(i), 1'b0); expect_state(pc_for(i), 2'b00);
        end
        $display("PASS: complete state transitions and saturation on 16 entries");

        // 3. Verify that each entry remained independently updated.
        for (i = 0; i < 16; i = i + 1)
            expect_state(pc_for(i), 2'b00);
        $display("PASS: independent entries");

        // 4. update_valid=0 must not alter the selected entry.
        @(negedge clk);
        update_pc = pc_for(3);
        actual_taken = 1'b1;
        update_valid = 1'b0;
        @(posedge clk);
        #1;
        expect_state(pc_for(3), 2'b00);
        $display("PASS: update disabled");

        // 5. Index aliasing: +64 bytes changes PC[6], not PC[5:2].
        update_branch(pc_for(7) + 32'h00000040, 1'b1);
        expect_state(pc_for(7), 2'b01);
        expect_state(pc_for(7) + 32'h00000040, 2'b01);
        expect_state(pc_for(8), 2'b00);
        $display("PASS: intentional PC index aliasing");

        // 6. Read one address while resolving a different branch.
        lookup_pc = pc_for(4);
        update_branch(pc_for(5), 1'b1);
        expect_state(pc_for(4), 2'b00);
        expect_state(pc_for(5), 2'b01);
        $display("PASS: separate lookup and update PCs");

        // 7. Read and write the same entry: old state before edge,
        // updated state after the edge (once combinational lookup settles).
        @(negedge clk);
        lookup_pc = pc_for(5);
        update_pc = pc_for(5);
        actual_taken = 1'b1;
        update_valid = 1'b1;
        #1;
        expect_state(pc_for(5), 2'b01);
        @(posedge clk);
        #1;
        update_valid = 1'b0;
        expect_state(pc_for(5), 2'b10);
        $display("PASS: same-entry read/update edge behavior");

        // 8. Reset must take priority over a simultaneous enabled update.
        @(negedge clk);
        reset = 1'b1;
        update_valid = 1'b1;
        update_pc = pc_for(5);
        actual_taken = 1'b1;
        @(posedge clk);
        #1;
        reset = 1'b0;
        update_valid = 1'b0;
        for (i = 0; i < 16; i = i + 1)
            expect_state(pc_for(i), 2'b01);
        $display("PASS: reset priority over enabled update");

        $display("ALL EXTENDED P1 CHECKS PASSED (%0d checks)", checks);
        $finish;
    end
endmodule
`default_nettype wire
