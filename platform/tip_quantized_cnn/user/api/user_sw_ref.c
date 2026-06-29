// ****************************************************************************
// user_sw_ref.c - SW reference layer math (PROVIDED).  See user_sw_ref.h.
// Adapted from the darknet quantized routines into a standalone, dependency-free SW
// version; bit-exact with rvx_ssw/darknet gemm.c and with the RTL accelerator.
//
// THIS FILE IS THE STEP-2 COMPUTE CONTRACT.  It GENERATES the golden, so reproducing
// it in RTL == byte-exact grading:  USER_IM2COL_COMPUTE must reproduce sw_im2col;
// USER_GEMM_REQUANT_COMPUTE must reproduce sw_gemm_nn (conv) / sw_gemm_nt (fc) + sw_requant.
//
// Operand routing (each MAC lane = signed weight x unsigned activation):
//   conv (gemm_nn): ONE weight broadcast to all lanes  x  per-lane activation column.
//   fc   (gemm_nt): per-lane W^T column (feature f = column f)  x  ONE broadcast input.
//                   W^T is the transposed weight; its row pitch Mpad = round-up of M.
//
// RTL packing: in hardware the three operand arrays are ONE word-addressed input BRAM
// (4 uint8/word): im2col/input @ word 0 | weights or W^T @ w_off | param blob @ p_off.
// The param blob is 5 int32 sections, one entry per output channel (conv) / feature (fc):
//   [0] M0   [1] right_shift   [2] bias_eff   [3] Sigma_w   [4] kernel_zp
// bias_eff already folds (raw_bias + N*in_zp*kernel_zp), so sw_requant adds NO separate
// N*in_zp*kzp term.  Sigma_w (sum of the output's weights) is precomputed here in the
// blob; Sigma_in (sum of the activations) is accumulated by the MAC at run time
// (sigma_in_flat).  Hence a single requant lane accumulates NEITHER -- it only reads them.
// (This LeNet is symmetric => kernel_zp = 0, so the kzp terms vanish; the path stays
// general and is byte-exact for kernel_zp != 0 as well.)
// ****************************************************************************
#include "user_sw_ref.h"

// unsigned trick: true iff 0 <= a < b  (darknet is_a_ge_zero_and_a_lt_b)
static int is_a_ge_zero_and_a_lt_b(int a, int b) { return (unsigned)a < (unsigned)b; }

// == darknet quantized_im2col_cpu_ext (the ported reference): general pad/stride/
// dilation; out-of-bounds taps emit input_zeropoint.  data_col is written sequentially
// (row r=(channel*kernel_h+kernel_row)*kernel_w+kernel_col, cols = output_h*output_w).
void sw_im2col(const unsigned char *data_im, int channels, int height, int width,
               int kernel_h, int kernel_w, int pad_h, int pad_w,
               int stride_h, int stride_w, int dilation_h, int dilation_w,
               unsigned char *data_col, int input_zeropoint)
{
    const int output_h = (height + 2*pad_h - (dilation_h*(kernel_h-1)+1)) / stride_h + 1;
    const int output_w = (width  + 2*pad_w - (dilation_w*(kernel_w-1)+1)) / stride_w + 1;
    const int channel_size = height * width;
    int channel, kernel_row, kernel_col, output_rows, output_col;
    for (channel = channels; channel--; data_im += channel_size) {
        for (kernel_row = 0; kernel_row < kernel_h; kernel_row++) {
            for (kernel_col = 0; kernel_col < kernel_w; kernel_col++) {
                int input_row = -pad_h + kernel_row * dilation_h;
                for (output_rows = output_h; output_rows; output_rows--) {
                    if (!is_a_ge_zero_and_a_lt_b(input_row, height)) {
                        for (output_col = output_w; output_col; output_col--)
                            *(data_col++) = (unsigned char)input_zeropoint;
                    } else {
                        int input_col = -pad_w + kernel_col * dilation_w;
                        for (output_col = output_w; output_col; output_col--) {
                            if (is_a_ge_zero_and_a_lt_b(input_col, width))
                                *(data_col++) = data_im[input_row * width + input_col];
                            else
                                *(data_col++) = (unsigned char)input_zeropoint;
                            input_col += stride_w;
                        }
                    }
                    input_row += stride_h;
                }
            }
        }
    }
}

