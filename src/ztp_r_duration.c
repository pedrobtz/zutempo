/*
 * ztp_r_duration.c -- .Call glue for Duration and for the arithmetic of
 * the plain types (design 4.1: a duration is a list of ten doubles).
 *
 * Every vector argument arrives recycled to one length; a duration list
 * holds ten REALSXP of that length, years to nanoseconds. Options arrive
 * as scalar integer codes (R/options.R); a unit code of -1 means auto.
 */

#include "ztp_r.h"
#include "ztp_format.h"
#include "ztp_relative.h"

#include <math.h>
#include <string.h>

static const char *ztp_r_duration_names[] = {
    "years", "months", "weeks", "days", "hours", "minutes", "seconds",
    "milliseconds", "microseconds", "nanoseconds", ""
};

static SEXP ztp_r_duration_alloc(R_xlen_t n)
{
    SEXP out = PROTECT(Rf_mkNamed(VECSXP, ztp_r_duration_names));
    for (int f = 0; f < ZTP_DURATION_FIELDS; f++)
        SET_VECTOR_ELT(out, f, Rf_allocVector(REALSXP, n));
    UNPROTECT(1);
    return out;
}

static void ztp_r_duration_put(SEXP list, R_xlen_t i, const ztp_duration *d)
{
    for (int f = 0; f < ZTP_DURATION_FIELDS; f++)
        REAL(VECTOR_ELT(list, f))[i] = ztp_duration_field(d, f);
}

static void ztp_r_duration_put_na(SEXP list, R_xlen_t i)
{
    for (int f = 0; f < ZTP_DURATION_FIELDS; f++)
        REAL(VECTOR_ELT(list, f))[i] = NA_REAL;
}

/* Read element i of a duration list; false when it is NA. */
static bool ztp_r_duration_get(SEXP list, R_xlen_t i, ztp_duration *d)
{
    for (int f = 0; f < ZTP_DURATION_FIELDS; f++) {
        double v = REAL(VECTOR_ELT(list, f))[i];
        if (ISNAN(v)) return false;
        ztp_duration_set_field(d, f, v);
    }
    return true;
}

/* ToIntegerIfIntegral on the fields of a would-be duration. */
static bool ztp_r_duration_fields(ztp_ctx *ctx, SEXP list, R_xlen_t i,
                                  ztp_duration *d)
{
    for (int f = 0; f < ZTP_DURATION_FIELDS; f++) {
        double v = REAL(VECTOR_ELT(list, f))[i];
        if (R_IsNA(v)) return false;
        if (ISNAN(v) || !R_FINITE(v) || v != trunc(v)) {
            ztp_fail(ctx, ZTP_ERR_RANGE, (size_t)i + 1, "`%s` must be an integer",
                     ztp_r_duration_names[f]);
            ztp_r_raise(ctx);
        }
        ztp_duration_set_field(d, f, v == 0 ? 0.0 : v);
    }
    return true;
}

static R_xlen_t ztp_r_duration_length(SEXP list)
{
    return Rf_xlength(VECTOR_ELT(list, 0));
}

static int ztp_r_int(SEXP x) { return Rf_asInteger(x); }

/* --- Duration itself ---------------------------------------------------- */

SEXP ztp_r_duration_create(SEXP fields)
{
    R_xlen_t n = ztp_r_duration_length(fields);
    SEXP out = PROTECT(ztp_r_duration_alloc(n));
    ztp_ctx ctx;

    ztp_ctx_init(&ctx);
    for (R_xlen_t i = 0; i < n; i++) {
        ztp_duration d, valid;
        if (!ztp_r_duration_fields(&ctx, fields, i, &d)) {
            ztp_r_duration_put_na(out, i);
            continue;
        }
        if (ztp_duration_create(&ctx, (size_t)i + 1, &d, &valid) != ZTP_OK) ztp_r_raise(&ctx);
        ztp_r_duration_put(out, i, &valid);
    }
    UNPROTECT(1);
    return out;
}

