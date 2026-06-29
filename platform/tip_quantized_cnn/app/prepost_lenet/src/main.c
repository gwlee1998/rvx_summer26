// ****************************************************************************
// RVX prepost - FULL LeNet-5 end-to-end inference on the two-IP accelerator.
// Thin app: all driver code is in user_accel_api, verification in user_verify_api,
// SW pooling in user_sw_ref.
//   conv1(1->6,k5) -> pool1 -> conv2(6->16,k5) -> pool2 -> fc1 256->120 ->
//   fc2 120->84 -> fc3 84->10 (LINEAR) -> argmax.
// Conv layers: IM2COL engine -> GEMM engine (gemm_nn).  Pooling: SW 2x2 max.
// FC layers: GEMM engine TRANSPOSE mode (gemm_nt).
//
// Rigor (per sample, both mnist_five and mnist_nine):
//   * comparator integrity self-test FIRST
//   * PER-LAYER byte-exact gates + handoff asserts + stage ISOLATION
//   * per-layer negative controls + a network negative control
//   Honest word-read compare only; LENET_ALL_PASS iff every check passes for ALL samples.
// ****************************************************************************
#include "platform_info.h"
#include "ervp_printf.h"
#include "ervp_variable_allocation.h"
#include "user_accel_api.h"
#include "user_verify_api.h"
#include "user_sw_ref.h"
#include "prepost_lenet_vectors.h"

unsigned char fc2_save[128] BIG_DATA_BSS ALIGNED_DATA;   // fc2 out kept for the network neg control
unsigned char negout[64]    BIG_DATA_BSS ALIGNED_DATA;   // network neg control output

static volatile unsigned char *U8(void *p) { return (volatile unsigned char *)p; }

// conv layer via IP: im2col(src -> lenet_mat) then gemm_nn(lenet_mat -> dst).
static void conv_ip(unsigned int src, unsigned int dst, int inc, int inh, int inw, int k,
                    int outh, int outw, int inzp, int outzp, signed char *wt, int *par, int M, int N)
{
    accel_conv(accel_paddr(lenet_mat), src, dst, inc, inh, inw, k, outh, outw, inzp, outzp, wt, par, M, N);
}
// fc layer via IP: transpose gemm_nt(src vector -> dst), output features on lanes.
static void fc_ip(unsigned int src, unsigned int dst, signed char *wt, int *par,
                  int M, int K, int Mpad, int inzp, int outzp)
{
    accel_fc(src, dst, wt, par, M, K, Mpad, inzp, outzp);
}

// ---- comparator integrity self-test for sample s (shared verify primitives) ----
static int integrity_selftest(int s)
{
    unsigned char *inp = lenet_input_s[s], *c1g = lenet_c1_golden_s[s], *f3g = lenet_f3_golden_s[s];
    int nz_in = verify_count_nonzero(inp, C1_INC*C1_INH*C1_INW);
    int nz_c1 = verify_count_nonzero(c1g, C1_OUTC*C1_N);
    int nz_f3 = verify_count_nonzero(f3g, F3_M);
    int lim = C1_INC*C1_INH*C1_INW; if (C1_OUTC*C1_N < lim) lim = C1_OUTC*C1_N;
    int diff = verify_count_diff_u8(c1g, inp, lim);
    printf("S%d SELFTEST nonzero input=%d c1_golden=%d f3_golden=%d (expect>0)\n", s, nz_in, nz_c1, nz_f3);
    printf("S%d SELFTEST discrimination c1_golden_vs_input diff=%d (expect>0)\n", s, diff);
    if (nz_in == 0 || nz_c1 == 0 || nz_f3 == 0) { printf("S%d SELFTEST_ABORT empty_vector\n", s); return 1; }
    if (diff == 0) { printf("S%d SELFTEST_ABORT golden_is_input_copy\n", s); return 1; }
    printf("S%d SELFTEST provenance: goldens from prepost_gen_lenet.py numpy int forward (==rvx_ssw gemm.c)\n", s);
    return 0;
}

