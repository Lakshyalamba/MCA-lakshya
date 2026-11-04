`timescale 1ns/1ps
`default_nettype none
// Person 3 (Tanmay): Combinational next-PC selector.
// Chooses between sequential PC+4 and a valid predicted branch target.
//
// Decision logic:
//   If the direction predictor says "taken" AND the BTB has a valid hit,
//   the predicted next PC is the BTB target address.
//   Otherwise (not-taken prediction, or BTB miss even with taken prediction),
//   the predicted next PC is the sequential fallback PC+4.
//
// This is a purely combinational module with zero-cycle lookup latency,
// intended for the fetch stage of a pipelined processor.
module next_pc_mux (
    input  wire [31:0] pc,               // current fetch PC
    input  wire        predicted_taken,   // P1 BHT direction prediction
    input  wire        btb_hit,           // P2 BTB tag match and valid
    input  wire [31:0] predicted_target,  // P2 BTB predicted target address
    output wire [31:0] predicted_next_pc  // selected next fetch address
);

    // Sequential fallback: assume 32-bit aligned instructions (PC + 4).
    wire [31:0] sequential_pc = pc + 32'd4;

    // Predicted next PC selection:
    //   Taken AND BTB hit  =>  use predicted target from BTB
    //   Taken AND BTB miss =>  fall back to PC+4 (recovered at resolution)
    //   Not taken           =>  PC+4 (sequential fetch)
    assign predicted_next_pc = (predicted_taken & btb_hit)
                             ? predicted_target
                             : sequential_pc;

endmodule
`default_nettype wire