SEXP ztp_r_duration_parse(SEXP x)
{
    R_xlen_t n = Rf_xlength(x);
    SEXP out = PROTECT(ztp_r_duration_alloc(n));
    ztp_ctx ctx;

    ztp_ctx_init(&ctx);
    for (R_xlen_t i = 0; i < n; i++) {
        ztp_duration d;
        const char *s;
        if (STRING_ELT(x, i) == NA_STRING) {
            ztp_r_duration_put_na(out, i);
            continue;
        }
        s = Rf_translateCharUTF8(STRING_ELT(x, i));
        if (ztp_duration_parse(&ctx, (size_t)i + 1, s, strlen(s), &d, NULL) != ZTP_OK)
            ztp_r_raise(&ctx);
        ztp_r_duration_put(out, i, &d);
    }
    UNPROTECT(1);
    return out;
}

SEXP ztp_r_duration_format(SEXP dur, SEXP precision)
{
    R_xlen_t n = ztp_r_duration_length(dur);
    int prec = ztp_r_int(precision);
    SEXP out = PROTECT(Rf_allocVector(STRSXP, n));

    for (R_xlen_t i = 0; i < n; i++) {
        ztp_duration d;
        char buf[ZTP_DURATION_FORMAT_CAP];
        if (!ztp_r_duration_get(dur, i, &d)) {
            SET_STRING_ELT(out, i, NA_STRING);
            continue;
        }
        ztp_duration_format(buf, &d, prec);
        SET_STRING_ELT(out, i, Rf_mkCharCE(buf, CE_UTF8));
    }
    UNPROTECT(1);
    return out;
}

/* AddDurations with ~add~; the R side negates for ~subtract~. */
SEXP ztp_r_duration_add(SEXP a, SEXP b)
{
    R_xlen_t n = ztp_r_duration_length(a);
    SEXP out = PROTECT(ztp_r_duration_alloc(n));
    ztp_ctx ctx;

    ztp_ctx_init(&ctx);
    for (R_xlen_t i = 0; i < n; i++) {
        ztp_duration da, db, result;
        ztp_unit largest;
        ztp_internal_duration d1, d2, sum;
        size_t idx = (size_t)i + 1;

        if (!ztp_r_duration_get(a, i, &da) || !ztp_r_duration_get(b, i, &db)) {
            ztp_r_duration_put_na(out, i);
            continue;
        }
        largest = ztp_duration_default_largest_unit(&da);
        if (ztp_duration_default_largest_unit(&db) < largest)
            largest = ztp_duration_default_largest_unit(&db);
        if (largest <= ZTP_UNIT_WEEK) {
            ztp_fail(&ctx, ZTP_ERR_RANGE, idx,
                     "durations with years, months or weeks cannot be added without a reference date");
            ztp_r_raise(&ctx);
        }
        d1 = ztp_duration_to_internal_24h(&da);
        d2 = ztp_duration_to_internal_24h(&db);
        if (ztp_time_duration_add(&ctx, idx, d1.time, d2.time, &sum.time) != ZTP_OK)
            ztp_r_raise(&ctx);
        memset(&sum.date, 0, sizeof sum.date);
        if (ztp_duration_from_internal(&ctx, idx, &sum, largest, &result) != ZTP_OK)
            ztp_r_raise(&ctx);
        ztp_r_duration_put(out, i, &result);
    }
    UNPROTECT(1);
    return out;
}

/* The relative date for element i, or false when none applies. */
static bool ztp_r_relative(SEXP relative_days, R_xlen_t i, int32_t *day)
{
    if (relative_days == R_NilValue) return false;
    if (INTEGER(relative_days)[i] == NA_INTEGER) return false;
    *day = INTEGER(relative_days)[i];
    return true;
}

static bool ztp_r_relative_na(SEXP relative_days, R_xlen_t i)
{
    return relative_days != R_NilValue && INTEGER(relative_days)[i] == NA_INTEGER;
}

/* Duration.prototype.round, with the per-element parts of its option
   validation. `largest` is a unit code or -1 for auto. */
