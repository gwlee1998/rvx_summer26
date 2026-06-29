# Quantized-CNN accelerator lab — 3 stages

You build the **compute logic** of a quantized LeNet-5 accelerator and run the whole
network on the platform. Everything else (the engine shells, DMA, tile sequencer, APB
regfile, BRAM, the MAC array + core, the SW driver/verify/reference library, the goldens,
the testbenches) is **provided**. All integer math; byte-exact grading.

```
USER_IM2COL_ENGINE       → USER_IM2COL_COMPUTE         (STEP 2, 40 pt — you write it)
USER_GEMM_REQUANT_ENGINE → USER_GEMM_REQUANT_COMPUTE   (STEP 2, 40 pt — you write it)
                             ├ USER_GEMM_CORE → USER_MAC_ARRAY     (provided)
                             └ USER_REQUANT_LANE  (x PE_RQ)        (STEP 2, 20 pt — you write it)
```

The single source for *what to compute* is the provided SW reference
`user/api/user_sw_ref.c` — it generates the golden, so byte-exact grading == reproducing it:
`sw_im2col` ⇒ USER_IM2COL_COMPUTE, `sw_gemm_nn`/`sw_gemm_nt` ⇒ USER_GEMM_REQUANT_COMPUTE,
`sw_requant` ⇒ USER_REQUANT_LANE.

## STEP 1 — analysis (read & report)

Read the provided source: the SW reference `user/api/user_sw_ref.c` (+ `.h`) for the math,
and the engine shells + infra modules under `user/rtl/src` (each file's header describes its
role / ports / behavior). Write an analysis report: the data flow
(DDR→DMA→BRAM→compute→BRAM→DDR), each provided RTL module's role, each provided/ported SW
function, and the im2col + requant math. Everything you need is in those files — no external
darknet reading.

## STEP 2 — unit build (implement + self-check)

Implement the body of each student module from its frozen ports + the contract in
`user/api/user_sw_ref.c`:
* `user/misc/step2/skeleton/user_im2col_compute.v`        — 40 pt
* `user/misc/step2/skeleton/user_gemm_requant_compute.v`  — 40 pt (compute-control)
* `user/misc/step2/skeleton/user_requant_lane.v`          — 20 pt (per-element requant)

The compute-control drives the two sub-cores (the provided USER_GEMM_CORE + your
USER_REQUANT_LANE, both instantiated in the skeleton as scaffold) and sequences the
NP = PE_N/PE_RQ requant passes. Validate with the provided self-checking testbench (drives
the frozen seam through BRAM models; byte-exact vs golden; prints PASS/FAIL + first mismatch):

```
cd user/misc/step2/tb
./run_tb.sh im2col skeleton      # your im2col core
./run_tb.sh gemm   skeleton      # your gemm-control + requant lane (compiled together)
```

A correct module prints `TB_..._COMPUTE: ALL_PASS`. Submit that log. Debug an intermediate
divergence with the dump (writes `<tb>_dump.txt`, produced vs golden):

```
./run_tb.sh gemm skeleton DEBUG
```

(`run_tb.sh <im2col|gemm> <answer|skeleton> [DEBUG]` — `answer` runs the reference; you work
in `skeleton`.)

## STEP 3 — integration (run the whole accelerator)

Drop your finished modules into `user/rtl/src/` (replacing the skeleton bodies the engines
instantiate), then run the full system:

```
cd sim_rtl
make prepost_lenet      # full LeNet-5, both samples, per-layer byte-exact + negative controls
make prepost_profile    # SW-vs-IP timing: per-conv im2col/gemm breakdown + whole-network
                        # end-to-end total + the 10-class result table (all in us)
make prepost_conv2      # focused conv2 gate suite
```

`LENET_ALL_PASS` = every layer byte-exact for both samples. The profile prints each
accelerated (layer,step) row byte-exact, the end-to-end SW-vs-IP total, and the full ranked
10-class score table for SW and IP.

## Provided vs graded

| | provided (do not edit) | graded (you write) |
|---|---|---|
| RTL | engine shells, USER_APB_REGFILE, USER_AXI_DMA, USER_TILE_SEQ, USER_BRAM, USER_MAC_ARRAY, USER_GEMM_CORE | USER_IM2COL_COMPUTE (40), USER_GEMM_REQUANT_COMPUTE (40), USER_REQUANT_LANE (20) |
| SW | user_accel_api, user_verify_api, user_sw_ref, the apps | — |
| infra | standalone TBs + goldens, DEBUG_DUMP, result table | — |

Total **100 pt** = im2col 40 + gemm compute-control 40 + requant lane 20.

## Conventions & RTL gotchas

* RTL style: **Verilog-1995, no functions**; 4-space indent, no tabs.
* The contract (what to compute) is `user/api/user_sw_ref.c`. Gotchas NOT in the C:
  1-cycle registered BRAM read latency; clean 1-cycle output write pulse; the requant
  right-shift is ARITHMETIC (signed); derive NP = PE_N/PE_RQ yourself.
* Default `(PE_N, PE_RQ) = (64, 16)`.
