// ****************************************************************************
// user_accel_api.c - two-IP accelerator driver implementation (PROVIDED).
// See user_accel_api.h.  The register sequences here are exactly those the apps used
// inline before the SW was factored into this library (behavior byte-identical).
// ****************************************************************************
#include "user_accel_api.h"

void accel_im2col_cfg(unsigned int base, unsigned int src, unsigned int dst,
                      int inh, int inw, int inc, int kh, int kw, int padh, int padw,
                      int strh, int strw, int dilh, int dilw, int outh, int outw,
                      int inzp, int inb, int outb)
{
    acc_wr(base, IM2COL_SRC, src);
    acc_wr(base, IM2COL_DST, dst);
    acc_wr(base, IM2COL_IN_H, inh);
    acc_wr(base, IM2COL_IN_W, inw);
    acc_wr(base, IM2COL_IN_C, inc);
    acc_wr(base, IM2COL_K_H, kh);
    acc_wr(base, IM2COL_K_W, kw);
    acc_wr(base, IM2COL_PAD_H, padh);
    acc_wr(base, IM2COL_PAD_W, padw);
    acc_wr(base, IM2COL_STR_H, strh);
    acc_wr(base, IM2COL_STR_W, strw);
    acc_wr(base, IM2COL_DIL_H, dilh);
    acc_wr(base, IM2COL_DIL_W, dilw);
    acc_wr(base, IM2COL_OUT_H, outh);
    acc_wr(base, IM2COL_OUT_W, outw);
    acc_wr(base, IM2COL_IN_ZP, inzp);
    acc_wr(base, IM2COL_INBYTES, inb);
    acc_wr(base, IM2COL_OUTBYTES, outb);
}

void accel_gemm_cfg(unsigned int base, unsigned int src, unsigned int wt, unsigned int par,
                    unsigned int dst, int M, int K, int N, int inzp, int outzp,
                    int srcb, int wb, int pb, int outb, int mode)
{
    acc_wr(base, GEMM_SRC, src);
    acc_wr(base, GEMM_WEIGHT, wt);
    acc_wr(base, GEMM_PARAM, par);
    acc_wr(base, GEMM_DST, dst);
    acc_wr(base, GEMM_M, M);
    acc_wr(base, GEMM_K, K);
    acc_wr(base, GEMM_N, N);
    acc_wr(base, GEMM_IN_ZP, inzp);
    acc_wr(base, GEMM_OUT_ZP, outzp);
    acc_wr(base, GEMM_SRCBYTES, srcb);
    acc_wr(base, GEMM_WBYTES, wb);
    acc_wr(base, GEMM_PBYTES, pb);
    acc_wr(base, GEMM_OUTBYTES, outb);
    acc_wr(base, GEMM_MODE, mode);
}

int accel_run_clr(unsigned int base)
{
    acc_wr(base, ACC_CONTROL, ACC_CTRL_CLR);
    return acc_run(base);
}

int accel_run_copy(unsigned int base)
{
    acc_wr(base, ACC_CONTROL, ACC_CTRL_COPY | ACC_CTRL_CLR);
    return acc_run(base);
}

int accel_im2col_run(unsigned int base, unsigned int src, unsigned int dst,
                     int inh, int inw, int inc, int kh, int kw, int padh, int padw,
                     int strh, int strw, int dilh, int dilw, int outh, int outw,
                     int inzp, int inb, int outb)
{
    accel_im2col_cfg(base, src, dst, inh, inw, inc, kh, kw, padh, padw,
                     strh, strw, dilh, dilw, outh, outw, inzp, inb, outb);
    return accel_run_clr(base);
}

int accel_gemm_run(unsigned int base, unsigned int src, unsigned int wt, unsigned int par,
                   unsigned int dst, int M, int K, int N, int inzp, int outzp,
                   int srcb, int wb, int pb, int outb, int mode)
{
    accel_gemm_cfg(base, src, wt, par, dst, M, K, N, inzp, outzp, srcb, wb, pb, outb, mode);
    return accel_run_clr(base);
}

void accel_conv(unsigned int mat_buf, unsigned int src, unsigned int dst,
                int inc, int inh, int inw, int k, int outh, int outw,
                int inzp, int outzp, const signed char *wt, const int *par, int M, int N)
{
    int K = inc*k*k;
    accel_im2col_run(ACCEL_IM2COL_BASE, src, mat_buf, inh, inw, inc, k, k, 0, 0,
                     1, 1, 1, 1, outh, outw, inzp, inc*inh*inw, K*N);
    accel_gemm_run(ACCEL_GEMM_BASE, mat_buf, accel_paddr(wt), accel_paddr(par), dst,
                   M, K, N, inzp, outzp, K*N, M*K, M*5*4, M*N, 0);
}

void accel_fc(unsigned int src, unsigned int dst, const signed char *wt, const int *par,
              int M, int K, int Mpad, int inzp, int outzp)
{
    accel_gemm_run(ACCEL_GEMM_BASE, src, accel_paddr(wt), accel_paddr(par), dst,
                   1, K, M, inzp, outzp, K, K*Mpad, M*5*4, M, 1);
}