// ================= per-sample full-network honest run =================
static int run_sample(int s)
{
    int fail = 0, pred, i;
    unsigned char *inp = lenet_input_s[s];
    printf("\n[PREPOST] ---- sample %d ----\n", s);

    if (integrity_selftest(s)) { printf("S%d LENET_FAIL (integrity self-test aborted)\n", s); return 1; }

    // ---- conv1 (no upstream: isolated == chained) -> pool1 ----
    conv_ip(accel_paddr(inp), accel_paddr(lenet_out), C1_INC, C1_INH, C1_INW, 5, C1_OUTH, C1_OUTW,
            C1_INZP, C1_OUTZP, lenet_c1_weight, lenet_c1_param, C1_OUTC, C1_N);
    fail += verify_compare_u8("CONV1", (unsigned char *)lenet_out, lenet_c1_golden_s[s], C1_OUTC*C1_N);
    sw_maxpool(U8(lenet_out), U8(lenet_act), C1_OUTC, C1_OUTH, C1_OUTW);
    fail += verify_compare_u8("POOL1", (unsigned char *)lenet_act, lenet_p1_golden_s[s], C1_OUTC*(C1_OUTH/2)*(C1_OUTW/2));
    fail += verify_compare_u8("ASSERT_POOL1_HANDOFF", (unsigned char *)lenet_act, lenet_p1_golden_s[s], C1_OUTC*(C1_OUTH/2)*(C1_OUTW/2));

    // ---- conv2 ISOLATED (from pool1 GOLDEN) ----
    conv_ip(accel_paddr(lenet_p1_golden_s[s]), accel_paddr(lenet_iso), C2_INC, C2_INH, C2_INW, 5, C2_OUTH, C2_OUTW,
            C2_INZP, C2_OUTZP, lenet_c2_weight, lenet_c2_param, C2_OUTC, C2_N);
    fail += verify_compare_u8("CONV2_ISO", (unsigned char *)lenet_iso, lenet_c2_golden_s[s], C2_OUTC*C2_N);
    // ---- conv2 CHAINED (from pool1 IP output in lenet_act) -> pool2 ----
    conv_ip(accel_paddr(lenet_act), accel_paddr(lenet_out), C2_INC, C2_INH, C2_INW, 5, C2_OUTH, C2_OUTW,
            C2_INZP, C2_OUTZP, lenet_c2_weight, lenet_c2_param, C2_OUTC, C2_N);
    fail += verify_compare_u8("CONV2", (unsigned char *)lenet_out, lenet_c2_golden_s[s], C2_OUTC*C2_N);
    sw_maxpool(U8(lenet_out), U8(lenet_act), C2_OUTC, C2_OUTH, C2_OUTW);
    fail += verify_compare_u8("POOL2", (unsigned char *)lenet_act, lenet_p2_golden_s[s], C2_OUTC*(C2_OUTH/2)*(C2_OUTW/2));
    fail += verify_compare_u8("ASSERT_POOL2_HANDOFF", (unsigned char *)lenet_act, lenet_p2_golden_s[s], C2_OUTC*(C2_OUTH/2)*(C2_OUTW/2));

    // ---- fc1 ISOLATED (from pool2 GOLDEN) ----
    fc_ip(accel_paddr(lenet_p2_golden_s[s]), accel_paddr(lenet_iso), lenet_f1_weight, lenet_f1_param, F1_M, F1_K, F1_MPAD, F1_INZP, F1_OUTZP);
    fail += verify_compare_u8("FC1_ISO", (unsigned char *)lenet_iso, lenet_f1_golden_s[s], F1_M);
    // ---- fc1 CHAINED (from pool2 IP output) ----
    fc_ip(accel_paddr(lenet_act), accel_paddr(lenet_out), lenet_f1_weight, lenet_f1_param, F1_M, F1_K, F1_MPAD, F1_INZP, F1_OUTZP);
    fail += verify_compare_u8("FC1", (unsigned char *)lenet_out, lenet_f1_golden_s[s], F1_M);
    for (i = 0; i < F1_M; i = i + 1) U8(lenet_act)[i] = U8(lenet_out)[i];

    // ---- fc2 -> fc3 (chained) ----
    fc_ip(accel_paddr(lenet_act), accel_paddr(lenet_out), lenet_f2_weight, lenet_f2_param, F2_M, F2_K, F2_MPAD, F2_INZP, F2_OUTZP);
    fail += verify_compare_u8("FC2", (unsigned char *)lenet_out, lenet_f2_golden_s[s], F2_M);
    for (i = 0; i < F2_M; i = i + 1) { U8(lenet_act)[i] = U8(lenet_out)[i]; fc2_save[i] = U8(lenet_out)[i]; }
    fc_ip(accel_paddr(lenet_act), accel_paddr(lenet_out), lenet_f3_weight, lenet_f3_param, F3_M, F3_K, F3_MPAD, F3_INZP, F3_OUTZP);
    fail += verify_compare_u8("FC3", (unsigned char *)lenet_out, lenet_f3_golden_s[s], F3_M);

    // ---- argmax / prediction ----
    pred = verify_argmax_u8(U8(lenet_out), F3_M);
    printf("S%d LENET_PRED got=%d expected=%d %s\n", s, pred, lenet_pred_s[s], (pred==lenet_pred_s[s])?"PASS":"FAIL");
    if (pred != lenet_pred_s[s]) fail++;

    // ---- network negative control: zero M0 of the winning class -> prediction must change ----
    {
        int sv = lenet_f3_param[pred], p2;
        lenet_f3_param[pred] = 0;
        fc_ip(accel_paddr(fc2_save), accel_paddr(negout), lenet_f3_weight, lenet_f3_param, F3_M, F3_K, F3_MPAD, F3_INZP, F3_OUTZP);
        p2 = verify_argmax_u8(U8(negout), F3_M);
        printf("S%d LENET_NEGCTRL corrupted_pred=%d clean_pred=%d %s\n", s, p2, pred, (p2!=pred)?"OK":"BROKEN");
        if (p2 == pred) fail++;
        lenet_f3_param[pred] = sv;
    }

    printf(fail ? "S%d LENET_FAIL\n" : "S%d LENET_PASS\n", s);
    return fail;
}

