// ****************************************************************************
// USER_IM2COL_ENGINE (IP #1) - THIN SHELL  (provided; students never edit this)
// Infrastructure only: APB slave + register file, AXI master read/write, AXI DMA,
// the tile sequencer, the input BRAM and the output BRAM. It instantiates exactly
// ONE compute module -- USER_IM2COL_COMPUTE (the student im2col index generator) --
// and wires it to the regfile geometry scalars and the two local BRAM ports:
//
//   USER_IM2COL_ENGINE   (this file: APB / AXI / DMA / BRAM / tile_seq)
//     +-- USER_IM2COL_COMPUTE  (user_im2col_compute.v: index/address gen, bounds/pad;
//                               the student-graded 40 pt module)
//     +-- USER_APB_REGFILE / USER_AXI_DMA / USER_TILE_SEQ / USER_BRAM (provided infra)
//
//   tile: IDLE -> READ_INPUT(DDR->BRAM) -> COMPUTE(student) -> WRITE(BRAM->DDR)
//         -> DONE(done_sticky).   copy_smoke: DDR->out_bram->DDR (no compute).
// clk = clk_system. Verilog-1995, no functions. AXI outputs registered in USER_AXI_DMA.
// ****************************************************************************
module USER_IM2COL_ENGINE
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
    // AXI master - write address / data / response channels (im2col -> DDR)
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
    // AXI master - read address / data channels (input tensor <- DDR)
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
parameter LOCAL_WORDS = 8192;
parameter BW_INDEX = 13;

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
// ---- AXI master: write address / data / response (im2col -> DDR) ----
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
// ---- AXI master: read address / data (input tensor <- DDR) ----
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

// ---- APB register file (provided module): geometry read by index from regs_flat ----
localparam R_STATUS = 0,  R_START = 1,  R_CONTROL = 2,  R_SRC  = 3,  R_DST  = 4,
           R_INH    = 5,  R_INW   = 6,  R_INC     = 7,  R_KH   = 8,  R_KW   = 9,
           R_PADH   = 10, R_PADW  = 11, R_STRH    = 12, R_STRW = 13, R_DILH = 14,
           R_DILW   = 15, R_OUTH  = 16, R_OUTW    = 17, R_INZP = 18, R_INBYTES = 19,
           R_OUTBYTES = 20;
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
wire [31:0] cfg_src_addr = regs_flat[R_SRC*32  +: 32];
wire [31:0] cfg_dst_addr = regs_flat[R_DST*32  +: 32];
wire [31:0] cfg_inh      = regs_flat[R_INH*32  +: 32];
wire [31:0] cfg_inw      = regs_flat[R_INW*32  +: 32];
wire [31:0] cfg_inc      = regs_flat[R_INC*32  +: 32];
wire [31:0] cfg_kh       = regs_flat[R_KH*32   +: 32];
wire [31:0] cfg_kw       = regs_flat[R_KW*32   +: 32];
wire [31:0] cfg_padh     = regs_flat[R_PADH*32 +: 32];
wire [31:0] cfg_padw     = regs_flat[R_PADW*32 +: 32];
wire [31:0] cfg_strh     = regs_flat[R_STRH*32 +: 32];
wire [31:0] cfg_strw     = regs_flat[R_STRW*32 +: 32];
wire [31:0] cfg_dilh     = regs_flat[R_DILH*32 +: 32];
wire [31:0] cfg_dilw     = regs_flat[R_DILW*32 +: 32];
wire [31:0] cfg_outh     = regs_flat[R_OUTH*32 +: 32];
wire [31:0] cfg_outw     = regs_flat[R_OUTW*32 +: 32];
wire [31:0] cfg_inzp     = regs_flat[R_INZP*32 +: 32];
wire [31:0] cfg_inbytes  = regs_flat[R_INBYTES*32  +: 32];
wire [31:0] cfg_outbytes = regs_flat[R_OUTBYTES*32 +: 32];
wire [31:0] cfg_control  = regs_flat[R_CONTROL*32  +: 32];
wire [15:0] in_num_words  = cfg_inbytes[17:2]  + (|cfg_inbytes[1:0]);
wire [15:0] out_num_words = cfg_outbytes[17:2] + (|cfg_outbytes[1:0]);

// ---- BRAMs: input (write=DMA, read=student) ; output (write=copy?DMA:student, read=DMA) ----
wire [BW_INDEX-1:0] dma_bw_index;
wire [31:0]         dma_bw_wdata;
wire                dma_bw_wen;
wire [BW_INDEX-1:0] dma_br_index;
wire                dma_br_ren;
wire [31:0]         out_r_data;
wire [BW_INDEX-1:0] in_bram_rindex;
wire                in_bram_ren;
wire [31:0]         in_bram_rdata;
wire [BW_INDEX-1:0] out_bram_windex;
wire [3:0]          out_bram_wbe;
wire [31:0]         out_bram_wdata;
wire                out_bram_wen;
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

// ---- student compute (im2col index gen) ----
wire im2col_start;
wire im2col_done;
USER_IM2COL_COMPUTE #(.BW_INDEX(BW_INDEX))
i_compute
(
    .clk             (clk),
    .rstnn           (rstnn),
    .start           (im2col_start),
    .end_flag        (im2col_done),
    .src_ready       (1'b1),
    .dst_ready       (1'b1),
    .in_h            (cfg_inh),
    .in_w            (cfg_inw),
    .in_c            (cfg_inc),
    .k_h             (cfg_kh),
    .k_w             (cfg_kw),
    .pad_h           (cfg_padh),
    .pad_w           (cfg_padw),
    .stride_h        (cfg_strh),
    .stride_w        (cfg_strw),
    .dil_h           (cfg_dilh),
    .dil_w           (cfg_dilw),
    .out_h           (cfg_outh),
    .out_w           (cfg_outw),
    .in_zp           (cfg_inzp),
    .in_bram_rindex  (in_bram_rindex),
    .in_bram_ren     (in_bram_ren),
    .in_bram_rdata   (in_bram_rdata),
    .out_bram_windex (out_bram_windex),
    .out_bram_wbe    (out_bram_wbe),
    .out_bram_wdata  (out_bram_wdata),
    .out_bram_wen    (out_bram_wen)
);

// ---- tile sequencer (shared USER_TILE_SEQ module; NUM_READS=1: input tensor) ----
USER_TILE_SEQ #(.BW_ADDR(BW_ADDR), .BW_INDEX(BW_INDEX), .NUM_READS(1))
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
    .rd0_nw         (in_num_words),
    .rd1_addr       (32'd0),
    .rd1_lword      ({BW_INDEX{1'b0}}),
    .rd1_nw         (16'd0),
    .rd2_addr       (32'd0),
    .rd2_lword      ({BW_INDEX{1'b0}}),
    .rd2_nw         (16'd0),
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
    .compute_start  (im2col_start),
    .compute_done   (im2col_done),
    .done_sticky    (done_sticky),
    .error_sticky   (error_sticky),
    .status_state   (status_state)
);
endmodule
