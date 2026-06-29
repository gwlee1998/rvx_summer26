#ifndef __USER_VERIFY_API_H__
#define __USER_VERIFY_API_H__
// ****************************************************************************
// user_verify_api - honest verification + result reporting (PROVIDED library)
// The anti-false-pass tooling shared by every app: a full-byte word-correct
// comparator (reports first mismatch), a comparator-integrity self-test, the
// negative-control "expect change" check, argmax, a full class-score result table,
// and a DEBUG_DUMP helper to eyeball a result vs its golden.  No memory_compare()
// (which false-passed historically) -- only direct byte-correct comparison.
//
// NOTE: the SW reference layer math (im2col / gemm / requant / maxpool) lives in
// user_sw_ref.h, not here.
// ****************************************************************************

// honest compare: scan 32-bit words (DRAM is word-addressed), report first mismatch.
// Returns the mismatch count (0 == byte-exact).  Prints "<name> PASS|FAIL ...".
int verify_compare_u8(const char *name, const unsigned char *got,
                      const unsigned char *expected, int size);

// negative control: a non-zero mismatch is REQUIRED (the mutation must change output).
// Returns 0 if the control behaved (mism>0), 1 if broken (mism==0).
int verify_expect_change(const char *name, int mism);

// count nonzero bytes / differing bytes (self-test primitives)
int verify_count_nonzero(const unsigned char *b, int n);
int verify_count_diff_u8(const unsigned char *a, const unsigned char *b, int n);

// comparator-integrity self-test: input + golden must be non-empty AND the golden must
// differ from a reference vector (else the comparator/goldens cannot discriminate).
// Prints the SELFTEST lines; returns non-zero (bad) if any check fails.
int verify_selftest(const char *tag, const unsigned char *input, int ninput,
                    const unsigned char *golden, int ngolden,
                    const unsigned char *discrim_ref, int ndiscrim);

// argmax over n uint8 (first max wins -> stable, tie by lowest index)
int verify_argmax_u8(volatile unsigned char *v, int n);

// result table: print all nclasses with their uint8 logit, ranked high->low (stable,
// ties by class index), for BOTH the SW and IP results, plus each predicted class.
void verify_print_score_table(const char *tag, const unsigned char *sw_scores,
                              const unsigned char *ip_scores, int nclasses);

// DEBUG_DUMP helper (no-op unless compiled with -DDEBUG_DUMP): print got vs golden for
// bytes [lo..hi] (lo<0 / hi<0 -> full range) so a PASS can be independently inspected.
void verify_dump_vs_golden(const char *label, const unsigned char *got,
                           const unsigned char *exp, int n, int lo, int hi);

#endif
