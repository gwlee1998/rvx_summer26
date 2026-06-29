// ****************************************************************************
// tb_im2col_compute.v - STEP 2 standalone self-checking testbench (PROVIDED)
// Exercises USER_IM2COL_COMPUTE ALONE (no engine, no AXI/DMA): drives the frozen
// seam directly through two USER_BRAM models.  Two cases:
//   1) real conv2 im2col (C=6 12x12, k5 -> 8x8)   -- golden from the numpy reference
//   2) a small synthetic geometry (C=2 4x4, k3 -> 2x2, in_zp=7)
// Self-checking: byte-exact compare vs golden, prints PASS/FAIL + first mismatch.
// A skeleton (blank) DUT never raises end_flag -> the run TIMES OUT and FAILs.
//
// DEBUG_DUMP (compile with +define+DEBUG_DUMP, default OFF): writes the produced
// matrix and the golden matrix side by side to im2col_dump.txt so you can see which
// (row,col) diverges.  Limit the dump with +dump_lo=<byte> +dump_hi=<byte> plusargs.
//
// Run (from step2/tb):  see step2/README.md  (run_tb.sh im2col answer | skeleton)
// ****************************************************************************
`timescale 1ns/1ps
`ifndef GDIR
 `define GDIR "golden/"
`endif
`include "tb_vectors.vh"

module tb_im2col_compute;

    localparam BW_INDEX = 13;

    reg                  clk = 1'b0;
    reg                  rstnn = 1'b0;
    reg                  start = 1'b0;
    wire                 end_flag;
    // geometry config
    reg [31:0] in_h, in_w, in_c, k_h, k_w, pad_h, pad_w, stride_h, stride_w, dil_h, dil_w, out_h, out_w, in_zp;
    // DUT <-> input BRAM read port
    wire [BW_INDEX-1:0]  in_bram_rindex;
    wire                 in_bram_ren;
    wire [31:0]          in_bram_rdata;
    // DUT <-> output BRAM write port
    wire [BW_INDEX-1:0]  out_bram_windex;
    wire [3:0]           out_bram_wbe;
    wire [31:0]          out_bram_wdata;
    wire                 out_bram_wen;
    // TB-driven input-BRAM write (preload) + output-BRAM read (check)
    reg [BW_INDEX-1:0]   pl_windex;
    reg                  pl_wen;
    reg [31:0]           pl_wdata;
    reg [BW_INDEX-1:0]   ck_rindex;
    reg                  ck_ren;
    wire [31:0]          ck_rdata;

    integer total_fail = 0;

    always #5 clk = ~clk;   // 100 MHz

    // input BRAM: write = TB preload, read = DUT
    USER_BRAM #(.DEPTH(8192), .AW(BW_INDEX))
    i_in_bram
    (
        .clk    (clk),
        .windex (pl_windex),
        .wen    (pl_wen),
        .wbe    (4'hF),
        .wdata  (pl_wdata),
        .rindex (in_bram_rindex),
        .ren    (in_bram_ren),
        .rdata  (in_bram_rdata)
    );
    // output BRAM: write = DUT, read = TB check
    USER_BRAM #(.DEPTH(8192), .AW(BW_INDEX))
    i_out_bram
    (
        .clk    (clk),
        .windex (out_bram_windex),
        .wen    (out_bram_wen),
        .wbe    (out_bram_wbe),
        .wdata  (out_bram_wdata),
        .rindex (ck_rindex),
        .ren    (ck_ren),
        .rdata  (ck_rdata)
    );

    USER_IM2COL_COMPUTE #(.BW_INDEX(BW_INDEX))
    dut
    (
        .clk             (clk),
        .rstnn           (rstnn),
        .start           (start),
        .end_flag        (end_flag),
        .src_ready       (1'b1),
        .dst_ready       (1'b1),
        .in_h            (in_h),
        .in_w            (in_w),
        .in_c            (in_c),
        .k_h             (k_h),
        .k_w             (k_w),
        .pad_h           (pad_h),
        .pad_w           (pad_w),
        .stride_h        (stride_h),
        .stride_w        (stride_w),
        .dil_h           (dil_h),
        .dil_w           (dil_w),
        .out_h           (out_h),
        .out_w           (out_w),
        .in_zp           (in_zp),
        .in_bram_rindex  (in_bram_rindex),
        .in_bram_ren     (in_bram_ren),
        .in_bram_rdata   (in_bram_rdata),
        .out_bram_windex (out_bram_windex),
        .out_bram_wbe    (out_bram_wbe),
        .out_bram_wdata  (out_bram_wdata),
        .out_bram_wen    (out_bram_wen)
    );

    reg [31:0] inmem [0:1023];
    reg [31:0] gold  [0:4095];

    // preload input BRAM words [0..nwords-1] from inmem via the write port
    task preload(input integer nwords);
        integer i;
        begin
            @(negedge clk);
            for (i = 0; i < nwords; i = i + 1) begin
                pl_windex = i[BW_INDEX-1:0];
                pl_wdata  = inmem[i];
                pl_wen    = 1'b1;
                @(negedge clk);
            end
            pl_wen = 1'b0;
        end
    endtask

    // reset, pulse start, wait for end_flag (timeout -> blank DUT -> FAIL)
    task run_dut;
        integer t;
        begin
            rstnn = 1'b0; @(negedge clk); @(negedge clk);
            rstnn = 1'b1; @(negedge clk);
            start = 1'b1; @(negedge clk); start = 1'b0;
            t = 0;
            while (end_flag !== 1'b1 && t < 300000) begin @(negedge clk); t = t + 1; end
            if (t >= 300000) $display("  [TIMEOUT] end_flag never asserted (blank/incomplete DUT)");
        end
    endtask

    // compare output BRAM words [0..nwords-1] vs gold; byte-exact over nbytes
    task check(input [255:0] name, input integer nwords, input integer nbytes);
        integer i, b, g, e, mism, fi;
        reg [31:0] rw, gw;
        begin
            mism = 0; fi = -1;
            for (i = 0; i < nwords; i = i + 1) begin
                ck_rindex = i[BW_INDEX-1:0]; ck_ren = 1'b1;
                @(posedge clk); @(posedge clk); #1;   // registered-read latency margin
                rw = ck_rdata; gw = gold[i];
                for (b = 0; b < 4; b = b + 1) begin
                    if (i*4 + b < nbytes) begin
                        g = (rw >> (8*b)) & 32'hff;
                        e = (gw >> (8*b)) & 32'hff;
                        if (g !== e) begin
                            mism = mism + 1;
                            if (fi < 0) begin fi = i*4 + b; $display("  %0s first mismatch: byte=%0d got=%0d exp=%0d", name, fi, g, e); end
                        end
                    end
                end
            end
            ck_ren = 1'b0;
            if (mism == 0) $display("  %0s PASS (%0d bytes byte-exact)", name, nbytes);
            else begin $display("  %0s FAIL mism=%0d", name, mism); total_fail = total_fail + 1; end
`ifdef DEBUG_DUMP
            dump_side_by_side(name, nbytes);
