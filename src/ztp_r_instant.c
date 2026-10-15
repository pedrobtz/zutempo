/*
 * ztp_r_instant.c -- .Call glue for Instant (design 4.1: a complex value
 * of integral epoch seconds and nanoseconds in [0, 10^9)).
 */

#include "ztp_r.h"
#include "ztp_instant.h"
#include "ztp_parse.h"
#include "ztp_relative.h"

#include <math.h>
#include <string.h>

static bool ztp_r_instant_get(const Rcomplex *p, R_xlen_t i, zuf_i128 *ns)
{
    if (ISNAN(p[i].r)) return false;
    *ns = ztp_epoch_ns_join(p[i].r, p[i].i);
    return true;
}

static void ztp_r_instant_put(Rcomplex *p, R_xlen_t i, zuf_i128 ns)
{
    ztp_epoch_ns_split(ns, &p[i].r, &p[i].i);
}

static void ztp_r_instant_put_na(Rcomplex *p, R_xlen_t i)
{
    p[i].r = NA_REAL;
    p[i].i = NA_REAL;
}

static void ztp_r_instant_check(ztp_ctx *ctx, size_t index, zuf_i128 ns)
{
    if (!ztp_is_valid_epoch_ns(ns)) {
        ztp_fail(ctx, ZTP_ERR_RANGE, index, "the instant is outside the representable range");
        ztp_r_raise(ctx);
    }
}

SEXP ztp_r_instant_parse(SEXP x)
{
    R_xlen_t n = Rf_xlength(x);
    SEXP out = PROTECT(Rf_allocVector(CPLXSXP, n));
    Rcomplex *po = COMPLEX(out);
    ztp_ctx ctx;

    ztp_ctx_init(&ctx);
    for (R_xlen_t i = 0; i < n; i++) {
        ztp_parsed p;
        ztp_iso_date d;
        zuf_i128 ns;
        const char *s;

        if (STRING_ELT(x, i) == NA_STRING) {
            ztp_r_instant_put_na(po, i);
            continue;
        }
        s = Rf_translateCharUTF8(STRING_ELT(x, i));
        if (ztp_parse(&ctx, (size_t)i + 1, s, strlen(s), ZTP_PARSE_INSTANT, &p, NULL) != ZTP_OK)
            ztp_r_raise(&ctx);
        d.year = p.year;
        d.month = p.month;
        d.day = p.day;
        if (ztp_instant_from_local(&ctx, (size_t)i + 1, ztp_epoch_day_from_iso_date(&d),
                                   ztp_ns_from_iso_time(&p.time),
                                   p.has_z ? 0 : p.offset_ns, &ns) != ZTP_OK)
            ztp_r_raise(&ctx);
        ztp_r_instant_put(po, i, ns);
    }
    UNPROTECT(1);
    return out;
}

SEXP ztp_r_instant_from_epoch_ms(SEXP ms)
{
    R_xlen_t n = Rf_xlength(ms);
    const double *p = REAL(ms);
    SEXP out = PROTECT(Rf_allocVector(CPLXSXP, n));
    Rcomplex *po = COMPLEX(out);
    ztp_ctx ctx;

    ztp_ctx_init(&ctx);
    for (R_xlen_t i = 0; i < n; i++) {
        zuf_i128 v, ns;
        if (R_IsNA(p[i])) {
            ztp_r_instant_put_na(po, i);
            continue;
        }
        if (!R_FINITE(p[i]) || p[i] != trunc(p[i]) || !ztp_i128_from_double(p[i], &v)) {
            ztp_fail(&ctx, ZTP_ERR_RANGE, (size_t)i + 1, "epoch milliseconds must be an integer");
            ztp_r_raise(&ctx);
        }
        ns = zuf_i128_mul_wrap(v, zuf_i128_from_i64(ZTP_NS_PER_MILLISECOND));
        ztp_r_instant_check(&ctx, (size_t)i + 1, ns);
        ztp_r_instant_put(po, i, ns);
    }
    UNPROTECT(1);
    return out;
}

