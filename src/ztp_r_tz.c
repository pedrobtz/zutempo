/*
 * ztp_r_tz.c -- .Call glue for the time zone database (design 8). The R
 * side finds the files and reads their bytes; the engine parses and caches.
 */

#include "ztp_r.h"
#include "ztp_tz.h"

#include <string.h>

SEXP ztp_r_tz_load(SEXP id, SEXP bytes)
{
    ztp_ctx ctx;

    ztp_ctx_init(&ctx);
    if (ztp_tz_cache_put(&ctx, 0, Rf_translateCharUTF8(STRING_ELT(id, 0)), RAW(bytes),
                         (size_t)Rf_xlength(bytes)) != ZTP_OK)
        ztp_r_raise(&ctx);
    return R_NilValue;
}

SEXP ztp_r_tz_reset(void)
{
    ztp_tz_cache_reset();
    return R_NilValue;
}

SEXP ztp_r_tz_loaded(SEXP id)
{
    return Rf_ScalarLogical(ztp_tz_cache_find(Rf_translateCharUTF8(STRING_ELT(id, 0))) != NULL);
}

static const ztp_tz_entry *ztp_r_tz_entry(SEXP id)
{
    const ztp_tz_entry *e = ztp_tz_cache_find(Rf_translateCharUTF8(STRING_ELT(id, 0)));
    if (e == NULL) Rf_error("zutempo: time zone is not loaded");
    return e;
}

/* The offset, DST flag and abbreviation at epoch seconds. */
SEXP ztp_r_tz_utoff(SEXP id, SEXP seconds)
{
    const ztp_tz_entry *e = ztp_r_tz_entry(id);
    R_xlen_t n = Rf_xlength(seconds);
    const double *p = REAL(seconds);
    const char *names[] = {"utoff", "isdst", "abbr", ""};
    SEXP out = PROTECT(Rf_mkNamed(VECSXP, names));
    SEXP utoff = SET_VECTOR_ELT(out, 0, Rf_allocVector(INTSXP, n));
    SEXP isdst = SET_VECTOR_ELT(out, 1, Rf_allocVector(LGLSXP, n));
    SEXP abbr = SET_VECTOR_ELT(out, 2, Rf_allocVector(STRSXP, n));

    for (R_xlen_t i = 0; i < n; i++) {
        bool dst;
        const char *a;
        if (ISNAN(p[i])) {
            INTEGER(utoff)[i] = NA_INTEGER;
            LOGICAL(isdst)[i] = NA_LOGICAL;
            SET_STRING_ELT(abbr, i, NA_STRING);
            continue;
        }
        INTEGER(utoff)[i] = ztp_tz_utoff_at(&e->data, (int64_t)p[i], &dst, &a);
        LOGICAL(isdst)[i] = dst;
        SET_STRING_ELT(abbr, i, Rf_mkCharCE(a, CE_UTF8));
    }
    UNPROTECT(1);
    return out;
}

/* The candidates for local date-times: a list of instant vectors. */
SEXP ztp_r_tz_possible(SEXP id, SEXP days, SEXP ns)
{
    const ztp_tz_entry *e = ztp_r_tz_entry(id);
    R_xlen_t n = Rf_xlength(days);
    SEXP out = PROTECT(Rf_allocVector(VECSXP, n));

    for (R_xlen_t i = 0; i < n; i++) {
        zuf_i128 cands[2];
        int k = ztp_tz_possible_epoch_ns(&e->data, INTEGER(days)[i], (int64_t)REAL(ns)[i], cands);
        SEXP v = PROTECT(Rf_allocVector(CPLXSXP, k));
        for (int j = 0; j < k; j++) ztp_epoch_ns_split(cands[j], &COMPLEX(v)[j].r, &COMPLEX(v)[j].i);
        SET_VECTOR_ELT(out, i, v);
        UNPROTECT(1);
    }
    UNPROTECT(1);
    return out;
}

/* The next (direction 1) or previous (-1) transition after each instant. */
SEXP ztp_r_tz_transition(SEXP id, SEXP x, SEXP direction)
{
    const ztp_tz_entry *e = ztp_r_tz_entry(id);
    R_xlen_t n = Rf_xlength(x);
    const Rcomplex *p = COMPLEX(x);
    int dir = Rf_asInteger(direction);
    SEXP out = PROTECT(Rf_allocVector(CPLXSXP, n));
    const int64_t limit = (int64_t)ZTP_MAX_EPOCH_DAY * 86400;

    for (R_xlen_t i = 0; i < n; i++) {
        int64_t t, found;
        bool ok;
        if (ISNAN(p[i].r)) {
            COMPLEX(out)[i].r = NA_REAL;
            COMPLEX(out)[i].i = NA_REAL;
            continue;
        }
        /* A transition is a whole second; the instant's nanoseconds decide
           which side of a transition at that second it is on. */
        t = (int64_t)p[i].r;
        ok = dir > 0 ? ztp_tz_next_transition(&e->data, t, limit, &found)
                     : ztp_tz_previous_transition(&e->data, p[i].i > 0 ? t + 1 : t, limit, &found);
        if (!ok) {
            COMPLEX(out)[i].r = NA_REAL;
            COMPLEX(out)[i].i = NA_REAL;
        } else {
            COMPLEX(out)[i].r = (double)found;
            COMPLEX(out)[i].i = 0;
        }
    }
    UNPROTECT(1);
    return out;
}

SEXP ztp_r_tz_last_explicit(SEXP id)
{
    const ztp_tz_entry *e = ztp_r_tz_entry(id);
    int64_t t;
    return Rf_ScalarReal(ztp_tz_last_explicit(&e->data, &t) ? (double)t : NA_REAL);
}

SEXP ztp_r_tz_links_version(void)
{
    return Rf_mkString(ztp_tz_links_version);
}

SEXP ztp_r_tz_link_target(SEXP ids)
{
    R_xlen_t n = Rf_xlength(ids);
    SEXP out = PROTECT(Rf_allocVector(STRSXP, n));

    for (R_xlen_t i = 0; i < n; i++) {
        const char *t = STRING_ELT(ids, i) == NA_STRING ? NULL
                        : ztp_tz_link_target(Rf_translateCharUTF8(STRING_ELT(ids, i)));
        SET_STRING_ELT(out, i, t ? Rf_mkCharCE(t, CE_UTF8) : NA_STRING);
    }
    UNPROTECT(1);
    return out;
}

/* Parse a TZ string and report the offsets it gives at epoch seconds, for
   tests of the rule engine on strings no fixture carries. */
SEXP ztp_r_tz_rule_utoff(SEXP rule, SEXP seconds)
{
    ztp_ctx ctx;
    ztp_tz_data data;
    const char *s = Rf_translateCharUTF8(STRING_ELT(rule, 0));
    R_xlen_t n = Rf_xlength(seconds);
    SEXP out = PROTECT(Rf_allocVector(INTSXP, n));

    ztp_ctx_init(&ctx);
    memset(&data, 0, sizeof data);
    if (ztp_tz_posix_parse(&ctx, 0, s, strlen(s), &data.footer) != ZTP_OK) ztp_r_raise(&ctx);
    data.has_footer = true;
    for (R_xlen_t i = 0; i < n; i++)
        INTEGER(out)[i] = ztp_tz_utoff_at(&data, (int64_t)REAL(seconds)[i], NULL, NULL);
    UNPROTECT(1);
    return out;
}
