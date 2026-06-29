// ****************************************************************************
// RVX prepost - USER_BRAM (shared SKELETON infra)
// 1R/1W, 32-bit, byte-write-enable, REGISTERED read (1-cycle latency) BRAM.
// ram_style="block" + registered-read-only => maps to RAMB36E1 (no async read
// port, so NOT distributed LUT-RAM). Standard Xilinx byte-write inference
// template. Verilog-1995 style (synthesis attribute is a tool pragma, ignored
// by simulators). Replaces ERVP_MEMORY_CELL_1R1W (whose combinational
// rdata_asynch port forces LUT-RAM and over-utilizes the device).
// ****************************************************************************
module USER_BRAM
(
    // clock
    clk,
    // write port (byte-write-enable)
    windex,
    wen,
    wbe,
    wdata,
    // read port (registered, 1-cycle latency)
    rindex,
    ren,
    rdata
);
parameter DEPTH = 8192;
parameter AW = 13;

// ---- clock ----
input wire clk;
// ---- write port ----
input wire [AW-1:0] windex;
input wire wen;
input wire [3:0] wbe;
input wire [31:0] wdata;
// ---- read port ----
input wire [AW-1:0] rindex;
input wire ren;
output reg [31:0] rdata;

(* ram_style = "block" *) reg [31:0] mem [0:DEPTH-1];
integer i;
initial begin for(i=0;i<DEPTH;i=i+1) mem[i]=32'd0; end

// ---- registered 1R/1W BRAM access concern (byte-write + 1-cycle read) ----
always @(posedge clk)
begin
    if(wen)
    begin
        if(wbe[0]) mem[windex][7:0]   <= wdata[7:0];
        if(wbe[1]) mem[windex][15:8]  <= wdata[15:8];
        if(wbe[2]) mem[windex][23:16] <= wdata[23:16];
        if(wbe[3]) mem[windex][31:24] <= wdata[31:24];
    end
    if(ren) rdata <= mem[rindex];
end
endmodule
