// ****************************************************************************
// ****************************************************************************
// Copyright SoC Design Research Group, All rights reserved.
// Electronics and Telecommunications Research Institute (ETRI)
// 
// THESE DOCUMENTS CONTAIN CONFIDENTIAL INFORMATION AND KNOWLEDGE
// WHICH IS THE PROPERTY OF ETRI. NO PART OF THIS PUBLICATION IS
// TO BE USED FOR ANY OTHER PURPOSE, AND THESE ARE NOT TO BE
// REPRODUCED, COPIED, DISCLOSED, TRANSMITTED, STORED IN A RETRIEVAL
// SYSTEM OR TRANSLATED INTO ANY OTHER HUMAN OR COMPUTER LANGUAGE,
// IN ANY FORM, BY ANY MEANS, IN WHOLE OR IN PART, WITHOUT THE
// COMPLETE PRIOR WRITTEN PERMISSION OF ETRI.
// ****************************************************************************
// 2026-06-29
// Kyuseung Han (han@etri.re.kr)
// ****************************************************************************
// ****************************************************************************

`include "ervp_platform_controller_memorymap_offset.vh"
`include "ervp_external_peri_group_memorymap_offset.vh"
`include "memorymap_info.vh"
`include "ervp_global.vh"
`include "platform_info.vh"
`include "munoc_network_include.vh"