SEXP ztp_r_duration_round(SEXP dur, SEXP largest, SEXP smallest, SEXP increment,
                          SEXP mode, SEXP smallest_present, SEXP relative_days)
{
    R_xlen_t n = ztp_r_duration_length(dur);
    int largest_code = ztp_r_int(largest);
    ztp_unit smallest_unit = (ztp_unit)ztp_r_int(smallest);
    int64_t inc = (int64_t)Rf_asReal(increment);
    ztp_rounding_mode rmode = (ztp_rounding_mode)ztp_r_int(mode);
    bool smallest_given = Rf_asLogical(smallest_present) == TRUE;
    SEXP out = PROTECT(ztp_r_duration_alloc(n));
    ztp_ctx ctx;

    ztp_ctx_init(&ctx);
    for (R_xlen_t i = 0; i < n; i++) {
        ztp_duration d, result;
        ztp_unit existing, largest_unit;
        size_t idx = (size_t)i + 1;
        int32_t rel;

        if (!ztp_r_duration_get(dur, i, &d) || ztp_r_relative_na(relative_days, i)) {
            ztp_r_duration_put_na(out, i);
            continue;
        }
        existing = ztp_duration_default_largest_unit(&d);
        if (largest_code < 0) {
            largest_unit = existing < smallest_unit ? existing : smallest_unit;
            if (!smallest_given && largest_code == -2) {
                ztp_fail(&ctx, ZTP_ERR_RANGE, idx,
                         "one of `smallest_unit` and `largest_unit` is required");
                ztp_r_raise(&ctx);
            }
        } else {
            largest_unit = (ztp_unit)largest_code;
        }
        if (largest_unit > smallest_unit) {
            ztp_fail(&ctx, ZTP_ERR_RANGE, idx,
                     "`largest_unit` must not be smaller than `smallest_unit`");
            ztp_r_raise(&ctx);
        }
        if (inc > 1 && largest_unit != smallest_unit && smallest_unit <= ZTP_UNIT_DAY) {
            ztp_fail(&ctx, ZTP_ERR_RANGE, idx,
                     "a `rounding_increment` above 1 on a date unit needs `largest_unit` equal to `smallest_unit`");
            ztp_r_raise(&ctx);
        }
        if (ztp_r_relative(relative_days, i, &rel)) {
            ztp_internal_duration internal = ztp_duration_to_internal_24h(&d), rounded;
            int64_t target_ns, target_days;
            ztp_date_duration dd;
            int32_t target_day;

            ztp_add_time(0, internal.time, &target_ns, &target_days);
            dd = internal.date;
            dd.days = (double)target_days;
            if (ztp_calendar_date_add(&ctx, idx, rel, &dd, ZTP_OVERFLOW_CONSTRAIN, &target_day) != ZTP_OK)
                ztp_r_raise(&ctx);
            if (ztp_difference_plain_date_time_rounded(&ctx, idx, rel, 0, target_day, target_ns,
                                                       largest_unit, inc, smallest_unit, rmode,
                                                       &rounded) != ZTP_OK)
                ztp_r_raise(&ctx);
            if (ztp_duration_from_internal(&ctx, idx, &rounded, largest_unit, &result) != ZTP_OK)
                ztp_r_raise(&ctx);
        } else {
            ztp_internal_duration internal, rounded;

            if (existing <= ZTP_UNIT_WEEK || largest_unit <= ZTP_UNIT_WEEK) {
                ztp_fail(&ctx, ZTP_ERR_RANGE, idx,
                         "rounding years, months or weeks needs `relative_to`");
                ztp_r_raise(&ctx);
            }
            internal = ztp_duration_to_internal_24h(&d);
            memset(&rounded.date, 0, sizeof rounded.date);
            if (smallest_unit == ZTP_UNIT_DAY) {
                zuf_i128 step = zuf_i128_mul_i64_i64(ZTP_NS_PER_DAY, inc);
                zuf_i128 days_ns = ztp_round_i128_to_increment(internal.time, step, rmode, false);
                zuf_i128 q;
                int64_t r;
                zuf_i128_divmod_trunc_i64(days_ns, ZTP_NS_PER_DAY, &q, &r);
                rounded.date.days = ztp_i128_to_double(q);
                rounded.time = zuf_i128_from_i64(0);
            } else if (ztp_time_duration_round(&ctx, idx, internal.time, inc, smallest_unit,
                                               rmode, &rounded.time) != ZTP_OK) {
                ztp_r_raise(&ctx);
            }
            if (ztp_duration_from_internal(&ctx, idx, &rounded, largest_unit, &result) != ZTP_OK)
                ztp_r_raise(&ctx);
        }
        ztp_r_duration_put(out, i, &result);
    }
    UNPROTECT(1);
    return out;
}

