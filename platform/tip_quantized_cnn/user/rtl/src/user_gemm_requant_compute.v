// ****************************************************************************
// USER_GEMM_REQUANT_COMPUTE - STEP 2 student module (40 pt; compute-control).
// Contract (what to compute): user/api/user_sw_ref.c -- sw_gemm_nn (conv) / sw_gemm_nt (fc).
// Ports below are FROZEN. Drives the provided USER_GEMM_CORE (MAC) + PE_RQ x USER_REQUANT_LANE
// (requant), both instantiated below as scaffold; you write the control: param-blob capture,
// conv/fc operand routing, K-step driving, NP-pass sequencing, 4xuint8 packing, output writes.
// RTL gotchas not in the C: 1-cycle registered BRAM read latency; clean 1-cycle output write
// pulse; the requant right-shift is ARITHMETIC; derive NP = PE_N/PE_RQ yourself.
// ****************************************************************************
module USER_GEMM_REQUANT_COMPUTE
(
    // clock / reset
    clk,
    rstnn,
    // framing handshake (engine drives start ; compute raises done at completion)
    start,
    done,
    // regfile config scalars (read-only)
    cfg_m,
    cfg_k,
    cfg_n,
    in_zp,
    out_zp,
    mode,
    w_off,
    p_off,
    // input BRAM read port (im2col | W^T weights | param blob)
    in_bram_rindex,
    in_bram_ren,
    in_bram_rdata,
    // output BRAM write port (packed 4 x uint8 / word)
    out_bram_windex,
    out_bram_wen,
    out_bram_wbe,
    out_bram_wdata
);
parameter PE_N = 64;            // MAC lanes / output-tile width (must be mult of 4)
parameter BW_PEN = 6;           // log2(PE_N)
parameter PE_RQ = 16;           // parallel requant lanes (must divide PE_N)
parameter SI_W = 20;            // Sigma_in accumulator width (max K*255)
parameter BW_INDEX = 14;        // local BRAM address width

// ---- elaboration-time parameter guards (bad param -> "module not found" naming it) ----
generate
    if (PE_N % PE_RQ != 0) begin: g_bad_pe_rq
        PARAM_ERROR_PE_RQ_must_evenly_divide_PE_N u_param_error ();
    end
    if (PE_N % 4 != 0) begin: g_bad_pe_n
        PARAM_ERROR_PE_N_must_be_multiple_of_4 u_param_error ();
    end
endgenerate

// ---- clock / reset ----
input wire clk;
input wire rstnn;
// ---- framing handshake ----
input wire start;
output reg done;
// ---- regfile config scalars ----
input wire [31:0] cfg_m;        // M : output channels (conv) ; 1 (fc, features on lanes)
input wire [31:0] cfg_k;        // K : reduction length
input wire [31:0] cfg_n;        // N : output lanes (conv pixels ; fc features)
input wire [31:0] in_zp;        // layer input zero-point
input wire [7:0]  out_zp;       // layer output zero-point
input wire mode;                // 0 conv gemm_nn ; 1 fc gemm_nt (transpose)
input wire [BW_INDEX-1:0] w_off;// input-BRAM offset of the weight / W^T region
input wire [BW_INDEX-1:0] p_off;// input-BRAM offset of the param blob
// ---- input BRAM read port ----
output wire [BW_INDEX-1:0] in_bram_rindex;
output wire in_bram_ren;
input wire [31:0] in_bram_rdata;
// ---- output BRAM write port ----
output wire [BW_INDEX-1:0] out_bram_windex;
output wire out_bram_wen;
output wire [3:0] out_bram_wbe;
output wire [31:0] out_bram_wdata;