`endif
        end
    endtask

`ifdef DEBUG_DUMP
    // dump produced vs golden bytes (optionally a [dump_lo,dump_hi] range) to a file
    task dump_side_by_side(input [255:0] name, input integer nbytes);
        integer fd, i, lo, hi, gi, gj, rc;
        reg [31:0] rw, gw;
        begin
            lo = 0; hi = nbytes - 1;
            rc = $value$plusargs("dump_lo=%d", lo);
            rc = $value$plusargs("dump_hi=%d", hi);
            fd = $fopen("im2col_dump.txt", "w");
            $fdisplay(fd, "# %0s  byte : produced golden", name);
            for (i = lo; i <= hi && i < nbytes; i = i + 1) begin
                ck_rindex = (i>>2); ck_ren = 1'b1; @(posedge clk); @(posedge clk); #1; rw = ck_rdata; ck_ren = 1'b0;
                gw = gold[i>>2];
                gi = (rw >> (8*(i&3))) & 32'hff;
                gj = (gw >> (8*(i&3))) & 32'hff;
                $fdisplay(fd, "%0d : %0d %0d %s", i, gi, gj, (gi===gj)?"":"  <-- DIFF");
            end
            $fclose(fd);
            $display("  [DEBUG_DUMP] wrote im2col_dump.txt bytes [%0d..%0d]", lo, hi);
        end
    endtask
`endif

    initial begin
        pl_windex = 0; pl_wen = 0; pl_wdata = 0; ck_rindex = 0; ck_ren = 0;
        pad_h = 0; pad_w = 0; stride_h = 1; stride_w = 1; dil_h = 1; dil_w = 1;

        // ---------- case 1: real conv2 im2col ----------
        $display("[tb_im2col_compute] case 1: conv2 im2col (C=%0d %0dx%0d k%0d -> %0dx%0d)",
                 `IM2COL_INC, `IM2COL_INH, `IM2COL_INW, `IM2COL_K, `IM2COL_OUTH, `IM2COL_OUTW);
        $readmemh({`GDIR, "im2col_in.memh"},   inmem);
        $readmemh({`GDIR, "im2col_gold.memh"}, gold);
        in_c = `IM2COL_INC; in_h = `IM2COL_INH; in_w = `IM2COL_INW;
        k_h  = `IM2COL_K;   k_w  = `IM2COL_K;
        out_h = `IM2COL_OUTH; out_w = `IM2COL_OUTW; in_zp = `IM2COL_INZP;
        preload(`IM2COL_IN_WORDS);
        run_dut;
        check("conv2_im2col", `IM2COL_GOLD_WORDS, `IM2COL_KROWS * `IM2COL_NCOLS);

        // ---------- case 2: synthetic geometry ----------
        $display("[tb_im2col_compute] case 2: synthetic (C=%0d %0dx%0d k%0d -> %0dx%0d in_zp=%0d)",
                 `IM2COL_SYN_INC, `IM2COL_SYN_INH, `IM2COL_SYN_INW, `IM2COL_SYN_K,
                 `IM2COL_SYN_OUTH, `IM2COL_SYN_OUTW, `IM2COL_SYN_INZP);
        $readmemh({`GDIR, "im2col_syn_in.memh"},   inmem);
        $readmemh({`GDIR, "im2col_syn_gold.memh"}, gold);
        in_c = `IM2COL_SYN_INC; in_h = `IM2COL_SYN_INH; in_w = `IM2COL_SYN_INW;
        k_h  = `IM2COL_SYN_K;   k_w  = `IM2COL_SYN_K;
        out_h = `IM2COL_SYN_OUTH; out_w = `IM2COL_SYN_OUTW; in_zp = `IM2COL_SYN_INZP;
        preload(`IM2COL_SYN_IN_WORDS);
        run_dut;
        check("synth_im2col", `IM2COL_SYN_GOLD_WORDS, `IM2COL_SYN_KROWS * `IM2COL_SYN_NCOLS);

        if (total_fail == 0) $display("TB_IM2COL_COMPUTE: ALL_PASS");
        else                 $display("TB_IM2COL_COMPUTE: FAIL (%0d case(s))", total_fail);
        $finish;
    end
endmodule
