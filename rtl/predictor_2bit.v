`timescale 1ns/1ps
`default_nettype none
// Person 1: direction predictor over a 2-bit Branch History Table (BHT).
module predictor_2bit #(
    parameter integer INDEX_BITS = 4
)(
    input  wire        clk,
    input  wire        reset,
    input  wire [31:0] lookup_pc,
    output wire        predict_taken,
    output wire [1:0]  prediction_state,
    input  wire        update_valid,
    input  wire [31:0] update_pc,
    input  wire        actual_taken
);
    branch_history_table #(.INDEX_BITS(INDEX_BITS)) bht (
        .clk(clk),
        .reset(reset),
        .lookup_pc(lookup_pc),
        .lookup_state(prediction_state),
        .update_valid(update_valid),
        .update_pc(update_pc),
        .actual_taken(actual_taken)
    );

    // 00/01 -> not taken, 10/11 -> taken.
    assign predict_taken = prediction_state[1];
endmodule
`default_nettype wire
