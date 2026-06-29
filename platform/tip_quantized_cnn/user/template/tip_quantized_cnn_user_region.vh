/*****************/
/* Custom Region */
/*****************/

// wire clk_system;
// wire clk_core;
// wire clk_system_external;
// wire clk_system_debug;
// wire clk_local_access;
// wire clk_process_000;
// wire clk_dram_if;
// wire clk_dram_sys;
// wire clk_dram_ref;
// wire clk_noc;
// wire gclk_system;
// wire gclk_core;
// wire gclk_system_external;
// wire gclk_system_debug;
// wire gclk_local_access;
// wire gclk_process_000;
// wire gclk_noc;
// wire tick_1us;
// wire tick_62d5ms;
// wire tick_gpio;
// wire spi_common_sclk;
// wire spi_common_sdq0;
// wire global_rstnn;
// wire global_rstpp;
// wire [(6)-1:0] rstnn_seqeunce;
// wire [(6)-1:0] rstpp_seqeunce;
// wire rstnn_user;
// wire rstpp_user;
// wire i_im2col_clk;
// wire i_im2col_rstnn;
// wire i_im2col_rpsel;
// wire i_im2col_rpenable;
// wire i_im2col_rpwrite;
// wire [(32)-1:0] i_im2col_rpaddr;
// wire [(32)-1:0] i_im2col_rpwdata;
// wire i_im2col_rpready;
// wire [(32)-1:0] i_im2col_rprdata;
// wire i_im2col_rpslverr;
// wire i_im2col_sxawready;
// wire i_im2col_sxawvalid;
// wire [(32)-1:0] i_im2col_sxawaddr;
// wire [(2)-1:0] i_im2col_sxawid;
// wire [(8)-1:0] i_im2col_sxawlen;
// wire [(3)-1:0] i_im2col_sxawsize;
// wire [(2)-1:0] i_im2col_sxawburst;
// wire i_im2col_sxwready;
// wire i_im2col_sxwvalid;
// wire [(2)-1:0] i_im2col_sxwid;
// wire [(32)-1:0] i_im2col_sxwdata;
// wire [(32/8)-1:0] i_im2col_sxwstrb;
// wire i_im2col_sxwlast;
// wire i_im2col_sxbready;
// wire i_im2col_sxbvalid;
// wire [(2)-1:0] i_im2col_sxbid;
// wire [(2)-1:0] i_im2col_sxbresp;
// wire i_im2col_sxarready;
// wire i_im2col_sxarvalid;
// wire [(32)-1:0] i_im2col_sxaraddr;
// wire [(2)-1:0] i_im2col_sxarid;
// wire [(8)-1:0] i_im2col_sxarlen;
// wire [(3)-1:0] i_im2col_sxarsize;
// wire [(2)-1:0] i_im2col_sxarburst;
// wire i_im2col_sxrready;
// wire i_im2col_sxrvalid;
// wire [(2)-1:0] i_im2col_sxrid;
// wire [(32)-1:0] i_im2col_sxrdata;
// wire i_im2col_sxrlast;
// wire [(2)-1:0] i_im2col_sxrresp;
// wire i_gemm_requant_clk;
// wire i_gemm_requant_rstnn;
// wire i_gemm_requant_rpsel;
// wire i_gemm_requant_rpenable;
// wire i_gemm_requant_rpwrite;
// wire [(32)-1:0] i_gemm_requant_rpaddr;
// wire [(32)-1:0] i_gemm_requant_rpwdata;
// wire i_gemm_requant_rpready;
// wire [(32)-1:0] i_gemm_requant_rprdata;
// wire i_gemm_requant_rpslverr;
// wire i_gemm_requant_sxawready;
// wire i_gemm_requant_sxawvalid;
// wire [(32)-1:0] i_gemm_requant_sxawaddr;
// wire [(2)-1:0] i_gemm_requant_sxawid;
// wire [(8)-1:0] i_gemm_requant_sxawlen;
// wire [(3)-1:0] i_gemm_requant_sxawsize;
// wire [(2)-1:0] i_gemm_requant_sxawburst;
// wire i_gemm_requant_sxwready;
// wire i_gemm_requant_sxwvalid;
// wire [(2)-1:0] i_gemm_requant_sxwid;
// wire [(32)-1:0] i_gemm_requant_sxwdata;
// wire [(32/8)-1:0] i_gemm_requant_sxwstrb;
// wire i_gemm_requant_sxwlast;
// wire i_gemm_requant_sxbready;
// wire i_gemm_requant_sxbvalid;
// wire [(2)-1:0] i_gemm_requant_sxbid;
// wire [(2)-1:0] i_gemm_requant_sxbresp;
// wire i_gemm_requant_sxarready;
// wire i_gemm_requant_sxarvalid;
// wire [(32)-1:0] i_gemm_requant_sxaraddr;
// wire [(2)-1:0] i_gemm_requant_sxarid;
// wire [(8)-1:0] i_gemm_requant_sxarlen;
// wire [(3)-1:0] i_gemm_requant_sxarsize;
// wire [(2)-1:0] i_gemm_requant_sxarburst;
// wire i_gemm_requant_sxrready;
// wire i_gemm_requant_sxrvalid;
// wire [(2)-1:0] i_gemm_requant_sxrid;
// wire [(32)-1:0] i_gemm_requant_sxrdata;
// wire i_gemm_requant_sxrlast;
// wire [(2)-1:0] i_gemm_requant_sxrresp;

