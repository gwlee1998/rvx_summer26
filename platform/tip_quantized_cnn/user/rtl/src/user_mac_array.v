// ****************************************************************************
// RVX prepost - USER_MAC_ARRAY  (shared SKELETON; students never edit)
// PE_N independent MAC lanes + a per-lane Sigma_in side-accumulator, behind a
// clean interface (NO AXI/APB/BRAM here). One K-reduction at a time:
//   clear   : zero acc[] and sigma_in[] (tile start)
//   mac_en  : acc[i] += sgn[i] * uns[i] ; sigma_in[i] += uns[i]   (per K step)
//   mac_last: assert WITH the final mac_en of the K-reduction
//   acc_done: 1-cycle strobe when acc[]/sigma_in[] hold the finished sums
// Each lane multiplies a SIGNED 8b operand by an UNSIGNED 8b operand; Sigma_in
// always accumulates the UNSIGNED operand. The engine decides, per GEMM mode,
// which operand is broadcast and which is per-lane (so ONE array serves both):
//   conv  gemm_nn : sgn = broadcast weight  , uns = per-lane activation (im2col)
//   fc    gemm_nt : sgn = per-lane W^T weight, uns = broadcast input activation
// acc/sigma_in are exposed as flat buses; the requant array reads them while the
// MAC array holds them (not cleared until the next tile). Verilog-1995, no funcs.
//
// always blocks grouped by concern: per-lane accumulation (generate) ; handshake.
// ****************************************************************************
module USER_MAC_ARRAY
(
    // clock / reset
    clk,
    rstnn,
    // K-reduction control
    clear,
    mac_en,
    mac_last,
    // per-lane operands in (engine routes broadcast/per-lane per GEMM mode)
    sgn_flat,
    uns_flat,
    // accumulator + activation side-sum out (held until next tile clear)
    acc_flat,
    sigma_in_flat,
    // handshake
    acc_done
);
parameter PE_N = 64;
parameter SI_W = 20;

// ---- clock / reset ----
input wire clk;
input wire rstnn;
// ---- K-reduction control ----
input wire clear;
input wire mac_en;
input wire mac_last;
// ---- per-lane operands in ----
input wire [PE_N*8-1:0] sgn_flat;             // per-lane SIGNED   operand (weight)
input wire [PE_N*8-1:0] uns_flat;             // per-lane UNSIGNED operand (activation)
// ---- accumulator + side-sum out ----
output wire [PE_N*32-1:0] acc_flat;
output wire [PE_N*SI_W-1:0] sigma_in_flat;
// ---- handshake ----
output reg acc_done;

(* use_dsp = "yes" *) reg signed [31:0] acc [0:PE_N-1];
reg [SI_W-1:0] sigma_in [0:PE_N-1];

// ---- per-lane accumulation (acc + Sigma_in cleared/advanced together) ----
genvar gp;
generate for(gp=0; gp<PE_N; gp=gp+1) begin: pe
    always @(posedge clk or negedge rstnn)
    begin
        if(!rstnn) begin acc[gp] <= 0; sigma_in[gp] <= 0; end
        else if(clear) begin acc[gp] <= 0; sigma_in[gp] <= 0; end
        else if(mac_en)
        begin
            acc[gp]      <= acc[gp] + $signed(sgn_flat[gp*8 +: 8]) * $signed({1'b0, uns_flat[gp*8 +: 8]});
            sigma_in[gp] <= sigma_in[gp] + uns_flat[gp*8 +: 8];
        end
    end
    assign acc_flat[gp*32 +: 32]       = acc[gp];
    assign sigma_in_flat[gp*SI_W +: SI_W] = sigma_in[gp];
end endgenerate

// ---- handshake: acc_done one cycle after the final MAC of the K-reduction ----
always @(posedge clk or negedge rstnn)
begin
    if(!rstnn) acc_done <= 1'b0;
    else acc_done <= mac_en & mac_last;
end
endmodule
