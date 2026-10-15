/*
 * ztp_r_plain.c -- .Call glue for PlainDate, PlainTime and PlainDateTime.
 *
 * Storage (design 4.1): PlainDate is an integer epoch day, PlainTime a
 * double count of nanoseconds of day, PlainDateTime a complex value with
 * the epoch day in the real part and the nanoseconds of day in the
 * imaginary part. Every vector argument arrives recycled to one length;
 * options arrive as scalar integer codes (R/options.R).
 */

#include "ztp_r.h"
#include "ztp_format.h"
#include "ztp_parse.h"
#include "ztp_duration.h"
#include "ztp_round.h"

#include <math.h>
#include <string.h>

/* Field codes shared with R/accessors.R. */
enum {
    ZTP_FIELD_YEAR = 1,
    ZTP_FIELD_MONTH = 2,
    ZTP_FIELD_DAY = 3,
    ZTP_FIELD_DAY_OF_WEEK = 4,
    ZTP_FIELD_DAY_OF_YEAR = 5,
    ZTP_FIELD_WEEK_OF_YEAR = 6,
    ZTP_FIELD_YEAR_OF_WEEK = 7,
    ZTP_FIELD_DAYS_IN_MONTH = 8,
    ZTP_FIELD_DAYS_IN_YEAR = 9,
    ZTP_FIELD_IN_LEAP_YEAR = 10,
    ZTP_FIELD_HOUR = 11,
    ZTP_FIELD_MINUTE = 12,
    ZTP_FIELD_SECOND = 13,
    ZTP_FIELD_MILLISECOND = 14,
    ZTP_FIELD_MICROSECOND = 15,
    ZTP_FIELD_NANOSECOND = 16
};


/* ToIntegerWithTruncation (or the positive variant) on one R double.
   Returns false for NA, which the caller propagates. NaN and infinities
   are range errors, as the specification's conversions throw. */
static bool ztp_r_integer_field(ztp_ctx *ctx, double x, size_t index,
                                const char *name, bool positive, int64_t *out)
{
    if (R_IsNA(x)) return false;
    if (ISNAN(x) || !R_FINITE(x)) {
        ztp_fail(ctx, ZTP_ERR_RANGE, index, "%s must be a finite number", name);
        ztp_r_raise(ctx);
    }
    x = trunc(x);
    if (x > 9.0e15 || x < -9.0e15) {
        ztp_fail(ctx, ZTP_ERR_RANGE, index, "%s is out of range", name);
        ztp_r_raise(ctx);
    }
    if (positive && x < 1) {
        ztp_fail(ctx, ZTP_ERR_RANGE, index, "%s must be a positive integer", name);
        ztp_r_raise(ctx);
    }
    *out = (int64_t)x;
    return true;
}

static int ztp_r_scalar_int(SEXP x)
{
    return Rf_asInteger(x);
}

/* --- PlainDate ---------------------------------------------------------- */

static int ztp_r_date_from_fields(ztp_ctx *ctx, size_t index, int64_t year,
                                  int64_t month, int64_t day,
                                  ztp_overflow overflow)
{
    ztp_iso_date d;
    int32_t epoch_day;

    if (ztp_regulate_iso_date(ctx, index, year, month, day, overflow, &d) != ZTP_OK)
        ztp_r_raise(ctx);
    epoch_day = ztp_epoch_day_from_iso_date(&d);
    if (!ztp_iso_date_within_limits(epoch_day)) {
        ztp_fail(ctx, ZTP_ERR_RANGE, index,
                 "%d-%02u-%02u is outside the range of a PlainDate",
                 (int)d.year, d.month, d.day);
        ztp_r_raise(ctx);
    }
    return (int)epoch_day;
}

SEXP ztp_r_plain_date_from_fields(SEXP year, SEXP month, SEXP day,
                                  SEXP overflow)
{
    R_xlen_t n = Rf_xlength(year);
    const double *py = REAL(year), *pm = REAL(month), *pd = REAL(day);
    ztp_overflow ov = (ztp_overflow)ztp_r_scalar_int(overflow);
    SEXP out = PROTECT(Rf_allocVector(INTSXP, n));
    int *po = INTEGER(out);
    ztp_ctx ctx;

    ztp_ctx_init(&ctx);
    for (R_xlen_t i = 0; i < n; i++) {
        int64_t y, m, d;
        size_t idx = (size_t)i + 1;

        if (!ztp_r_integer_field(&ctx, py[i], idx, "year", false, &y) ||
            !ztp_r_integer_field(&ctx, pm[i], idx, "month", true, &m) ||
            !ztp_r_integer_field(&ctx, pd[i], idx, "day", true, &d)) {
            po[i] = NA_INTEGER;
            continue;
        }
        po[i] = ztp_r_date_from_fields(&ctx, idx, y, m, d, ov);
    }
    UNPROTECT(1);
    return out;
}

