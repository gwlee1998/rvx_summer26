// ****************************************************************************
// RVX prepost - USER_TILE_SEQ  (shared SKELETON infrastructure)
// Generic tile sequencer for an APB+AXI-master engine: orchestrates
//   IDLE -> READ[0..NUM_READS-1] -> COMPUTE -> WRITE -> DONE(done_sticky)
// via a USER_AXI_DMA command port and a compute start/end_flag handshake.
// copy_mode = data-movement smoke: a single READ[0] then WRITE (compute skipped;
// the engine's BRAM mux routes the DMA fill straight to the output buffer).
// One concern per always block (FSM / DMA-command / status). Verilog-1995.
//
// The engine supplies up to 3 read descriptors (ddr addr / local word / #words)
// + 1 write descriptor; unused read slots are ignored when NUM_READS<3.
// USER_IM2COL_ENGINE: NUM_READS=1.  USER_GEMM_REQUANT_ENGINE: NUM_READS=3.
// ****************************************************************************
module USER_TILE_SEQ
(
    // clock / reset
    clk,
    rstnn,
    // control + copy-mode handshake
    start,
    clear,
    copy_mode,
    copy_active,
    // read descriptors (up to NUM_READS: ddr addr / local word / #words)
    rd0_addr,
    rd0_lword,
    rd0_nw,
    rd1_addr,
    rd1_lword,
    rd1_nw,
    rd2_addr,
    rd2_lword,
    rd2_nw,
    // write descriptor
    wr_addr,
    wr_lword,
    wr_nw,
    // AXI DMA command port
    dma_start,
    dma_write_en,
    dma_ddr_addr,
    dma_local_word,
    dma_num_words,
    dma_busy,
    dma_done,
    dma_error,
    // compute (engine core) handshake
    compute_start,
    compute_done,
    // status / sticky flags
    done_sticky,
    error_sticky,
    status_state
);
parameter BW_ADDR = 32;
parameter BW_INDEX = 13;
parameter NUM_READS = 1;          // 1 for IM2COL, 3 for GEMM_REQUANT

// ---- clock / reset ----
input wire clk;
input wire rstnn;
// ---- control + copy-mode handshake ----
input wire start;                 // 1-cycle start pulse
input wire clear;                 // 1-cycle clear-sticky pulse
input wire copy_mode;             // data-movement smoke select (sampled at start)
output reg copy_active;           // latched copy_mode, valid during the operation
// ---- read descriptors ----
input wire [BW_ADDR-1:0]   rd0_addr;
input wire [BW_INDEX-1:0]  rd0_lword;
input wire [16-1:0]        rd0_nw;
input wire [BW_ADDR-1:0]   rd1_addr;
input wire [BW_INDEX-1:0]  rd1_lword;
input wire [16-1:0]        rd1_nw;
input wire [BW_ADDR-1:0]   rd2_addr;
input wire [BW_INDEX-1:0]  rd2_lword;
input wire [16-1:0]        rd2_nw;
// ---- write descriptor ----
input wire [BW_ADDR-1:0]   wr_addr;
input wire [BW_INDEX-1:0]  wr_lword;
input wire [16-1:0]        wr_nw;
// ---- AXI DMA command port ----
output reg dma_start;
output reg dma_write_en;
output reg [BW_ADDR-1:0]  dma_ddr_addr;
output reg [BW_INDEX-1:0] dma_local_word;
output reg [16-1:0]       dma_num_words;
input wire dma_busy;
input wire dma_done;
input wire dma_error;
// ---- compute (engine core) handshake ----
output reg compute_start;
input wire compute_done;
// ---- status / sticky flags ----
output reg done_sticky;
output reg error_sticky;
output reg [2:0] status_state;

localparam T_IDLE=0,T_RD=1,T_CMP=2,T_CMPW=3,T_WR=4,T_DONE=5,T_ERR=6;
reg [2:0] tstate;
reg issued;
reg [1:0] rp;                     // current read-phase index (0..NUM_READS-1)