module TIP_QUANTIZED_CNN
(
	external_clk_0,
	external_clk_0_pair,
	external_rstnn,
	led_list,
	pjtag_rtck,
	pjtag_rtrstnn,
	pjtag_rtms,
	pjtag_rtdi,
	pjtag_rtdo,
	printf_tx,
	printf_rx
	`include "slow_dram_cell_port_dec.vh"
);


input wire external_clk_0;
input wire external_clk_0_pair;
input wire external_rstnn;
output wire [((1)*(1))-1:0] led_list;
input wire pjtag_rtck;
input wire pjtag_rtrstnn;
input wire pjtag_rtms;
input wire pjtag_rtdi;
output wire pjtag_rtdo;
output wire printf_tx;
input wire printf_rx;

`include "slow_dram_cell_port_def.vh"


wire clk_system;
wire clk_core;
wire clk_system_external;
wire clk_system_debug;
wire clk_local_access;
wire clk_process_000;
wire clk_dram_if;
wire clk_dram_sys;
wire clk_dram_ref;
wire clk_noc;
wire gclk_system;
wire gclk_core;
wire gclk_system_external;
wire gclk_system_debug;
wire gclk_local_access;
wire gclk_process_000;
wire gclk_noc;
wire tick_1us;
wire tick_62d5ms;
wire tick_gpio;
wire spi_common_sclk;
wire spi_common_sdq0;
wire global_rstnn;
wire global_rstpp;
wire [(6)-1:0] rstnn_seqeunce;
wire [(6)-1:0] rstpp_seqeunce;
wire rstnn_user;
wire rstpp_user;
wire i_rtl_clk_system;
wire i_rtl_clk_core;
wire i_rtl_clk_system_external;
wire i_rtl_clk_system_debug;
wire i_rtl_clk_local_access;
wire i_rtl_clk_process_000;
wire i_rtl_clk_dram_if;
wire i_rtl_clk_dram_sys;
wire i_rtl_clk_dram_ref;
wire i_rtl_clk_noc;
wire i_rtl_gclk_system;
wire i_rtl_gclk_core;
wire i_rtl_gclk_system_external;
wire i_rtl_gclk_system_debug;
wire i_rtl_gclk_local_access;
wire i_rtl_gclk_process_000;
wire i_rtl_gclk_noc;
wire i_rtl_tick_1us;
wire i_rtl_tick_62d5ms;
wire i_rtl_tick_gpio;
wire i_rtl_spi_common_sclk;
wire i_rtl_spi_common_sdq0;
wire i_rtl_external_rstnn;
wire i_rtl_global_rstnn;
wire i_rtl_global_rstpp;
wire [(6)-1:0] i_rtl_rstnn_seqeunce;
wire [(6)-1:0] i_rtl_rstpp_seqeunce;
wire i_rtl_rstnn_user;
wire i_rtl_rstpp_user;
wire [((1)*(1))-1:0] i_rtl_led_list;
wire i_rtl_i_im2col_clk;
wire i_rtl_i_im2col_rstnn;
wire i_rtl_i_gemm_requant_clk;
wire i_rtl_i_gemm_requant_rstnn;
wire i_rtl_i_system_ddr_clk_ref;
wire i_rtl_i_system_ddr_clk_sys;
wire i_rtl_i_system_ddr_rstnn_sys;
wire i_rtl_i_system_ddr_clk_dram_if;
wire i_rtl_i_system_ddr_rstnn_dram_if;
wire i_rtl_i_system_ddr_initialized;
wire i_rtl_i_pll0_external_rstnn;
wire i_rtl_i_pll0_clk_system;
wire i_rtl_i_pll0_clk_dram_sys;
wire i_rtl_i_pll0_clk_dram_ref;
wire i_rtl_i_system_sram_clk;
wire i_rtl_i_system_sram_rstnn;
wire i_rtl_pjtag_rtck;
wire i_rtl_pjtag_rtrstnn;
wire i_rtl_pjtag_rtms;
wire i_rtl_pjtag_rtdi;
wire i_rtl_pjtag_rtdo;
wire i_rtl_printf_tx;
wire i_rtl_printf_rx;
wire i_rtl_i_im2col_spsel;
wire i_rtl_i_im2col_spenable;
wire i_rtl_i_im2col_spwrite;
wire [(32)-1:0] i_rtl_i_im2col_spaddr;
wire [(32)-1:0] i_rtl_i_im2col_spwdata;
wire i_rtl_i_im2col_spready;
wire [(32)-1:0] i_rtl_i_im2col_sprdata;
wire i_rtl_i_im2col_spslverr;
wire i_rtl_i_im2col_rxawready;
wire i_rtl_i_im2col_rxawvalid;
wire [(32)-1:0] i_rtl_i_im2col_rxawaddr;
wire [(2)-1:0] i_rtl_i_im2col_rxawid;
wire [(8)-1:0] i_rtl_i_im2col_rxawlen;
wire [(3)-1:0] i_rtl_i_im2col_rxawsize;
wire [(2)-1:0] i_rtl_i_im2col_rxawburst;
wire i_rtl_i_im2col_rxwready;
wire i_rtl_i_im2col_rxwvalid;
wire [(2)-1:0] i_rtl_i_im2col_rxwid;
wire [(32)-1:0] i_rtl_i_im2col_rxwdata;
wire [(32/8)-1:0] i_rtl_i_im2col_rxwstrb;
wire i_rtl_i_im2col_rxwlast;
wire i_rtl_i_im2col_rxbready;
wire i_rtl_i_im2col_rxbvalid;
wire [(2)-1:0] i_rtl_i_im2col_rxbid;
wire [(2)-1:0] i_rtl_i_im2col_rxbresp;
wire i_rtl_i_im2col_rxarready;
wire i_rtl_i_im2col_rxarvalid;
wire [(32)-1:0] i_rtl_i_im2col_rxaraddr;
wire [(2)-1:0] i_rtl_i_im2col_rxarid;
wire [(8)-1:0] i_rtl_i_im2col_rxarlen;
wire [(3)-1:0] i_rtl_i_im2col_rxarsize;
wire [(2)-1:0] i_rtl_i_im2col_rxarburst;
wire i_rtl_i_im2col_rxrready;
wire i_rtl_i_im2col_rxrvalid;
wire [(2)-1:0] i_rtl_i_im2col_rxrid;
wire [(32)-1:0] i_rtl_i_im2col_rxrdata;
wire i_rtl_i_im2col_rxrlast;
wire [(2)-1:0] i_rtl_i_im2col_rxrresp;
wire i_rtl_i_gemm_requant_spsel;
wire i_rtl_i_gemm_requant_spenable;
wire i_rtl_i_gemm_requant_spwrite;
wire [(32)-1:0] i_rtl_i_gemm_requant_spaddr;
wire [(32)-1:0] i_rtl_i_gemm_requant_spwdata;
wire i_rtl_i_gemm_requant_spready;
wire [(32)-1:0] i_rtl_i_gemm_requant_sprdata;
wire i_rtl_i_gemm_requant_spslverr;
wire i_rtl_i_gemm_requant_rxawready;
wire i_rtl_i_gemm_requant_rxawvalid;
wire [(32)-1:0] i_rtl_i_gemm_requant_rxawaddr;
wire [(2)-1:0] i_rtl_i_gemm_requant_rxawid;
wire [(8)-1:0] i_rtl_i_gemm_requant_rxawlen;
wire [(3)-1:0] i_rtl_i_gemm_requant_rxawsize;
wire [(2)-1:0] i_rtl_i_gemm_requant_rxawburst;
wire i_rtl_i_gemm_requant_rxwready;
wire i_rtl_i_gemm_requant_rxwvalid;
wire [(2)-1:0] i_rtl_i_gemm_requant_rxwid;
wire [(32)-1:0] i_rtl_i_gemm_requant_rxwdata;
wire [(32/8)-1:0] i_rtl_i_gemm_requant_rxwstrb;
wire i_rtl_i_gemm_requant_rxwlast;
wire i_rtl_i_gemm_requant_rxbready;
wire i_rtl_i_gemm_requant_rxbvalid;
wire [(2)-1:0] i_rtl_i_gemm_requant_rxbid;
wire [(2)-1:0] i_rtl_i_gemm_requant_rxbresp;
wire i_rtl_i_gemm_requant_rxarready;
wire i_rtl_i_gemm_requant_rxarvalid;
wire [(32)-1:0] i_rtl_i_gemm_requant_rxaraddr;
wire [(2)-1:0] i_rtl_i_gemm_requant_rxarid;
wire [(8)-1:0] i_rtl_i_gemm_requant_rxarlen;
wire [(3)-1:0] i_rtl_i_gemm_requant_rxarsize;
wire [(2)-1:0] i_rtl_i_gemm_requant_rxarburst;
wire i_rtl_i_gemm_requant_rxrready;
wire i_rtl_i_gemm_requant_rxrvalid;
wire [(2)-1:0] i_rtl_i_gemm_requant_rxrid;
wire [(32)-1:0] i_rtl_i_gemm_requant_rxrdata;
wire i_rtl_i_gemm_requant_rxrlast;
wire [(2)-1:0] i_rtl_i_gemm_requant_rxrresp;
wire i_rtl_i_system_ddr_sxawready;
wire i_rtl_i_system_ddr_sxawvalid;
wire [(32)-1:0] i_rtl_i_system_ddr_sxawaddr;
wire [(16)-1:0] i_rtl_i_system_ddr_sxawid;
wire [(8)-1:0] i_rtl_i_system_ddr_sxawlen;
wire [(3)-1:0] i_rtl_i_system_ddr_sxawsize;
wire [(2)-1:0] i_rtl_i_system_ddr_sxawburst;
wire i_rtl_i_system_ddr_sxwready;
wire i_rtl_i_system_ddr_sxwvalid;
wire [(16)-1:0] i_rtl_i_system_ddr_sxwid;
wire [(32)-1:0] i_rtl_i_system_ddr_sxwdata;
wire [(32/8)-1:0] i_rtl_i_system_ddr_sxwstrb;
wire i_rtl_i_system_ddr_sxwlast;
wire i_rtl_i_system_ddr_sxbready;
wire i_rtl_i_system_ddr_sxbvalid;
wire [(16)-1:0] i_rtl_i_system_ddr_sxbid;
wire [(2)-1:0] i_rtl_i_system_ddr_sxbresp;
wire i_rtl_i_system_ddr_sxarready;
wire i_rtl_i_system_ddr_sxarvalid;
wire [(32)-1:0] i_rtl_i_system_ddr_sxaraddr;
wire [(16)-1:0] i_rtl_i_system_ddr_sxarid;
wire [(8)-1:0] i_rtl_i_system_ddr_sxarlen;
wire [(3)-1:0] i_rtl_i_system_ddr_sxarsize;
wire [(2)-1:0] i_rtl_i_system_ddr_sxarburst;
wire i_rtl_i_system_ddr_sxrready;
wire i_rtl_i_system_ddr_sxrvalid;
wire [(16)-1:0] i_rtl_i_system_ddr_sxrid;
wire [(32)-1:0] i_rtl_i_system_ddr_sxrdata;
wire i_rtl_i_system_ddr_sxrlast;
wire [(2)-1:0] i_rtl_i_system_ddr_sxrresp;
wire i_rtl_i_system_sram_sxawready;
wire i_rtl_i_system_sram_sxawvalid;
wire [(32)-1:0] i_rtl_i_system_sram_sxawaddr;
wire [(`REQUIRED_BW_OF_SLAVE_TID)-1:0] i_rtl_i_system_sram_sxawid;
wire [(8)-1:0] i_rtl_i_system_sram_sxawlen;
wire [(3)-1:0] i_rtl_i_system_sram_sxawsize;
wire [(2)-1:0] i_rtl_i_system_sram_sxawburst;
wire i_rtl_i_system_sram_sxwready;
wire i_rtl_i_system_sram_sxwvalid;
wire [(`REQUIRED_BW_OF_SLAVE_TID)-1:0] i_rtl_i_system_sram_sxwid;
wire [(32)-1:0] i_rtl_i_system_sram_sxwdata;
wire [(32/8)-1:0] i_rtl_i_system_sram_sxwstrb;
wire i_rtl_i_system_sram_sxwlast;
wire i_rtl_i_system_sram_sxbready;
wire i_rtl_i_system_sram_sxbvalid;
wire [(`REQUIRED_BW_OF_SLAVE_TID)-1:0] i_rtl_i_system_sram_sxbid;
wire [(2)-1:0] i_rtl_i_system_sram_sxbresp;
wire i_rtl_i_system_sram_sxarready;
wire i_rtl_i_system_sram_sxarvalid;
wire [(32)-1:0] i_rtl_i_system_sram_sxaraddr;
wire [(`REQUIRED_BW_OF_SLAVE_TID)-1:0] i_rtl_i_system_sram_sxarid;
wire [(8)-1:0] i_rtl_i_system_sram_sxarlen;
wire [(3)-1:0] i_rtl_i_system_sram_sxarsize;
wire [(2)-1:0] i_rtl_i_system_sram_sxarburst;
wire i_rtl_i_system_sram_sxrready;
wire i_rtl_i_system_sram_sxrvalid;
wire [(`REQUIRED_BW_OF_SLAVE_TID)-1:0] i_rtl_i_system_sram_sxrid;
wire [(32)-1:0] i_rtl_i_system_sram_sxrdata;
wire i_rtl_i_system_sram_sxrlast;
wire [(2)-1:0] i_rtl_i_system_sram_sxrresp;
wire i_im2col_clk;
wire i_im2col_rstnn;
wire i_im2col_rpsel;
wire i_im2col_rpenable;
wire i_im2col_rpwrite;
wire [(32)-1:0] i_im2col_rpaddr;
wire [(32)-1:0] i_im2col_rpwdata;
wire i_im2col_rpready;
wire [(32)-1:0] i_im2col_rprdata;
wire i_im2col_rpslverr;
wire i_im2col_sxawready;
wire i_im2col_sxawvalid;
wire [(32)-1:0] i_im2col_sxawaddr;
wire [(2)-1:0] i_im2col_sxawid;
wire [(8)-1:0] i_im2col_sxawlen;
wire [(3)-1:0] i_im2col_sxawsize;
wire [(2)-1:0] i_im2col_sxawburst;
wire i_im2col_sxwready;
wire i_im2col_sxwvalid;
wire [(2)-1:0] i_im2col_sxwid;
wire [(32)-1:0] i_im2col_sxwdata;
wire [(32/8)-1:0] i_im2col_sxwstrb;
wire i_im2col_sxwlast;
wire i_im2col_sxbready;
wire i_im2col_sxbvalid;
wire [(2)-1:0] i_im2col_sxbid;
wire [(2)-1:0] i_im2col_sxbresp;
wire i_im2col_sxarready;
wire i_im2col_sxarvalid;
wire [(32)-1:0] i_im2col_sxaraddr;
wire [(2)-1:0] i_im2col_sxarid;
wire [(8)-1:0] i_im2col_sxarlen;
wire [(3)-1:0] i_im2col_sxarsize;
wire [(2)-1:0] i_im2col_sxarburst;
wire i_im2col_sxrready;
wire i_im2col_sxrvalid;
wire [(2)-1:0] i_im2col_sxrid;
wire [(32)-1:0] i_im2col_sxrdata;
wire i_im2col_sxrlast;
wire [(2)-1:0] i_im2col_sxrresp;
wire i_gemm_requant_clk;
wire i_gemm_requant_rstnn;
wire i_gemm_requant_rpsel;
wire i_gemm_requant_rpenable;
wire i_gemm_requant_rpwrite;
wire [(32)-1:0] i_gemm_requant_rpaddr;
wire [(32)-1:0] i_gemm_requant_rpwdata;
wire i_gemm_requant_rpready;
wire [(32)-1:0] i_gemm_requant_rprdata;
wire i_gemm_requant_rpslverr;
wire i_gemm_requant_sxawready;
wire i_gemm_requant_sxawvalid;
wire [(32)-1:0] i_gemm_requant_sxawaddr;
wire [(2)-1:0] i_gemm_requant_sxawid;
wire [(8)-1:0] i_gemm_requant_sxawlen;
wire [(3)-1:0] i_gemm_requant_sxawsize;
wire [(2)-1:0] i_gemm_requant_sxawburst;
wire i_gemm_requant_sxwready;
wire i_gemm_requant_sxwvalid;
wire [(2)-1:0] i_gemm_requant_sxwid;
wire [(32)-1:0] i_gemm_requant_sxwdata;
wire [(32/8)-1:0] i_gemm_requant_sxwstrb;
wire i_gemm_requant_sxwlast;
wire i_gemm_requant_sxbready;
wire i_gemm_requant_sxbvalid;
wire [(2)-1:0] i_gemm_requant_sxbid;
wire [(2)-1:0] i_gemm_requant_sxbresp;
wire i_gemm_requant_sxarready;
wire i_gemm_requant_sxarvalid;
wire [(32)-1:0] i_gemm_requant_sxaraddr;
wire [(2)-1:0] i_gemm_requant_sxarid;
wire [(8)-1:0] i_gemm_requant_sxarlen;
wire [(3)-1:0] i_gemm_requant_sxarsize;
wire [(2)-1:0] i_gemm_requant_sxarburst;
wire i_gemm_requant_sxrready;
wire i_gemm_requant_sxrvalid;
wire [(2)-1:0] i_gemm_requant_sxrid;
wire [(32)-1:0] i_gemm_requant_sxrdata;
wire i_gemm_requant_sxrlast;
wire [(2)-1:0] i_gemm_requant_sxrresp;
wire i_system_ddr_clk_ref;
wire i_system_ddr_clk_sys;
wire i_system_ddr_rstnn_sys;
wire i_system_ddr_clk_dram_if;
wire i_system_ddr_rstnn_dram_if;
wire i_system_ddr_initialized;
wire i_system_ddr_rxawready;
wire i_system_ddr_rxawvalid;
wire [(32)-1:0] i_system_ddr_rxawaddr;
wire [(16)-1:0] i_system_ddr_rxawid;
wire [(8)-1:0] i_system_ddr_rxawlen;
wire [(3)-1:0] i_system_ddr_rxawsize;
wire [(2)-1:0] i_system_ddr_rxawburst;
wire i_system_ddr_rxwready;
wire i_system_ddr_rxwvalid;
wire [(16)-1:0] i_system_ddr_rxwid;
wire [(32)-1:0] i_system_ddr_rxwdata;
wire [(32/8)-1:0] i_system_ddr_rxwstrb;
wire i_system_ddr_rxwlast;
wire i_system_ddr_rxbready;
wire i_system_ddr_rxbvalid;
wire [(16)-1:0] i_system_ddr_rxbid;
wire [(2)-1:0] i_system_ddr_rxbresp;
wire i_system_ddr_rxarready;
wire i_system_ddr_rxarvalid;
wire [(32)-1:0] i_system_ddr_rxaraddr;
wire [(16)-1:0] i_system_ddr_rxarid;
wire [(8)-1:0] i_system_ddr_rxarlen;
wire [(3)-1:0] i_system_ddr_rxarsize;
wire [(2)-1:0] i_system_ddr_rxarburst;
wire i_system_ddr_rxrready;
wire i_system_ddr_rxrvalid;
wire [(16)-1:0] i_system_ddr_rxrid;
wire [(32)-1:0] i_system_ddr_rxrdata;
wire i_system_ddr_rxrlast;
wire [(2)-1:0] i_system_ddr_rxrresp;
wire i_pll0_external_clk;
wire i_pll0_external_clk_pair;
wire i_pll0_external_rstnn;
wire i_pll0_clk_system;
wire i_pll0_clk_dram_sys;
wire i_pll0_clk_dram_ref;
wire i_system_sram_clk;
wire i_system_sram_rstnn;
wire i_system_sram_rxawready;
wire i_system_sram_rxawvalid;
wire [(32)-1:0] i_system_sram_rxawaddr;
wire [(`REQUIRED_BW_OF_SLAVE_TID)-1:0] i_system_sram_rxawid;
wire [(8)-1:0] i_system_sram_rxawlen;
wire [(3)-1:0] i_system_sram_rxawsize;
wire [(2)-1:0] i_system_sram_rxawburst;
wire i_system_sram_rxwready;
wire i_system_sram_rxwvalid;
wire [(`REQUIRED_BW_OF_SLAVE_TID)-1:0] i_system_sram_rxwid;
wire [(32)-1:0] i_system_sram_rxwdata;
wire [(32/8)-1:0] i_system_sram_rxwstrb;
wire i_system_sram_rxwlast;
wire i_system_sram_rxbready;
wire i_system_sram_rxbvalid;
wire [(`REQUIRED_BW_OF_SLAVE_TID)-1:0] i_system_sram_rxbid;
wire [(2)-1:0] i_system_sram_rxbresp;
wire i_system_sram_rxarready;
wire i_system_sram_rxarvalid;
wire [(32)-1:0] i_system_sram_rxaraddr;
wire [(`REQUIRED_BW_OF_SLAVE_TID)-1:0] i_system_sram_rxarid;
wire [(8)-1:0] i_system_sram_rxarlen;
wire [(3)-1:0] i_system_sram_rxarsize;
wire [(2)-1:0] i_system_sram_rxarburst;
wire i_system_sram_rxrready;
wire i_system_sram_rxrvalid;
wire [(`REQUIRED_BW_OF_SLAVE_TID)-1:0] i_system_sram_rxrid;
wire [(32)-1:0] i_system_sram_rxrdata;
wire i_system_sram_rxrlast;
wire [(2)-1:0] i_system_sram_rxrresp;

TIP_QUANTIZED_CNN_RTL
i_rtl
(
	.clk_system(i_rtl_clk_system),
	.clk_core(i_rtl_clk_core),
	.clk_system_external(i_rtl_clk_system_external),
	.clk_system_debug(i_rtl_clk_system_debug),
	.clk_local_access(i_rtl_clk_local_access),
	.clk_process_000(i_rtl_clk_process_000),
	.clk_dram_if(i_rtl_clk_dram_if),
	.clk_dram_sys(i_rtl_clk_dram_sys),
	.clk_dram_ref(i_rtl_clk_dram_ref),
	.clk_noc(i_rtl_clk_noc),
	.gclk_system(i_rtl_gclk_system),
	.gclk_core(i_rtl_gclk_core),
	.gclk_system_external(i_rtl_gclk_system_external),
	.gclk_system_debug(i_rtl_gclk_system_debug),
	.gclk_local_access(i_rtl_gclk_local_access),
	.gclk_process_000(i_rtl_gclk_process_000),
	.gclk_noc(i_rtl_gclk_noc),
	.tick_1us(i_rtl_tick_1us),
	.tick_62d5ms(i_rtl_tick_62d5ms),
	.tick_gpio(i_rtl_tick_gpio),
	.spi_common_sclk(i_rtl_spi_common_sclk),
	.spi_common_sdq0(i_rtl_spi_common_sdq0),
	.external_rstnn(i_rtl_external_rstnn),
	.global_rstnn(i_rtl_global_rstnn),
	.global_rstpp(i_rtl_global_rstpp),
	.rstnn_seqeunce(i_rtl_rstnn_seqeunce),
	.rstpp_seqeunce(i_rtl_rstpp_seqeunce),
	.rstnn_user(i_rtl_rstnn_user),
	.rstpp_user(i_rtl_rstpp_user),
	.led_list(i_rtl_led_list),
	.i_im2col_clk(i_rtl_i_im2col_clk),
	.i_im2col_rstnn(i_rtl_i_im2col_rstnn),
	.i_gemm_requant_clk(i_rtl_i_gemm_requant_clk),
	.i_gemm_requant_rstnn(i_rtl_i_gemm_requant_rstnn),
	.i_system_ddr_clk_ref(i_rtl_i_system_ddr_clk_ref),
	.i_system_ddr_clk_sys(i_rtl_i_system_ddr_clk_sys),
	.i_system_ddr_rstnn_sys(i_rtl_i_system_ddr_rstnn_sys),
	.i_system_ddr_clk_dram_if(i_rtl_i_system_ddr_clk_dram_if),
	.i_system_ddr_rstnn_dram_if(i_rtl_i_system_ddr_rstnn_dram_if),
	.i_system_ddr_initialized(i_rtl_i_system_ddr_initialized),
	.i_pll0_external_rstnn(i_rtl_i_pll0_external_rstnn),
	.i_pll0_clk_system(i_rtl_i_pll0_clk_system),
	.i_pll0_clk_dram_sys(i_rtl_i_pll0_clk_dram_sys),
	.i_pll0_clk_dram_ref(i_rtl_i_pll0_clk_dram_ref),
	.i_system_sram_clk(i_rtl_i_system_sram_clk),
	.i_system_sram_rstnn(i_rtl_i_system_sram_rstnn),
	.pjtag_rtck(i_rtl_pjtag_rtck),
	.pjtag_rtrstnn(i_rtl_pjtag_rtrstnn),
	.pjtag_rtms(i_rtl_pjtag_rtms),
	.pjtag_rtdi(i_rtl_pjtag_rtdi),
	.pjtag_rtdo(i_rtl_pjtag_rtdo),
	.printf_tx(i_rtl_printf_tx),
	.printf_rx(i_rtl_printf_rx),
	.i_im2col_spsel(i_rtl_i_im2col_spsel),
	.i_im2col_spenable(i_rtl_i_im2col_spenable),
	.i_im2col_spwrite(i_rtl_i_im2col_spwrite),
	.i_im2col_spaddr(i_rtl_i_im2col_spaddr),
	.i_im2col_spwdata(i_rtl_i_im2col_spwdata),
	.i_im2col_spready(i_rtl_i_im2col_spready),
	.i_im2col_sprdata(i_rtl_i_im2col_sprdata),
	.i_im2col_spslverr(i_rtl_i_im2col_spslverr),
	.i_im2col_rxawready(i_rtl_i_im2col_rxawready),
	.i_im2col_rxawvalid(i_rtl_i_im2col_rxawvalid),
	.i_im2col_rxawaddr(i_rtl_i_im2col_rxawaddr),
	.i_im2col_rxawid(i_rtl_i_im2col_rxawid),
	.i_im2col_rxawlen(i_rtl_i_im2col_rxawlen),
	.i_im2col_rxawsize(i_rtl_i_im2col_rxawsize),
	.i_im2col_rxawburst(i_rtl_i_im2col_rxawburst),
	.i_im2col_rxwready(i_rtl_i_im2col_rxwready),
	.i_im2col_rxwvalid(i_rtl_i_im2col_rxwvalid),
	.i_im2col_rxwid(i_rtl_i_im2col_rxwid),
	.i_im2col_rxwdata(i_rtl_i_im2col_rxwdata),
	.i_im2col_rxwstrb(i_rtl_i_im2col_rxwstrb),
	.i_im2col_rxwlast(i_rtl_i_im2col_rxwlast),
	.i_im2col_rxbready(i_rtl_i_im2col_rxbready),
	.i_im2col_rxbvalid(i_rtl_i_im2col_rxbvalid),
	.i_im2col_rxbid(i_rtl_i_im2col_rxbid),
	.i_im2col_rxbresp(i_rtl_i_im2col_rxbresp),
	.i_im2col_rxarready(i_rtl_i_im2col_rxarready),
	.i_im2col_rxarvalid(i_rtl_i_im2col_rxarvalid),
	.i_im2col_rxaraddr(i_rtl_i_im2col_rxaraddr),
	.i_im2col_rxarid(i_rtl_i_im2col_rxarid),
	.i_im2col_rxarlen(i_rtl_i_im2col_rxarlen),
	.i_im2col_rxarsize(i_rtl_i_im2col_rxarsize),
	.i_im2col_rxarburst(i_rtl_i_im2col_rxarburst),
	.i_im2col_rxrready(i_rtl_i_im2col_rxrready),
	.i_im2col_rxrvalid(i_rtl_i_im2col_rxrvalid),
	.i_im2col_rxrid(i_rtl_i_im2col_rxrid),
	.i_im2col_rxrdata(i_rtl_i_im2col_rxrdata),
	.i_im2col_rxrlast(i_rtl_i_im2col_rxrlast),
	.i_im2col_rxrresp(i_rtl_i_im2col_rxrresp),
	.i_gemm_requant_spsel(i_rtl_i_gemm_requant_spsel),
	.i_gemm_requant_spenable(i_rtl_i_gemm_requant_spenable),
	.i_gemm_requant_spwrite(i_rtl_i_gemm_requant_spwrite),
	.i_gemm_requant_spaddr(i_rtl_i_gemm_requant_spaddr),
	.i_gemm_requant_spwdata(i_rtl_i_gemm_requant_spwdata),
	.i_gemm_requant_spready(i_rtl_i_gemm_requant_spready),
	.i_gemm_requant_sprdata(i_rtl_i_gemm_requant_sprdata),
	.i_gemm_requant_spslverr(i_rtl_i_gemm_requant_spslverr),
	.i_gemm_requant_rxawready(i_rtl_i_gemm_requant_rxawready),
	.i_gemm_requant_rxawvalid(i_rtl_i_gemm_requant_rxawvalid),
	.i_gemm_requant_rxawaddr(i_rtl_i_gemm_requant_rxawaddr),
	.i_gemm_requant_rxawid(i_rtl_i_gemm_requant_rxawid),
	.i_gemm_requant_rxawlen(i_rtl_i_gemm_requant_rxawlen),
	.i_gemm_requant_rxawsize(i_rtl_i_gemm_requant_rxawsize),
	.i_gemm_requant_rxawburst(i_rtl_i_gemm_requant_rxawburst),
	.i_gemm_requant_rxwready(i_rtl_i_gemm_requant_rxwready),
	.i_gemm_requant_rxwvalid(i_rtl_i_gemm_requant_rxwvalid),
	.i_gemm_requant_rxwid(i_rtl_i_gemm_requant_rxwid),
	.i_gemm_requant_rxwdata(i_rtl_i_gemm_requant_rxwdata),
	.i_gemm_requant_rxwstrb(i_rtl_i_gemm_requant_rxwstrb),
	.i_gemm_requant_rxwlast(i_rtl_i_gemm_requant_rxwlast),
	.i_gemm_requant_rxbready(i_rtl_i_gemm_requant_rxbready),
	.i_gemm_requant_rxbvalid(i_rtl_i_gemm_requant_rxbvalid),
	.i_gemm_requant_rxbid(i_rtl_i_gemm_requant_rxbid),
	.i_gemm_requant_rxbresp(i_rtl_i_gemm_requant_rxbresp),
	.i_gemm_requant_rxarready(i_rtl_i_gemm_requant_rxarready),
	.i_gemm_requant_rxarvalid(i_rtl_i_gemm_requant_rxarvalid),
	.i_gemm_requant_rxaraddr(i_rtl_i_gemm_requant_rxaraddr),
	.i_gemm_requant_rxarid(i_rtl_i_gemm_requant_rxarid),
	.i_gemm_requant_rxarlen(i_rtl_i_gemm_requant_rxarlen),
	.i_gemm_requant_rxarsize(i_rtl_i_gemm_requant_rxarsize),
	.i_gemm_requant_rxarburst(i_rtl_i_gemm_requant_rxarburst),
	.i_gemm_requant_rxrready(i_rtl_i_gemm_requant_rxrready),
	.i_gemm_requant_rxrvalid(i_rtl_i_gemm_requant_rxrvalid),
	.i_gemm_requant_rxrid(i_rtl_i_gemm_requant_rxrid),
	.i_gemm_requant_rxrdata(i_rtl_i_gemm_requant_rxrdata),
	.i_gemm_requant_rxrlast(i_rtl_i_gemm_requant_rxrlast),
	.i_gemm_requant_rxrresp(i_rtl_i_gemm_requant_rxrresp),
	.i_system_ddr_sxawready(i_rtl_i_system_ddr_sxawready),
	.i_system_ddr_sxawvalid(i_rtl_i_system_ddr_sxawvalid),
	.i_system_ddr_sxawaddr(i_rtl_i_system_ddr_sxawaddr),
	.i_system_ddr_sxawid(i_rtl_i_system_ddr_sxawid),
	.i_system_ddr_sxawlen(i_rtl_i_system_ddr_sxawlen),
	.i_system_ddr_sxawsize(i_rtl_i_system_ddr_sxawsize),
	.i_system_ddr_sxawburst(i_rtl_i_system_ddr_sxawburst),
	.i_system_ddr_sxwready(i_rtl_i_system_ddr_sxwready),
	.i_system_ddr_sxwvalid(i_rtl_i_system_ddr_sxwvalid),
	.i_system_ddr_sxwid(i_rtl_i_system_ddr_sxwid),
	.i_system_ddr_sxwdata(i_rtl_i_system_ddr_sxwdata),
	.i_system_ddr_sxwstrb(i_rtl_i_system_ddr_sxwstrb),
	.i_system_ddr_sxwlast(i_rtl_i_system_ddr_sxwlast),
	.i_system_ddr_sxbready(i_rtl_i_system_ddr_sxbready),
	.i_system_ddr_sxbvalid(i_rtl_i_system_ddr_sxbvalid),
	.i_system_ddr_sxbid(i_rtl_i_system_ddr_sxbid),
	.i_system_ddr_sxbresp(i_rtl_i_system_ddr_sxbresp),
	.i_system_ddr_sxarready(i_rtl_i_system_ddr_sxarready),
	.i_system_ddr_sxarvalid(i_rtl_i_system_ddr_sxarvalid),
	.i_system_ddr_sxaraddr(i_rtl_i_system_ddr_sxaraddr),
	.i_system_ddr_sxarid(i_rtl_i_system_ddr_sxarid),
	.i_system_ddr_sxarlen(i_rtl_i_system_ddr_sxarlen),
	.i_system_ddr_sxarsize(i_rtl_i_system_ddr_sxarsize),
	.i_system_ddr_sxarburst(i_rtl_i_system_ddr_sxarburst),
	.i_system_ddr_sxrready(i_rtl_i_system_ddr_sxrready),
	.i_system_ddr_sxrvalid(i_rtl_i_system_ddr_sxrvalid),
	.i_system_ddr_sxrid(i_rtl_i_system_ddr_sxrid),
	.i_system_ddr_sxrdata(i_rtl_i_system_ddr_sxrdata),
	.i_system_ddr_sxrlast(i_rtl_i_system_ddr_sxrlast),
	.i_system_ddr_sxrresp(i_rtl_i_system_ddr_sxrresp),
	.i_system_sram_sxawready(i_rtl_i_system_sram_sxawready),
	.i_system_sram_sxawvalid(i_rtl_i_system_sram_sxawvalid),
	.i_system_sram_sxawaddr(i_rtl_i_system_sram_sxawaddr),
	.i_system_sram_sxawid(i_rtl_i_system_sram_sxawid),
	.i_system_sram_sxawlen(i_rtl_i_system_sram_sxawlen),
	.i_system_sram_sxawsize(i_rtl_i_system_sram_sxawsize),
	.i_system_sram_sxawburst(i_rtl_i_system_sram_sxawburst),
	.i_system_sram_sxwready(i_rtl_i_system_sram_sxwready),
	.i_system_sram_sxwvalid(i_rtl_i_system_sram_sxwvalid),
	.i_system_sram_sxwid(i_rtl_i_system_sram_sxwid),
	.i_system_sram_sxwdata(i_rtl_i_system_sram_sxwdata),
	.i_system_sram_sxwstrb(i_rtl_i_system_sram_sxwstrb),
	.i_system_sram_sxwlast(i_rtl_i_system_sram_sxwlast),
	.i_system_sram_sxbready(i_rtl_i_system_sram_sxbready),
	.i_system_sram_sxbvalid(i_rtl_i_system_sram_sxbvalid),
	.i_system_sram_sxbid(i_rtl_i_system_sram_sxbid),
	.i_system_sram_sxbresp(i_rtl_i_system_sram_sxbresp),
	.i_system_sram_sxarready(i_rtl_i_system_sram_sxarready),
	.i_system_sram_sxarvalid(i_rtl_i_system_sram_sxarvalid),
	.i_system_sram_sxaraddr(i_rtl_i_system_sram_sxaraddr),
	.i_system_sram_sxarid(i_rtl_i_system_sram_sxarid),
	.i_system_sram_sxarlen(i_rtl_i_system_sram_sxarlen),
	.i_system_sram_sxarsize(i_rtl_i_system_sram_sxarsize),
	.i_system_sram_sxarburst(i_rtl_i_system_sram_sxarburst),
	.i_system_sram_sxrready(i_rtl_i_system_sram_sxrready),
	.i_system_sram_sxrvalid(i_rtl_i_system_sram_sxrvalid),
	.i_system_sram_sxrid(i_rtl_i_system_sram_sxrid),
	.i_system_sram_sxrdata(i_rtl_i_system_sram_sxrdata),
	.i_system_sram_sxrlast(i_rtl_i_system_sram_sxrlast),
	.i_system_sram_sxrresp(i_rtl_i_system_sram_sxrresp)
);

TIP_QUANTIZED_CNN_SLOW_DRAM_00
i_system_ddr
(
	.clk_ref(i_system_ddr_clk_ref),
	.clk_sys(i_system_ddr_clk_sys),
	.rstnn_sys(i_system_ddr_rstnn_sys),
	.clk_dram_if(i_system_ddr_clk_dram_if),
	.rstnn_dram_if(i_system_ddr_rstnn_dram_if),
	.initialized(i_system_ddr_initialized),
	.rxawready(i_system_ddr_rxawready),
	.rxawvalid(i_system_ddr_rxawvalid),
	.rxawaddr(i_system_ddr_rxawaddr),
	.rxawid(i_system_ddr_rxawid),
	.rxawlen(i_system_ddr_rxawlen),
	.rxawsize(i_system_ddr_rxawsize),
	.rxawburst(i_system_ddr_rxawburst),
	.rxwready(i_system_ddr_rxwready),
	.rxwvalid(i_system_ddr_rxwvalid),
	.rxwid(i_system_ddr_rxwid),
	.rxwdata(i_system_ddr_rxwdata),
	.rxwstrb(i_system_ddr_rxwstrb),
	.rxwlast(i_system_ddr_rxwlast),
	.rxbready(i_system_ddr_rxbready),
	.rxbvalid(i_system_ddr_rxbvalid),
	.rxbid(i_system_ddr_rxbid),
	.rxbresp(i_system_ddr_rxbresp),
	.rxarready(i_system_ddr_rxarready),
	.rxarvalid(i_system_ddr_rxarvalid),
	.rxaraddr(i_system_ddr_rxaraddr),
	.rxarid(i_system_ddr_rxarid),
	.rxarlen(i_system_ddr_rxarlen),
	.rxarsize(i_system_ddr_rxarsize),
	.rxarburst(i_system_ddr_rxarburst),
	.rxrready(i_system_ddr_rxrready),
	.rxrvalid(i_system_ddr_rxrvalid),
	.rxrid(i_system_ddr_rxrid),
	.rxrdata(i_system_ddr_rxrdata),
	.rxrlast(i_system_ddr_rxrlast),
	.rxrresp(i_system_ddr_rxrresp)
	`include "slow_dram_cell_port_mapping.vh"
);

TIP_QUANTIZED_CNN_CLOCK_PLL_0_01
i_pll0
(
	.external_clk(i_pll0_external_clk),
	.external_clk_pair(i_pll0_external_clk_pair),
	.external_rstnn(i_pll0_external_rstnn),
	.clk_system(i_pll0_clk_system),
	.clk_dram_sys(i_pll0_clk_dram_sys),
	.clk_dram_ref(i_pll0_clk_dram_ref)
);

TIP_QUANTIZED_CNN_SRAM_AXI_02
i_system_sram
(
	.clk(i_system_sram_clk),
	.rstnn(i_system_sram_rstnn),
	.rxawready(i_system_sram_rxawready),
	.rxawvalid(i_system_sram_rxawvalid),
	.rxawaddr(i_system_sram_rxawaddr),
	.rxawid(i_system_sram_rxawid),
	.rxawlen(i_system_sram_rxawlen),
	.rxawsize(i_system_sram_rxawsize),
	.rxawburst(i_system_sram_rxawburst),
	.rxwready(i_system_sram_rxwready),
	.rxwvalid(i_system_sram_rxwvalid),
	.rxwid(i_system_sram_rxwid),
	.rxwdata(i_system_sram_rxwdata),
	.rxwstrb(i_system_sram_rxwstrb),
	.rxwlast(i_system_sram_rxwlast),
	.rxbready(i_system_sram_rxbready),
	.rxbvalid(i_system_sram_rxbvalid),
	.rxbid(i_system_sram_rxbid),
	.rxbresp(i_system_sram_rxbresp),
	.rxarready(i_system_sram_rxarready),
	.rxarvalid(i_system_sram_rxarvalid),
	.rxaraddr(i_system_sram_rxaraddr),
	.rxarid(i_system_sram_rxarid),
	.rxarlen(i_system_sram_rxarlen),
	.rxarsize(i_system_sram_rxarsize),
	.rxarburst(i_system_sram_rxarburst),
	.rxrready(i_system_sram_rxrready),
	.rxrvalid(i_system_sram_rxrvalid),
	.rxrid(i_system_sram_rxrid),
	.rxrdata(i_system_sram_rxrdata),
	.rxrlast(i_system_sram_rxrlast),
	.rxrresp(i_system_sram_rxrresp)
);

assign i_rtl_external_rstnn = external_rstnn;
assign i_im2col_clk = i_rtl_i_im2col_clk;
assign i_im2col_rstnn = i_rtl_i_im2col_rstnn;
assign i_gemm_requant_clk = i_rtl_i_gemm_requant_clk;
assign i_gemm_requant_rstnn = i_rtl_i_gemm_requant_rstnn;
assign i_system_ddr_clk_ref = i_rtl_i_system_ddr_clk_ref;
assign i_system_ddr_clk_sys = i_rtl_i_system_ddr_clk_sys;
assign i_system_ddr_rstnn_sys = i_rtl_i_system_ddr_rstnn_sys;
assign i_rtl_i_system_ddr_clk_dram_if = i_system_ddr_clk_dram_if;
assign i_system_ddr_rstnn_dram_if = i_rtl_i_system_ddr_rstnn_dram_if;
assign i_rtl_i_system_ddr_initialized = i_system_ddr_initialized;
assign i_pll0_external_clk = external_clk_0;
assign i_pll0_external_clk_pair = external_clk_0_pair;
assign i_pll0_external_rstnn = i_rtl_i_pll0_external_rstnn;
assign i_rtl_i_pll0_clk_system = i_pll0_clk_system;
assign i_rtl_i_pll0_clk_dram_sys = i_pll0_clk_dram_sys;
assign i_rtl_i_pll0_clk_dram_ref = i_pll0_clk_dram_ref;
assign i_system_sram_clk = i_rtl_i_system_sram_clk;
assign i_system_sram_rstnn = i_rtl_i_system_sram_rstnn;
assign clk_system = i_rtl_clk_system;
assign clk_core = i_rtl_clk_core;
assign clk_system_external = i_rtl_clk_system_external;
assign clk_system_debug = i_rtl_clk_system_debug;
assign clk_local_access = i_rtl_clk_local_access;
assign clk_process_000 = i_rtl_clk_process_000;
assign clk_dram_if = i_rtl_clk_dram_if;
assign clk_dram_sys = i_rtl_clk_dram_sys;
assign clk_dram_ref = i_rtl_clk_dram_ref;
assign clk_noc = i_rtl_clk_noc;
assign gclk_system = i_rtl_gclk_system;
assign gclk_core = i_rtl_gclk_core;
assign gclk_system_external = i_rtl_gclk_system_external;
assign gclk_system_debug = i_rtl_gclk_system_debug;
assign gclk_local_access = i_rtl_gclk_local_access;
assign gclk_process_000 = i_rtl_gclk_process_000;
assign gclk_noc = i_rtl_gclk_noc;
assign tick_1us = i_rtl_tick_1us;
assign tick_62d5ms = i_rtl_tick_62d5ms;
assign tick_gpio = i_rtl_tick_gpio;
assign spi_common_sclk = i_rtl_spi_common_sclk;
assign spi_common_sdq0 = i_rtl_spi_common_sdq0;
assign global_rstnn = i_rtl_global_rstnn;
assign global_rstpp = i_rtl_global_rstpp;
assign rstnn_seqeunce = i_rtl_rstnn_seqeunce;
assign rstpp_seqeunce = i_rtl_rstpp_seqeunce;
assign rstnn_user = i_rtl_rstnn_user;
assign rstpp_user = i_rtl_rstpp_user;
assign led_list[1*(0+1)-1 -:1] = i_rtl_led_list[1*(0+1)-1 -:1];
assign i_rtl_pjtag_rtck = pjtag_rtck;
assign i_rtl_pjtag_rtrstnn = pjtag_rtrstnn;
assign i_rtl_pjtag_rtms = pjtag_rtms;
assign i_rtl_pjtag_rtdi = pjtag_rtdi;
assign pjtag_rtdo = i_rtl_pjtag_rtdo;
assign printf_tx = i_rtl_printf_tx;
assign i_rtl_printf_rx = printf_rx;
assign i_im2col_rpsel = i_rtl_i_im2col_spsel;
assign i_im2col_rpenable = i_rtl_i_im2col_spenable;
assign i_im2col_rpwrite = i_rtl_i_im2col_spwrite;
assign i_im2col_rpaddr = i_rtl_i_im2col_spaddr;
assign i_im2col_rpwdata = i_rtl_i_im2col_spwdata;
assign i_rtl_i_im2col_spready = i_im2col_rpready;
assign i_rtl_i_im2col_sprdata = i_im2col_rprdata;
assign i_rtl_i_im2col_spslverr = i_im2col_rpslverr;
assign i_im2col_sxawready = i_rtl_i_im2col_rxawready;
assign i_rtl_i_im2col_rxawvalid = i_im2col_sxawvalid;
assign i_rtl_i_im2col_rxawaddr = i_im2col_sxawaddr;
assign i_rtl_i_im2col_rxawid = i_im2col_sxawid;
assign i_rtl_i_im2col_rxawlen = i_im2col_sxawlen;
assign i_rtl_i_im2col_rxawsize = i_im2col_sxawsize;
assign i_rtl_i_im2col_rxawburst = i_im2col_sxawburst;
assign i_im2col_sxwready = i_rtl_i_im2col_rxwready;
assign i_rtl_i_im2col_rxwvalid = i_im2col_sxwvalid;
assign i_rtl_i_im2col_rxwid = i_im2col_sxwid;
assign i_rtl_i_im2col_rxwdata = i_im2col_sxwdata;
assign i_rtl_i_im2col_rxwstrb = i_im2col_sxwstrb;
assign i_rtl_i_im2col_rxwlast = i_im2col_sxwlast;
assign i_rtl_i_im2col_rxbready = i_im2col_sxbready;
assign i_im2col_sxbvalid = i_rtl_i_im2col_rxbvalid;
assign i_im2col_sxbid = i_rtl_i_im2col_rxbid;
assign i_im2col_sxbresp = i_rtl_i_im2col_rxbresp;
assign i_im2col_sxarready = i_rtl_i_im2col_rxarready;
assign i_rtl_i_im2col_rxarvalid = i_im2col_sxarvalid;
assign i_rtl_i_im2col_rxaraddr = i_im2col_sxaraddr;
assign i_rtl_i_im2col_rxarid = i_im2col_sxarid;
assign i_rtl_i_im2col_rxarlen = i_im2col_sxarlen;
assign i_rtl_i_im2col_rxarsize = i_im2col_sxarsize;
assign i_rtl_i_im2col_rxarburst = i_im2col_sxarburst;
assign i_rtl_i_im2col_rxrready = i_im2col_sxrready;
assign i_im2col_sxrvalid = i_rtl_i_im2col_rxrvalid;
assign i_im2col_sxrid = i_rtl_i_im2col_rxrid;
assign i_im2col_sxrdata = i_rtl_i_im2col_rxrdata;
assign i_im2col_sxrlast = i_rtl_i_im2col_rxrlast;
assign i_im2col_sxrresp = i_rtl_i_im2col_rxrresp;
assign i_gemm_requant_rpsel = i_rtl_i_gemm_requant_spsel;
assign i_gemm_requant_rpenable = i_rtl_i_gemm_requant_spenable;
assign i_gemm_requant_rpwrite = i_rtl_i_gemm_requant_spwrite;
assign i_gemm_requant_rpaddr = i_rtl_i_gemm_requant_spaddr;
assign i_gemm_requant_rpwdata = i_rtl_i_gemm_requant_spwdata;
assign i_rtl_i_gemm_requant_spready = i_gemm_requant_rpready;
assign i_rtl_i_gemm_requant_sprdata = i_gemm_requant_rprdata;
assign i_rtl_i_gemm_requant_spslverr = i_gemm_requant_rpslverr;
assign i_gemm_requant_sxawready = i_rtl_i_gemm_requant_rxawready;
assign i_rtl_i_gemm_requant_rxawvalid = i_gemm_requant_sxawvalid;
assign i_rtl_i_gemm_requant_rxawaddr = i_gemm_requant_sxawaddr;
assign i_rtl_i_gemm_requant_rxawid = i_gemm_requant_sxawid;
assign i_rtl_i_gemm_requant_rxawlen = i_gemm_requant_sxawlen;
assign i_rtl_i_gemm_requant_rxawsize = i_gemm_requant_sxawsize;
assign i_rtl_i_gemm_requant_rxawburst = i_gemm_requant_sxawburst;
assign i_gemm_requant_sxwready = i_rtl_i_gemm_requant_rxwready;
assign i_rtl_i_gemm_requant_rxwvalid = i_gemm_requant_sxwvalid;
assign i_rtl_i_gemm_requant_rxwid = i_gemm_requant_sxwid;
assign i_rtl_i_gemm_requant_rxwdata = i_gemm_requant_sxwdata;
assign i_rtl_i_gemm_requant_rxwstrb = i_gemm_requant_sxwstrb;
assign i_rtl_i_gemm_requant_rxwlast = i_gemm_requant_sxwlast;
assign i_rtl_i_gemm_requant_rxbready = i_gemm_requant_sxbready;
assign i_gemm_requant_sxbvalid = i_rtl_i_gemm_requant_rxbvalid;
assign i_gemm_requant_sxbid = i_rtl_i_gemm_requant_rxbid;
assign i_gemm_requant_sxbresp = i_rtl_i_gemm_requant_rxbresp;
assign i_gemm_requant_sxarready = i_rtl_i_gemm_requant_rxarready;
assign i_rtl_i_gemm_requant_rxarvalid = i_gemm_requant_sxarvalid;
assign i_rtl_i_gemm_requant_rxaraddr = i_gemm_requant_sxaraddr;
assign i_rtl_i_gemm_requant_rxarid = i_gemm_requant_sxarid;
assign i_rtl_i_gemm_requant_rxarlen = i_gemm_requant_sxarlen;
assign i_rtl_i_gemm_requant_rxarsize = i_gemm_requant_sxarsize;
assign i_rtl_i_gemm_requant_rxarburst = i_gemm_requant_sxarburst;
assign i_rtl_i_gemm_requant_rxrready = i_gemm_requant_sxrready;
assign i_gemm_requant_sxrvalid = i_rtl_i_gemm_requant_rxrvalid;
assign i_gemm_requant_sxrid = i_rtl_i_gemm_requant_rxrid;
assign i_gemm_requant_sxrdata = i_rtl_i_gemm_requant_rxrdata;
assign i_gemm_requant_sxrlast = i_rtl_i_gemm_requant_rxrlast;
assign i_gemm_requant_sxrresp = i_rtl_i_gemm_requant_rxrresp;
assign i_rtl_i_system_ddr_sxawready = i_system_ddr_rxawready;
assign i_system_ddr_rxawvalid = i_rtl_i_system_ddr_sxawvalid;
assign i_system_ddr_rxawaddr = i_rtl_i_system_ddr_sxawaddr;
assign i_system_ddr_rxawid = i_rtl_i_system_ddr_sxawid;
assign i_system_ddr_rxawlen = i_rtl_i_system_ddr_sxawlen;
assign i_system_ddr_rxawsize = i_rtl_i_system_ddr_sxawsize;
assign i_system_ddr_rxawburst = i_rtl_i_system_ddr_sxawburst;
assign i_rtl_i_system_ddr_sxwready = i_system_ddr_rxwready;
assign i_system_ddr_rxwvalid = i_rtl_i_system_ddr_sxwvalid;
assign i_system_ddr_rxwid = i_rtl_i_system_ddr_sxwid;
assign i_system_ddr_rxwdata = i_rtl_i_system_ddr_sxwdata;
assign i_system_ddr_rxwstrb = i_rtl_i_system_ddr_sxwstrb;
assign i_system_ddr_rxwlast = i_rtl_i_system_ddr_sxwlast;
assign i_system_ddr_rxbready = i_rtl_i_system_ddr_sxbready;
assign i_rtl_i_system_ddr_sxbvalid = i_system_ddr_rxbvalid;
assign i_rtl_i_system_ddr_sxbid = i_system_ddr_rxbid;
assign i_rtl_i_system_ddr_sxbresp = i_system_ddr_rxbresp;
assign i_rtl_i_system_ddr_sxarready = i_system_ddr_rxarready;
assign i_system_ddr_rxarvalid = i_rtl_i_system_ddr_sxarvalid;
assign i_system_ddr_rxaraddr = i_rtl_i_system_ddr_sxaraddr;
assign i_system_ddr_rxarid = i_rtl_i_system_ddr_sxarid;
assign i_system_ddr_rxarlen = i_rtl_i_system_ddr_sxarlen;
assign i_system_ddr_rxarsize = i_rtl_i_system_ddr_sxarsize;
assign i_system_ddr_rxarburst = i_rtl_i_system_ddr_sxarburst;
assign i_system_ddr_rxrready = i_rtl_i_system_ddr_sxrready;
assign i_rtl_i_system_ddr_sxrvalid = i_system_ddr_rxrvalid;
assign i_rtl_i_system_ddr_sxrid = i_system_ddr_rxrid;
assign i_rtl_i_system_ddr_sxrdata = i_system_ddr_rxrdata;
assign i_rtl_i_system_ddr_sxrlast = i_system_ddr_rxrlast;
assign i_rtl_i_system_ddr_sxrresp = i_system_ddr_rxrresp;
assign i_rtl_i_system_sram_sxawready = i_system_sram_rxawready;
assign i_system_sram_rxawvalid = i_rtl_i_system_sram_sxawvalid;
assign i_system_sram_rxawaddr = i_rtl_i_system_sram_sxawaddr;
assign i_system_sram_rxawid = i_rtl_i_system_sram_sxawid;
assign i_system_sram_rxawlen = i_rtl_i_system_sram_sxawlen;
assign i_system_sram_rxawsize = i_rtl_i_system_sram_sxawsize;
assign i_system_sram_rxawburst = i_rtl_i_system_sram_sxawburst;
assign i_rtl_i_system_sram_sxwready = i_system_sram_rxwready;
assign i_system_sram_rxwvalid = i_rtl_i_system_sram_sxwvalid;
assign i_system_sram_rxwid = i_rtl_i_system_sram_sxwid;
assign i_system_sram_rxwdata = i_rtl_i_system_sram_sxwdata;
assign i_system_sram_rxwstrb = i_rtl_i_system_sram_sxwstrb;
assign i_system_sram_rxwlast = i_rtl_i_system_sram_sxwlast;
assign i_system_sram_rxbready = i_rtl_i_system_sram_sxbready;
assign i_rtl_i_system_sram_sxbvalid = i_system_sram_rxbvalid;
assign i_rtl_i_system_sram_sxbid = i_system_sram_rxbid;
assign i_rtl_i_system_sram_sxbresp = i_system_sram_rxbresp;
assign i_rtl_i_system_sram_sxarready = i_system_sram_rxarready;
assign i_system_sram_rxarvalid = i_rtl_i_system_sram_sxarvalid;
assign i_system_sram_rxaraddr = i_rtl_i_system_sram_sxaraddr;
assign i_system_sram_rxarid = i_rtl_i_system_sram_sxarid;
assign i_system_sram_rxarlen = i_rtl_i_system_sram_sxarlen;
assign i_system_sram_rxarsize = i_rtl_i_system_sram_sxarsize;
assign i_system_sram_rxarburst = i_rtl_i_system_sram_sxarburst;
assign i_system_sram_rxrready = i_rtl_i_system_sram_sxrready;
assign i_rtl_i_system_sram_sxrvalid = i_system_sram_rxrvalid;
assign i_rtl_i_system_sram_sxrid = i_system_sram_rxrid;
assign i_rtl_i_system_sram_sxrdata = i_system_sram_rxrdata;
assign i_rtl_i_system_sram_sxrlast = i_system_sram_rxrlast;
assign i_rtl_i_system_sram_sxrresp = i_system_sram_rxrresp;

`include "tip_quantized_cnn_user_region.vh"

`ifdef USE_ILA
`include "ila_description.vh"
`endif

endmodule