static bool ztp_r_parse_elt(ztp_ctx *ctx, SEXP x, R_xlen_t i,
                            ztp_parse_goal goal, ztp_parsed *parsed)
{
    SEXP elt = STRING_ELT(x, i);
    const char *s;

    if (elt == NA_STRING) return false;
    s = Rf_translateCharUTF8(elt);
    if (ztp_parse(ctx, (size_t)i + 1, s, strlen(s), goal, parsed, NULL) != ZTP_OK)
        ztp_r_raise(ctx);
    return true;
}

static int ztp_r_date_from_parsed(ztp_ctx *ctx, size_t index,
                                  const ztp_parsed *p)
{
    ztp_iso_date d = {p->year, p->month, p->day};
    int32_t epoch_day = ztp_epoch_day_from_iso_date(&d);

    if (!ztp_iso_date_within_limits(epoch_day)) {
        ztp_fail(ctx, ZTP_ERR_RANGE, index,
                 "the date is outside the range of a PlainDate");
        ztp_r_raise(ctx);
    }
    return (int)epoch_day;
}

SEXP ztp_r_plain_date_parse(SEXP x)
{
    R_xlen_t n = Rf_xlength(x);
    SEXP out = PROTECT(Rf_allocVector(INTSXP, n));
    int *po = INTEGER(out);
    ztp_ctx ctx;

    ztp_ctx_init(&ctx);
    for (R_xlen_t i = 0; i < n; i++) {
        ztp_parsed p;
        if (!ztp_r_parse_elt(&ctx, x, i, ZTP_PARSE_DATE_TIME, &p)) {
            po[i] = NA_INTEGER;
            continue;
        }
        po[i] = ztp_r_date_from_parsed(&ctx, (size_t)i + 1, &p);
    }
    UNPROTECT(1);
    return out;
}

/* One field of a date; in_leap_year comes back as 0/1. */
static int ztp_r_date_field_value(int32_t epoch_day, int field)
{
    ztp_iso_date d;
    int32_t week_year;
    uint32_t week;

    ztp_iso_date_from_epoch_day(epoch_day, &d);
    switch (field) {
    case ZTP_FIELD_YEAR:          return (int)d.year;
    case ZTP_FIELD_MONTH:         return (int)d.month;
    case ZTP_FIELD_DAY:           return (int)d.day;
    case ZTP_FIELD_DAY_OF_WEEK:   return (int)ztp_iso_day_of_week(epoch_day);
    case ZTP_FIELD_DAY_OF_YEAR:   return (int)ztp_iso_day_of_year(epoch_day);
    case ZTP_FIELD_WEEK_OF_YEAR:
        ztp_iso_week_of_year(epoch_day, &week_year, &week);
        return (int)week;
    case ZTP_FIELD_YEAR_OF_WEEK:
        ztp_iso_week_of_year(epoch_day, &week_year, &week);
        return (int)week_year;
    case ZTP_FIELD_DAYS_IN_MONTH: return (int)ztp_iso_days_in_month(d.year, d.month);
    case ZTP_FIELD_DAYS_IN_YEAR:  return (int)ztp_iso_days_in_year(d.year);
    case ZTP_FIELD_IN_LEAP_YEAR:  return ztp_iso_in_leap_year(d.year) ? 1 : 0;
    default:
        Rf_error("zutempo: unknown date field %d", field);
    }
}

static int ztp_r_time_field_value(int64_t ns, int field)
{
    ztp_iso_time t;

    ztp_iso_time_from_ns(ns, &t);
    switch (field) {
    case ZTP_FIELD_HOUR:        return (int)t.hour;
    case ZTP_FIELD_MINUTE:      return (int)t.minute;
    case ZTP_FIELD_SECOND:      return (int)t.second;
    case ZTP_FIELD_MILLISECOND: return (int)t.millisecond;
    case ZTP_FIELD_MICROSECOND: return (int)t.microsecond;
    case ZTP_FIELD_NANOSECOND:  return (int)t.nanosecond;
    default:
        Rf_error("zutempo: unknown time field %d", field);
    }
}