SEXP ztp_r_duration_total(SEXP dur, SEXP unit, SEXP relative_days)
{
    R_xlen_t n = ztp_r_duration_length(dur);
    ztp_unit u = (ztp_unit)ztp_r_int(unit);
    SEXP out = PROTECT(Rf_allocVector(REALSXP, n));
    double *po = REAL(out);
    ztp_ctx ctx;

    ztp_ctx_init(&ctx);
    for (R_xlen_t i = 0; i < n; i++) {
        ztp_duration d;
        size_t idx = (size_t)i + 1;
        int32_t rel;

        if (!ztp_r_duration_get(dur, i, &d) || ztp_r_relative_na(relative_days, i)) {
            po[i] = NA_REAL;
            continue;
        }
        if (ztp_r_relative(relative_days, i, &rel)) {
            ztp_internal_duration internal = ztp_duration_to_internal_24h(&d);
            int64_t target_ns, target_days;
            ztp_date_duration dd;
            int32_t target_day;

            ztp_add_time(0, internal.time, &target_ns, &target_days);
            dd = internal.date;
            dd.days = (double)target_days;
            if (ztp_calendar_date_add(&ctx, idx, rel, &dd, ZTP_OVERFLOW_CONSTRAIN, &target_day) != ZTP_OK)
                ztp_r_raise(&ctx);
            if (ztp_difference_plain_date_time_total(&ctx, idx, rel, 0, target_day, target_ns,
                                                     u, &po[i]) != ZTP_OK)
                ztp_r_raise(&ctx);
        } else {
            ztp_internal_duration internal;
            if (ztp_duration_default_largest_unit(&d) <= ZTP_UNIT_WEEK || u <= ZTP_UNIT_WEEK) {
                ztp_fail(&ctx, ZTP_ERR_RANGE, idx,
                         "totalling years, months or weeks needs `relative_to`");
                ztp_r_raise(&ctx);
            }
            internal = ztp_duration_to_internal_24h(&d);
            po[i] = ztp_time_duration_total(internal.time, u);
        }
    }
    UNPROTECT(1);
    return out;
}

/* DateDurationDays. */
static ztp_status ztp_r_date_duration_days(ztp_ctx *ctx, size_t idx,
                                           const ztp_date_duration *dd, int32_t rel,
                                           double *out)
{
    ztp_date_duration ymw = *dd;
    int32_t later;

    ymw.days = 0;
    if (ztp_date_duration_sign(&ymw) == 0) {
        *out = dd->days;
        return ZTP_OK;
    }
    if (ztp_calendar_date_add(ctx, idx, rel, &ymw, ZTP_OVERFLOW_CONSTRAIN, &later) != ZTP_OK)
        return ctx->status;
    *out = dd->days + (double)((int64_t)later - rel);
    return ZTP_OK;
}

