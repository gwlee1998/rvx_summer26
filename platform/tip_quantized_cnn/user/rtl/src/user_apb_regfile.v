// ****************************************************************************
// RVX prepost - USER_APB_REGFILE  (PROVIDED infrastructure; students never edit)
// Generic APB slave register file: 64 x 32-bit words, 8-byte APB spacing
// (idx = rpaddr[8:3]). Holds the engine's config; word 0 is read-only STATUS
// (built from the status inputs), word 1 (START) and word 0 (STATUS) are not stored.
// Exposes the whole register array flat (regs_flat) so the engine shell reads its
// config by index, plus the two control pulses (START.bit0 -> start_pulse;
// CONTROL.bit31 -> clear_pulse). This is the ONLY stateful block factored out of the
// engine shells, so the shells are pure structural wiring.
//
//   APB slave  : rpsel/rpenable/rpwrite/rpaddr/rpwdata -> rpready/rprdata/rpslverr
//   status in  : done_sticky / error_sticky / status_state  (-> STATUS word read)
//   config out : regs_flat (NUM_REGS x 32) ; start_pulse ; clear_pulse
// Verilog-1995, no functions.
// ****************************************************************************
module USER_APB_REGFILE
(
    // clock / reset
    clk,
    rstnn,
    // APB slave
    rpsel,
    rpenable,
    rpwrite,
    rpaddr,
    rpwdata,
    rpready,
    rprdata,
    rpslverr,
    // status inputs (for the STATUS word read)
    done_sticky,
    error_sticky,
    status_state,
    // config outputs
    regs_flat,
    start_pulse,
    clear_pulse
);
parameter BW_ADDR = 32;
parameter BW_APB_DATA = 32;
parameter NUM_REGS = 64;
localparam R_STATUS = 0, R_START = 1, R_CONTROL = 2;

// ---- clock / reset ----
input wire clk;
input wire rstnn;
// ---- APB slave ----
input wire rpsel;
input wire rpenable;
input wire rpwrite;
input wire [BW_ADDR-1:0] rpaddr;
input wire [BW_APB_DATA-1:0] rpwdata;
output wire rpready;
output wire [BW_APB_DATA-1:0] rprdata;
output wire rpslverr;
// ---- status inputs ----
input wire done_sticky;
input wire error_sticky;
input wire [2:0] status_state;
// ---- config outputs ----
output wire [NUM_REGS*32-1:0] regs_flat;
output wire start_pulse;
output wire clear_pulse;

reg [31:0] regfile [0:NUM_REGS-1];
integer ri;
wire [5:0] reg_idx = rpaddr[8:3];
wire apb_wr = rpsel & rpenable & rpwrite;
assign start_pulse = apb_wr & (reg_idx==R_START)   & rpwdata[0];
assign clear_pulse = apb_wr & (reg_idx==R_CONTROL) & rpwdata[31];
wire [31:0] status_word = {22'b0, error_sticky, done_sticky, 5'b0, status_state};
assign rpready  = 1'b1;
assign rpslverr = 1'b0;
assign rprdata  = (reg_idx==R_STATUS) ? status_word : regfile[reg_idx];

// ---- APB regfile write concern (reset-clears all; START/STATUS are not stored) ----
always @(posedge clk or negedge rstnn)
begin
    if(!rstnn) for(ri=0;ri<NUM_REGS;ri=ri+1) regfile[ri]<=32'd0;
    else if(apb_wr && (reg_idx!=R_STATUS) && (reg_idx!=R_START)) regfile[reg_idx]<=rpwdata;
end

// ---- flat view of the register array (engine shell indexes this by R_*) ----
genvar gi;
generate for(gi=0; gi<NUM_REGS; gi=gi+1) begin: rflat
    assign regs_flat[gi*32 +: 32] = regfile[gi];
end endgenerate
endmodule