static SEXP ztp_r_field_vector(int field, R_xlen_t n)
{
    return Rf_allocVector(field == ZTP_FIELD_IN_LEAP_YEAR ? LGLSXP : INTSXP, n);
}

SEXP ztp_r_plain_date_field(SEXP days, SEXP field)
{
    R_xlen_t n = Rf_xlength(days);
    int f = ztp_r_scalar_int(field);
    const int *pd = INTEGER(days);
    SEXP out = PROTECT(ztp_r_field_vector(f, n));
    int *po = INTEGER(out);

    for (R_xlen_t i = 0; i < n; i++)
        po[i] = pd[i] == NA_INTEGER ? NA_INTEGER : ztp_r_date_field_value(pd[i], f);
    UNPROTECT(1);
    return out;
}

SEXP ztp_r_plain_date_format(SEXP days, SEXP show_calendar)
{
    R_xlen_t n = Rf_xlength(days);
    const int *pd = INTEGER(days);
    ztp_show_calendar show = (ztp_show_calendar)ztp_r_scalar_int(show_calendar);
    SEXP out = PROTECT(Rf_allocVector(STRSXP, n));

    for (R_xlen_t i = 0; i < n; i++) {
        char buf[ZTP_FORMAT_DATE_CAP];
        if (pd[i] == NA_INTEGER) {
            SET_STRING_ELT(out, i, NA_STRING);
            continue;
        }
        ztp_format_iso_date(buf, pd[i], show);
        SET_STRING_ELT(out, i, Rf_mkCharCE(buf, CE_UTF8));
    }
    UNPROTECT(1);
    return out;
}

/* --- PlainTime ---------------------------------------------------------- */

SEXP ztp_r_plain_time_from_fields(SEXP hour, SEXP minute, SEXP second,
                                  SEXP millisecond, SEXP microsecond,
                                  SEXP nanosecond, SEXP overflow)
{
    R_xlen_t n = Rf_xlength(hour);
    const double *ph = REAL(hour), *pmi = REAL(minute), *ps = REAL(second),
                 *pms = REAL(millisecond), *pus = REAL(microsecond),
                 *pns = REAL(nanosecond);
    ztp_overflow ov = (ztp_overflow)ztp_r_scalar_int(overflow);
    SEXP out = PROTECT(Rf_allocVector(REALSXP, n));
    double *po = REAL(out);
    ztp_ctx ctx;

    ztp_ctx_init(&ctx);
    for (R_xlen_t i = 0; i < n; i++) {
        int64_t h, mi, s, ms, us, ns;
        size_t idx = (size_t)i + 1;
        ztp_iso_time t;

        if (!ztp_r_integer_field(&ctx, ph[i], idx, "hour", false, &h) ||
            !ztp_r_integer_field(&ctx, pmi[i], idx, "minute", false, &mi) ||
            !ztp_r_integer_field(&ctx, ps[i], idx, "second", false, &s) ||
            !ztp_r_integer_field(&ctx, pms[i], idx, "millisecond", false, &ms) ||
            !ztp_r_integer_field(&ctx, pus[i], idx, "microsecond", false, &us) ||
            !ztp_r_integer_field(&ctx, pns[i], idx, "nanosecond", false, &ns)) {
            po[i] = NA_REAL;
            continue;
        }
        if (ztp_regulate_time(&ctx, idx, h, mi, s, ms, us, ns, ov, &t) != ZTP_OK)
            ztp_r_raise(&ctx);
        po[i] = (double)ztp_ns_from_iso_time(&t);
    }
    UNPROTECT(1);
    return out;
}

SEXP ztp_r_plain_time_parse(SEXP x)
{
    R_xlen_t n = Rf_xlength(x);
    SEXP out = PROTECT(Rf_allocVector(REALSXP, n));
    double *po = REAL(out);
    ztp_ctx ctx;

    ztp_ctx_init(&ctx);
    for (R_xlen_t i = 0; i < n; i++) {
        ztp_parsed p;
        if (!ztp_r_parse_elt(&ctx, x, i, ZTP_PARSE_TIME, &p)) {
            po[i] = NA_REAL;
            continue;
        }
        po[i] = (double)ztp_ns_from_iso_time(&p.time);
    }
    UNPROTECT(1);
    return out;
}