// read-descriptor mux (combinational, by current read phase)
reg [BW_ADDR-1:0]  sel_addr;
reg [BW_INDEX-1:0] sel_lword;
reg [16-1:0]       sel_nw;
always @(*)
begin
    case(rp)
        2'd0:    begin sel_addr=rd0_addr; sel_lword=rd0_lword; sel_nw=rd0_nw; end
        2'd1:    begin sel_addr=rd1_addr; sel_lword=rd1_lword; sel_nw=rd1_nw; end
        default: begin sel_addr=rd2_addr; sel_lword=rd2_lword; sel_nw=rd2_nw; end
    endcase
end

// ---- FSM state + read-phase + sequencing-flags concern ----
always @(posedge clk or negedge rstnn)
begin
    if(!rstnn) begin tstate<=T_IDLE; issued<=1'b0; rp<=2'd0; copy_active<=1'b0; end
    else
    begin
        case(tstate)
        T_IDLE: if(start) begin copy_active<=copy_mode; rp<=2'd0; issued<=1'b0; tstate<=T_RD; end
        T_RD:
            if(!issued) issued<=1'b1;
            else if(dma_done)
            begin
                issued<=1'b0;
                if(dma_error)               tstate<=T_ERR;
                else if(copy_active)        tstate<=T_WR;
                else if(rp==NUM_READS-1)    tstate<=T_CMP;
                else                        rp<=rp+2'd1;   // stay in T_RD, issue next read
            end
        T_CMP:  tstate<=T_CMPW;
        T_CMPW: if(compute_done) begin issued<=1'b0; tstate<=T_WR; end
        T_WR:
            if(!issued) issued<=1'b1;
            else if(dma_done) begin issued<=1'b0; tstate<= dma_error?T_ERR:T_DONE; end
        T_DONE: tstate<=T_IDLE;
        T_ERR:  tstate<=T_IDLE;
        default: tstate<=T_IDLE;
        endcase
    end
end

// ---- DMA-command + compute-start concern (driven per state) ----
always @(posedge clk or negedge rstnn)
begin
    if(!rstnn) begin dma_start<=1'b0; dma_write_en<=1'b0; dma_ddr_addr<=0; dma_local_word<=0; dma_num_words<=0; compute_start<=1'b0; end
    else
    begin
        dma_start<=1'b0; compute_start<=1'b0;
        case(tstate)
        T_RD:  begin dma_write_en<=1'b0; dma_ddr_addr<=sel_addr; dma_local_word<=sel_lword; dma_num_words<=sel_nw; if(!issued) dma_start<=1'b1; end
        T_CMP: compute_start<=1'b1;
        T_WR:  begin dma_write_en<=1'b1; dma_ddr_addr<=wr_addr;  dma_local_word<=wr_lword;  dma_num_words<=wr_nw;  if(!issued) dma_start<=1'b1; end
        default: ;
        endcase
    end
end

// ---- status / sticky-flags concern ----
always @(posedge clk or negedge rstnn)
begin
    if(!rstnn) begin done_sticky<=1'b0; error_sticky<=1'b0; status_state<=3'd0; end
    else
    begin
        if(clear) begin done_sticky<=1'b0; error_sticky<=1'b0; end
        case(tstate)
        T_IDLE:  begin status_state<=3'd0; if(start) begin done_sticky<=1'b0; error_sticky<=1'b0; end end
        T_RD:    status_state<=3'd2;
        T_CMP:   status_state<=3'd3;
        T_CMPW:  status_state<=3'd3;
        T_WR:    status_state<=3'd4;
        T_DONE:  begin done_sticky<=1'b1; status_state<=3'd0; end
        T_ERR:   begin error_sticky<=1'b1; status_state<=3'd7; end
        default: ;
        endcase
    end
end
endmodule