// ---- PROVIDED scaffold #1: the MAC core. You drive start/step + the per-lane operands
//      (sgn = signed weight, uns = unsigned activation, routed per conv/fc); it returns the
//      held accumulators + Sigma_in + done. ----
wire [PE_N*8-1:0]    sgn_flat, uns_flat;
wire [PE_N*32-1:0]   acc_flat;
wire [PE_N*SI_W-1:0] sigma_in_flat;
wire gemm_core_start, gemm_core_step, gemm_core_done;
USER_GEMM_CORE #(.PE_N(PE_N), .SI_W(SI_W))
i_gemm_core
(
    .clk           (clk),
    .rstnn         (rstnn),
    .start         (gemm_core_start),
    .k_len         (cfg_k[15:0]),
    .step          (gemm_core_step),
    .sgn_flat      (sgn_flat),
    .uns_flat      (uns_flat),
    .acc_flat      (acc_flat),
    .sigma_in_flat (sigma_in_flat),
    .done          (gemm_core_done)
);

// ---- PROVIDED scaffold #2: PE_RQ requant lanes (one requant pass = PE_RQ elements). For
//      each pass load this pass's PE_RQ operands into the *_sel regs + pulse req_fire, then
//      read q/valid back. Sequence NP = PE_N/PE_RQ passes to cover all PE_N accumulators. ----
reg  req_fire;
reg  [31:0]     mm_sel  [0:PE_RQ-1];
reg  [SI_W-1:0] si_sel  [0:PE_RQ-1];
reg  [31:0]     m0_sel  [0:PE_RQ-1];
reg  [7:0]      rs_sel  [0:PE_RQ-1];
reg  [31:0]     bias_sel[0:PE_RQ-1];
reg  [31:0]     sw_sel  [0:PE_RQ-1];
reg  [31:0]     kzp_sel [0:PE_RQ-1];
wire [PE_RQ-1:0] rq_valid;
wire [7:0] rq_byte [0:PE_RQ-1];
genvar gr;
generate for(gr=0; gr<PE_RQ; gr=gr+1) begin: rq
    wire [7:0] lane_q;
    wire       lane_v;
    USER_REQUANT_LANE #(.SI_W(SI_W))
    i_lane
    (
        .clk         (clk),
        .rstnn       (rstnn),
        .valid_in    (req_fire),
        .mm          (mm_sel[gr]),
        .sigma_in    (si_sel[gr]),
        .m0          (m0_sel[gr]),
        .right_shift (rs_sel[gr]),
        .bias_eff    (bias_sel[gr]),
        .sigma_w     (sw_sel[gr]),
        .kernel_zp   (kzp_sel[gr]),
        .in_zp       (in_zp),
        .out_zp      (out_zp),
        .q           (lane_q),
        .valid_out   (lane_v)
    );
    assign rq_byte[gr]  = lane_q;
    assign rq_valid[gr] = lane_v;
end endgenerate

// ---- inert tie-offs: the skeleton FAILs on purpose. DELETE everything below and implement
//      the control -- drive the two cores above, sequence the NP passes, capture rq_byte,
//      pack 4 x uint8, write the output BRAM, and raise done. ----
assign sgn_flat        = {(PE_N*8){1'b0}};
assign uns_flat        = {(PE_N*8){1'b0}};
assign gemm_core_start = 1'b0;
assign gemm_core_step  = 1'b0;
assign in_bram_rindex  = {BW_INDEX{1'b0}};
assign in_bram_ren     = 1'b0;
assign out_bram_windex = {BW_INDEX{1'b0}};
assign out_bram_wen    = 1'b0;
assign out_bram_wbe    = 4'b0;
assign out_bram_wdata  = 32'b0;
integer ti;
always @(posedge clk)
begin
    done     <= 1'b0;
    req_fire <= 1'b0;
    for(ti=0; ti<PE_RQ; ti=ti+1)
    begin
        mm_sel[ti]<=0; si_sel[ti]<=0; m0_sel[ti]<=0; rs_sel[ti]<=0;
        bias_sel[ti]<=0; sw_sel[ti]<=0; kzp_sel[ti]<=0;
    end
end
endmodule