SEXP ztp_r_plain_time_field(SEXP ns, SEXP field)
{
    R_xlen_t n = Rf_xlength(ns);
    int f = ztp_r_scalar_int(field);
    const double *p = REAL(ns);
    SEXP out = PROTECT(Rf_allocVector(INTSXP, n));
    int *po = INTEGER(out);

    for (R_xlen_t i = 0; i < n; i++)
        po[i] = ISNAN(p[i]) ? NA_INTEGER : ztp_r_time_field_value((int64_t)p[i], f);
    UNPROTECT(1);
    return out;
}

SEXP ztp_r_plain_time_round(SEXP ns, SEXP increment, SEXP unit, SEXP mode)
{
    R_xlen_t n = Rf_xlength(ns);
    const double *p = REAL(ns);
    int64_t inc = (int64_t)Rf_asReal(increment);
    ztp_unit u = (ztp_unit)ztp_r_scalar_int(unit);
    ztp_rounding_mode m = (ztp_rounding_mode)ztp_r_scalar_int(mode);
    SEXP out = PROTECT(Rf_allocVector(REALSXP, n));
    double *po = REAL(out);

    for (R_xlen_t i = 0; i < n; i++) {
        int64_t rounded, days;
        if (ISNAN(p[i])) {
            po[i] = NA_REAL;
            continue;
        }
        ztp_round_time((int64_t)p[i], inc, u, m, &rounded, &days);
        po[i] = (double)rounded;   /* PlainTime drops the day carry */
    }
    UNPROTECT(1);
    return out;
}

SEXP ztp_r_plain_time_format(SEXP ns, SEXP precision)
{
    R_xlen_t n = Rf_xlength(ns);
    const double *p = REAL(ns);
    int prec = ztp_r_scalar_int(precision);
    SEXP out = PROTECT(Rf_allocVector(STRSXP, n));

    for (R_xlen_t i = 0; i < n; i++) {
        char buf[ZTP_FORMAT_TIME_CAP];
        if (ISNAN(p[i])) {
            SET_STRING_ELT(out, i, NA_STRING);
            continue;
        }
        ztp_format_time(buf, (int64_t)p[i], prec);
        SET_STRING_ELT(out, i, Rf_mkCharCE(buf, CE_UTF8));
    }
    UNPROTECT(1);
    return out;
}

/* --- PlainDateTime ------------------------------------------------------ */

static Rcomplex ztp_r_na_complex(void)
{
    Rcomplex z;
    z.r = NA_REAL;
    z.i = NA_REAL;
    return z;
}

static Rcomplex ztp_r_make_date_time(ztp_ctx *ctx, size_t index,
                                     int64_t epoch_day, int64_t ns_of_day)
{
    Rcomplex z;

    if (!ztp_iso_date_time_within_limits(epoch_day, ns_of_day)) {
        ztp_fail(ctx, ZTP_ERR_RANGE, index,
                 "the date-time is outside the range of a PlainDateTime");
        ztp_r_raise(ctx);
    }
    z.r = (double)epoch_day;
    z.i = (double)ns_of_day;
    return z;
}

SEXP ztp_r_plain_date_time_from_fields(SEXP year, SEXP month, SEXP day,
                                       SEXP hour, SEXP minute, SEXP second,
                                       SEXP millisecond, SEXP microsecond,
                                       SEXP nanosecond, SEXP overflow)
{
    R_xlen_t n = Rf_xlength(year);
    const double *py = REAL(year), *pm = REAL(month), *pd = REAL(day),
                 *ph = REAL(hour), *pmi = REAL(minute), *ps = REAL(second),
                 *pms = REAL(millisecond), *pus = REAL(microsecond),
                 *pns = REAL(nanosecond);
    ztp_overflow ov = (ztp_overflow)ztp_r_scalar_int(overflow);
    SEXP out = PROTECT(Rf_allocVector(CPLXSXP, n));
    Rcomplex *po = COMPLEX(out);
    ztp_ctx ctx;

    ztp_ctx_init(&ctx);
    for (R_xlen_t i = 0; i < n; i++) {
        int64_t y, m, d, h, mi, s, ms, us, ns;
        size_t idx = (size_t)i + 1;
        ztp_iso_date date;
        ztp_iso_time time;

        if (!ztp_r_integer_field(&ctx, py[i], idx, "year", false, &y) ||
            !ztp_r_integer_field(&ctx, pm[i], idx, "month", true, &m) ||
            !ztp_r_integer_field(&ctx, pd[i], idx, "day", true, &d) ||
            !ztp_r_integer_field(&ctx, ph[i], idx, "hour", false, &h) ||
            !ztp_r_integer_field(&ctx, pmi[i], idx, "minute", false, &mi) ||
            !ztp_r_integer_field(&ctx, ps[i], idx, "second", false, &s) ||
            !ztp_r_integer_field(&ctx, pms[i], idx, "millisecond", false, &ms) ||
            !ztp_r_integer_field(&ctx, pus[i], idx, "microsecond", false, &us) ||
            !ztp_r_integer_field(&ctx, pns[i], idx, "nanosecond", false, &ns)) {
            po[i] = ztp_r_na_complex();
            continue;
        }
        /* InterpretTemporalDateTimeFields: the date, then the time. */
        if (ztp_regulate_iso_date(&ctx, idx, y, m, d, ov, &date) != ZTP_OK)
            ztp_r_raise(&ctx);
        if (ztp_regulate_time(&ctx, idx, h, mi, s, ms, us, ns, ov, &time) != ZTP_OK)
            ztp_r_raise(&ctx);
        po[i] = ztp_r_make_date_time(&ctx, idx, ztp_epoch_day_from_iso_date(&date),
                                     ztp_ns_from_iso_time(&time));
    }
    UNPROTECT(1);
    return out;
}