SEXP ztp_r_duration_compare(SEXP a, SEXP b, SEXP relative_days)
{
    R_xlen_t n = ztp_r_duration_length(a);
    SEXP out = PROTECT(Rf_allocVector(INTSXP, n));
    int *po = INTEGER(out);
    ztp_ctx ctx;

    ztp_ctx_init(&ctx);
    for (R_xlen_t i = 0; i < n; i++) {
        ztp_duration da, db;
        size_t idx = (size_t)i + 1;
        bool equal = true;
        int32_t rel;
        ztp_internal_duration d1, d2;
        double days1, days2;
        zuf_i128 t1, t2;

        if (!ztp_r_duration_get(a, i, &da) || !ztp_r_duration_get(b, i, &db) ||
            ztp_r_relative_na(relative_days, i)) {
            po[i] = NA_INTEGER;
            continue;
        }
        for (int f = 0; f < ZTP_DURATION_FIELDS; f++)
            if (ztp_duration_field(&da, f) != ztp_duration_field(&db, f)) equal = false;
        if (equal) {
            po[i] = 0;
            continue;
        }
        d1 = ztp_duration_to_internal(&da);
        d2 = ztp_duration_to_internal(&db);
        if (ztp_duration_default_largest_unit(&da) <= ZTP_UNIT_WEEK ||
            ztp_duration_default_largest_unit(&db) <= ZTP_UNIT_WEEK) {
            if (!ztp_r_relative(relative_days, i, &rel)) {
                ztp_fail(&ctx, ZTP_ERR_RANGE, idx,
                         "comparing durations with years, months or weeks needs `relative_to`");
                ztp_r_raise(&ctx);
            }
            if (ztp_r_date_duration_days(&ctx, idx, &d1.date, rel, &days1) != ZTP_OK ||
                ztp_r_date_duration_days(&ctx, idx, &d2.date, rel, &days2) != ZTP_OK)
                ztp_r_raise(&ctx);
        } else {
            days1 = da.days;
            days2 = db.days;
        }
        if (ztp_time_duration_add_days(&ctx, idx, d1.time, days1, &t1) != ZTP_OK ||
            ztp_time_duration_add_days(&ctx, idx, d2.time, days2, &t2) != ZTP_OK)
            ztp_r_raise(&ctx);
        po[i] = zuf_i128_cmp(t1, t2);
    }
    UNPROTECT(1);
    return out;
}

/* --- arithmetic on the plain types ------------------------------------- */

SEXP ztp_r_plain_date_add(SEXP days, SEXP dur, SEXP overflow)
{
    R_xlen_t n = Rf_xlength(days);
    const int *pd = INTEGER(days);
    ztp_overflow ov = (ztp_overflow)ztp_r_int(overflow);
    SEXP out = PROTECT(Rf_allocVector(INTSXP, n));
    int *po = INTEGER(out);
    ztp_ctx ctx;

    ztp_ctx_init(&ctx);
    for (R_xlen_t i = 0; i < n; i++) {
        ztp_duration d;
        ztp_internal_duration internal;
        ztp_date_duration dd;
        zuf_i128 q;
        int64_t r, whole;
        int32_t result;

        if (pd[i] == NA_INTEGER || !ztp_r_duration_get(dur, i, &d)) {
            po[i] = NA_INTEGER;
            continue;
        }
        /* ToDateDurationRecordWithoutTime */
        internal = ztp_duration_to_internal_24h(&d);
        zuf_i128_divmod_trunc_i64(internal.time, ZTP_NS_PER_DAY, &q, &r);
        zuf_i128_to_i64(q, &whole);
        dd = internal.date;
        dd.days = (double)whole;
        if (ztp_calendar_date_add(&ctx, (size_t)i + 1, pd[i], &dd, ov, &result) != ZTP_OK)
            ztp_r_raise(&ctx);
        po[i] = (int)result;
    }
    UNPROTECT(1);
    return out;
}