/* DO NOT MODIFY THE ABOVE */
/* MUST MODIFY THE BELOW   */


/*
USER_IM2COL_ENGINE
#(
	.SIZE_OF_MEMORYMAP((32'h 1000)),
	.BW_ADDR(32),
	.BW_APB_DATA(32),
	.BW_AXI_DATA(32),
	.BW_AXI_TID(2)
)
i_im2col
(
	.clk(i_im2col_clk),
	.rstnn(i_im2col_rstnn),
	.rpsel(i_im2col_rpsel),
	.rpenable(i_im2col_rpenable),
	.rpwrite(i_im2col_rpwrite),
	.rpaddr(i_im2col_rpaddr),
	.rpwdata(i_im2col_rpwdata),
	.rpready(i_im2col_rpready),
	.rprdata(i_im2col_rprdata),
	.rpslverr(i_im2col_rpslverr),
	.sxawready(i_im2col_sxawready),
	.sxawvalid(i_im2col_sxawvalid),
	.sxawaddr(i_im2col_sxawaddr),
	.sxawid(i_im2col_sxawid),
	.sxawlen(i_im2col_sxawlen),
	.sxawsize(i_im2col_sxawsize),
	.sxawburst(i_im2col_sxawburst),
	.sxwready(i_im2col_sxwready),
	.sxwvalid(i_im2col_sxwvalid),
	.sxwid(i_im2col_sxwid),
	.sxwdata(i_im2col_sxwdata),
	.sxwstrb(i_im2col_sxwstrb),
	.sxwlast(i_im2col_sxwlast),
	.sxbready(i_im2col_sxbready),
	.sxbvalid(i_im2col_sxbvalid),
	.sxbid(i_im2col_sxbid),
	.sxbresp(i_im2col_sxbresp),
	.sxarready(i_im2col_sxarready),
	.sxarvalid(i_im2col_sxarvalid),
	.sxaraddr(i_im2col_sxaraddr),
	.sxarid(i_im2col_sxarid),
	.sxarlen(i_im2col_sxarlen),
	.sxarsize(i_im2col_sxarsize),
	.sxarburst(i_im2col_sxarburst),
	.sxrready(i_im2col_sxrready),
	.sxrvalid(i_im2col_sxrvalid),
	.sxrid(i_im2col_sxrid),
	.sxrdata(i_im2col_sxrdata),
	.sxrlast(i_im2col_sxrlast),
	.sxrresp(i_im2col_sxrresp)
);
*/
//assign `NOT_CONNECT = i_im2col_clk;
//assign `NOT_CONNECT = i_im2col_rstnn;
//assign `NOT_CONNECT = i_im2col_rpsel;
//assign `NOT_CONNECT = i_im2col_rpenable;
//assign `NOT_CONNECT = i_im2col_rpwrite;
//assign `NOT_CONNECT = i_im2col_rpaddr;
//assign `NOT_CONNECT = i_im2col_rpwdata;
assign i_im2col_rpready = 0;
assign i_im2col_rprdata = 0;
assign i_im2col_rpslverr = 0;
//assign `NOT_CONNECT = i_im2col_sxawready;
assign i_im2col_sxawvalid = 0;
assign i_im2col_sxawaddr = 0;
assign i_im2col_sxawid = 0;
assign i_im2col_sxawlen = 0;
assign i_im2col_sxawsize = 0;
assign i_im2col_sxawburst = 0;
//assign `NOT_CONNECT = i_im2col_sxwready;
assign i_im2col_sxwvalid = 0;
assign i_im2col_sxwid = 0;
assign i_im2col_sxwdata = 0;
assign i_im2col_sxwstrb = 0;
assign i_im2col_sxwlast = 0;
assign i_im2col_sxbready = 0;
//assign `NOT_CONNECT = i_im2col_sxbvalid;
//assign `NOT_CONNECT = i_im2col_sxbid;
//assign `NOT_CONNECT = i_im2col_sxbresp;
//assign `NOT_CONNECT = i_im2col_sxarready;
assign i_im2col_sxarvalid = 0;
assign i_im2col_sxaraddr = 0;
assign i_im2col_sxarid = 0;
assign i_im2col_sxarlen = 0;
assign i_im2col_sxarsize = 0;
assign i_im2col_sxarburst = 0;
assign i_im2col_sxrready = 0;
//assign `NOT_CONNECT = i_im2col_sxrvalid;
//assign `NOT_CONNECT = i_im2col_sxrid;
//assign `NOT_CONNECT = i_im2col_sxrdata;
//assign `NOT_CONNECT = i_im2col_sxrlast;
//assign `NOT_CONNECT = i_im2col_sxrresp;

