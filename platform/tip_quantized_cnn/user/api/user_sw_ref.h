#ifndef __USER_SW_REF_H__
#define __USER_SW_REF_H__
// ****************************************************************************
// user_sw_ref - SW reference layer math for the quantized CNN (PROVIDED library)
// These are the darknet quantized routines whose source was COPIED INTO this project
// and adapted into a standalone SW version (NOT pulled as a darknet package): im2col,
// the requant, gemm_nn (conv), gemm_nt (fc transpose), and 2x2 maxpool.  They are the
// bit-exact SW counterpart (== rvx_ssw/darknet gemm.c) that the accelerator is BOTH
// validated against (byte-exact) and profiled against (SW-vs-IP timing).  All integer
// math; no float.  See step2/spec/*.md for the requant/im2col math in full.
// ****************************************************************************

// im2col (== darknet quantized_im2col_cpu_ext): data_im[channels x height x width]
// uint8 -> data_col[K x N], K=channels*kernel_h*kernel_w, N=output_h*output_w.
// FULL geometry (pad / stride / dilation); out-of-bounds taps take input_zeropoint.
// output_h/output_w are derived internally; row r=(ch*kernel_h+kr)*kernel_w+kc.
void sw_im2col(const unsigned char *data_im, int channels, int height, int width,
               int kernel_h, int kernel_w, int pad_h, int pad_w,
               int stride_h, int stride_w, int dilation_h, int dilation_w,
               unsigned char *data_col, int input_zeropoint);

// requant one accumulator to uint8 (== gemm.c quantized epilogue):
//   temp = mm - inzp*Sw - kzp*sin + bias_eff ; prod = temp*M0 (int64) ;
//   round-half-up on bit(RS-1) ; q = (prod >>> RS) + round (ARITHMETIC shift) ;
//   clamp: q>=255->255 ; q<=0->outzp ; else (q+outzp)&0xff.
unsigned char sw_requant(long long mm, long long sin, int M0, int RS, int BIAS,
                         int Sw, int KZP, int inzp, int outzp);

// gemm_nn + requant (conv): mat[K x N] uint8, wt[M x K] int8,
// par = M0|RS|BIAS|Sw|KZP (5 sections of M) -> out[M x N] uint8.
void sw_gemm_nn(const unsigned char *mat, const signed char *wt, const int *par,
                unsigned char *out, int M, int K, int N, int inzp, int outzp);

// gemm_nt + requant (fc transpose): in[K] uint8, wt_T[K x Mpad] int8 (transposed),
// par = M0|RS|BIAS|Sw|KZP (5 sections of M) -> out[M] uint8.
void sw_gemm_nt(const unsigned char *in, const signed char *wt_T, const int *par,
                unsigned char *out, int M, int K, int Mpad, int inzp, int outzp);

// 2x2 stride-2 max pool: src[C x H x W] -> dst[C x H/2 x W/2].
void sw_maxpool(volatile unsigned char *src, volatile unsigned char *dst, int C, int H, int Wd);

#endif
