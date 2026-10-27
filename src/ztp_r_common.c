/* ztp_r_common.c -- raising conditions, and zutempo_info()'s native part. */

#include "ztp_r.h"
#include "ztp_probe.h"

#include <math.h>
#include <stdarg.h>
#include <stdio.h>

void ztp_r_raise(const ztp_ctx *ctx)
{
    /* stop_zutempo(message, kind, index, position = ) in the package
       namespace. The index and the position travel as doubles so that long
       vectors and strings are covered; R turns 0 into NULL. */
    SEXP name = PROTECT(Rf_mkString("zutempo"));
    SEXP ns = PROTECT(R_FindNamespace(name));
    /* The message quotes inputs read with Rf_translateCharUTF8(), and
       ztp_fail() keeps it valid UTF-8, so it is marked as such. */
    SEXP message = PROTECT(Rf_ScalarString(Rf_mkCharCE(ctx->msg, CE_UTF8)));
    SEXP kind = PROTECT(Rf_mkString(ztp_status_kind(ctx->status)));
    SEXP index = PROTECT(Rf_ScalarReal((double)ctx->index));
    SEXP position = PROTECT(Rf_ScalarReal((double)ctx->position));
    SEXP call = PROTECT(Rf_lang5(Rf_install("stop_zutempo"), message, kind,
                                 index, position));
    SET_TAG(CDR(CDR(CDR(CDR(call)))), Rf_install("position"));
    Rf_eval(call, ns);
    /* Not reached: stop_zutempo() signals an error. Unprotect for form. */
    UNPROTECT(7);
    Rf_error("zutempo: stop_zutempo() returned");
}

void ztp_r_type_error(R_xlen_t index, const char *fmt, ...)
{
    char buf[ZTP_MSG_CAP];
    va_list ap;
    ztp_ctx ctx;

    va_start(ap, fmt);
    vsnprintf(buf, sizeof buf, fmt, ap);
    va_end(ap);
    ztp_ctx_init(&ctx);
    ztp_fail(&ctx, ZTP_ERR_TYPE, (size_t)index, "%s", buf);
    ztp_r_raise(&ctx);
}

R_xlen_t ztp_r_arg(SEXP x, SEXPTYPE type, R_xlen_t n, const char *name)
{
    R_xlen_t len;

    if (TYPEOF(x) != type)
        ztp_r_type_error(0, "internal: `%s` must be of type %s, not %s", name,
                         Rf_type2char(type), Rf_type2char(TYPEOF(x)));
    len = XLENGTH(x);
    if (n >= 0 && len != n)
        ztp_r_type_error(0, "internal: `%s` must have length %.0f, not %.0f", name, (double)n,
                         (double)len);
    return len;
}

void ztp_r_arg_or_null(SEXP x, SEXPTYPE type, R_xlen_t n, const char *name)
{
    if (x != R_NilValue) ztp_r_arg(x, type, n, name);
}

void ztp_r_scalar(SEXP x, const char *name)
{
    SEXPTYPE t = TYPEOF(x);
    if ((t != LGLSXP && t != INTSXP && t != REALSXP) || XLENGTH(x) != 1)
        ztp_r_type_error(0, "internal: `%s` must be a single number", name);
}

int ztp_r_option_int(SEXP x, const char *name)
{
    ztp_r_scalar(x, name);
    return Rf_asInteger(x);
}

double ztp_r_option_real(SEXP x, const char *name)
{
    ztp_r_scalar(x, name);
    return Rf_asReal(x);
}

R_xlen_t ztp_r_duration_arg(SEXP list, R_xlen_t n, const char *name)
{
    if (TYPEOF(list) != VECSXP || XLENGTH(list) != ZTP_DURATION_FIELDS)
        ztp_r_type_error(0, "`%s` is not a valid duration(): it must be a list of %d fields",
                         name, ZTP_DURATION_FIELDS);
    if (n < 0) n = Rf_xlength(VECTOR_ELT(list, 0));
    for (int f = 0; f < ZTP_DURATION_FIELDS; f++) {
        SEXP field = VECTOR_ELT(list, f);
        if (TYPEOF(field) != REALSXP || XLENGTH(field) != n)
            ztp_r_type_error(0,
                             "`%s` is not a valid duration(): its fields must be doubles of "
                             "one length",
                             name);
    }
    return n;
}

R_xlen_t ztp_r_zoned_arg(SEXP x, SEXP codes, SEXP zones, R_xlen_t n)
{
    R_xlen_t len;

    if (TYPEOF(x) != CPLXSXP || (n >= 0 && XLENGTH(x) != n))
        ztp_r_type_error(0, "internal: a zoned value must be a complex vector%s",
                         n >= 0 ? " of the common length" : "");
    len = XLENGTH(x);
    ztp_r_zone_codes_arg(codes, zones, len);
    return len;
}

void ztp_r_zone_codes_arg(SEXP codes, SEXP zones, R_xlen_t len)
{
    R_xlen_t nz;
    const int *pc;

    if (TYPEOF(zones) != STRSXP)
        ztp_r_type_error(0, "the value is not a valid %s: its zone table is not a character vector",
                         "zoned_date_time()");
    nz = XLENGTH(zones);
    for (R_xlen_t k = 0; k < nz; k++)
        if (STRING_ELT(zones, k) == NA_STRING)
            ztp_r_type_error(0, "the value is not a valid %s: its zone table holds NA",
                             "zoned_date_time()");
    if (TYPEOF(codes) != INTSXP || XLENGTH(codes) != len)
        ztp_r_type_error(0,
                         "the value is not a valid %s: its zone codes must be an integer "
                         "vector of its length",
                         "zoned_date_time()");
    pc = INTEGER(codes);
    for (R_xlen_t i = 0; i < len; i++)
        if (pc[i] != NA_INTEGER && (pc[i] < 1 || pc[i] > nz))
            ztp_r_type_error(i + 1, "the value is not a valid %s: its zone code is out of range",
                             "zoned_date_time()");
}

SEXP ztp_r_info(void)
{
    const char *names[] = {"zufast", "int128", ""};
    SEXP out = PROTECT(Rf_mkNamed(VECSXP, names));
    SET_VECTOR_ELT(out, 0, Rf_mkString(ztp_probe_zufast_version()));
    SET_VECTOR_ELT(out, 1, Rf_ScalarLogical(ztp_probe_have_int128()));
    UNPROTECT(1);
    return out;
}
