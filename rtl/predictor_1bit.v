`timescale 1ns/1ps
`default_nettype none

// ============================================================================
// Module: predictor_1bit
// Project: Dynamic Branch Prediction Subsystem (MCA Project #5)
// Author: Vansh (P4 — Baseline Predictors, Branch Traces and Verification)
//
// Description:
//   Parameterized 1-bit Branch History Table (BHT) predictor.
//   Maintains a 1-bit state per entry representing the last observed branch
//   outcome (0 = Not Taken, 1 = Taken).
//
// Architecture & Conventions:
//   - Aligned 32-bit instructions: index extracted from PC[INDEX_BITS+1:2].
//   - Default INDEX_BITS = 4 yields 16 independent BHT entries.
//   - Active-high synchronous reset clears all table entries to 1'b0 (Not Taken).
//   - Pre-update combinational lookup: predict_taken reflects the table state
//     at lookup_pc before any concurrent or subsequent update.
//   - Synchronous update: on rising clock edge, if update_valid is asserted,
//     the table entry indexed by update_pc is updated with actual_taken.
// ============================================================================

module predictor_1bit #(
    parameter integer INDEX_BITS = 4
)(
    input  wire        clk,
    input  wire        reset,
    input  wire [31:0] lookup_pc,
    output wire        predict_taken,
    input  wire        update_valid,
    input  wire [31:0] update_pc,
    input  wire        actual_taken
);

    localparam integer ENTRIES = (1 << INDEX_BITS);

    // 1-bit history storage: 1 bit per table entry
    reg history [0:ENTRIES-1];

    // Word-aligned table indexing (drops lowest 2 byte-offset bits)
    wire [INDEX_BITS-1:0] lookup_idx = lookup_pc[INDEX_BITS+1:2];
    wire [INDEX_BITS-1:0] update_idx = update_pc[INDEX_BITS+1:2];

    // Combinational lookup
    assign predict_taken = history[lookup_idx];

    integer i;
    always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < ENTRIES; i = i + 1) begin
                history[i] <= 1'b0;
            end
        end else if (update_valid) begin
            history[update_idx] <= actual_taken;
        end
    end

endmodule

`default_nettype wire