SEXP ztp_r_plain_date_time_parse(SEXP x)
{
    R_xlen_t n = Rf_xlength(x);
    SEXP out = PROTECT(Rf_allocVector(CPLXSXP, n));
    Rcomplex *po = COMPLEX(out);
    ztp_ctx ctx;

    ztp_ctx_init(&ctx);
    for (R_xlen_t i = 0; i < n; i++) {
        ztp_parsed p;
        ztp_iso_date d;
        if (!ztp_r_parse_elt(&ctx, x, i, ZTP_PARSE_DATE_TIME, &p)) {
            po[i] = ztp_r_na_complex();
            continue;
        }
        d.year = p.year;
        d.month = p.month;
        d.day = p.day;
        po[i] = ztp_r_make_date_time(&ctx, (size_t)i + 1,
                                     ztp_epoch_day_from_iso_date(&d),
                                     p.has_time ? ztp_ns_from_iso_time(&p.time) : 0);
    }
    UNPROTECT(1);
    return out;
}

/* CombineISODateAndTimeRecord followed by CreateTemporalDateTime. */
SEXP ztp_r_plain_date_time_combine(SEXP days, SEXP ns)
{
    R_xlen_t n = Rf_xlength(days);
    const int *pd = INTEGER(days);
    const double *pt = REAL(ns);
    SEXP out = PROTECT(Rf_allocVector(CPLXSXP, n));
    Rcomplex *po = COMPLEX(out);
    ztp_ctx ctx;

    ztp_ctx_init(&ctx);
    for (R_xlen_t i = 0; i < n; i++) {
        if (pd[i] == NA_INTEGER || ISNAN(pt[i])) {
            po[i] = ztp_r_na_complex();
            continue;
        }
        po[i] = ztp_r_make_date_time(&ctx, (size_t)i + 1, pd[i], (int64_t)pt[i]);
    }
    UNPROTECT(1);
    return out;
}

SEXP ztp_r_plain_date_time_field(SEXP x, SEXP field)
{
    R_xlen_t n = Rf_xlength(x);
    int f = ztp_r_scalar_int(field);
    const Rcomplex *p = COMPLEX(x);
    SEXP out = PROTECT(ztp_r_field_vector(f, n));
    int *po = INTEGER(out);

    for (R_xlen_t i = 0; i < n; i++) {
        if (ISNAN(p[i].r)) {
            po[i] = NA_INTEGER;
            continue;
        }
        po[i] = f >= ZTP_FIELD_HOUR
                    ? ztp_r_time_field_value((int64_t)p[i].i, f)
                    : ztp_r_date_field_value((int32_t)p[i].r, f);
    }
    UNPROTECT(1);
    return out;
}

SEXP ztp_r_plain_date_time_round(SEXP x, SEXP increment, SEXP unit, SEXP mode)
{
    R_xlen_t n = Rf_xlength(x);
    const Rcomplex *p = COMPLEX(x);
    int64_t inc = (int64_t)Rf_asReal(increment);
    ztp_unit u = (ztp_unit)ztp_r_scalar_int(unit);
    ztp_rounding_mode m = (ztp_rounding_mode)ztp_r_scalar_int(mode);
    SEXP out = PROTECT(Rf_allocVector(CPLXSXP, n));
    Rcomplex *po = COMPLEX(out);
    ztp_ctx ctx;

    ztp_ctx_init(&ctx);
    for (R_xlen_t i = 0; i < n; i++) {
        int64_t rounded, days;
        if (ISNAN(p[i].r)) {
            po[i] = ztp_r_na_complex();
            continue;
        }
        /* RoundISODateTime: round the time, carry the days into the date. */
        ztp_round_time((int64_t)p[i].i, inc, u, m, &rounded, &days);
        po[i] = ztp_r_make_date_time(&ctx, (size_t)i + 1,
                                     (int64_t)p[i].r + days, rounded);
    }
    UNPROTECT(1);
    return out;
}

