`timescale 1ns/1ps
`default_nettype none
// Person 3 (Tanmay): Branch resolution and misprediction recovery.
//
// This combinational module compares saved fetch-time predictions
// against actual execute-stage branch outcomes and generates
// pipeline control signals: mispredict, flush, redirect, redirect_pc.
//
// IMPORTANT: All prediction inputs (predicted_taken, btb_hit,
// predicted_target) must be the values saved at fetch time, NOT
// the current BHT/BTB lookup outputs. The BHT/BTB may have been
// updated by intervening branches between fetch and resolution.
//
// Misprediction conditions (when valid=1):
//   1. Direction mismatch: predicted_taken != actual_taken
//   2. Target mismatch (for taken branches only):
//      actual_taken AND (BTB miss OR predicted_target != actual_target)
//
// On misprediction:
//   - flush = 1:  invalidate younger wrong-path instructions
//   - redirect = 1: redirect fetch to actual_next_pc
//   - redirect_pc = actual_next_pc
//
// When valid=0 (no branch resolving this cycle), all outputs are
// deasserted and redirect_pc defaults to 0.
module branch_resolution (
    input  wire        valid,              // a branch is resolving this cycle
    input  wire [31:0] branch_pc,          // PC of the resolving branch
    // Saved fetch-time predictions
    input  wire        predicted_taken,    // direction prediction at fetch
    input  wire        btb_hit,            // BTB hit status at fetch
    input  wire [31:0] predicted_target,   // BTB target at fetch
    // Actual resolved outcomes
    input  wire        actual_taken,       // true branch direction
    input  wire [31:0] actual_target,      // true branch target address
    // Pipeline control outputs
    output wire        mispredict,         // recovery needed
    output wire        flush,              // kill younger wrong-path work
    output wire        redirect,           // redirect fetch unit
    output wire [31:0] redirect_pc         // corrected fetch address
);

    // ---------------------------------------------------------------
    // Compute the architecturally correct next PC after this branch.
    //   Taken branch  => jump to actual_target
    //   Not-taken     => fall through to branch_pc + 4
    // ---------------------------------------------------------------
    wire [31:0] actual_next_pc = actual_taken
                               ? actual_target
                               : (branch_pc + 32'd4);

    // ---------------------------------------------------------------
    // Direction mismatch: predicted direction differs from actual.
    // ---------------------------------------------------------------
    wire direction_wrong = (predicted_taken != actual_taken);

    // ---------------------------------------------------------------
    // Target mismatch: the branch was actually taken, but either
    // the BTB missed (no target available) or the BTB target was
    // wrong. Only relevant when actual_taken=1.
    // ---------------------------------------------------------------
    wire target_wrong = actual_taken & (~btb_hit | (predicted_target != actual_target));

    // ---------------------------------------------------------------
    // A misprediction occurs when a valid branch resolves and
    // either the direction or target (for taken branches) was wrong.
    // ---------------------------------------------------------------
    assign mispredict  = valid & (direction_wrong | target_wrong);

    // In this prototype, flush and redirect are synonymous with
    // misprediction. A full pipelined CPU would have more nuanced
    // flush scope (e.g., selective per-stage kill signals).
    assign flush       = mispredict;
    assign redirect    = mispredict;

    // When redirecting, supply the corrected next PC.
    // When not redirecting, output zero (consumers should ignore).
    assign redirect_pc = redirect ? actual_next_pc : 32'd0;

endmodule
`default_nettype wire
