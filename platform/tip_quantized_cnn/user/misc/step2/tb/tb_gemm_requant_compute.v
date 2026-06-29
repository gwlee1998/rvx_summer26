// ****************************************************************************
// tb_gemm_requant_compute.v - STEP 2 standalone self-checking testbench (PROVIDED)
// Exercises USER_GEMM_REQUANT_COMPUTE ALONE together with the PROVIDED
// USER_GEMM_CORE + USER_MAC_ARRAY (no engine, no AXI/DMA).  The input BRAM is
// preloaded with the exact [im2col/vec | weights/W^T | param-blob] image the engine's
// DMA would build; the DUT requantizes into the output BRAM.  Cases:
//   1) conv2 gemm_nn tile  (M=16 K=150 N=64)        -- golden = numpy reference
//   2) fc1   gemm_nt tile  (K=256, 120 features)    -- golden = numpy reference
//   3) negative control    (corrupt one M0 word -> output MUST change)
// Self-checking: byte-exact compare vs golden, PASS/FAIL + first mismatch.  A blank
// DUT never raises done -> run TIMES OUT -> FAIL.
//
// DEBUG_DUMP (+define+DEBUG_DUMP, default OFF): dumps the requantized output next to
// the golden to gemm_dump.txt; limit with +dump_lo=<byte> +dump_hi=<byte>.
//
// Run (from step2/tb):  see step2/README.md  (run_tb.sh gemm answer | skeleton)
// ****************************************************************************
`timescale 1ns/1ps
`ifndef GDIR
 `define GDIR "golden/"
`endif
`include "tb_vectors.vh"

module tb_gemm_requant_compute;

    localparam BW_INDEX = 14;
    localparam PE_N = 64;
    localparam PE_RQ = 16;
    localparam BW_PEN = 6;
    localparam SI_W = 20;

    reg                  clk = 1'b0;
    reg                  rstnn = 1'b0;
    reg                  start = 1'b0;
    wire                 done;
    reg [31:0]           cfg_m, cfg_k, cfg_n, in_zp;
    reg [7:0]            out_zp;
    reg                  mode;
    reg [BW_INDEX-1:0]   w_off, p_off;
    // DUT <-> input BRAM read
    wire [BW_INDEX-1:0]  in_bram_rindex;
    wire                 in_bram_ren;
    wire [31:0]          in_bram_rdata;
    // DUT <-> output BRAM write
    wire [BW_INDEX-1:0]  out_bram_windex;
    wire                 out_bram_wen;
    wire [3:0]           out_bram_wbe;
    wire [31:0]          out_bram_wdata;
    // TB preload (input write) + check (output read)
    reg [BW_INDEX-1:0]   pl_windex;
    reg                  pl_wen;
    reg [31:0]           pl_wdata;
    reg [BW_INDEX-1:0]   ck_rindex;
    reg                  ck_ren;
    wire [31:0]          ck_rdata;

    integer total_fail = 0;

    always #5 clk = ~clk;   // 100 MHz

    USER_BRAM #(.DEPTH(16384), .AW(BW_INDEX))
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
    USER_BRAM #(.DEPTH(16384), .AW(BW_INDEX))
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

    USER_GEMM_REQUANT_COMPUTE #(.PE_N(PE_N), .BW_PEN(BW_PEN), .PE_RQ(PE_RQ), .SI_W(SI_W), .BW_INDEX(BW_INDEX))
    dut
    (
        .clk             (clk),
        .rstnn           (rstnn),
        .start           (start),
        .done            (done),
        .cfg_m           (cfg_m),
        .cfg_k           (cfg_k),
        .cfg_n           (cfg_n),
        .in_zp           (in_zp),
        .out_zp          (out_zp),
        .mode            (mode),
        .w_off           (w_off),
        .p_off           (p_off),
        .in_bram_rindex  (in_bram_rindex),
        .in_bram_ren     (in_bram_ren),
        .in_bram_rdata   (in_bram_rdata),
        .out_bram_windex (out_bram_windex),
        .out_bram_wen    (out_bram_wen),
        .out_bram_wbe    (out_bram_wbe),
        .out_bram_wdata  (out_bram_wdata)
    );

    reg [31:0] inmem [0:16383];
    reg [31:0] gold  [0:511];

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

    task run_dut;
        integer t;
        begin
            rstnn = 1'b0; @(negedge clk); @(negedge clk);
            rstnn = 1'b1; @(negedge clk);
            start = 1'b1; @(negedge clk); start = 1'b0;
            t = 0;
            while (done !== 1'b1 && t < 500000) begin @(negedge clk); t = t + 1; end
            if (t >= 500000) $display("  [TIMEOUT] done never asserted (blank/incomplete DUT)");
        end
    endtask

    // count mismatches over nbytes into mism_out (task: timing control is legal here)
    task mismatch_count(input integer nwords, input integer nbytes, output integer mism_out);
        integer i, b, g, e, mism;
        reg [31:0] rw, gw;
        begin
            mism = 0;
            for (i = 0; i < nwords; i = i + 1) begin
                ck_rindex = i[BW_INDEX-1:0]; ck_ren = 1'b1;
                @(posedge clk); @(posedge clk); #1;
                rw = ck_rdata; gw = gold[i];
                for (b = 0; b < 4; b = b + 1)
                    if (i*4 + b < nbytes) begin
                        g = (rw >> (8*b)) & 32'hff;
                        e = (gw >> (8*b)) & 32'hff;
                        if (g !== e) mism = mism + 1;
                    end
            end
            ck_ren = 1'b0;
            mism_out = mism;
        end
    endtask

    task check(input [255:0] name, input integer nwords, input integer nbytes);
        integer i, b, g, e, mism, fi;
        reg [31:0] rw, gw;
        begin
            mism = 0; fi = -1;
            for (i = 0; i < nwords; i = i + 1) begin
                ck_rindex = i[BW_INDEX-1:0]; ck_ren = 1'b1;
                @(posedge clk); @(posedge clk); #1;
                rw = ck_rdata; gw = gold[i];
                for (b = 0; b < 4; b = b + 1)
                    if (i*4 + b < nbytes) begin
                        g = (rw >> (8*b)) & 32'hff;
                        e = (gw >> (8*b)) & 32'hff;
                        if (g !== e) begin
                            mism = mism + 1;
                            if (fi < 0) begin fi = i*4 + b; $display("  %0s first mismatch: byte=%0d got=%0d exp=%0d", name, fi, g, e); end
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
    task dump_side_by_side(input [255:0] name, input integer nbytes);
        integer fd, i, lo, hi, gi, gj, rc;
        reg [31:0] rw, gw;
        begin
            lo = 0; hi = nbytes - 1;
            rc = $value$plusargs("dump_lo=%d", lo);
            rc = $value$plusargs("dump_hi=%d", hi);
            fd = $fopen("gemm_dump.txt", "w");
            $fdisplay(fd, "# %0s  elem : produced golden", name);
            for (i = lo; i <= hi && i < nbytes; i = i + 1) begin
                ck_rindex = (i>>2); ck_ren = 1'b1; @(posedge clk); @(posedge clk); #1; rw = ck_rdata; ck_ren = 1'b0;
                gw = gold[i>>2];
                gi = (rw >> (8*(i&3))) & 32'hff;
                gj = (gw >> (8*(i&3))) & 32'hff;
                $fdisplay(fd, "%0d : %0d %0d %s", i, gi, gj, (gi===gj)?"":"  <-- DIFF");
            end
            $fclose(fd);
            $display("  [DEBUG_DUMP] wrote gemm_dump.txt bytes [%0d..%0d]", lo, hi);
        end
    endtask
`endif

    integer neg_mism;

    initial begin
        pl_windex = 0; pl_wen = 0; pl_wdata = 0; ck_rindex = 0; ck_ren = 0;

        // ---------- case 1: conv2 gemm_nn ----------
        $display("[tb_gemm_requant_compute] case 1: conv2 gemm_nn (M=%0d K=%0d N=%0d)",
                 `GEMM_CONV_M, `GEMM_CONV_K, `GEMM_CONV_N);
        $readmemh({`GDIR, "gemm_conv_in.memh"},   inmem);
        $readmemh({`GDIR, "gemm_conv_gold.memh"}, gold);
        cfg_m = `GEMM_CONV_M; cfg_k = `GEMM_CONV_K; cfg_n = `GEMM_CONV_N;
        in_zp = `GEMM_CONV_INZP; out_zp = `GEMM_CONV_OUTZP; mode = 1'b0;
        w_off = `GEMM_CONV_WOFF; p_off = `GEMM_CONV_POFF;
        preload(`GEMM_CONV_IN_WORDS);
        run_dut;
        check("conv2_gemm", `GEMM_CONV_GOLD_WORDS, `GEMM_CONV_M * `GEMM_CONV_N);

        // ---------- case 3a: negative control on the conv image (corrupt one M0) ----------
        // p_off word 0 is M0[channel 0]; flip its sign bit -> output MUST change.
        inmem[`GEMM_CONV_POFF] = inmem[`GEMM_CONV_POFF] ^ 32'h8000_0000;
        preload(`GEMM_CONV_IN_WORDS);
        run_dut;
        mismatch_count(`GEMM_CONV_GOLD_WORDS, `GEMM_CONV_M * `GEMM_CONV_N, neg_mism);
        if (neg_mism > 0) $display("  conv2_gemm NEG_CONTROL_OK (corrupt M0 -> mism=%0d)", neg_mism);
        else begin $display("  conv2_gemm NEG_CONTROL_BROKEN mism=0"); total_fail = total_fail + 1; end

        // ---------- case 2: fc1 gemm_nt (transpose) ----------
        $display("[tb_gemm_requant_compute] case 2: fc1 gemm_nt (K=%0d features=%0d)",
                 `GEMM_FC_K, `GEMM_FC_FEATURES);
        $readmemh({`GDIR, "gemm_fc_in.memh"},   inmem);
        $readmemh({`GDIR, "gemm_fc_gold.memh"}, gold);
        cfg_m = `GEMM_FC_M; cfg_k = `GEMM_FC_K; cfg_n = `GEMM_FC_N;
        in_zp = `GEMM_FC_INZP; out_zp = `GEMM_FC_OUTZP; mode = 1'b1;
        w_off = `GEMM_FC_WOFF; p_off = `GEMM_FC_POFF;
        preload(`GEMM_FC_IN_WORDS);
        run_dut;
        check("fc1_gemm", `GEMM_FC_GOLD_WORDS, `GEMM_FC_FEATURES);

        if (total_fail == 0) $display("TB_GEMM_REQUANT_COMPUTE: ALL_PASS");
        else                 $display("TB_GEMM_REQUANT_COMPUTE: FAIL (%0d check(s))", total_fail);
        $finish;
    end
endmodule
