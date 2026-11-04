module branch_target_buffer #(
    parameter INDEX_BITS = 4
)(
    input  wire        clk,
    input  wire        reset,
    input  wire [31:0] lookup_pc,
    input  wire        update_valid,
    input  wire [31:0] update_pc,
    input  wire [31:0] update_target,
    output wire        hit,
    output wire [31:0] target
);
    localparam ENTRIES  = 1 << INDEX_BITS;
    localparam TAG_BITS = 32 - 2 - INDEX_BITS;

    reg                valid_r  [0:ENTRIES-1];
    reg [TAG_BITS-1:0] tag_r    [0:ENTRIES-1];
    reg [31:0]         target_r [0:ENTRIES-1];

    wire [INDEX_BITS-1:0] lookup_idx = lookup_pc[INDEX_BITS+1:2];
    wire [TAG_BITS-1:0]   lookup_tag = lookup_pc[31:INDEX_BITS+2];
    wire [INDEX_BITS-1:0] update_idx = update_pc[INDEX_BITS+1:2];
    wire [TAG_BITS-1:0]   update_tag = update_pc[31:INDEX_BITS+2];

    assign hit    = valid_r[lookup_idx] && (tag_r[lookup_idx] == lookup_tag);
    assign target = hit ? target_r[lookup_idx] : 32'd0;

    integer i;
    always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < ENTRIES; i = i + 1)
                valid_r[i] <= 1'b0;
        end else if (update_valid) begin
            valid_r [update_idx] <= 1'b1;
            tag_r   [update_idx] <= update_tag;
            target_r[update_idx] <= update_target;
        end
    end
endmodule
