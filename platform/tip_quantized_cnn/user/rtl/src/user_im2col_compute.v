// ****************************************************************************
// USER_IM2COL_COMPUTE - STEP 2 student module (40 pt).
// Contract (what to compute): sw_im2col in user/api/user_sw_ref.c (the lowered im2col matrix).
// Ports below are FROZEN. RTL gotchas not in the C: 1-cycle registered BRAM read latency;
// clean 1-cycle output write pulse; assert end_flag for exactly one cycle at the end.
// ****************************************************************************
module USER_IM2COL_COMPUTE
(
    // clock / reset
    clk,
    rstnn,
    // framing + backpressure handshake (NO AXI/APB/DMA here)
    start,
    end_flag,
    src_ready,
    dst_ready,
    // regfile config scalars (geometry)
    in_h,
    in_w,
    in_c,
    k_h,
    k_w,
    pad_h,
    pad_w,
    stride_h,
    stride_w,
    dil_h,
    dil_w,
    out_h,
    out_w,
    in_zp,
    // local input BRAM read port (CHW activations)
    in_bram_rindex,
    in_bram_ren,
    in_bram_rdata,
    // local output BRAM write port (im2col matrix)
    out_bram_windex,
    out_bram_wbe,
    out_bram_wdata,
    out_bram_wen
);
parameter BW_INDEX = 13;

// ---- clock / reset ----
input wire clk;
input wire rstnn;
// ---- framing + backpressure handshake ----
input wire start;
output reg end_flag;
input wire src_ready;
input wire dst_ready;
// ---- regfile config scalars (geometry) ----
input wire [31:0] in_h;
input wire [31:0] in_w;
input wire [31:0] in_c;
input wire [31:0] k_h;
input wire [31:0] k_w;
input wire [31:0] pad_h;
input wire [31:0] pad_w;
input wire [31:0] stride_h;
input wire [31:0] stride_w;
input wire [31:0] dil_h;
input wire [31:0] dil_w;
input wire [31:0] out_h;
input wire [31:0] out_w;
input wire [31:0] in_zp;
// ---- local input BRAM read port ----
output reg [BW_INDEX-1:0] in_bram_rindex;
output reg in_bram_ren;
input wire [31:0] in_bram_rdata;
// ---- local output BRAM write port ----
output reg [BW_INDEX-1:0] out_bram_windex;
output reg [3:0] out_bram_wbe;
output reg [31:0] out_bram_wdata;
output reg out_bram_wen;

// ---- inert tie-offs: the skeleton FAILs on purpose. DELETE and implement the datapath
//      (read CHW from the input BRAM, write the lowered matrix, pulse end_flag at the end). ----
always @(posedge clk) begin
    end_flag        <= 1'b0;
    in_bram_rindex  <= {BW_INDEX{1'b0}};
    in_bram_ren     <= 1'b0;
    out_bram_windex <= {BW_INDEX{1'b0}};
    out_bram_wbe    <= 4'b0;
    out_bram_wdata  <= 32'b0;
    out_bram_wen    <= 1'b0;
end
endmodule
