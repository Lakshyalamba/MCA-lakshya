`timescale 1ns/1ps
module predictor_top #(parameter INDEX_BITS = 4)(
    input wire clk, reset,
    input wire [31:0] lookup_pc,
    output wire baseline_taken,
    output wire one_bit_taken,
    output wire two_bit_taken,
    output wire [1:0] two_bit_state,
    input wire update_valid,
    input wire [31:0] update_pc,
    input wire actual_taken
);
    assign baseline_taken = 1'b0;
    predictor_1bit #(.INDEX_BITS(INDEX_BITS)) one_bit (
        .clk(clk), .reset(reset), .lookup_pc(lookup_pc),
        .predict_taken(one_bit_taken), .update_valid(update_valid),
        .update_pc(update_pc), .actual_taken(actual_taken)
    );
    predictor_2bit #(.INDEX_BITS(INDEX_BITS)) two_bit (
        .clk(clk), .reset(reset), .lookup_pc(lookup_pc),
        .predict_taken(two_bit_taken), .prediction_state(two_bit_state),
        .update_valid(update_valid), .update_pc(update_pc), .actual_taken(actual_taken)
    );
endmodule
