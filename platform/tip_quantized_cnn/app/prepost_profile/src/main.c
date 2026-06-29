// ****************************************************************************
// RVX prepost - ORCA-core SW (darknet-style quantized C) vs two-IP accelerator
// TIMING PROFILE.  Thin app: driver in user_accel_api, verify+result in
// user_verify_api, SW reference in user_sw_ref.  get_real_clock_tick() returns
// MICROSECONDS (us); SW and IP share the timer so speedup is unit-free.
//
// Three reports (mnist_five; correctness already proven on 2 samples by prepost_lenet):
//   1) PER-(LAYER,STEP) BREAKDOWN - every conv layer times im2col and gemm_requant as
//      TWO separate steps (SW vs IP); each fc layer is one gemm_requant row; maxpool and
//      softmax/argmax appear as SW-only (not-accelerated) rows.  Each accelerated row is
//      byte-exact (SW result == IP result == numpy golden).
//   2) WHOLE-NETWORK END-TO-END total - the COMPLETE inference run once for SW and once
//      for IP, with NO per-step timers, INCLUDING the non-accelerated SW stages
//      (maxpool, argmax).  One SW-vs-IP pair.
//   3) RESULT - the full 10-class score table (ranked high->low) for SW and IP + predict.
//
// SW reference == rvx_ssw/darknet gemm.c: temp = mm - in_zp*Sw - kzp*Sin + bias_eff ;
// prod=temp*M0 (int64) ; round-half-up ; arithmetic >>rs ; clamp to uint8.
// ****************************************************************************
#include "platform_info.h"
#include "ervp_printf.h"
#include "ervp_real_clock.h"
#include "ervp_variable_allocation.h"
#include "user_accel_api.h"
#include "user_verify_api.h"
#include "user_sw_ref.h"
#include "prepost_lenet_vectors.h"

#define TICK() ((unsigned int)get_real_clock_tick())

// SW scratch (DRAM-backed; SW reads/writes directly)
unsigned char sw_mat[16384] BIG_DATA_BSS ALIGNED_DATA;
unsigned char sw_a[8192]    BIG_DATA_BSS ALIGNED_DATA;
unsigned char sw_b[8192]    BIG_DATA_BSS ALIGNED_DATA;
unsigned char sw_out[256]   BIG_DATA_BSS ALIGNED_DATA;

static volatile unsigned char *U8(void *p) { return (volatile unsigned char *)p; }

static int g_fail = 0;

static unsigned int sp10(unsigned int sw_us, unsigned int ip_us)
{ return ip_us ? (sw_us*10u)/ip_us : 0; }

// accelerated (layer,step) row: SW vs IP us + byte-exact verdict (ip==golden && sw==golden)
static void acc_row(const char *layer, const char *step, unsigned int sw_us, unsigned int ip_us,
                    const unsigned char *sw_res, const unsigned char *ip_res,
                    const unsigned char *golden, int nbytes)
{
    int sw_ex = (verify_count_diff_u8(sw_res, golden, nbytes) == 0);
    int ip_ex = (verify_count_diff_u8(ip_res, golden, nbytes) == 0);
    unsigned int s = sp10(sw_us, ip_us);
    printf("BRK %-6s %-12s SW=%u us  IP=%u us  speedup=%u.%u  exact=%d\n",
           layer, step, sw_us, ip_us, s/10, s%10, (sw_ex && ip_ex));
    if (!(sw_ex && ip_ex)) g_fail++;
}

// SW-only (not accelerated) row
static void sw_only_row(const char *layer, const char *step, unsigned int sw_us)
{ printf("BRK %-6s %-12s SW=%u us  IP=-  speedup=-    exact=-\n", layer, step, sw_us); }