/* From doubles (exact integers only) or decimal strings. */
SEXP ztp_r_instant_from_epoch_ns(SEXP x)
{
    R_xlen_t n = Rf_xlength(x);
    SEXP out = PROTECT(Rf_allocVector(CPLXSXP, n));
    Rcomplex *po = COMPLEX(out);
    ztp_ctx ctx;

    ztp_ctx_init(&ctx);
    for (R_xlen_t i = 0; i < n; i++) {
        zuf_i128 ns;
        if (TYPEOF(x) == STRSXP) {
            const char *s;
            zuf_result r;
            if (STRING_ELT(x, i) == NA_STRING) {
                ztp_r_instant_put_na(po, i);
                continue;
            }
            s = Rf_translateCharUTF8(STRING_ELT(x, i));
            r = zuf_parse_i128(s, s + strlen(s), &ns);
            if (r.status != ZUF_OK || r.ptr != s + strlen(s)) {
                ztp_fail(&ctx, ZTP_ERR_RANGE, (size_t)i + 1,
                         "\"%s\" is not a decimal integer", s);
                ztp_r_raise(&ctx);
            }
        } else {
            double v = REAL(x)[i];
            if (R_IsNA(v)) {
                ztp_r_instant_put_na(po, i);
                continue;
            }
            if (!R_FINITE(v) || v != trunc(v) || !ztp_i128_from_double(v, &ns)) {
                ztp_fail(&ctx, ZTP_ERR_RANGE, (size_t)i + 1, "epoch nanoseconds must be an integer");
                ztp_r_raise(&ctx);
            }
        }
        ztp_r_instant_check(&ctx, (size_t)i + 1, ns);
        ztp_r_instant_put(po, i, ns);
    }
    UNPROTECT(1);
    return out;
}

SEXP ztp_r_instant_epoch_ms(SEXP x)
{
    R_xlen_t n = Rf_xlength(x);
    const Rcomplex *p = COMPLEX(x);
    SEXP out = PROTECT(Rf_allocVector(REALSXP, n));
    double *po = REAL(out);

    for (R_xlen_t i = 0; i < n; i++) {
        zuf_i128 ns, q;
        int64_t r;
        if (!ztp_r_instant_get(p, i, &ns)) {
            po[i] = NA_REAL;
            continue;
        }
        zuf_i128_divmod_floor_i64(ns, ZTP_NS_PER_MILLISECOND, &q, &r);
        po[i] = ztp_i128_to_double(q);
    }
    UNPROTECT(1);
    return out;
}

SEXP ztp_r_instant_epoch_ns_string(SEXP x)
{
    R_xlen_t n = Rf_xlength(x);
    const Rcomplex *p = COMPLEX(x);
    SEXP out = PROTECT(Rf_allocVector(STRSXP, n));

    for (R_xlen_t i = 0; i < n; i++) {
        zuf_i128 ns;
        char buf[ZUF_I128_MAX_CHARS + 1];
        char *end;
        if (!ztp_r_instant_get(p, i, &ns)) {
            SET_STRING_ELT(out, i, NA_STRING);
            continue;
        }
        end = zuf_write_i128(buf, ns);
        *end = '\0';
        SET_STRING_ELT(out, i, Rf_mkCharCE(buf, CE_UTF8));
    }
    UNPROTECT(1);
    return out;
}

/* Reading a duration list element: shared with ztp_r_duration.c. */
static bool ztp_r_dur_get(SEXP list, R_xlen_t i, ztp_duration *d)
{
    for (int f = 0; f < ZTP_DURATION_FIELDS; f++) {
        double v = REAL(VECTOR_ELT(list, f))[i];
        if (ISNAN(v)) return false;
        ztp_duration_set_field(d, f, v);
    }
    return true;
}

/* AddDurationToInstant with ~add~; the R side negates for ~subtract~. */
SEXP ztp_r_instant_add(SEXP x, SEXP dur)
{
    R_xlen_t n = Rf_xlength(x);
    const Rcomplex *p = COMPLEX(x);
    SEXP out = PROTECT(Rf_allocVector(CPLXSXP, n));
    Rcomplex *po = COMPLEX(out);
    ztp_ctx ctx;

    ztp_ctx_init(&ctx);
    for (R_xlen_t i = 0; i < n; i++) {
        zuf_i128 ns, result;
        ztp_duration d;
        ztp_internal_duration internal;
        size_t idx = (size_t)i + 1;

        if (!ztp_r_instant_get(p, i, &ns) || !ztp_r_dur_get(dur, i, &d)) {
            ztp_r_instant_put_na(po, i);
            continue;
        }
        if (ztp_duration_default_largest_unit(&d) <= ZTP_UNIT_DAY) {
            ztp_fail(&ctx, ZTP_ERR_RANGE, idx,
                     "only time units can be added to an Instant");
            ztp_r_raise(&ctx);
        }
        internal = ztp_duration_to_internal_24h(&d);
        result = zuf_i128_add_wrap(ns, internal.time);
        ztp_r_instant_check(&ctx, idx, result);
        ztp_r_instant_put(po, i, result);
    }
    UNPROTECT(1);
    return out;
}

