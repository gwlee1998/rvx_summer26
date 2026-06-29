// ****************************************************************************
// RVX prepost platform - USER_AXI_DMA (shared SKELETON infrastructure)
// One-outstanding AXI4 master read/write DMA between DDR and an internal BRAM.
// INCR bursts up to MAX_BURST beats, sxarsize/sxawsize = 3'b010 (4 bytes/beat).
// Verilog-1995 style. rstnn = async active-low.
//
//   READ  (dma_write_en=0): DDR[ddr_addr ..] -> BRAM write port (bw_*)  (1 beat/cyc)
//   WRITE (dma_write_en=1): BRAM read port (br_*) -> DDR[ddr_addr ..]   (registered
//                     BRAM read => 2 cyc/beat, no read-data hazard)
//
// NOTE: bursts are NOT split on 4KB boundaries (the rvx sim DDR model does not
// enforce it; buffers are 64B-aligned and <=12KB). Flagged for real-AXI use.
// NOTE: byte counts here are whole 32-bit words (all conv2 blobs are word-sized);
// sub-word tail strobes are not exercised.
// ****************************************************************************

module USER_AXI_DMA
(
    // clock / reset
    clk,
    rstnn,
    // DMA command interface
    dma_start,
    dma_write_en,
    dma_ddr_addr,
    dma_local_word,
    dma_num_words,
    dma_busy,
    dma_done,
    dma_error,
    // BRAM write port (DDR -> BRAM)
    bw_index,
    bw_wdata,
    bw_wen,
    // BRAM read port (BRAM -> DDR)
    br_index,
    br_ren,
    br_rdata,
    // AXI master - write address / data / response channels
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
    // AXI master - read address / data channels
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

parameter BW_ADDR = 32;
parameter BW_AXI_DATA = 32;
parameter BW_AXI_TID = 2;
parameter BW_INDEX = 13;
parameter MAX_BURST = 16;

input wire clk;
input wire rstnn;

// command interface
input wire dma_start;
input wire dma_write_en;                       // 1 = write BRAM->DDR, 0 = read DDR->BRAM
input wire [BW_ADDR-1:0] dma_ddr_addr;
input wire [BW_INDEX-1:0] dma_local_word;
input wire [16-1:0] dma_num_words;
output reg dma_busy;
output reg dma_done;
output reg dma_error;

// BRAM write port (read path: DDR -> BRAM)
output reg [BW_INDEX-1:0] bw_index;
output reg [BW_AXI_DATA-1:0] bw_wdata;
output reg bw_wen;

// BRAM read port (write path: BRAM -> DDR); br_rdata is the registered rdata_synch
output reg [BW_INDEX-1:0] br_index;
output reg br_ren;
input wire [BW_AXI_DATA-1:0] br_rdata;

// AXI master
input wire sxawready;
output reg sxawvalid;
output reg [BW_ADDR-1:0] sxawaddr;
output wire [BW_AXI_TID-1:0] sxawid;
output reg [8-1:0] sxawlen;
output wire [3-1:0] sxawsize;
output wire [2-1:0] sxawburst;
input wire sxwready;
output reg sxwvalid;
output wire [BW_AXI_TID-1:0] sxwid;
output reg [BW_AXI_DATA-1:0] sxwdata;
output reg [BW_AXI_DATA/8-1:0] sxwstrb;
output reg sxwlast;
output reg sxbready;
input wire sxbvalid;
input wire [BW_AXI_TID-1:0] sxbid;
input wire [2-1:0] sxbresp;
input wire sxarready;
output reg sxarvalid;
output reg [BW_ADDR-1:0] sxaraddr;
output wire [BW_AXI_TID-1:0] sxarid;
output reg [8-1:0] sxarlen;
output wire [3-1:0] sxarsize;
output wire [2-1:0] sxarburst;
output reg sxrready;
input wire sxrvalid;
input wire [BW_AXI_TID-1:0] sxrid;
input wire [BW_AXI_DATA-1:0] sxrdata;
input wire sxrlast;
input wire [2-1:0] sxrresp;

// constant AXI attributes
localparam [2:0] AXI_SIZE_4B    = 3'b010;   // AxSIZE = 4 bytes/beat (matches BW_AXI_DATA=32)
localparam [1:0] AXI_BURST_INCR = 2'b01;    // AxBURST = INCR
assign sxarid = 0;
assign sxawid = 0;
assign sxwid  = 0;
assign sxarsize  = AXI_SIZE_4B;
assign sxawsize  = AXI_SIZE_4B;
assign sxarburst = AXI_BURST_INCR;
assign sxawburst = AXI_BURST_INCR;

localparam S_IDLE  = 4'd0;
localparam S_RAR   = 4'd1;   // read  address
localparam S_RDAT  = 4'd2;   // read  data
localparam S_WAW   = 4'd3;   // write address
localparam S_WD0   = 4'd4;   // write: BRAM-latency wait (br_rdata for cur_word settles)
localparam S_WRD   = 4'd5;   // write: capture settled br_rdata into the W beat
localparam S_WDAT  = 4'd6;   // write: drive W beat, wait wready
localparam S_WRESP = 4'd7;   // write response
localparam S_FIN   = 4'd8;

reg [3:0] state;
reg [BW_ADDR-1:0]  cur_ddr;
reg [BW_INDEX-1:0] cur_word;
reg [16-1:0] rem_words;
reg [8-1:0]  blen_m1;      // current burst length-1
reg [8-1:0]  beat;         // beat index within current burst

wire [16-1:0] this_burst = (rem_words >= MAX_BURST) ? MAX_BURST[15:0] : rem_words;

// ---- FSM state-transitions concern (reads handshakes/counters; assigns only state) ----
always @(posedge clk or negedge rstnn)
begin
    if(!rstnn) state <= S_IDLE;
    else
    begin
        case(state)
        S_IDLE:  if(dma_start) state <= (dma_num_words==0) ? S_FIN : (dma_write_en ? S_WAW : S_RAR);
        S_RAR:   if(sxarvalid && sxarready) state <= S_RDAT;
        S_RDAT:  if(sxrvalid && sxrready && sxrlast) state <= (rem_words - 1'b1 != 0) ? S_RAR : S_FIN;
        S_WAW:   if(sxawvalid && sxawready) state <= S_WD0;
        S_WD0:   state <= S_WRD;                                    // wait 1 cyc for BRAM read
        S_WRD:   state <= S_WDAT;
        S_WDAT:  if(sxwvalid && sxwready) state <= (beat == blen_m1) ? S_WRESP : S_WD0;
        S_WRESP: if(sxbvalid && sxbready) state <= (rem_words != 0) ? S_WAW : S_FIN;
        S_FIN:   state <= S_IDLE;
        default: state <= S_IDLE;
        endcase
    end
end

// ---- datapath concern: transfer counters, AXI AR/R/AW/W/B channel regs, BRAM ports, status ----
always @(posedge clk or negedge rstnn)
begin
    if(!rstnn)
    begin
        dma_busy <= 1'b0; dma_done <= 1'b0; dma_error <= 1'b0;
        bw_index <= 0; bw_wdata <= 0; bw_wen <= 1'b0;
        br_index <= 0; br_ren <= 1'b0;
        sxarvalid <= 1'b0; sxaraddr <= 0; sxarlen <= 0; sxrready <= 1'b0;
        sxawvalid <= 1'b0; sxawaddr <= 0; sxawlen <= 0;
        sxwvalid <= 1'b0; sxwdata <= 0; sxwstrb <= 0; sxwlast <= 1'b0;
        sxbready <= 1'b0;
        cur_ddr <= 0; cur_word <= 0; rem_words <= 0; blen_m1 <= 0; beat <= 0;
    end
    else
    begin
        // default 1-cycle pulses
        dma_done <= 1'b0;
        bw_wen <= 1'b0;

        case(state)
        S_IDLE:
        begin
            if(dma_start)
            begin
                cur_ddr   <= dma_ddr_addr;
                cur_word  <= dma_local_word;
                rem_words <= dma_num_words;
                dma_busy  <= 1'b1;
                dma_error <= 1'b0;
            end
        end

        // ---------------- READ ----------------
        S_RAR:
        begin
            sxaraddr  <= cur_ddr;
            sxarlen   <= this_burst[7:0] - 8'd1;
            blen_m1   <= this_burst[7:0] - 8'd1;
            sxarvalid <= 1'b1;
            if(sxarvalid && sxarready)
            begin
                sxarvalid <= 1'b0;
                sxrready  <= 1'b1;
                beat      <= 0;
            end
        end
        S_RDAT:
        begin
            if(sxrvalid && sxrready)
            begin
                bw_index <= cur_word;
                bw_wdata <= sxrdata;
                bw_wen   <= 1'b1;
                cur_word <= cur_word + 1'b1;
                cur_ddr  <= cur_ddr + (BW_AXI_DATA/8);   // advance one beat (4 bytes)
                rem_words<= rem_words - 1'b1;
                if(sxrresp != 2'b00) dma_error <= 1'b1;
                if(sxrlast) sxrready <= 1'b0;
            end
        end

        // ---------------- WRITE ----------------
        S_WAW:
        begin
            sxawaddr  <= cur_ddr;
            sxawlen   <= this_burst[7:0] - 8'd1;
            blen_m1   <= this_burst[7:0] - 8'd1;
            sxawvalid <= 1'b1;
            br_index  <= cur_word;   // prefetch first beat word
            br_ren    <= 1'b1;
            if(sxawvalid && sxawready)
            begin
                sxawvalid <= 1'b0;
                beat      <= 0;
            end
        end
        S_WRD:
        begin
            // br_rdata now valid for cur_word; present the W beat
            sxwdata  <= br_rdata;
            sxwstrb  <= {(BW_AXI_DATA/8){1'b1}};
            sxwlast  <= (beat == blen_m1);
            sxwvalid <= 1'b1;
        end
        S_WDAT:
        begin
            if(sxwvalid && sxwready)
            begin
                sxwvalid <= 1'b0;
                sxwlast  <= 1'b0;
                cur_word <= cur_word + 1'b1;
                cur_ddr  <= cur_ddr + (BW_AXI_DATA/8);   // advance one beat (4 bytes)
                rem_words<= rem_words - 1'b1;
                if(beat == blen_m1)
                begin
                    br_ren   <= 1'b0;
                    sxbready <= 1'b1;
                end
                else
                begin
                    beat     <= beat + 1'b1;
                    br_index <= cur_word + 1'b1; // prefetch next beat
                    br_ren   <= 1'b1;
                end
            end
        end
        S_WRESP:
        begin
            if(sxbvalid && sxbready)
            begin
                sxbready <= 1'b0;
                if(sxbresp != 2'b00) dma_error <= 1'b1;
            end
        end

        S_FIN:
        begin
            dma_busy <= 1'b0;
            dma_done <= 1'b1;
        end
        default: ;
        endcase
    end
end

endmodule