SEXP ztp_r_plain_date_until(SEXP d1, SEXP d2, SEXP largest, SEXP smallest,
                            SEXP increment, SEXP mode)
{
    R_xlen_t n = Rf_xlength(d1);
    const int *p1 = INTEGER(d1), *p2 = INTEGER(d2);
    ztp_unit largest_unit = (ztp_unit)ztp_r_int(largest);
    ztp_unit smallest_unit = (ztp_unit)ztp_r_int(smallest);
    int64_t inc = (int64_t)Rf_asReal(increment);
    ztp_rounding_mode rmode = (ztp_rounding_mode)ztp_r_int(mode);
    SEXP out = PROTECT(ztp_r_duration_alloc(n));
    ztp_ctx ctx;

    ztp_ctx_init(&ctx);
    for (R_xlen_t i = 0; i < n; i++) {
        ztp_internal_duration diff, rounded;
        ztp_duration result;
        size_t idx = (size_t)i + 1;

        if (p1[i] == NA_INTEGER || p2[i] == NA_INTEGER) {
            ztp_r_duration_put_na(out, i);
            continue;
        }
        ztp_calendar_date_until(p1[i], p2[i], largest_unit, &diff.date);
        diff.time = zuf_i128_from_i64(0);
        if (p1[i] != p2[i] && (smallest_unit != ZTP_UNIT_DAY || inc != 1)) {
            if (ztp_round_relative_duration(&ctx, idx, &diff, p1[i], 0, p2[i], 0, largest_unit,
                                            inc, smallest_unit, rmode, &rounded) != ZTP_OK)
                ztp_r_raise(&ctx);
            diff = rounded;
        }
        if (ztp_duration_from_internal(&ctx, idx, &diff, ZTP_UNIT_DAY, &result) != ZTP_OK)
            ztp_r_raise(&ctx);
        ztp_r_duration_put(out, i, &result);
    }
    UNPROTECT(1);
    return out;
}

SEXP ztp_r_plain_time_add(SEXP ns, SEXP dur)
{
    R_xlen_t n = Rf_xlength(ns);
    const double *p = REAL(ns);
    SEXP out = PROTECT(Rf_allocVector(REALSXP, n));
    double *po = REAL(out);

    for (R_xlen_t i = 0; i < n; i++) {
        ztp_duration d;
        ztp_internal_duration internal;
        int64_t result_ns, days;

        if (ISNAN(p[i]) || !ztp_r_duration_get(dur, i, &d)) {
            po[i] = NA_REAL;
            continue;
        }
        internal = ztp_duration_to_internal(&d);
        ztp_add_time((int64_t)p[i], internal.time, &result_ns, &days);
        po[i] = (double)result_ns;
    }
    UNPROTECT(1);
    return out;
}

SEXP ztp_r_plain_time_until(SEXP t1, SEXP t2, SEXP largest, SEXP smallest,
                            SEXP increment, SEXP mode)
{
    R_xlen_t n = Rf_xlength(t1);
    const double *p1 = REAL(t1), *p2 = REAL(t2);
    ztp_unit largest_unit = (ztp_unit)ztp_r_int(largest);
    ztp_unit smallest_unit = (ztp_unit)ztp_r_int(smallest);
    int64_t inc = (int64_t)Rf_asReal(increment);
    ztp_rounding_mode rmode = (ztp_rounding_mode)ztp_r_int(mode);
    SEXP out = PROTECT(ztp_r_duration_alloc(n));
    ztp_ctx ctx;

    ztp_ctx_init(&ctx);
    for (R_xlen_t i = 0; i < n; i++) {
        ztp_internal_duration diff;
        ztp_duration result;
        size_t idx = (size_t)i + 1;

        if (ISNAN(p1[i]) || ISNAN(p2[i])) {
            ztp_r_duration_put_na(out, i);
            continue;
        }
        memset(&diff.date, 0, sizeof diff.date);
        if (ztp_time_duration_round(&ctx, idx, zuf_i128_from_i64((int64_t)p2[i] - (int64_t)p1[i]),
                                    inc, smallest_unit, rmode, &diff.time) != ZTP_OK)
            ztp_r_raise(&ctx);
        if (ztp_duration_from_internal(&ctx, idx, &diff, largest_unit, &result) != ZTP_OK)
            ztp_r_raise(&ctx);
        ztp_r_duration_put(out, i, &result);
    }
    UNPROTECT(1);
    return out;
}