static SEXP ztp_r_dur_alloc(R_xlen_t n)
{
    const char *names[] = {"years", "months", "weeks", "days", "hours", "minutes", "seconds",
                           "milliseconds", "microseconds", "nanoseconds", ""};
    SEXP out = PROTECT(Rf_mkNamed(VECSXP, names));
    for (int f = 0; f < ZTP_DURATION_FIELDS; f++)
        SET_VECTOR_ELT(out, f, Rf_allocVector(REALSXP, n));
    UNPROTECT(1);
    return out;
}

SEXP ztp_r_instant_until(SEXP x1, SEXP x2, SEXP largest, SEXP smallest,
                         SEXP increment, SEXP mode)
{
    R_xlen_t n = Rf_xlength(x1);
    const Rcomplex *p1 = COMPLEX(x1), *p2 = COMPLEX(x2);
    ztp_unit largest_unit = (ztp_unit)Rf_asInteger(largest);
    ztp_unit smallest_unit = (ztp_unit)Rf_asInteger(smallest);
    int64_t inc = (int64_t)Rf_asReal(increment);
    ztp_rounding_mode rmode = (ztp_rounding_mode)Rf_asInteger(mode);
    SEXP out = PROTECT(ztp_r_dur_alloc(n));
    ztp_ctx ctx;

    ztp_ctx_init(&ctx);
    for (R_xlen_t i = 0; i < n; i++) {
        zuf_i128 a, b;
        ztp_internal_duration diff;
        ztp_duration result;
        size_t idx = (size_t)i + 1;

        if (!ztp_r_instant_get(p1, i, &a) || !ztp_r_instant_get(p2, i, &b)) {
            for (int f = 0; f < ZTP_DURATION_FIELDS; f++) REAL(VECTOR_ELT(out, f))[i] = NA_REAL;
            continue;
        }
        memset(&diff.date, 0, sizeof diff.date);
        if (ztp_time_duration_round(&ctx, idx, zuf_i128_sub_wrap(b, a), inc, smallest_unit,
                                    rmode, &diff.time) != ZTP_OK)
            ztp_r_raise(&ctx);
        if (ztp_duration_from_internal(&ctx, idx, &diff, largest_unit, &result) != ZTP_OK)
            ztp_r_raise(&ctx);
        for (int f = 0; f < ZTP_DURATION_FIELDS; f++)
            REAL(VECTOR_ELT(out, f))[i] = ztp_duration_field(&result, f);
    }
    UNPROTECT(1);
    return out;
}

SEXP ztp_r_instant_round(SEXP x, SEXP increment, SEXP unit, SEXP mode)
{
    R_xlen_t n = Rf_xlength(x);
    const Rcomplex *p = COMPLEX(x);
    int64_t inc = (int64_t)Rf_asReal(increment);
    ztp_unit u = (ztp_unit)Rf_asInteger(unit);
    ztp_rounding_mode m = (ztp_rounding_mode)Rf_asInteger(mode);
    SEXP out = PROTECT(Rf_allocVector(CPLXSXP, n));
    Rcomplex *po = COMPLEX(out);
    ztp_ctx ctx;

    ztp_ctx_init(&ctx);
    for (R_xlen_t i = 0; i < n; i++) {
        zuf_i128 ns, rounded;
        if (!ztp_r_instant_get(p, i, &ns)) {
            ztp_r_instant_put_na(po, i);
            continue;
        }
        rounded = ztp_round_instant(ns, inc, u, m);
        ztp_r_instant_check(&ctx, (size_t)i + 1, rounded);
        ztp_r_instant_put(po, i, rounded);
    }
    UNPROTECT(1);
    return out;
}

/* Format with "Z", or in the zone named by `zone` (a single string). */
SEXP ztp_r_instant_format(SEXP x, SEXP zone, SEXP precision)
{
    R_xlen_t n = Rf_xlength(x);
    const Rcomplex *p = COMPLEX(x);
    int prec = Rf_asInteger(precision);
    SEXP out = PROTECT(Rf_allocVector(STRSXP, n));
    ztp_zone z;
    const ztp_zone *zp = NULL;
    ztp_ctx ctx;

    ztp_ctx_init(&ctx);
    if (zone != R_NilValue) {
        const char *s = Rf_translateCharUTF8(STRING_ELT(zone, 0));
        if (ztp_zone_parse(&ctx, 0, s, strlen(s), &z) != ZTP_OK) ztp_r_raise(&ctx);
        zp = &z;
    }
    for (R_xlen_t i = 0; i < n; i++) {
        zuf_i128 ns;
        char buf[ZTP_FORMAT_DATE_TIME_CAP];
        if (!ztp_r_instant_get(p, i, &ns)) {
            SET_STRING_ELT(out, i, NA_STRING);
            continue;
        }
        ztp_format_instant(buf, ns, zp, prec);
        SET_STRING_ELT(out, i, Rf_mkCharCE(buf, CE_UTF8));
    }
    UNPROTECT(1);
    return out;
}