int main(void)
{
    int s = 0;
    unsigned int t0, t1, swc, ipc, sw_total, ip_total;
    int psw, pip;
    unsigned char *inp = lenet_input_s[s];
    unsigned char *p1g = lenet_p1_golden_s[s];
    unsigned char *p2g = lenet_p2_golden_s[s];

    printf("\n[PREPOST] SW vs two-IP accelerator timing profile (mnist_five), units = us\n");

    // ================= 1) PER-(LAYER,STEP) BREAKDOWN =================
    printf("\n-- breakdown: per (layer, step) --\n");
    printf("BRK layer  step          SW          IP        speedup  exact\n");

    // ---- CONV1: im2col + gemm_requant + (SW) maxpool ----
    t0 = TICK(); sw_im2col(inp, C1_INC, C1_INH, C1_INW, 5, 5, 0, 0, 1, 1, 1, 1, sw_mat, C1_INZP); t1 = TICK(); swc = t1-t0;
    t0 = TICK(); accel_im2col_run(ACCEL_IM2COL_BASE, accel_paddr(inp), accel_paddr(lenet_mat),
                                  C1_INH, C1_INW, C1_INC, 5, 5, 0, 0, 1, 1, 1, 1, C1_OUTH, C1_OUTW,
                                  C1_INZP, C1_INC*C1_INH*C1_INW, C1_K*C1_N); t1 = TICK(); ipc = t1-t0;
    acc_row("conv1", "im2col", swc, ipc, sw_mat, U8(lenet_mat), sw_mat, C1_K*C1_N); // im2col golden == SW im2col
    t0 = TICK(); sw_gemm_nn(sw_mat, lenet_c1_weight, lenet_c1_param, sw_out, C1_OUTC, C1_K, C1_N, C1_INZP, C1_OUTZP); t1 = TICK(); swc = t1-t0;
    t0 = TICK(); accel_gemm_run(ACCEL_GEMM_BASE, accel_paddr(lenet_mat), accel_paddr(lenet_c1_weight),
                                accel_paddr(lenet_c1_param), accel_paddr(lenet_out), C1_OUTC, C1_K, C1_N,
                                C1_INZP, C1_OUTZP, C1_K*C1_N, C1_OUTC*C1_K, C1_OUTC*5*4, C1_OUTC*C1_N, 0); t1 = TICK(); ipc = t1-t0;
    acc_row("conv1", "gemm_requant", swc, ipc, sw_out, U8(lenet_out), lenet_c1_golden_s[s], C1_OUTC*C1_N);
    t0 = TICK(); sw_maxpool(U8(lenet_c1_golden_s[s]), U8(sw_a), C1_OUTC, C1_OUTH, C1_OUTW); t1 = TICK();
    sw_only_row("pool1", "maxpool", t1-t0);

    // ---- CONV2 (from pool1 golden): im2col + gemm_requant + (SW) maxpool ----
    t0 = TICK(); sw_im2col(p1g, C2_INC, C2_INH, C2_INW, 5, 5, 0, 0, 1, 1, 1, 1, sw_mat, C2_INZP); t1 = TICK(); swc = t1-t0;
    t0 = TICK(); accel_im2col_run(ACCEL_IM2COL_BASE, accel_paddr(p1g), accel_paddr(lenet_mat),
                                  C2_INH, C2_INW, C2_INC, 5, 5, 0, 0, 1, 1, 1, 1, C2_OUTH, C2_OUTW,
                                  C2_INZP, C2_INC*C2_INH*C2_INW, C2_K*C2_N); t1 = TICK(); ipc = t1-t0;
    acc_row("conv2", "im2col", swc, ipc, sw_mat, U8(lenet_mat), sw_mat, C2_K*C2_N);
    t0 = TICK(); sw_gemm_nn(sw_mat, lenet_c2_weight, lenet_c2_param, sw_out, C2_OUTC, C2_K, C2_N, C2_INZP, C2_OUTZP); t1 = TICK(); swc = t1-t0;
    t0 = TICK(); accel_gemm_run(ACCEL_GEMM_BASE, accel_paddr(lenet_mat), accel_paddr(lenet_c2_weight),
                                accel_paddr(lenet_c2_param), accel_paddr(lenet_out), C2_OUTC, C2_K, C2_N,
                                C2_INZP, C2_OUTZP, C2_K*C2_N, C2_OUTC*C2_K, C2_OUTC*5*4, C2_OUTC*C2_N, 0); t1 = TICK(); ipc = t1-t0;
    acc_row("conv2", "gemm_requant", swc, ipc, sw_out, U8(lenet_out), lenet_c2_golden_s[s], C2_OUTC*C2_N);
    t0 = TICK(); sw_maxpool(U8(lenet_c2_golden_s[s]), U8(sw_a), C2_OUTC, C2_OUTH, C2_OUTW); t1 = TICK();
    sw_only_row("pool2", "maxpool", t1-t0);

    // ---- FC1/FC2/FC3 (gemm_nt; one gemm_requant row each, from golden upstream) ----
    t0 = TICK(); sw_gemm_nt(p2g, lenet_f1_weight, lenet_f1_param, sw_out, F1_M, F1_K, F1_MPAD, F1_INZP, F1_OUTZP); t1 = TICK(); swc = t1-t0;
    t0 = TICK(); accel_fc(accel_paddr(p2g), accel_paddr(lenet_out), lenet_f1_weight, lenet_f1_param, F1_M, F1_K, F1_MPAD, F1_INZP, F1_OUTZP); t1 = TICK(); ipc = t1-t0;
    acc_row("fc1", "gemm_requant", swc, ipc, sw_out, U8(lenet_out), lenet_f1_golden_s[s], F1_M);
    t0 = TICK(); sw_gemm_nt(lenet_f1_golden_s[s], lenet_f2_weight, lenet_f2_param, sw_out, F2_M, F2_K, F2_MPAD, F2_INZP, F2_OUTZP); t1 = TICK(); swc = t1-t0;
    t0 = TICK(); accel_fc(accel_paddr(lenet_f1_golden_s[s]), accel_paddr(lenet_out), lenet_f2_weight, lenet_f2_param, F2_M, F2_K, F2_MPAD, F2_INZP, F2_OUTZP); t1 = TICK(); ipc = t1-t0;
    acc_row("fc2", "gemm_requant", swc, ipc, sw_out, U8(lenet_out), lenet_f2_golden_s[s], F2_M);
    t0 = TICK(); sw_gemm_nt(lenet_f2_golden_s[s], lenet_f3_weight, lenet_f3_param, sw_out, F3_M, F3_K, F3_MPAD, F3_INZP, F3_OUTZP); t1 = TICK(); swc = t1-t0;
    t0 = TICK(); accel_fc(accel_paddr(lenet_f2_golden_s[s]), accel_paddr(lenet_out), lenet_f3_weight, lenet_f3_param, F3_M, F3_K, F3_MPAD, F3_INZP, F3_OUTZP); t1 = TICK(); ipc = t1-t0;
    acc_row("fc3", "gemm_requant", swc, ipc, sw_out, U8(lenet_out), lenet_f3_golden_s[s], F3_M);

    // ---- softmax/argmax (SW-only) ----
    t0 = TICK(); psw = verify_argmax_u8(U8(lenet_f3_golden_s[s]), F3_M); t1 = TICK();
    sw_only_row("out", "argmax", t1-t0);
    (void)psw;

    // ================= 2) WHOLE-NETWORK END-TO-END (clean, no per-step timers) =================
    // SW path (includes maxpool + argmax)
    t0 = TICK();
    sw_im2col(inp, C1_INC, C1_INH, C1_INW, 5, 5, 0, 0, 1, 1, 1, 1, sw_mat, C1_INZP);
    sw_gemm_nn(sw_mat, lenet_c1_weight, lenet_c1_param, sw_a, C1_OUTC, C1_K, C1_N, C1_INZP, C1_OUTZP);
    sw_maxpool(U8(sw_a), U8(sw_b), C1_OUTC, C1_OUTH, C1_OUTW);
    sw_im2col(sw_b, C2_INC, C2_INH, C2_INW, 5, 5, 0, 0, 1, 1, 1, 1, sw_mat, C2_INZP);
    sw_gemm_nn(sw_mat, lenet_c2_weight, lenet_c2_param, sw_a, C2_OUTC, C2_K, C2_N, C2_INZP, C2_OUTZP);
    sw_maxpool(U8(sw_a), U8(sw_b), C2_OUTC, C2_OUTH, C2_OUTW);
    sw_gemm_nt(sw_b, lenet_f1_weight, lenet_f1_param, sw_a, F1_M, F1_K, F1_MPAD, F1_INZP, F1_OUTZP);
    sw_gemm_nt(sw_a, lenet_f2_weight, lenet_f2_param, sw_b, F2_M, F2_K, F2_MPAD, F2_INZP, F2_OUTZP);
    sw_gemm_nt(sw_b, lenet_f3_weight, lenet_f3_param, sw_out, F3_M, F3_K, F3_MPAD, F3_INZP, F3_OUTZP);
    psw = verify_argmax_u8(U8(sw_out), F3_M);
    t1 = TICK(); sw_total = t1-t0;

    // IP path (conv/fc on the engines; maxpool + argmax in SW -> included in the span)
    t0 = TICK();
    accel_conv(accel_paddr(lenet_mat), accel_paddr(inp), accel_paddr(lenet_act),
               C1_INC, C1_INH, C1_INW, 5, C1_OUTH, C1_OUTW, C1_INZP, C1_OUTZP, lenet_c1_weight, lenet_c1_param, C1_OUTC, C1_N);
    sw_maxpool(U8(lenet_act), U8(lenet_iso), C1_OUTC, C1_OUTH, C1_OUTW);
    accel_conv(accel_paddr(lenet_mat), accel_paddr(lenet_iso), accel_paddr(lenet_act),
               C2_INC, C2_INH, C2_INW, 5, C2_OUTH, C2_OUTW, C2_INZP, C2_OUTZP, lenet_c2_weight, lenet_c2_param, C2_OUTC, C2_N);
    sw_maxpool(U8(lenet_act), U8(lenet_iso), C2_OUTC, C2_OUTH, C2_OUTW);
    accel_fc(accel_paddr(lenet_iso), accel_paddr(lenet_act), lenet_f1_weight, lenet_f1_param, F1_M, F1_K, F1_MPAD, F1_INZP, F1_OUTZP);
    accel_fc(accel_paddr(lenet_act), accel_paddr(lenet_iso), lenet_f2_weight, lenet_f2_param, F2_M, F2_K, F2_MPAD, F2_INZP, F2_OUTZP);
    accel_fc(accel_paddr(lenet_iso), accel_paddr(lenet_out), lenet_f3_weight, lenet_f3_param, F3_M, F3_K, F3_MPAD, F3_INZP, F3_OUTZP);
    pip = verify_argmax_u8(U8(lenet_out), F3_M);
    t1 = TICK(); ip_total = t1-t0;

    {
        int sw_ok = (verify_count_diff_u8(sw_out, lenet_f3_golden_s[s], F3_M) == 0);
        int ip_ok = (verify_count_diff_u8((unsigned char *)lenet_out, lenet_f3_golden_s[s], F3_M) == 0);
        unsigned int e = sp10(sw_total, ip_total);
        printf("\n-- whole-network end-to-end (includes SW maxpool/argmax) --\n");
        printf("END2END SW=%u us  IP=%u us  speedup=%u.%u  sw_exact=%d ip_exact=%d pred_sw=%d pred_ip=%d\n",
               sw_total, ip_total, e/10, e%10, sw_ok, ip_ok, psw, pip);
        if (!sw_ok || !ip_ok) g_fail++;
        if (psw != lenet_pred_s[s] || pip != lenet_pred_s[s]) g_fail++;
    }

    // ================= 3) RESULT: full 10-class score table (SW + IP) =================
    printf("\n-- result: 10-class scores --\n");
    verify_print_score_table("RESULT", sw_out, (unsigned char *)lenet_out, F3_M);

    printf(g_fail ? "\nPROFILE_FAIL (a path was not byte-exact)\n" : "\nPROFILE_ALL_EXACT\n");
    return g_fail;
}
