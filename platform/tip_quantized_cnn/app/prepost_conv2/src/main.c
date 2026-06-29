// ****************************************************************************
// RVX prepost - conv2 two-IP accelerator reference test  (HONEST harness)
// Thin app: all driver code is in user_accel_api, all verification in user_verify_api.
//
// Real gates:
//   A: per-engine data-movement smoke (copy)
//   B: IM2COL matrix == golden
//   C: GEMM_REQUANT on the GOLDEN im2col matrix == golden output
//   D: END-TO-END IM2COL -> GEMM_REQUANT (IP-produced matrix) == golden output
//   E: GEMM_REQUANT on GOLDEN matrix with NONZERO kernel_zp == kzp golden
// plus a full negative-control suite (each proven to FAIL when it should).
// ****************************************************************************
#include "platform_info.h"
#include "ervp_printf.h"
#include "ervp_real_clock.h"
#include "ervp_variable_allocation.h"
#include "user_accel_api.h"
#include "user_verify_api.h"
#include "prepost_conv2_vectors.h"

#define TICK() ((unsigned int)get_real_clock_tick())

// engine-reachable DRAM scratch for the GEMM copy-smoke destination (weight-sized)
unsigned char prepost_copy_wt_hw[CONV2_WEIGHT_BYTES] BIG_DATA_BSS ALIGNED_DATA;

// conv2 im2col config (fixed geometry) -> program the regfile (no launch)
static void cfg_im2col(unsigned int src, unsigned int dst, int inb, int outb)
{
    accel_im2col_cfg(ACCEL_IM2COL_BASE, src, dst,
                     CONV2_IN_H, CONV2_IN_W, CONV2_IN_C, CONV2_KH, CONV2_KW,
                     0, 0, 1, 1, 1, 1, CONV2_OUT_H, CONV2_OUT_W, CONV2_IN_ZP, inb, outb);
}
// conv2 gemm config (fixed dims) -> program the regfile (no launch)
static void cfg_gemm(unsigned int src, unsigned int wt, unsigned int par, unsigned int dst,
                     int inzp, int srcb, int outb)
{
    accel_gemm_cfg(ACCEL_GEMM_BASE, src, wt, par, dst, CONV2_M, CONV2_K, CONV2_N,
                   inzp, CONV2_LAYER_ZP, srcb, CONV2_WEIGHT_BYTES, CONV2_PARAM_BYTES, outb, 0);
}
// run im2col (input tensor -> dst matrix)
static void run_im2col(unsigned int src, unsigned int dst, int outb)
{
    cfg_im2col(src, dst, CONV2_INPUT_BYTES, outb);
    accel_run_clr(ACCEL_IM2COL_BASE);
}
// run gemm on a matrix (weights = the conv2 weights)
static void run_gemm(unsigned int matsrc, unsigned int par, unsigned int dst, int inzp)
{
    cfg_gemm(matsrc, accel_paddr(prepost_conv2_weight), par, dst, inzp, CONV2_IM2COL_BYTES, CONV2_OUTPUT_BYTES);
    accel_run_clr(ACCEL_GEMM_BASE);
}

