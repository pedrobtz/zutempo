/* ztp_r_probe.c -- .Call glue for the stage 1 probe (ztp_probe.h). */

#include "ztp_r.h"
#include "ztp_probe.h"

SEXP ztp_r_probe_civil(SEXP days)
{
    R_xlen_t n = Rf_xlength(days);
    const double *x = REAL(days);
    const char *names[] = {"year", "month", "day", ""};
    SEXP out = PROTECT(Rf_mkNamed(VECSXP, names));
    SEXP year = SET_VECTOR_ELT(out, 0, Rf_allocVector(INTSXP, n));
    SEXP month = SET_VECTOR_ELT(out, 1, Rf_allocVector(INTSXP, n));
    SEXP day = SET_VECTOR_ELT(out, 2, Rf_allocVector(INTSXP, n));
    int *py = INTEGER(year), *pm = INTEGER(month), *pd = INTEGER(day);
    ztp_ctx ctx;

    ztp_ctx_init(&ctx);
    for (R_xlen_t i = 0; i < n; i++) {
        int32_t y;
        uint32_t m, d;

        if (ISNAN(x[i])) {
            py[i] = pm[i] = pd[i] = NA_INTEGER;
            continue;
        }
        if (ztp_probe_civil(&ctx, x[i], (size_t)i + 1, &y, &m, &d) != ZTP_OK)
            ztp_r_raise(&ctx);
        py[i] = (int)y;
        pm[i] = (int)m;
        pd[i] = (int)d;
    }
    UNPROTECT(1);
    return out;
}

SEXP ztp_r_probe_mul(SEXP a, SEXP b)
{
    R_xlen_t n = Rf_xlength(a);
    const double *pa = REAL(a), *pb = REAL(b);
    SEXP out = PROTECT(Rf_allocVector(STRSXP, n));
    ztp_ctx ctx;

    ztp_ctx_init(&ctx);
    for (R_xlen_t i = 0; i < n; i++) {
        char buf[ZTP_PROBE_DECIMAL_CAP];

        if (ISNAN(pa[i]) || ISNAN(pb[i])) {
            SET_STRING_ELT(out, i, NA_STRING);
            continue;
        }
        if (ztp_probe_mul(&ctx, pa[i], pb[i], (size_t)i + 1, buf) != ZTP_OK)
            ztp_r_raise(&ctx);
        SET_STRING_ELT(out, i, Rf_mkChar(buf));
    }
    UNPROTECT(1);
    return out;
}

SEXP ztp_r_probe_fail(SEXP kind, SEXP index)
{
    ztp_ctx ctx;

    ztp_ctx_init(&ctx);
    ztp_probe_fail(&ctx, CHAR(STRING_ELT(kind, 0)),
                   (size_t)REAL(index)[0]);
    ztp_r_raise(&ctx);
}
