`timescale 1ns/1ps
module predictor_1bit #(parameter INDEX_BITS = 4)(
    input wire clk, reset,
    input wire [31:0] lookup_pc,
    output wire predict_taken,
    input wire update_valid,
    input wire [31:0] update_pc,
    input wire actual_taken
);
    reg [((1 << INDEX_BITS)-1):0] history;
    wire [INDEX_BITS-1:0] lookup_idx = lookup_pc[INDEX_BITS+1:2];
    wire [INDEX_BITS-1:0] update_idx = update_pc[INDEX_BITS+1:2];
    assign predict_taken = history[lookup_idx];
    always @(posedge clk) begin
        if (reset) history <= 0;
        else if (update_valid) history[update_idx] <= actual_taken;
    end
endmodule