// requant ONE accumulator (one output element) to uint8 -- the per-lane HW model
// (RVX_REQUANT_LANE).  mm = the K-reduction MAC ; sin = Sigma_in (Sum of activations,
// from the MAC) ; Sw = Sigma_w (from the param blob) ; BIAS = bias_eff (see header).
//   temp = mm - in_zp*Sw - kernel_zp*sin + bias_eff           (signed)
//   prod = temp * M0  (int64) ; round-half-up on bit(RS-1) ;
//   q    = (prod >>> RS) + round   (>>> = ARITHMETIC/signed shift -- logical is WRONG
//          for negative outputs) ;
//   clamp: q>=255 -> 255 ; q<=0 -> out_zp ; else (q + out_zp) & 0xFF.
unsigned char sw_requant(long long mm, long long sin, int M0, int RS, int BIAS,
                         int Sw, int KZP, int inzp, int outzp)
{
    long long temp = mm - (long long)inzp*Sw - (long long)KZP*sin + BIAS;
    long long prod = temp * (long long)M0;
    long long q;
    if (M0 == 0 || RS >= 63) q = 0;
    else { long long add = (prod >> (RS-1)) & 1LL; q = (prod >> RS) + add; }   // arithmetic shift (signed)
    if (q >= 255) return 255;
    if (q <= 0)   return (unsigned char)outzp;
    return (unsigned char)((q + outzp) & 0xff);
}

// conv (gemm_nn) + requant: mat[K x N] uint8, wt[M x K] int8, par = 5 sections of M
// (M0|right_shift|bias_eff|Sigma_w|kernel_zp) -> out[M x N] uint8.  The inner K-loop is
// the MAC's job (mm += weight*act ; sin += act); sw_requant is the per-lane epilogue.
// Output channel m is the broadcast weight; output pixel n is the per-lane activation.
void sw_gemm_nn(const unsigned char *mat, const signed char *wt, const int *par,
                unsigned char *out, int M, int K, int N, int inzp, int outzp)
{
    int m, n, kk;
    for (m = 0; m < M; m = m + 1)
    {
        int M0 = par[m], RS = par[M+m], BIAS = par[2*M+m], Sw = par[3*M+m], KZP = par[4*M+m];
        for (n = 0; n < N; n = n + 1)
        {
            long long mm = 0, sin = 0;
            for (kk = 0; kk < K; kk = kk + 1) { int a = mat[kk*N+n]; mm += (long long)wt[m*K+kk]*a; sin += a; }
            out[m*N+n] = sw_requant(mm, sin, M0, RS, BIAS, Sw, KZP, inzp, outzp);
        }
    }
}

// fc (gemm_nt, transpose) + requant: in[K] uint8, wt_T[K x Mpad] int8 (transposed so
// feature f is column f), par = 5 sections of M -> out[M] uint8.  Per feature f:
// mm = Sum_k wt_T[k*Mpad+f]*in[k] ; sin = Sum_k in[k] ; then the same sw_requant.
void sw_gemm_nt(const unsigned char *in, const signed char *wt_T, const int *par,
                unsigned char *out, int M, int K, int Mpad, int inzp, int outzp)
{
    int f, kk;
    for (f = 0; f < M; f = f + 1)
    {
        int M0 = par[f], RS = par[M+f], BIAS = par[2*M+f], Sw = par[3*M+f], KZP = par[4*M+f];
        long long mm = 0, sin = 0;
        for (kk = 0; kk < K; kk = kk + 1) { int a = in[kk]; mm += (long long)wt_T[kk*Mpad+f]*a; sin += a; }
        out[f] = sw_requant(mm, sin, M0, RS, BIAS, Sw, KZP, inzp, outzp);
    }
}

void sw_maxpool(volatile unsigned char *src, volatile unsigned char *dst, int C, int H, int Wd)
{
    int c, oh, ow, oH = H/2, oW = Wd/2;
    for (c = 0; c < C; c = c + 1)
        for (oh = 0; oh < oH; oh = oh + 1)
            for (ow = 0; ow < oW; ow = ow + 1)
            {
                int b = c*H*Wd + (2*oh)*Wd + (2*ow);
                unsigned char a = src[b], bb = src[b+1], cc = src[b+Wd], dd = src[b+Wd+1], m = a;
                if (bb > m) m = bb;
                if (cc > m) m = cc;
                if (dd > m) m = dd;
                dst[c*oH*oW + oh*oW + ow] = m;
            }
}