SEXP ztp_r_plain_date_time_add(SEXP x, SEXP dur, SEXP overflow)
{
    R_xlen_t n = Rf_xlength(x);
    const Rcomplex *p = COMPLEX(x);
    ztp_overflow ov = (ztp_overflow)ztp_r_int(overflow);
    SEXP out = PROTECT(Rf_allocVector(CPLXSXP, n));
    Rcomplex *po = COMPLEX(out);
    ztp_ctx ctx;

    ztp_ctx_init(&ctx);
    for (R_xlen_t i = 0; i < n; i++) {
        ztp_duration d;
        ztp_internal_duration internal;
        int64_t time_ns, days;
        ztp_date_duration dd;
        int32_t added;
        size_t idx = (size_t)i + 1;

        if (ISNAN(p[i].r) || !ztp_r_duration_get(dur, i, &d)) {
            po[i].r = NA_REAL;
            po[i].i = NA_REAL;
            continue;
        }
        internal = ztp_duration_to_internal_24h(&d);
        ztp_add_time((int64_t)p[i].i, internal.time, &time_ns, &days);
        dd = internal.date;
        dd.days = (double)days;
        if (ztp_calendar_date_add(&ctx, idx, (int32_t)p[i].r, &dd, ov, &added) != ZTP_OK)
            ztp_r_raise(&ctx);
        if (!ztp_iso_date_time_within_limits(added, time_ns)) {
            ztp_fail(&ctx, ZTP_ERR_RANGE, idx,
                     "the result is outside the range of a PlainDateTime");
            ztp_r_raise(&ctx);
        }
        po[i].r = (double)added;
        po[i].i = (double)time_ns;
    }
    UNPROTECT(1);
    return out;
}

SEXP ztp_r_plain_date_time_until(SEXP x1, SEXP x2, SEXP largest, SEXP smallest,
                                 SEXP increment, SEXP mode)
{
    R_xlen_t n = Rf_xlength(x1);
    const Rcomplex *p1 = COMPLEX(x1), *p2 = COMPLEX(x2);
    ztp_unit largest_unit = (ztp_unit)ztp_r_int(largest);
    ztp_unit smallest_unit = (ztp_unit)ztp_r_int(smallest);
    int64_t inc = (int64_t)Rf_asReal(increment);
    ztp_rounding_mode rmode = (ztp_rounding_mode)ztp_r_int(mode);
    SEXP out = PROTECT(ztp_r_duration_alloc(n));
    ztp_ctx ctx;

    ztp_ctx_init(&ctx);
    for (R_xlen_t i = 0; i < n; i++) {
        ztp_internal_duration diff;
        ztp_duration result;
        size_t idx = (size_t)i + 1;

        if (ISNAN(p1[i].r) || ISNAN(p2[i].r)) {
            ztp_r_duration_put_na(out, i);
            continue;
        }
        if (ztp_difference_plain_date_time_rounded(&ctx, idx, (int32_t)p1[i].r, (int64_t)p1[i].i,
                                                   (int32_t)p2[i].r, (int64_t)p2[i].i,
                                                   largest_unit, inc, smallest_unit, rmode,
                                                   &diff) != ZTP_OK)
            ztp_r_raise(&ctx);
        if (ztp_duration_from_internal(&ctx, idx, &diff, largest_unit, &result) != ZTP_OK)
            ztp_r_raise(&ctx);
        ztp_r_duration_put(out, i, &result);
    }
    UNPROTECT(1);
    return out;
}

/* The first day of a year-month code. */
static int32_t ztp_r_year_month_first_day(int code)
{
    int q = code >= 0 ? code / 12 : -((-code + 11) / 12);
    ztp_iso_date d = {(int32_t)(1970 + q), (uint32_t)(code - q * 12 + 1), 1};
    return ztp_epoch_day_from_iso_date(&d);
}