// ================= per-LAYER negative controls (RTL wiring; run once, sample 0) =================
static int layer_negative_controls(int s)
{
    int neg = 0;
    printf("\n[PREPOST] ---- per-layer negative controls (sample %d) ----\n", s);

    // conv1 weight -> conv1 output changes
    {
        signed char sv = lenet_c1_weight[7];
        lenet_c1_weight[7] = (signed char)(sv ^ 0x55);
        conv_ip(accel_paddr(lenet_input_s[s]), accel_paddr(lenet_iso), C1_INC, C1_INH, C1_INW, 5, C1_OUTH, C1_OUTW,
                C1_INZP, C1_OUTZP, lenet_c1_weight, lenet_c1_param, C1_OUTC, C1_N);
        neg += verify_expect_change("NEG_C1_WEIGHT",
               verify_compare_u8("NEG_C1_WEIGHT", (unsigned char *)lenet_iso, lenet_c1_golden_s[s], C1_OUTC*C1_N));
        lenet_c1_weight[7] = sv;
    }
    // conv2 M0 (param word 0 = M0[0]) -> conv2 output changes
    {
        int sv = lenet_c2_param[0];
        lenet_c2_param[0] ^= 0x40000000;
        conv_ip(accel_paddr(lenet_p1_golden_s[s]), accel_paddr(lenet_iso), C2_INC, C2_INH, C2_INW, 5, C2_OUTH, C2_OUTW,
                C2_INZP, C2_OUTZP, lenet_c2_weight, lenet_c2_param, C2_OUTC, C2_N);
        neg += verify_expect_change("NEG_C2_M0",
               verify_compare_u8("NEG_C2_M0", (unsigned char *)lenet_iso, lenet_c2_golden_s[s], C2_OUTC*C2_N));
        lenet_c2_param[0] = sv;
    }
    // fc1 W^T weight -> fc1 output changes (transpose path consumes per-lane weights)
    {
        signed char sv = lenet_f1_weight[13];
        lenet_f1_weight[13] = (signed char)(sv ^ 0x7f);
        fc_ip(accel_paddr(lenet_p2_golden_s[s]), accel_paddr(lenet_iso), lenet_f1_weight, lenet_f1_param, F1_M, F1_K, F1_MPAD, F1_INZP, F1_OUTZP);
        neg += verify_expect_change("NEG_F1_WEIGHT",
               verify_compare_u8("NEG_F1_WEIGHT", (unsigned char *)lenet_iso, lenet_f1_golden_s[s], F1_M));
        lenet_f1_weight[13] = sv;
    }
    // fc1 per-feature M0 -> fc1 output changes (corrupt the WHOLE M0 section to guarantee a change)
    {
        int j;
        for (j = 0; j < F1_M; j = j + 1) lenet_f1_param[j] ^= 0x40000000;
        fc_ip(accel_paddr(lenet_p2_golden_s[s]), accel_paddr(lenet_iso), lenet_f1_weight, lenet_f1_param, F1_M, F1_K, F1_MPAD, F1_INZP, F1_OUTZP);
        neg += verify_expect_change("NEG_F1_M0",
               verify_compare_u8("NEG_F1_M0", (unsigned char *)lenet_iso, lenet_f1_golden_s[s], F1_M));
        for (j = 0; j < F1_M; j = j + 1) lenet_f1_param[j] ^= 0x40000000;
    }
    // conv2 in_zp -> conv2 output changes (in_zp wired into -in_zp*Sigma_w correction)
    {
        conv_ip(accel_paddr(lenet_p1_golden_s[s]), accel_paddr(lenet_iso), C2_INC, C2_INH, C2_INW, 5, C2_OUTH, C2_OUTW,
                C2_INZP + 1, C2_OUTZP, lenet_c2_weight, lenet_c2_param, C2_OUTC, C2_N);
        neg += verify_expect_change("NEG_C2_INZP",
               verify_compare_u8("NEG_C2_INZP", (unsigned char *)lenet_iso, lenet_c2_golden_s[s], C2_OUTC*C2_N));
    }

    printf(neg ? "LAYER_NEGCTRL_FAIL\n" : "LAYER_NEGCTRL_ALL_PASS\n");
    return neg;
}

int main(void)
{
    int fail = 0, s, i, cross = 0;
    printf("\n[PREPOST] FULL LeNet-5 end-to-end inference (HONEST harness, %d samples)\n", LENET_NSAMPLES);

    // harness-level discrimination: the two samples' fc3 goldens must differ (not constant)
    for (i = 0; i < F3_M; i = i + 1) if (lenet_f3_golden_s[0][i] != lenet_f3_golden_s[1][i]) cross++;
    printf("SELFTEST cross-sample f3_golden diff=%d (expect>0)\n", cross);
    if (cross == 0) { printf("SELFTEST_ABORT goldens_not_sample_specific\n"); return 1; }

    for (s = 0; s < LENET_NSAMPLES; s = s + 1) fail += run_sample(s);
    fail += layer_negative_controls(0);

    printf(fail ? "LENET_ALL_FAIL\n" : "LENET_ALL_PASS\n");
    return fail;
}