/* Normalise a time zone identifier string, for tests and later stages. */
SEXP ztp_r_zone_normalise(SEXP x)
{
    R_xlen_t n = Rf_xlength(x);
    SEXP out = PROTECT(Rf_allocVector(STRSXP, n));
    ztp_ctx ctx;

    ztp_ctx_init(&ctx);
    for (R_xlen_t i = 0; i < n; i++) {
        ztp_zone z;
        const char *s;
        if (STRING_ELT(x, i) == NA_STRING) {
            SET_STRING_ELT(out, i, NA_STRING);
            continue;
        }
        s = Rf_translateCharUTF8(STRING_ELT(x, i));
        if (ztp_zone_parse(&ctx, (size_t)i + 1, s, strlen(s), &z) != ZTP_OK) ztp_r_raise(&ctx);
        SET_STRING_ELT(out, i, Rf_mkCharCE(z.id, CE_UTF8));
    }
    UNPROTECT(1);
    return out;
}

/* POSIXct seconds to instants (design 6.10): the double's exact value,
   rounded half to even to the nanosecond. NA stays NA; an infinite or
   out-of-range value is a range error. */
SEXP ztp_r_instant_from_seconds(SEXP x)
{
    R_xlen_t n = Rf_xlength(x);
    const double *px = REAL(x);
    SEXP out = PROTECT(Rf_allocVector(CPLXSXP, n));
    Rcomplex *po = COMPLEX(out);
    ztp_ctx ctx;

    ztp_ctx_init(&ctx);
    for (R_xlen_t i = 0; i < n; i++) {
        zuf_i128 ns;
        if (ISNAN(px[i])) {
            ztp_r_instant_put_na(po, i);
            continue;
        }
        if (!ztp_epoch_ns_from_seconds(px[i], &ns)) {
            ztp_fail(&ctx, ZTP_ERR_RANGE, (size_t)i + 1,
                     "the time is outside the representable range");
            ztp_r_raise(&ctx);
        }
        ztp_r_instant_check(&ctx, (size_t)i + 1, ns);
        ztp_r_instant_put(po, i, ns);
    }
    UNPROTECT(1);
    return out;
}

/* Instants to POSIXct seconds: the nearest double, ties to even. */
SEXP ztp_r_instant_to_seconds(SEXP x)
{
    R_xlen_t n = Rf_xlength(x);
    const Rcomplex *p = COMPLEX(x);
    SEXP out = PROTECT(Rf_allocVector(REALSXP, n));
    double *po = REAL(out);

    for (R_xlen_t i = 0; i < n; i++) {
        zuf_i128 ns;
        po[i] = ztp_r_instant_get(p, i, &ns) ? ztp_seconds_from_epoch_ns(ns) : NA_REAL;
    }
    UNPROTECT(1);
    return out;
}

/* A double number of seconds, as difftime holds it, split exactly into
   whole seconds and nanoseconds of the same sign (truncation), the
   nanoseconds rounded half to even. NA stays NA in both; an infinite or
   huge value is a range error. */
SEXP ztp_r_seconds_split(SEXP x)
{
    R_xlen_t n = Rf_xlength(x);
    const double *px = REAL(x);
    const char *names[] = {"seconds", "nanoseconds", ""};
    SEXP out = PROTECT(Rf_mkNamed(VECSXP, names));
    double *ps = REAL(SET_VECTOR_ELT(out, 0, Rf_allocVector(REALSXP, n)));
    double *pn = REAL(SET_VECTOR_ELT(out, 1, Rf_allocVector(REALSXP, n)));
    ztp_ctx ctx;

    ztp_ctx_init(&ctx);
    for (R_xlen_t i = 0; i < n; i++) {
        zuf_i128 ns, q;
        int64_t r, whole;
        if (ISNAN(px[i])) {
            ps[i] = pn[i] = NA_REAL;
            continue;
        }
        if (!ztp_epoch_ns_from_seconds(px[i], &ns) ||
            !zuf_i128_divmod_trunc_i64(ns, 1000000000, &q, &r) || !zuf_i128_to_i64(q, &whole)) {
            ztp_fail(&ctx, ZTP_ERR_RANGE, (size_t)i + 1, "the number of seconds is too large");
            ztp_r_raise(&ctx);
        }
        ps[i] = (double)whole;
        pn[i] = (double)r;
    }
    UNPROTECT(1);
    return out;
}
