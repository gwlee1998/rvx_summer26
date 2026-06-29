#!/bin/bash
# run_tb.sh <im2col|gemm> <answer|skeleton> [DEBUG]
# Compiles the chosen compute module + the provided infra + the standalone TB and runs it.
#   answer   -> step2/answer/   (expected: ALL_PASS)
#   skeleton -> step2/skeleton/ (expected: FAIL -- blanks are real)
# DEBUG adds +define+DEBUG_DUMP (writes <tb>_dump.txt). Run from anywhere.
set -e
TB="$1"; WHICH="${2:-skeleton}"; DBG="$3"
HERE="$(cd "$(dirname "$0")" && pwd)"          # step2/tb
SRC="$HERE/../../../rtl/src"
CMP="$HERE/../$WHICH"
[ -d "$CMP" ] || { echo "no such dir: $CMP (use answer|skeleton)"; exit 1; }
source /home/gwlee/rvx_quantized_darknet/npx-tutorials/rvx_setup.sh >/dev/null 2>&1 || true
cd "$HERE"
rm -rf work; vlib work >/dev/null 2>&1
DEF=""; [ "$DBG" = "DEBUG" ] && DEF="+define+DEBUG_DUMP"
case "$TB" in
  im2col)
    vlog -quiet +incdir+golden $DEF \
        "$SRC/user_bram.v" "$CMP/user_im2col_compute.v" "$HERE/tb_im2col_compute.v" >/dev/null
    vsim -c -quiet -do "run -all; quit" tb_im2col_compute ;;
  gemm)
    vlog -quiet +incdir+golden $DEF \
        "$SRC/user_bram.v" "$SRC/user_mac_array.v" "$SRC/user_gemm_core.v" \
        "$CMP/user_requant_lane.v" "$CMP/user_gemm_requant_compute.v" "$HERE/tb_gemm_requant_compute.v" >/dev/null
    vsim -c -quiet -do "run -all; quit" tb_gemm_requant_compute ;;
  *) echo "usage: run_tb.sh <im2col|gemm> <answer|skeleton> [DEBUG]"; exit 1 ;;
esac
