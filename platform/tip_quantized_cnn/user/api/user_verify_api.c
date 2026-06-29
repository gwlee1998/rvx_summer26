// ****************************************************************************
// user_verify_api.c - honest verification + result reporting (PROVIDED).
// See user_verify_api.h.  Word-correct comparison only; never memory_compare().
// ****************************************************************************
#include "ervp_printf.h"
#include "user_verify_api.h"

int verify_compare_u8(const char *name, const unsigned char *got,
                      const unsigned char *expected, int size)
{
    const unsigned int *gw = (const unsigned int *)got;
    const unsigned int *ew = (const unsigned int *)expected;
    int nw = size >> 2, i, b, mism = 0, fi = -1, fg = -1, fe = -1;
    for (i = 0; i < nw; i = i + 1)
        if (gw[i] != ew[i])
            for (b = 0; b < 4; b = b + 1)
            {
                int gb = (gw[i] >> (8*b)) & 0xff;
                int eb = (ew[i] >> (8*b)) & 0xff;
                if (gb != eb) { if (fi < 0) { fi = i*4+b; fg = gb; fe = eb; } mism = mism + 1; }
            }
    for (i = (nw << 2); i < size; i = i + 1)
        if (got[i] != expected[i]) { if (fi < 0) { fi = i; fg = got[i]; fe = expected[i]; } mism = mism + 1; }
    printf("%s %s mism=%d first=%d got=%d exp=%d\n", name, mism ? "FAIL" : "PASS", mism, fi, fg, fe);
    return mism;
}

int verify_expect_change(const char *name, int mism)
{
    if (mism > 0) { printf("%s NEGATIVE_CONTROL_OK mism=%d\n", name, mism); return 0; }
    printf("%s NEGATIVE_CONTROL_BROKEN mism=0\n", name);
    return 1;
}

int verify_count_nonzero(const unsigned char *b, int n)
{ int i, c = 0; for (i = 0; i < n; i = i + 1) if (b[i]) c++; return c; }

int verify_count_diff_u8(const unsigned char *a, const unsigned char *b, int n)
{ int i, c = 0; for (i = 0; i < n; i = i + 1) if (a[i] != b[i]) c++; return c; }

int verify_selftest(const char *tag, const unsigned char *input, int ninput,
                    const unsigned char *golden, int ngolden,
                    const unsigned char *discrim_ref, int ndiscrim)
{
    int nz_in = verify_count_nonzero(input, ninput);
    int nz_g  = verify_count_nonzero(golden, ngolden);
    int lim   = (ngolden < ndiscrim) ? ngolden : ndiscrim;
    int diff  = verify_count_diff_u8(golden, discrim_ref, lim);
    int bad   = 0;
    printf("%s SELFTEST nonzero input=%d golden=%d (expect>0)\n", tag, nz_in, nz_g);
    if (nz_in == 0 || nz_g == 0) { printf("%s SELFTEST_ABORT empty_vector\n", tag); bad = 1; }
    printf("%s SELFTEST discrimination golden_vs_ref diff=%d (expect>0)\n", tag, diff);
    if (diff == 0) { printf("%s SELFTEST_ABORT comparator_cannot_discriminate\n", tag); bad = 1; }
    printf("%s SELFTEST provenance: goldens from the numpy int reference (==rvx_ssw gemm.c)\n", tag);
    return bad;
}

int verify_argmax_u8(volatile unsigned char *v, int n)
{ int i, best = v[0], p = 0; for (i = 1; i < n; i = i + 1) if (v[i] > best) { best = v[i]; p = i; } return p; }

void verify_print_score_table(const char *tag, const unsigned char *sw_scores,
                              const unsigned char *ip_scores, int nclasses)
{
    int order[256], i, j, tmp, psw = 0, pip = 0;
    if (nclasses > 256) nclasses = 256;
    for (i = 0; i < nclasses; i = i + 1) order[i] = i;
    // stable selection sort by IP logit descending, ties broken by class index ascending
    for (i = 0; i < nclasses - 1; i = i + 1)
    {
        int best = i;
        for (j = i + 1; j < nclasses; j = j + 1)
            if (ip_scores[order[j]] > ip_scores[order[best]] ||
                (ip_scores[order[j]] == ip_scores[order[best]] && order[j] < order[best]))
                best = j;
        if (best != i) { tmp = order[i]; order[i] = order[best]; order[best] = tmp; }
    }
    printf("%s SCORES rank class sw_logit ip_logit\n", tag);
    for (i = 0; i < nclasses; i = i + 1)
        printf("%s SCORE %d class=%d sw=%d ip=%d\n", tag, i, order[i],
               sw_scores[order[i]], ip_scores[order[i]]);
    for (i = 1; i < nclasses; i = i + 1)
    {
        if (sw_scores[i] > sw_scores[psw]) psw = i;
        if (ip_scores[i] > ip_scores[pip]) pip = i;
    }
    printf("%s PREDICT sw=%d ip=%d\n", tag, psw, pip);
}

void verify_dump_vs_golden(const char *label, const unsigned char *got,
                           const unsigned char *exp, int n, int lo, int hi)
{
#ifdef DEBUG_DUMP
    int i;
    if (lo < 0) lo = 0;
    if (hi < 0 || hi >= n) hi = n - 1;
    printf("DUMP_BEGIN %s [%d..%d]\n", label, lo, hi);
    for (i = lo; i <= hi; i = i + 1)
        printf("DUMP %s %d got=%d exp=%d%s\n", label, i, got[i], exp[i], (got[i] != exp[i]) ? " DIFF" : "");
    printf("DUMP_END %s\n", label);
#else
    (void)label; (void)got; (void)exp; (void)n; (void)lo; (void)hi;
#endif
}