SEXP ztp_r_plain_date_time_format(SEXP x, SEXP precision, SEXP show_calendar)
{
    R_xlen_t n = Rf_xlength(x);
    const Rcomplex *p = COMPLEX(x);
    int prec = ztp_r_scalar_int(precision);
    ztp_show_calendar show = (ztp_show_calendar)ztp_r_scalar_int(show_calendar);
    SEXP out = PROTECT(Rf_allocVector(STRSXP, n));

    for (R_xlen_t i = 0; i < n; i++) {
        char buf[ZTP_FORMAT_DATE_TIME_CAP];
        if (ISNAN(p[i].r)) {
            SET_STRING_ELT(out, i, NA_STRING);
            continue;
        }
        ztp_format_iso_date_time(buf, (int32_t)p[i].r, (int64_t)p[i].i, prec, show);
        SET_STRING_ELT(out, i, Rf_mkCharCE(buf, CE_UTF8));
    }
    UNPROTECT(1);
    return out;
}

/* --- PlainYearMonth ----------------------------------------------------- */

/* Months since 1970-01, the stored form; the limits are those of
   ISOYearMonthWithinLimits. */
static int ztp_r_year_month_code(ztp_ctx *ctx, size_t index, int64_t year,
                                 int64_t month)
{
    if (!ztp_iso_year_month_within_limits(year, month)) {
        ztp_fail(ctx, ZTP_ERR_RANGE, index,
                 "%lld-%02lld is outside the range of a PlainYearMonth",
                 (long long)year, (long long)month);
        ztp_r_raise(ctx);
    }
    return (int)((year - 1970) * 12 + (month - 1));
}

/* CalendarYearMonthFromFields for the ISO calendar: the day is 1. */
SEXP ztp_r_plain_year_month_from_fields(SEXP year, SEXP month, SEXP overflow)
{
    R_xlen_t n = Rf_xlength(year);
    const double *py = REAL(year), *pm = REAL(month);
    ztp_overflow ov = (ztp_overflow)ztp_r_scalar_int(overflow);
    SEXP out = PROTECT(Rf_allocVector(INTSXP, n));
    int *po = INTEGER(out);
    ztp_ctx ctx;

    ztp_ctx_init(&ctx);
    for (R_xlen_t i = 0; i < n; i++) {
        int64_t y, m;
        size_t idx = (size_t)i + 1;
        ztp_iso_date d;

        if (!ztp_r_integer_field(&ctx, py[i], idx, "year", false, &y) ||
            !ztp_r_integer_field(&ctx, pm[i], idx, "month", true, &m)) {
            po[i] = NA_INTEGER;
            continue;
        }
        if (ztp_regulate_iso_date(&ctx, idx, y, m, 1, ov, &d) != ZTP_OK)
            ztp_r_raise(&ctx);
        po[i] = ztp_r_year_month_code(&ctx, idx, d.year, d.month);
    }
    UNPROTECT(1);
    return out;
}

SEXP ztp_r_plain_year_month_parse(SEXP x)
{
    R_xlen_t n = Rf_xlength(x);
    SEXP out = PROTECT(Rf_allocVector(INTSXP, n));
    int *po = INTEGER(out);
    ztp_ctx ctx;

    ztp_ctx_init(&ctx);
    for (R_xlen_t i = 0; i < n; i++) {
        ztp_parsed p;
        if (!ztp_r_parse_elt(&ctx, x, i, ZTP_PARSE_YEAR_MONTH, &p)) {
            po[i] = NA_INTEGER;
            continue;
        }
        po[i] = ztp_r_year_month_code(&ctx, (size_t)i + 1, p.year, p.month);
    }
    UNPROTECT(1);
    return out;
}

