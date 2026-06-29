// ****************************************************************************
// USER_GEMM_REQUANT_ENGINE (IP #2) - THIN SHELL  (provided; students never edit)
// Infrastructure only: APB slave + register file, AXI master read/write, AXI DMA,
// the tile sequencer, the input BRAM (im2col / weights / param blob) and the output
// BRAM. It instantiates exactly ONE compute module -- USER_GEMM_REQUANT_COMPUTE (the
// student compute brain) -- and wires it to the regfile config scalars, the two
// local BRAM ports, and the start/done handshake. NOTHING about HOW the GEMM+requant
// is computed lives here:
//
//   USER_GEMM_REQUANT_ENGINE   (this file: APB / AXI / DMA / BRAM / tile_seq)
//     |-- USER_GEMM_REQUANT_COMPUTE  (user_gemm_requant_compute.v: control FSM +
//     |        addressing + MAC drive + requant; the student-graded 60 pt module)
//     |     +-- USER_GEMM_CORE   (user_gemm_core.v: clear/mac_en/mac_last drive)
//     |            +-- USER_MAC_ARRAY (user_mac_array.v: PE_N MAC lanes + Sigma_in)
//     +-- USER_APB_REGFILE / USER_AXI_DMA / USER_TILE_SEQ / USER_BRAM (provided infra)
//
//   input  BRAM: im2col @ word0 | weights @ W_OFF | param blob @ P_OFF
//   output BRAM: GEMM result (packed 4 uint8/word) or, in copy-smoke mode, the DMA fill.
// Verilog-1995, no functions.
// ****************************************************************************
module USER_GEMM_REQUANT_ENGINE
(
    // clock / reset
    clk,
    rstnn,
    // APB slave (regfile programming)
    rpsel,
    rpenable,
    rpwrite,
    rpaddr,
    rpwdata,
    rpready,
    rprdata,
    rpslverr,
    // AXI master - write address / data / response channels (results -> DDR)
    sxawready,
    sxawvalid,
    sxawaddr,
    sxawid,
    sxawlen,
    sxawsize,
    sxawburst,
    sxwready,
    sxwvalid,
    sxwid,
    sxwdata,
    sxwstrb,
    sxwlast,
    sxbready,
    sxbvalid,
    sxbid,
    sxbresp,
    // AXI master - read address / data channels (operands <- DDR)
    sxarready,
    sxarvalid,
    sxaraddr,
    sxarid,
    sxarlen,
    sxarsize,
    sxarburst,
    sxrready,
    sxrvalid,
    sxrid,
    sxrdata,
    sxrlast,
    sxrresp
);
parameter SIZE_OF_MEMORYMAP = (32'h 1000);
parameter BW_ADDR = 32;
parameter BW_APB_DATA = 32;
parameter BW_AXI_DATA = 32;
parameter BW_AXI_TID = 2;
parameter LOCAL_WORDS = 16384;  // 64KB local BRAM: holds im2col + weights + params (fc1 weights = 30KB)
parameter BW_INDEX = 14;
parameter PE_N = 64;            // MAC lanes / output-pixel tile width (must be mult of 4)
parameter BW_PEN = 6;           // log2(PE_N)
parameter PE_RQ = 16;           // parallel requant lanes (must divide PE_N)
localparam SI_W = 20;           // Sigma_in accumulator width (passed to the compute core)

// ---- clock / reset ----
input wire clk;
input wire rstnn;
// ---- APB slave (regfile programming) ----
input wire rpsel;
input wire rpenable;
input wire rpwrite;
input wire [(BW_ADDR)-1:0] rpaddr;
input wire [(BW_APB_DATA)-1:0] rpwdata;
output wire rpready;
output wire [(BW_APB_DATA)-1:0] rprdata;
output wire rpslverr;
// ---- AXI master: write address / data / response (results -> DDR) ----
input wire sxawready;
output wire sxawvalid;
output wire [(BW_ADDR)-1:0] sxawaddr;
output wire [(BW_AXI_TID)-1:0] sxawid;
output wire [(8)-1:0] sxawlen;
output wire [(3)-1:0] sxawsize;
output wire [(2)-1:0] sxawburst;
input wire sxwready;
output wire sxwvalid;
output wire [(BW_AXI_TID)-1:0] sxwid;
output wire [(BW_AXI_DATA)-1:0] sxwdata;
output wire [(BW_AXI_DATA/8)-1:0] sxwstrb;
output wire sxwlast;
output wire sxbready;
input wire sxbvalid;
input wire [(BW_AXI_TID)-1:0] sxbid;
input wire [(2)-1:0] sxbresp;
// ---- AXI master: read address / data (operands <- DDR) ----
input wire sxarready;
output wire sxarvalid;
output wire [(BW_ADDR)-1:0] sxaraddr;
output wire [(BW_AXI_TID)-1:0] sxarid;
output wire [(8)-1:0] sxarlen;
output wire [(3)-1:0] sxarsize;
output wire [(2)-1:0] sxarburst;
output wire sxrready;
input wire sxrvalid;
input wire [(BW_AXI_TID)-1:0] sxrid;
input wire [(BW_AXI_DATA)-1:0] sxrdata;
input wire sxrlast;
input wire [(2)-1:0] sxrresp;

// ---- APB register file (provided module): config read by index from regs_flat ----
localparam R_STATUS = 0,  R_START  = 1,  R_CONTROL = 2,  R_SRC   = 3,  R_WEIGHT = 4,
           R_PARAM  = 5,  R_DST    = 6,  R_M       = 7,  R_K     = 8,  R_N      = 9,
           R_INZP   = 10, R_OUTZP  = 11, R_SRCB    = 12, R_WB    = 13, R_PB     = 14,
           R_OUTB   = 15, R_MODE   = 16;   // R_MODE: 0 = conv gemm_nn ; 1 = fc gemm_nt (transpose)
wire             done_sticky;
wire             error_sticky;
wire [2:0]       status_state;
wire [64*32-1:0] regs_flat;
wire             start_pulse;
wire             clear_pulse;
USER_APB_REGFILE #(.BW_ADDR(BW_ADDR), .BW_APB_DATA(BW_APB_DATA), .NUM_REGS(64))
i_regfile
(
    .clk          (clk),
    .rstnn        (rstnn),
    .rpsel        (rpsel),
    .rpenable     (rpenable),
    .rpwrite      (rpwrite),
    .rpaddr       (rpaddr),
    .rpwdata      (rpwdata),
    .rpready      (rpready),
    .rprdata      (rprdata),
    .rpslverr     (rpslverr),
    .done_sticky  (done_sticky),
    .error_sticky (error_sticky),
    .status_state (status_state),
    .regs_flat    (regs_flat),
    .start_pulse  (start_pulse),
    .clear_pulse  (clear_pulse)
);
wire [31:0] cfg_src_addr    = regs_flat[R_SRC*32     +: 32];
wire [31:0] cfg_weight_addr = regs_flat[R_WEIGHT*32  +: 32];
wire [31:0] cfg_param       = regs_flat[R_PARAM*32   +: 32];
wire [31:0] cfg_dst_addr    = regs_flat[R_DST*32     +: 32];
wire [31:0] cfg_M           = regs_flat[R_M*32       +: 32];
wire [31:0] cfg_K           = regs_flat[R_K*32       +: 32];
wire [31:0] cfg_N           = regs_flat[R_N*32       +: 32];
wire [31:0] cfg_inzp        = regs_flat[R_INZP*32    +: 32];
wire [31:0] cfg_outzp       = regs_flat[R_OUTZP*32   +: 32];
wire [31:0] cfg_srcb        = regs_flat[R_SRCB*32    +: 32];
wire [31:0] cfg_wb          = regs_flat[R_WB*32      +: 32];
wire [31:0] cfg_pb          = regs_flat[R_PB*32      +: 32];
wire [31:0] cfg_outb        = regs_flat[R_OUTB*32    +: 32];
wire [31:0] cfg_control     = regs_flat[R_CONTROL*32 +: 32];
wire [15:0] src_num_words    = cfg_srcb[17:2] + (|cfg_srcb[1:0]);
wire [15:0] weight_num_words = cfg_wb[17:2]   + (|cfg_wb[1:0]);
wire [15:0] param_num_words  = cfg_pb[17:2]   + (|cfg_pb[1:0]);
wire [15:0] out_num_words    = cfg_outb[17:2] + (|cfg_outb[1:0]);
wire [BW_INDEX-1:0] W_OFF = src_num_words[BW_INDEX-1:0];                              // weight region base in BRAM
wire [BW_INDEX-1:0] P_OFF = src_num_words[BW_INDEX-1:0] + weight_num_words[BW_INDEX-1:0]; // param region base
wire tile_mode = regs_flat[R_MODE*32];                                               // 0 conv ; 1 fc transpose

// ---- input BRAM (im2col @ word0 | weights @ W_OFF | param blob @ P_OFF):
//      write port = DMA fill ; read port = compute core ----
wire [BW_INDEX-1:0] dma_bw_index;
wire [31:0]         dma_bw_wdata;
wire                dma_bw_wen;
wire [BW_INDEX-1:0] dma_br_index;
wire                dma_br_ren;
wire [31:0]         out_r_data;
wire [BW_INDEX-1:0] in_bram_rindex;
wire                in_bram_ren;
wire [31:0]         in_bram_rdata;
wire                copy_mode_r;

USER_BRAM #(.DEPTH(LOCAL_WORDS), .AW(BW_INDEX))
i_input_bram
(
    .clk    (clk),
    .windex (dma_bw_index),
    .wen    (dma_bw_wen & ~copy_mode_r),
    .wbe    (4'hF),
    .wdata  (dma_bw_wdata),
    .rindex (in_bram_rindex),
    .ren    (in_bram_ren),
    .rdata  (in_bram_rdata)
);

// ---- GEMM+requant compute core (the student-graded brain) ----
wire                gemm_start;   // tile_seq -> compute start
wire                gemm_done;    // compute done -> tile_seq
wire [BW_INDEX-1:0] out_bram_windex;
wire                out_bram_wen;
wire [3:0]          out_bram_wbe;
wire [31:0]         out_bram_wdata;
USER_GEMM_REQUANT_COMPUTE #(.PE_N(PE_N), .BW_PEN(BW_PEN), .PE_RQ(PE_RQ), .SI_W(SI_W), .BW_INDEX(BW_INDEX))
i_gemm
(
    .clk             (clk),
    .rstnn           (rstnn),
    .start           (gemm_start),
    .done            (gemm_done),
    .cfg_m           (cfg_M),
    .cfg_k           (cfg_K),
    .cfg_n           (cfg_N),
    .in_zp           (cfg_inzp),
    .out_zp          (cfg_outzp[7:0]),
    .mode            (tile_mode),
    .w_off           (W_OFF),
    .p_off           (P_OFF),
    .in_bram_rindex  (in_bram_rindex),
    .in_bram_ren     (in_bram_ren),
    .in_bram_rdata   (in_bram_rdata),
    .out_bram_windex (out_bram_windex),
    .out_bram_wen    (out_bram_wen),
    .out_bram_wbe    (out_bram_wbe),
    .out_bram_wdata  (out_bram_wdata)
);

// ---- output BRAM: write port = (copy-smoke ? DMA fill : compute result) ; read port = DMA drain ----
wire [BW_INDEX-1:0] out_w_index = copy_mode_r ? dma_bw_index : out_bram_windex;
wire [31:0]         out_w_wdata = copy_mode_r ? dma_bw_wdata : out_bram_wdata;
wire [3:0]          out_w_wbe   = copy_mode_r ? 4'hF         : out_bram_wbe;
wire                out_w_wen   = copy_mode_r ? dma_bw_wen   : out_bram_wen;
USER_BRAM #(.DEPTH(LOCAL_WORDS), .AW(BW_INDEX))
i_output_bram
(
    .clk    (clk),
    .windex (out_w_index),
    .wen    (out_w_wen),
    .wbe    (out_w_wbe),
    .wdata  (out_w_wdata),
    .rindex (dma_br_index),
    .ren    (dma_br_ren),
    .rdata  (out_r_data)
);

// ---- AXI DMA ----
wire                dma_start;
wire                dma_write_en;
wire [31:0]         dma_ddr_addr;
wire [BW_INDEX-1:0] dma_local_word;
wire [15:0]         dma_num_words;
wire                dma_busy;
wire                dma_done;
wire                dma_error;
USER_AXI_DMA #(.BW_ADDR(BW_ADDR), .BW_AXI_DATA(BW_AXI_DATA), .BW_AXI_TID(BW_AXI_TID), .BW_INDEX(BW_INDEX), .MAX_BURST(16))
i_dma
(
    .clk            (clk),
    .rstnn          (rstnn),
    .dma_start      (dma_start),
    .dma_write_en   (dma_write_en),
    .dma_ddr_addr   (dma_ddr_addr),
    .dma_local_word (dma_local_word),
    .dma_num_words  (dma_num_words),
    .dma_busy       (dma_busy),
    .dma_done       (dma_done),
    .dma_error      (dma_error),
    .bw_index       (dma_bw_index),
    .bw_wdata       (dma_bw_wdata),
    .bw_wen         (dma_bw_wen),
    .br_index       (dma_br_index),
    .br_ren         (dma_br_ren),
    .br_rdata       (out_r_data),
    .sxawready      (sxawready),
    .sxawvalid      (sxawvalid),
    .sxawaddr       (sxawaddr),
    .sxawid         (sxawid),
    .sxawlen        (sxawlen),
    .sxawsize       (sxawsize),
    .sxawburst      (sxawburst),
    .sxwready       (sxwready),
    .sxwvalid       (sxwvalid),
    .sxwid          (sxwid),
    .sxwdata        (sxwdata),
    .sxwstrb        (sxwstrb),
    .sxwlast        (sxwlast),
    .sxbready       (sxbready),
    .sxbvalid       (sxbvalid),
    .sxbid          (sxbid),
    .sxbresp        (sxbresp),
    .sxarready      (sxarready),
    .sxarvalid      (sxarvalid),
    .sxaraddr       (sxaraddr),
    .sxarid         (sxarid),
    .sxarlen        (sxarlen),
    .sxarsize       (sxarsize),
    .sxarburst      (sxarburst),
    .sxrready       (sxrready),
    .sxrvalid       (sxrvalid),
    .sxrid          (sxrid),
    .sxrdata        (sxrdata),
    .sxrlast        (sxrlast),
    .sxrresp        (sxrresp)
);

// ---- tile sequencer (shared USER_TILE_SEQ; NUM_READS=3: im2col / weights / params) ----
USER_TILE_SEQ #(.BW_ADDR(BW_ADDR), .BW_INDEX(BW_INDEX), .NUM_READS(3))
i_tile
(
    .clk            (clk),
    .rstnn          (rstnn),
    .start          (start_pulse),
    .clear          (clear_pulse),
    .copy_mode      (cfg_control[0]),
    .copy_active    (copy_mode_r),
    .rd0_addr       (cfg_src_addr),
    .rd0_lword      ({BW_INDEX{1'b0}}),
    .rd0_nw         (src_num_words),
    .rd1_addr       (cfg_weight_addr),
    .rd1_lword      (W_OFF),
    .rd1_nw         (weight_num_words),
    .rd2_addr       (cfg_param),
    .rd2_lword      (P_OFF),
    .rd2_nw         (param_num_words),
    .wr_addr        (cfg_dst_addr),
    .wr_lword       ({BW_INDEX{1'b0}}),
    .wr_nw          (out_num_words),
    .dma_start      (dma_start),
    .dma_write_en   (dma_write_en),
    .dma_ddr_addr   (dma_ddr_addr),
    .dma_local_word (dma_local_word),
    .dma_num_words  (dma_num_words),
    .dma_busy       (dma_busy),
    .dma_done       (dma_done),
    .dma_error      (dma_error),
    .compute_start  (gemm_start),
    .compute_done   (gemm_done),
    .done_sticky    (done_sticky),
    .error_sticky   (error_sticky),
    .status_state   (status_state)
);
endmodule