/*
USER_GEMM_REQUANT_ENGINE
#(
	.SIZE_OF_MEMORYMAP((32'h 1000)),
	.BW_ADDR(32),
	.BW_APB_DATA(32),
	.BW_AXI_DATA(32),
	.BW_AXI_TID(2)
)
i_gemm_requant
(
	.clk(i_gemm_requant_clk),
	.rstnn(i_gemm_requant_rstnn),
	.rpsel(i_gemm_requant_rpsel),
	.rpenable(i_gemm_requant_rpenable),
	.rpwrite(i_gemm_requant_rpwrite),
	.rpaddr(i_gemm_requant_rpaddr),
	.rpwdata(i_gemm_requant_rpwdata),
	.rpready(i_gemm_requant_rpready),
	.rprdata(i_gemm_requant_rprdata),
	.rpslverr(i_gemm_requant_rpslverr),
	.sxawready(i_gemm_requant_sxawready),
	.sxawvalid(i_gemm_requant_sxawvalid),
	.sxawaddr(i_gemm_requant_sxawaddr),
	.sxawid(i_gemm_requant_sxawid),
	.sxawlen(i_gemm_requant_sxawlen),
	.sxawsize(i_gemm_requant_sxawsize),
	.sxawburst(i_gemm_requant_sxawburst),
	.sxwready(i_gemm_requant_sxwready),
	.sxwvalid(i_gemm_requant_sxwvalid),
	.sxwid(i_gemm_requant_sxwid),
	.sxwdata(i_gemm_requant_sxwdata),
	.sxwstrb(i_gemm_requant_sxwstrb),
	.sxwlast(i_gemm_requant_sxwlast),
	.sxbready(i_gemm_requant_sxbready),
	.sxbvalid(i_gemm_requant_sxbvalid),
	.sxbid(i_gemm_requant_sxbid),
	.sxbresp(i_gemm_requant_sxbresp),
	.sxarready(i_gemm_requant_sxarready),
	.sxarvalid(i_gemm_requant_sxarvalid),
	.sxaraddr(i_gemm_requant_sxaraddr),
	.sxarid(i_gemm_requant_sxarid),
	.sxarlen(i_gemm_requant_sxarlen),
	.sxarsize(i_gemm_requant_sxarsize),
	.sxarburst(i_gemm_requant_sxarburst),
	.sxrready(i_gemm_requant_sxrready),
	.sxrvalid(i_gemm_requant_sxrvalid),
	.sxrid(i_gemm_requant_sxrid),
	.sxrdata(i_gemm_requant_sxrdata),
	.sxrlast(i_gemm_requant_sxrlast),
	.sxrresp(i_gemm_requant_sxrresp)
);
*/
//assign `NOT_CONNECT = i_gemm_requant_clk;
//assign `NOT_CONNECT = i_gemm_requant_rstnn;
//assign `NOT_CONNECT = i_gemm_requant_rpsel;
//assign `NOT_CONNECT = i_gemm_requant_rpenable;
//assign `NOT_CONNECT = i_gemm_requant_rpwrite;
//assign `NOT_CONNECT = i_gemm_requant_rpaddr;
//assign `NOT_CONNECT = i_gemm_requant_rpwdata;
assign i_gemm_requant_rpready = 0;
assign i_gemm_requant_rprdata = 0;
assign i_gemm_requant_rpslverr = 0;
//assign `NOT_CONNECT = i_gemm_requant_sxawready;
assign i_gemm_requant_sxawvalid = 0;
assign i_gemm_requant_sxawaddr = 0;
assign i_gemm_requant_sxawid = 0;
assign i_gemm_requant_sxawlen = 0;
assign i_gemm_requant_sxawsize = 0;
assign i_gemm_requant_sxawburst = 0;
//assign `NOT_CONNECT = i_gemm_requant_sxwready;
assign i_gemm_requant_sxwvalid = 0;
assign i_gemm_requant_sxwid = 0;
assign i_gemm_requant_sxwdata = 0;
assign i_gemm_requant_sxwstrb = 0;
assign i_gemm_requant_sxwlast = 0;
assign i_gemm_requant_sxbready = 0;
//assign `NOT_CONNECT = i_gemm_requant_sxbvalid;
//assign `NOT_CONNECT = i_gemm_requant_sxbid;
//assign `NOT_CONNECT = i_gemm_requant_sxbresp;
//assign `NOT_CONNECT = i_gemm_requant_sxarready;
assign i_gemm_requant_sxarvalid = 0;
assign i_gemm_requant_sxaraddr = 0;
assign i_gemm_requant_sxarid = 0;
assign i_gemm_requant_sxarlen = 0;
assign i_gemm_requant_sxarsize = 0;
assign i_gemm_requant_sxarburst = 0;
assign i_gemm_requant_sxrready = 0;
//assign `NOT_CONNECT = i_gemm_requant_sxrvalid;
//assign `NOT_CONNECT = i_gemm_requant_sxrid;
//assign `NOT_CONNECT = i_gemm_requant_sxrdata;
//assign `NOT_CONNECT = i_gemm_requant_sxrlast;
//assign `NOT_CONNECT = i_gemm_requant_sxrresp;

