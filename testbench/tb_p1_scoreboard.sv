`timescale 1ns/1ps
`default_nettype none

// P1 independent reference-model verification of the 2-bit BHT.
// Compile with -Ptb_p1_scoreboard.INDEX_BITS=2/4/5 to test table sizes.
// All assertions fail the simulation with a non-zero exit status.
module tb_p1_scoreboard;
    parameter integer INDEX_BITS = 4;
    parameter integer RANDOM_CYCLES = 4096;
    localparam integer ENTRIES = (1 << INDEX_BITS);

    reg clk = 1'b0;
    always #5 clk = ~clk;

    reg reset = 1'b0;
    reg [31:0] lookup_pc = 32'h00000100;
    reg [31:0] update_pc = 32'h00000100;
    reg update_valid = 1'b0;
    reg actual_taken = 1'b0;
    wire predict_taken;
    wire [1:0] prediction_state;

    predictor_2bit #(.INDEX_BITS(INDEX_BITS)) dut (
        .clk(clk), .reset(reset), .lookup_pc(lookup_pc),
        .predict_taken(predict_taken), .prediction_state(prediction_state),
        .update_valid(update_valid), .update_pc(update_pc),
        .actual_taken(actual_taken)
    );

    // Model stored separately from the RTL. This table is the test oracle.
    reg [1:0] expected [0:ENTRIES-1];
    reg initialized = 1'b0;
    integer checks = 0;
    integer cycles = 0;
    integer updates = 0;
    integer resets = 0;
    integer i, j;
    reg [31:0] rng = 32'h65a7_b39d;
    reg [31:0] random_lookup, random_update;
    reg random_taken, random_enable, random_reset;

    function automatic integer index_of(input [31:0] pc);
        begin
            index_of = (pc >> 2) & (ENTRIES - 1);
        end
    endfunction

    function automatic [31:0] pc_for(input integer index);
        begin
            pc_for = 32'h00000100 + (index * 4);
        end
    endfunction

    // Independent transition table (not an RTL-like arithmetic update).
    function automatic [1:0] oracle_step(input [1:0] state, input taken);
        begin
            case (state)
                2'b00: oracle_step = taken ? 2'b01 : 2'b00;
                2'b01: oracle_step = taken ? 2'b10 : 2'b00;
                2'b10: oracle_step = taken ? 2'b11 : 2'b01;
                2'b11: oracle_step = taken ? 2'b11 : 2'b10;
                default: oracle_step = 2'bxx;
            endcase
        end
    endfunction

    function automatic [31:0] xorshift32(input [31:0] value);
        reg [31:0] x;
        begin
            x = value ^ (value << 13);
            x = x ^ (x >> 17);
            x = x ^ (x << 5);
            xorshift32 = x;
        end
    endfunction

    task automatic check_lookup(input [31:0] pc);
        reg [1:0] want;
        begin
            lookup_pc = pc;
            #1;  // Allow combinational read to settle.
            want = expected[index_of(pc)];
            checks = checks + 1;
            if (prediction_state !== want || predict_taken !== want[1]) begin
                $display("P1 SCOREBOARD FAIL: INDEX_BITS=%0d time=%0t pc=%h index=%0d expected=%b/%b actual=%b/%b",
                         INDEX_BITS, $time, pc, index_of(pc), want, want[1],
                         prediction_state, predict_taken);
                $fatal(1, "Independent BHT reference mismatch");
            end
        end
    endtask

    task automatic check_all_entries;
        integer k;
        begin
            for (k = 0; k < ENTRIES; k = k + 1)
                check_lookup(pc_for(k));
        end
    endtask

    task automatic cycle_action(
        input rst,
        input en,
        input [31:0] read_pc,
        input [31:0] write_pc,
        input outcome
    );
        integer index;
        begin
            @(negedge clk);
            reset = rst;
            update_valid = en;
            lookup_pc = read_pc;
            update_pc = write_pc;
            actual_taken = outcome;

            // Must predict from the OLD state (before branch resolution).
            #1;
            if (initialized)
                check_lookup(read_pc);

            // The reference model updates on the same active clock edge
            // as the RTL; only the resolved branch's index is trained.
            @(posedge clk);
            if (rst) begin
                for (index = 0; index < ENTRIES; index = index + 1)
                    expected[index] = 2'b01;
                resets = resets + 1;
            end else if (en) begin
                index = index_of(write_pc);
                expected[index] = oracle_step(expected[index], outcome);
                updates = updates + 1;
            end
            #1;  // Wait until the DUT's nonblocking assignments settle.
            update_valid = 1'b0;
            reset = 1'b0;
            initialized = 1'b1;
            cycles = cycles + 1;
            check_lookup(read_pc);
        end
    endtask

    initial begin
        // The first edge sets a defined state for every BHT entry.
        cycle_action(1'b1, 1'b0, pc_for(0), pc_for(0), 1'b0);
        check_all_entries();

        // For every address: visit all 8 (state, actual-outcome) pairs.
        // Starting at 01, the following sequence covers all four states
        // for both Taken and Not Taken, including both saturation limits.
        for (i = 0; i < ENTRIES; i = i + 1) begin
            cycle_action(1'b0, 1'b1, pc_for(i), pc_for(i), 1'b1); // 01,T -> 10
            cycle_action(1'b0, 1'b1, pc_for(i), pc_for(i), 1'b1); // 10,T -> 11
            cycle_action(1'b0, 1'b1, pc_for(i), pc_for(i), 1'b1); // 11,T -> 11
            cycle_action(1'b0, 1'b1, pc_for(i), pc_for(i), 1'b0); // 11,N -> 10
            cycle_action(1'b0, 1'b1, pc_for(i), pc_for(i), 1'b0); // 10,N -> 01
            cycle_action(1'b0, 1'b1, pc_for(i), pc_for(i), 1'b0); // 01,N -> 00
            cycle_action(1'b0, 1'b1, pc_for(i), pc_for(i), 1'b0); // 00,N -> 00
            cycle_action(1'b0, 1'b1, pc_for(i), pc_for(i), 1'b1); // 00,T -> 01
        end
        check_all_entries();
        $display("P1 DIRECTED PASS: all %0d entries, 8 transitions per entry", ENTRIES);

        // No update when update_valid is low, regardless of actual_taken.
        cycle_action(1'b0, 1'b0, pc_for(0), pc_for(1), 1'b1);
        check_all_entries();

        // Independent fetch/read PC and resolved/update PC.
        cycle_action(1'b0, 1'b1, pc_for(0), pc_for(ENTRIES-1), 1'b1);
        check_all_entries();

        // Aliasing: PC + (ENTRIES * 4) uses the exact same index bits.
        cycle_action(1'b0, 1'b1, pc_for(0),
                     pc_for(0) + (ENTRIES * 4), 1'b1);
        check_lookup(pc_for(0));
        check_lookup(pc_for(0) + (ENTRIES * 4));
        check_all_entries();

        // Reset must override a simultaneous valid update.
        cycle_action(1'b1, 1'b1, pc_for(0), pc_for(0), 1'b1);
        check_all_entries();
        $display("P1 RESET/ALIAS PASS: disabled updates and reset priority");

        // Deterministic stress, reproducible across runs and table sizes.
        for (j = 0; j < RANDOM_CYCLES; j = j + 1) begin
            rng = xorshift32(rng);
            random_lookup = {rng[31:2], 2'b00};
            rng = xorshift32(rng);
            random_update = {rng[31:2], 2'b00};
            // Include forced collisions between distinct PC addresses.
            if ((j % 5) == 0)
                random_update = random_lookup + (ENTRIES * 4);
            rng = xorshift32(rng);
            random_taken = rng[0];
            random_enable = (rng[3:1] != 3'b000);
            random_reset = ((j % 257) == 256);
            cycle_action(random_reset, random_enable,
                         random_lookup, random_update, random_taken);
            if ((j % 113) == 0)
                check_all_entries();
        end
        check_all_entries();
        $display("P1 SCOREBOARD PASS: INDEX_BITS=%0d, entries=%0d, cycles=%0d, updates=%0d, resets=%0d, checks=%0d",
                 INDEX_BITS, ENTRIES, cycles, updates, resets, checks);
        $finish;
    end
endmodule
`default_nettype wire