SEXP ztp_r_plain_year_month_format(SEXP x, SEXP show_calendar)
{
    R_xlen_t n = Rf_xlength(x);
    const int *px = INTEGER(x);
    ztp_show_calendar show = (ztp_show_calendar)ztp_r_scalar_int(show_calendar);
    SEXP out = PROTECT(Rf_allocVector(STRSXP, n));

    for (R_xlen_t i = 0; i < n; i++) {
        char buf[ZTP_FORMAT_DATE_CAP];
        int code, q;
        if (px[i] == NA_INTEGER) {
            SET_STRING_ELT(out, i, NA_STRING);
            continue;
        }
        code = px[i];
        q = code >= 0 ? code / 12 : -((-code + 11) / 12);   /* floor */
        ztp_format_iso_year_month(buf, (int32_t)(1970 + q),
                                  (uint32_t)(code - q * 12 + 1), show);
        SET_STRING_ELT(out, i, Rf_mkCharCE(buf, CE_UTF8));
    }
    UNPROTECT(1);
    return out;
}

/* --- PlainMonthDay ------------------------------------------------------ */

/* CalendarMonthDayFromFields for the ISO calendar: the month and day are
   regulated within `year` (1972 when the caller has none) and stored as
   month * 32 + day in the reference year 1972. */
SEXP ztp_r_plain_month_day_from_fields(SEXP year, SEXP month, SEXP day,
                                       SEXP overflow)
{
    R_xlen_t n = Rf_xlength(month);
    const double *py = REAL(year), *pm = REAL(month), *pd = REAL(day);
    ztp_overflow ov = (ztp_overflow)ztp_r_scalar_int(overflow);
    SEXP out = PROTECT(Rf_allocVector(INTSXP, n));
    int *po = INTEGER(out);
    ztp_ctx ctx;

    ztp_ctx_init(&ctx);
    for (R_xlen_t i = 0; i < n; i++) {
        int64_t y, m, d;
        size_t idx = (size_t)i + 1;
        ztp_iso_date date;

        if (!ztp_r_integer_field(&ctx, py[i], idx, "year", false, &y) ||
            !ztp_r_integer_field(&ctx, pm[i], idx, "month", true, &m) ||
            !ztp_r_integer_field(&ctx, pd[i], idx, "day", true, &d)) {
            po[i] = NA_INTEGER;
            continue;
        }
        if (ztp_regulate_iso_date(&ctx, idx, y, m, d, ov, &date) != ZTP_OK)
            ztp_r_raise(&ctx);
        po[i] = (int)(date.month * 32 + date.day);
    }
    UNPROTECT(1);
    return out;
}

SEXP ztp_r_plain_month_day_parse(SEXP x)
{
    R_xlen_t n = Rf_xlength(x);
    SEXP out = PROTECT(Rf_allocVector(INTSXP, n));
    int *po = INTEGER(out);
    ztp_ctx ctx;

    ztp_ctx_init(&ctx);
    for (R_xlen_t i = 0; i < n; i++) {
        ztp_parsed p;
        if (!ztp_r_parse_elt(&ctx, x, i, ZTP_PARSE_MONTH_DAY, &p)) {
            po[i] = NA_INTEGER;
            continue;
        }
        po[i] = (int)(p.month * 32 + p.day);
    }
    UNPROTECT(1);
    return out;
}

SEXP ztp_r_plain_month_day_format(SEXP x, SEXP show_calendar)
{
    R_xlen_t n = Rf_xlength(x);
    const int *px = INTEGER(x);
    ztp_show_calendar show = (ztp_show_calendar)ztp_r_scalar_int(show_calendar);
    SEXP out = PROTECT(Rf_allocVector(STRSXP, n));

    for (R_xlen_t i = 0; i < n; i++) {
        char buf[ZTP_FORMAT_DATE_CAP];
        if (px[i] == NA_INTEGER) {
            SET_STRING_ELT(out, i, NA_STRING);
            continue;
        }
        ztp_format_iso_month_day(buf, (uint32_t)(px[i] / 32), (uint32_t)(px[i] % 32), show);
        SET_STRING_ELT(out, i, Rf_mkCharCE(buf, CE_UTF8));
    }
    UNPROTECT(1);
    return out;
}

/* --- Parser self-check -------------------------------------------------- */

/* For tests: parse each string through one path and describe the outcome
   as text, so that the fast and slow paths can be compared. */