SEXP ztp_r_plain_year_month_add(SEXP ym, SEXP dur, SEXP overflow)
{
    R_xlen_t n = Rf_xlength(ym);
    const int *p = INTEGER(ym);
    ztp_overflow ov = (ztp_overflow)ztp_r_int(overflow);
    SEXP out = PROTECT(Rf_allocVector(INTSXP, n));
    int *po = INTEGER(out);
    ztp_ctx ctx;

    ztp_ctx_init(&ctx);
    for (R_xlen_t i = 0; i < n; i++) {
        ztp_duration d;
        ztp_internal_duration internal;
        int32_t added;
        ztp_iso_date date;
        size_t idx = (size_t)i + 1;

        if (p[i] == NA_INTEGER || !ztp_r_duration_get(dur, i, &d)) {
            po[i] = NA_INTEGER;
            continue;
        }
        internal = ztp_duration_to_internal(&d);
        if (internal.date.weeks != 0 || internal.date.days != 0 ||
            ztp_time_duration_sign(internal.time) != 0) {
            ztp_fail(&ctx, ZTP_ERR_RANGE, idx,
                     "only years and months can be added to a PlainYearMonth");
            ztp_r_raise(&ctx);
        }
        if (ztp_calendar_date_add(&ctx, idx, ztp_r_year_month_first_day(p[i]), &internal.date,
                                  ov, &added) != ZTP_OK)
            ztp_r_raise(&ctx);
        ztp_iso_date_from_epoch_day(added, &date);
        if (!ztp_iso_year_month_within_limits(date.year, date.month)) {
            ztp_fail(&ctx, ZTP_ERR_RANGE, idx,
                     "the result is outside the range of a PlainYearMonth");
            ztp_r_raise(&ctx);
        }
        po[i] = (int)(((int64_t)date.year - 1970) * 12 + (date.month - 1));
    }
    UNPROTECT(1);
    return out;
}

SEXP ztp_r_plain_year_month_until(SEXP ym1, SEXP ym2, SEXP largest, SEXP smallest,
                                  SEXP increment, SEXP mode)
{
    R_xlen_t n = Rf_xlength(ym1);
    const int *p1 = INTEGER(ym1), *p2 = INTEGER(ym2);
    ztp_unit largest_unit = (ztp_unit)ztp_r_int(largest);
    ztp_unit smallest_unit = (ztp_unit)ztp_r_int(smallest);
    int64_t inc = (int64_t)Rf_asReal(increment);
    ztp_rounding_mode rmode = (ztp_rounding_mode)ztp_r_int(mode);
    SEXP out = PROTECT(ztp_r_duration_alloc(n));
    ztp_ctx ctx;

    ztp_ctx_init(&ctx);
    for (R_xlen_t i = 0; i < n; i++) {
        ztp_internal_duration diff, rounded;
        ztp_duration result;
        int32_t this_day, other_day;
        size_t idx = (size_t)i + 1;

        if (p1[i] == NA_INTEGER || p2[i] == NA_INTEGER) {
            ztp_r_duration_put_na(out, i);
            continue;
        }
        this_day = ztp_r_year_month_first_day(p1[i]);
        other_day = ztp_r_year_month_first_day(p2[i]);
        ztp_calendar_date_until(this_day, other_day, largest_unit, &diff.date);
        diff.date.weeks = 0;
        diff.date.days = 0;
        diff.time = zuf_i128_from_i64(0);
        if (p1[i] != p2[i] && (smallest_unit != ZTP_UNIT_MONTH || inc != 1)) {
            if (ztp_round_relative_duration(&ctx, idx, &diff, this_day, 0, other_day, 0,
                                            largest_unit, inc, smallest_unit, rmode,
                                            &rounded) != ZTP_OK)
                ztp_r_raise(&ctx);
            diff = rounded;
        }
        if (ztp_duration_from_internal(&ctx, idx, &diff, ZTP_UNIT_DAY, &result) != ZTP_OK)
            ztp_r_raise(&ctx);
        ztp_r_duration_put(out, i, &result);
    }
    UNPROTECT(1);
    return out;
}