int main(void)
{
    int fail = 0, neg = 0;
    unsigned int t0, t1;
    printf("\n[PREPOST] two-IP conv2 accelerator reference test (HONEST harness)\n");

    if (verify_selftest("", prepost_conv2_input, CONV2_INPUT_BYTES,
                        prepost_conv2_expected, CONV2_OUTPUT_BYTES,
                        prepost_conv2_expected_kzp, CONV2_OUTPUT_BYTES))
    { printf("PREPOST_ALL_FAIL (integrity self-test aborted)\n"); return 1; }

    // ================= REAL GATES =================
    // ---- Gate A.1: IM2COL data-movement smoke (copy input -> copy_hw) ----
    cfg_im2col(accel_paddr(prepost_conv2_input), accel_paddr(prepost_conv2_copy_hw), CONV2_INPUT_BYTES, CONV2_INPUT_BYTES);
    t0 = TICK(); accel_run_copy(ACCEL_IM2COL_BASE); t1 = TICK();
    printf("A_IM2COL_SMOKE ticks=%u\n", t1-t0);
    fail += verify_compare_u8("A_IM2COL_SMOKE", prepost_conv2_copy_hw, prepost_conv2_input, CONV2_INPUT_BYTES);

    // ---- Gate A.2: GEMM data-movement smoke (copy weights -> copy_wt_hw) ----
    cfg_gemm(accel_paddr(prepost_conv2_weight), accel_paddr(prepost_conv2_weight), accel_paddr(prepost_conv2_param),
             accel_paddr(prepost_copy_wt_hw), CONV2_IN_ZP, CONV2_WEIGHT_BYTES, CONV2_WEIGHT_BYTES);
    t0 = TICK(); accel_run_copy(ACCEL_GEMM_BASE); t1 = TICK();
    printf("A_GEMM_SMOKE ticks=%u\n", t1-t0);
    fail += verify_compare_u8("A_GEMM_SMOKE", prepost_copy_wt_hw, prepost_conv2_weight, CONV2_WEIGHT_BYTES);

    // ---- Gate B: IM2COL matrix == golden ----
    t0 = TICK(); run_im2col(accel_paddr(prepost_conv2_input), accel_paddr(prepost_conv2_im2col_hw), CONV2_IM2COL_BYTES); t1 = TICK();
    printf("B_IM2COL_MATRIX ticks=%u\n", t1-t0);
    fail += verify_compare_u8("B_IM2COL_MATRIX", prepost_conv2_im2col_hw, prepost_conv2_im2col_golden, CONV2_IM2COL_BYTES);

    // ---- Gate C: GEMM on the GOLDEN im2col matrix == golden output ----
    t0 = TICK(); run_gemm(accel_paddr(prepost_conv2_im2col_golden), accel_paddr(prepost_conv2_param), accel_paddr(prepost_conv2_out_hw), CONV2_IN_ZP); t1 = TICK();
    printf("C_GEMM_GOLDENMAT ticks=%u\n", t1-t0);
    fail += verify_compare_u8("C_GEMM_GOLDENMAT", prepost_conv2_out_hw, prepost_conv2_expected, CONV2_OUTPUT_BYTES);

    // ---- handoff assert: IP-produced im2col matrix intact before D ----
    fail += verify_compare_u8("ASSERT_IM2COL_HANDOFF", prepost_conv2_im2col_hw, prepost_conv2_im2col_golden, CONV2_IM2COL_BYTES);

    // ---- Gate D: END-TO-END (IP matrix from B) -> GEMM == golden ----
    t0 = TICK(); run_gemm(accel_paddr(prepost_conv2_im2col_hw), accel_paddr(prepost_conv2_param), accel_paddr(prepost_conv2_out_hw), CONV2_IN_ZP); t1 = TICK();
    printf("D_END2END ticks=%u\n", t1-t0);
    fail += verify_compare_u8("D_END2END", prepost_conv2_out_hw, prepost_conv2_expected, CONV2_OUTPUT_BYTES);

    // ---- Gate E: GEMM on GOLDEN matrix with NONZERO kernel_zp == kzp golden ----
    t0 = TICK(); run_gemm(accel_paddr(prepost_conv2_im2col_golden), accel_paddr(prepost_conv2_param_kzp), accel_paddr(prepost_conv2_out_hw), CONV2_IN_ZP); t1 = TICK();
    printf("E_GEMM_KERNELZP ticks=%u\n", t1-t0);
    fail += verify_compare_u8("E_GEMM_KERNELZP", prepost_conv2_out_hw, prepost_conv2_expected_kzp, CONV2_OUTPUT_BYTES);

    printf(fail ? "PREPOST_GATES_FAIL\n" : "PREPOST_GATES_PASS\n");

    // ================= NEGATIVE CONTROLS =================
    printf("NEGATIVE_CONTROL_BEGIN\n");

    run_im2col(accel_paddr(prepost_conv2_input), accel_paddr(prepost_conv2_im2col_hw), CONV2_IM2COL_BYTES);
    prepost_conv2_im2col_golden[0] ^= 1;
    neg += verify_expect_change("NEG_B_BAD_EXPECTED",
            verify_compare_u8("NEG_B_BAD_EXPECTED", prepost_conv2_im2col_hw, prepost_conv2_im2col_golden, CONV2_IM2COL_BYTES));
    prepost_conv2_im2col_golden[0] ^= 1;

    run_gemm(accel_paddr(prepost_conv2_im2col_golden), accel_paddr(prepost_conv2_param), accel_paddr(prepost_conv2_out_hw), CONV2_IN_ZP);
    prepost_conv2_expected[0] ^= 1;
    neg += verify_expect_change("NEG_C_BAD_EXPECTED",
            verify_compare_u8("NEG_C_BAD_EXPECTED", prepost_conv2_out_hw, prepost_conv2_expected, CONV2_OUTPUT_BYTES));
    prepost_conv2_expected[0] ^= 1;

    run_gemm(accel_paddr(prepost_conv2_im2col_hw), accel_paddr(prepost_conv2_param), accel_paddr(prepost_conv2_out_hw), CONV2_IN_ZP);
    prepost_conv2_expected[0] ^= 1;
    neg += verify_expect_change("NEG_D_BAD_EXPECTED",
            verify_compare_u8("NEG_D_BAD_EXPECTED", prepost_conv2_out_hw, prepost_conv2_expected, CONV2_OUTPUT_BYTES));
    prepost_conv2_expected[0] ^= 1;

    // M0 mutation proves requant applies M0 (flip a high bit of M0[0])
    prepost_conv2_param[CONV2_PARAM_M0_WORD] ^= 0x40000000;
    run_gemm(accel_paddr(prepost_conv2_im2col_golden), accel_paddr(prepost_conv2_param), accel_paddr(prepost_conv2_out_hw), CONV2_IN_ZP);
    neg += verify_expect_change("NEG_MUT_M0",
            verify_compare_u8("NEG_MUT_M0", prepost_conv2_out_hw, prepost_conv2_expected, CONV2_OUTPUT_BYTES));
    prepost_conv2_param[CONV2_PARAM_M0_WORD] ^= 0x40000000;

    // weight-byte mutation proves the MAC uses weights
    {
        signed char sv = prepost_conv2_weight[11];
        prepost_conv2_weight[11] = -128;
        run_gemm(accel_paddr(prepost_conv2_im2col_golden), accel_paddr(prepost_conv2_param), accel_paddr(prepost_conv2_out_hw), CONV2_IN_ZP);
        neg += verify_expect_change("NEG_MUT_WEIGHT",
                verify_compare_u8("NEG_MUT_WEIGHT", prepost_conv2_out_hw, prepost_conv2_expected, CONV2_OUTPUT_BYTES));
        prepost_conv2_weight[11] = sv;
    }

    // input-byte mutation on the end-to-end path proves input flows through
    {
        unsigned char sv = prepost_conv2_input[7];
        prepost_conv2_input[7] ^= 0xff;
        run_im2col(accel_paddr(prepost_conv2_input), accel_paddr(prepost_conv2_im2col_hw), CONV2_IM2COL_BYTES);
        run_gemm(accel_paddr(prepost_conv2_im2col_hw), accel_paddr(prepost_conv2_param), accel_paddr(prepost_conv2_out_hw), CONV2_IN_ZP);
        neg += verify_expect_change("NEG_MUT_INPUT_E2E",
                verify_compare_u8("NEG_MUT_INPUT_E2E", prepost_conv2_out_hw, prepost_conv2_expected, CONV2_OUTPUT_BYTES));
        prepost_conv2_input[7] = sv;
    }

    // input_zp mutation proves in_zp is wired into the -in_zp*Sigma_w correction
    run_gemm(accel_paddr(prepost_conv2_im2col_golden), accel_paddr(prepost_conv2_param), accel_paddr(prepost_conv2_out_hw), CONV2_IN_ZP + 1);
    neg += verify_expect_change("NEG_MUT_INZP",
            verify_compare_u8("NEG_MUT_INZP", prepost_conv2_out_hw, prepost_conv2_expected, CONV2_OUTPUT_BYTES));

    printf(neg ? "NEGATIVE_CONTROL_FAIL\n" : "NEGATIVE_CONTROL_ALL_PASS\n");
    printf((fail || neg) ? "PREPOST_ALL_FAIL\n" : "PREPOST_ALL_PASS\n");
    return (fail || neg);
}