SEXP ztp_r_parse_describe(SEXP x, SEXP goal, SEXP path)
{
    R_xlen_t n = Rf_xlength(x);
    ztp_parse_goal g = (ztp_parse_goal)ztp_r_scalar_int(goal);
    int pth = ztp_r_scalar_int(path);
    SEXP out = PROTECT(Rf_allocVector(STRSXP, n));

    for (R_xlen_t i = 0; i < n; i++) {
        ztp_ctx ctx;
        ztp_parsed p;
        size_t pos;
        const char *s;
        char buf[160];

        if (STRING_ELT(x, i) == NA_STRING) {
            SET_STRING_ELT(out, i, NA_STRING);
            continue;
        }
        s = Rf_translateCharUTF8(STRING_ELT(x, i));
        ztp_ctx_init(&ctx);
        if (ztp_parse_path(&ctx, (size_t)i + 1, s, strlen(s), g, pth, &p, &pos) != ZTP_OK) {
            snprintf(buf, sizeof buf, "%s", ctx.status == ZTP_ERR_TYPE ? "n/a" : "error");
        } else {
            snprintf(buf, sizeof buf,
                     "%d-%02u-%02u y=%d d=%d time=%d %02u:%02u:%02u.%03u%03u%03u offset=%d %lld",
                     (int)p.year, p.month, p.day, (int)p.has_year, (int)p.has_day,
                     (int)p.has_time, p.time.hour,
                     p.time.minute, p.time.second, p.time.millisecond,
                     p.time.microsecond, p.time.nanosecond, (int)p.has_offset,
                     p.has_offset ? (long long)p.offset_ns : 0LL);
        }
        SET_STRING_ELT(out, i, Rf_mkCharCE(buf, CE_UTF8));
    }
    UNPROTECT(1);
    return out;
}

/* The syntax pass of zutempo_parse(): per element, NA where the string
   parses against the goal (or is NA), else the 1-based byte position and
   the message of the failure. A negative goal is a duration string. */
SEXP ztp_r_parse_check(SEXP x, SEXP goal)
{
    R_xlen_t n = Rf_xlength(x);
    int g = ztp_r_scalar_int(goal);
    const char *names[] = {"position", "message", ""};
    SEXP out = PROTECT(Rf_mkNamed(VECSXP, names));
    SEXP position = SET_VECTOR_ELT(out, 0, Rf_allocVector(REALSXP, n));
    SEXP message = SET_VECTOR_ELT(out, 1, Rf_allocVector(STRSXP, n));

    for (R_xlen_t i = 0; i < n; i++) {
        ztp_ctx ctx;
        ztp_parsed p;
        ztp_duration d;
        const char *s;
        ztp_status st;

        REAL(position)[i] = NA_REAL;
        SET_STRING_ELT(message, i, NA_STRING);
        if (STRING_ELT(x, i) == NA_STRING) continue;
        s = Rf_translateCharUTF8(STRING_ELT(x, i));
        ztp_ctx_init(&ctx);
        st = g < 0 ? ztp_duration_parse(&ctx, (size_t)i + 1, s, strlen(s), &d, NULL)
                   : ztp_parse(&ctx, (size_t)i + 1, s, strlen(s), (ztp_parse_goal)g, &p, NULL);
        if (st == ZTP_OK) continue;
        if (ctx.position > 0) REAL(position)[i] = (double)ctx.position;
        SET_STRING_ELT(message, i, Rf_mkCharCE(ctx.msg, CE_UTF8));
    }
    UNPROTECT(1);
    return out;
}

/* ParseTemporalTimeZoneString and ParseTemporalCalendarString on one
   string; `index` is the element a failure is reported against (0 for
   none). */
static size_t ztp_r_index_arg(SEXP index)
{
    double v = Rf_isNull(index) ? 0 : Rf_asReal(index);
    return ISNAN(v) || v < 1 ? 0 : (size_t)v;
}

SEXP ztp_r_time_zone_string(SEXP x, SEXP index)
{
    char buf[ZTP_TZ_ANNOTATION_CAP];
    const char *s = Rf_translateCharUTF8(STRING_ELT(x, 0));
    ztp_ctx ctx;

    ztp_ctx_init(&ctx);
    if (ztp_parse_time_zone_string(&ctx, ztp_r_index_arg(index), s, strlen(s), buf) != ZTP_OK)
        ztp_r_raise(&ctx);
    return Rf_mkString(buf);
}

SEXP ztp_r_calendar_string(SEXP x)
{
    char buf[ZTP_CALENDAR_CAP];
    const char *s = Rf_translateCharUTF8(STRING_ELT(x, 0));
    ztp_ctx ctx;

    ztp_ctx_init(&ctx);
    if (ztp_parse_calendar_string(&ctx, 0, s, strlen(s), buf) != ZTP_OK)
        ztp_r_raise(&ctx);
    return Rf_mkString(buf);
}
