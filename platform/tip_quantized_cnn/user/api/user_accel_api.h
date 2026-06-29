#ifndef __USER_ACCEL_API_H__
#define __USER_ACCEL_API_H__
// ****************************************************************************
// user_accel_api - driver for the two-IP quantized-CNN accelerator (PROVIDED library)
// Entry points for programming + running the USER_IM2COL_ENGINE and the
// USER_GEMM_REQUANT_ENGINE: low-level register access (acc_rd/acc_wr/acc_run), the
// per-engine config + run helpers, and conv/fc convenience wrappers that chain the two
// engines.  Real base addresses come from the generated memorymap
// (I_IM2COL_CONTROL_BASEADDR / I_GEMM_REQUANT_CONTROL_BASEADDR).
//
// Register model (both engines share the common block):
//   ACC_STATUS  : bit8 done_sticky, bit9 error_sticky
//   ACC_START   : write 1 to launch
//   ACC_CONTROL : bit0 copy-smoke mode, bit31 clear sticky/state
// The remaining offsets are the per-engine geometry/config scalars below.
// ****************************************************************************
#include "platform_info.h"
#include "ervp_mmio_util.h"

// common (both engines)
#define ACC_STATUS    0x00
#define ACC_START     0x08
#define ACC_CONTROL   0x10
#define ACC_DONE_BIT  (1u<<8)
#define ACC_ERR_BIT   (1u<<9)
#define ACC_CTRL_COPY (1u<<0)
#define ACC_CTRL_CLR  (1u<<31)

// USER_IM2COL_ENGINE register offsets
#define IM2COL_SRC      0x18
#define IM2COL_DST      0x20
#define IM2COL_IN_H     0x28
#define IM2COL_IN_W     0x30
#define IM2COL_IN_C     0x38
#define IM2COL_K_H      0x40
#define IM2COL_K_W      0x48
#define IM2COL_PAD_H    0x50
#define IM2COL_PAD_W    0x58
#define IM2COL_STR_H    0x60
#define IM2COL_STR_W    0x68
#define IM2COL_DIL_H    0x70
#define IM2COL_DIL_W    0x78
#define IM2COL_OUT_H    0x80
#define IM2COL_OUT_W    0x88
#define IM2COL_IN_ZP    0x90
#define IM2COL_INBYTES  0x98
#define IM2COL_OUTBYTES 0xA0

// USER_GEMM_REQUANT_ENGINE register offsets
#define GEMM_SRC        0x18   // im2col matrix base (DDR)
#define GEMM_WEIGHT     0x20
#define GEMM_PARAM      0x28
#define GEMM_DST        0x30
#define GEMM_M          0x38
#define GEMM_K          0x40
#define GEMM_N          0x48
#define GEMM_IN_ZP      0x50
#define GEMM_OUT_ZP     0x58
#define GEMM_SRCBYTES   0x60
#define GEMM_WBYTES     0x68
#define GEMM_PBYTES     0x70
#define GEMM_OUTBYTES   0x78
#define GEMM_MODE       0x80   // 0 = conv gemm_nn (broadcast weight) ; 1 = fc gemm_nt (transpose)

// platform instance base addresses
#define ACCEL_IM2COL_BASE I_IM2COL_CONTROL_BASEADDR
#define ACCEL_GEMM_BASE   I_GEMM_REQUANT_CONTROL_BASEADDR

// ---- low-level register access ----
static inline void acc_wr(unsigned int base, unsigned int off, unsigned int val)
{ mmio_write_data(base + off, val); }
static inline unsigned int acc_rd(unsigned int base, unsigned int off)
{ return mmio_read_data(base + off); }

// kick START and busy-wait on done_sticky (completion signal, not state==IDLE);
// returns 1 if the error-sticky bit is set, else 0.
static inline int acc_run(unsigned int base)
{
    acc_wr(base, ACC_START, 1);
    while ((acc_rd(base, ACC_STATUS) & ACC_DONE_BIT) == 0) { }
    return (acc_rd(base, ACC_STATUS) & ACC_ERR_BIT) ? 1 : 0;
}

// physical (bus) address of a SW buffer (engine masters address DRAM physically)
static inline unsigned int accel_paddr(const void *p)
{ return (unsigned int)(unsigned long)p; }

// ---- per-engine config (program the regfile; does NOT launch) ----
void accel_im2col_cfg(unsigned int base, unsigned int src, unsigned int dst,
                      int inh, int inw, int inc, int kh, int kw, int padh, int padw,
                      int strh, int strw, int dilh, int dilw, int outh, int outw,
                      int inzp, int inb, int outb);
void accel_gemm_cfg(unsigned int base, unsigned int src, unsigned int wt, unsigned int par,
                    unsigned int dst, int M, int K, int N, int inzp, int outzp,
                    int srcb, int wb, int pb, int outb, int mode);

// ---- launch helpers (clear sticky/state, then start + await) ----
int accel_run_clr(unsigned int base);    // normal run
int accel_run_copy(unsigned int base);   // copy-smoke run (DDR->BRAM->DDR, no compute)

// ---- one-call run = cfg + clear + start + await ----
int accel_im2col_run(unsigned int base, unsigned int src, unsigned int dst,
                     int inh, int inw, int inc, int kh, int kw, int padh, int padw,
                     int strh, int strw, int dilh, int dilw, int outh, int outw,
                     int inzp, int inb, int outb);
int accel_gemm_run(unsigned int base, unsigned int src, unsigned int wt, unsigned int par,
                   unsigned int dst, int M, int K, int N, int inzp, int outzp,
                   int srcb, int wb, int pb, int outb, int mode);

// ---- conv/fc convenience (chain the engines; uses the platform base macros) ----
// conv layer: im2col(src -> mat_buf) then gemm_nn(mat_buf -> dst).  k = kernel side;
// the GEMM reduction K = inc*k*k.
void accel_conv(unsigned int mat_buf, unsigned int src, unsigned int dst,
                int inc, int inh, int inw, int k, int outh, int outw,
                int inzp, int outzp, const signed char *wt, const int *par, int M, int N);
// fc layer: transpose gemm_nt(src vector -> dst), output features on the lanes.
void accel_fc(unsigned int src, unsigned int dst, const signed char *wt, const int *par,
              int M, int K, int Mpad, int inzp, int outzp);

#endif
