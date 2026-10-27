/*
 * ztp_r.h -- the glue between R and the engine (design 4, 10).
 *
 * Only files named ztp_r_*.c and init.c include R headers. The glue
 * unpacks R vectors, loops over elements, handles NA, calls the engine
 * with a ztp_ctx, and turns a failed context into an R condition through
 * ztp_r_raise(), which evaluates zutempo:::stop_zutempo() in the package
 * namespace and never returns.
 */
#ifndef ZTP_R_H
#define ZTP_R_H

#define R_NO_REMAP
#include <R.h>
#include <Rinternals.h>

#include "ztp.h"
#include "ztp_instant.h"
#include "ztp_iso.h"

#include <math.h>

/* Raise the condition that ctx describes. Never returns. */
#if defined(__GNUC__) || defined(__clang__)
__attribute__((noreturn))
#endif
void ztp_r_raise(const ztp_ctx *ctx);

/* Raise if ctx holds a failure; otherwise return. */
static inline void ztp_r_check(const ztp_ctx *ctx)
{
    if (ctx->status != ZTP_OK) ztp_r_raise(ctx);
}

/* --- checks at the .Call entries (design 4) -----------------------------

   The R layer recycles, types and validates every argument, so these
   checks fail only for a caller that bypasses it (an internal refactor,
   or the C table after v0.1.0) or for a value no constructor makes. Each
   raises a zutempo_type_error. */

/* Raise a zutempo_type_error with a printf-style message; index is the
   1-based element, 0 for none. Never returns. */
#if defined(__GNUC__) || defined(__clang__)
__attribute__((noreturn, format(printf, 2, 3)))
#endif
void ztp_r_type_error(R_xlen_t index, const char *fmt, ...);

/* x must have the given type and, unless n is negative, length n. Returns
   the length. */
R_xlen_t ztp_r_arg(SEXP x, SEXPTYPE type, R_xlen_t n, const char *name);

/* As ztp_r_arg, with NULL also allowed. */
void ztp_r_arg_or_null(SEXP x, SEXPTYPE type, R_xlen_t n, const char *name);

/* A scalar option: length 1 and logical, integer or double, which is what
   Rf_asInteger(), Rf_asLogical() and Rf_asReal() read. */
void ztp_r_scalar(SEXP x, const char *name);

/* ztp_r_scalar(), then the value as Rf_asInteger() or Rf_asReal() reads
   it. */
int ztp_r_option_int(SEXP x, const char *name);
double ztp_r_option_real(SEXP x, const char *name);

/* A duration list: ten REALSXP fields of one length, n unless n is
   negative. Returns the length. */
R_xlen_t ztp_r_duration_arg(SEXP list, R_xlen_t n, const char *name);

/* A zoned value's parts: x a complex vector of length n (any length when
   n is negative), codes an integer vector of x's length whose every
   non-NA code indexes zones, zones a character vector without NA.
   Returns the length. */
R_xlen_t ztp_r_zoned_arg(SEXP x, SEXP codes, SEXP zones, R_xlen_t n);

/* The codes and table alone, for n elements. */
void ztp_r_zone_codes_arg(SEXP codes, SEXP zones, R_xlen_t n);

/* --- stored values (design 4.1) -----------------------------------------

   Each getter reads element i of a vector in a type's stored form: false
   for NA; the value through the pointers when a constructor could have
   made it; a zutempo_type_error naming the type otherwise. The checks are
   a few comparisons per element, small next to the work each element
   costs afterwards, and they keep a crafted object from reaching the
   engine, whose functions assume valid input. */

static inline bool ztp_r_date_get(const int *p, R_xlen_t i, int32_t *out)
{
    int v = p[i];
    if (v == NA_INTEGER) return false;
    if (v < ZTP_MIN_EPOCH_DAY || v > ZTP_MAX_EPOCH_DAY)
        ztp_r_type_error(i + 1, "the value is not a valid %s", "plain_date()");
    *out = (int32_t)v;
    return true;
}

static inline bool ztp_r_ns_of_day_ok(double v)
{
    return v >= 0 && v < (double)ZTP_NS_PER_DAY && v == (double)(int64_t)v;
}

static inline bool ztp_r_time_get(const double *p, R_xlen_t i, int64_t *out)
{
    double v = p[i];
    if (ISNAN(v)) return false;
    if (!ztp_r_ns_of_day_ok(v))
        ztp_r_type_error(i + 1, "the value is not a valid %s", "plain_time()");
    *out = (int64_t)v;
    return true;
}

static inline bool ztp_r_date_time_get(const Rcomplex *p, R_xlen_t i, int32_t *day,
                                       int64_t *ns)
{
    double r = p[i].r, v = p[i].i;
    if (ISNAN(r)) return false;
    if (!(r >= ZTP_MIN_EPOCH_DAY && r <= ZTP_MAX_EPOCH_DAY && r == (double)(int32_t)r) ||
        !ztp_r_ns_of_day_ok(v) || !ztp_iso_date_time_within_limits((int64_t)r, (int64_t)v))
        ztp_r_type_error(i + 1, "the value is not a valid %s", "plain_date_time()");
    *day = (int32_t)r;
    *ns = (int64_t)v;
    return true;
}

/* A year-month is stored as months since 1970-01. */
static inline bool ztp_r_year_month_get(const int *p, R_xlen_t i, int32_t *year,
                                        uint32_t *month)
{
    int code = p[i], q;
    if (code == NA_INTEGER) return false;
    q = code >= 0 ? code / 12 : -((-code + 11) / 12);   /* floor */
    if (!ztp_iso_year_month_within_limits((int64_t)1970 + q, code - q * 12 + 1))
        ztp_r_type_error(i + 1, "the value is not a valid %s", "plain_year_month()");
    *year = (int32_t)(1970 + q);
    *month = (uint32_t)(code - q * 12 + 1);
    return true;
}

/* A month-day is stored as month * 32 + day, a valid date in 1972. */
static inline bool ztp_r_month_day_get(const int *p, R_xlen_t i, uint32_t *month,
                                       uint32_t *day)
{
    int code = p[i];
    if (code == NA_INTEGER) return false;
    if (code < 33 || code > 12 * 32 + 31 || code % 32 < 1 ||
        (uint32_t)(code % 32) > ztp_iso_days_in_month(1972, (uint32_t)(code / 32)))
        ztp_r_type_error(i + 1, "the value is not a valid %s", "plain_month_day()");
    *month = (uint32_t)(code / 32);
    *day = (uint32_t)(code % 32);
    return true;
}

/* An instant is stored as integral epoch seconds and nanoseconds in
   [0, 10^9), and so are a zoned value's instants; `what` names the type. */
static inline bool ztp_r_epoch_get(const Rcomplex *p, R_xlen_t i, zuf_i128 *ns,
                                   const char *what)
{
    if (ISNAN(p[i].r)) return false;
    if (!ztp_epoch_ns_join(p[i].r, p[i].i, ns))
        ztp_r_type_error(i + 1, "the value is not a valid %s", what);
    return true;
}

/* A duration is ten doubles: NA when any is NA, else integral and valid
   (IsValidDuration). Every double of 2^52 or more is an integer. */
static inline bool ztp_r_duration_get(SEXP list, R_xlen_t i, ztp_duration *d)
{
    bool integral = true;
    for (int f = 0; f < ZTP_DURATION_FIELDS; f++) {
        double v = REAL(VECTOR_ELT(list, f))[i];
        if (ISNAN(v)) return false;
        if (fabs(v) < 4503599627370496.0 && v != trunc(v)) integral = false;
        ztp_duration_set_field(d, f, v);
    }
    if (!integral || !ztp_duration_is_valid(d))
        ztp_r_type_error(i + 1, "the value is not a valid %s", "duration()");
    return true;
}

/* .Call entry points, registered in init.c. */
SEXP ztp_r_info(void);
SEXP ztp_r_probe_civil(SEXP days);
SEXP ztp_r_probe_mul(SEXP a, SEXP b);
SEXP ztp_r_probe_fail(SEXP kind, SEXP index);

/* ztp_r_plain.c */
SEXP ztp_r_plain_date_from_fields(SEXP year, SEXP month, SEXP day, SEXP overflow);
SEXP ztp_r_plain_date_parse(SEXP x);
SEXP ztp_r_plain_date_field(SEXP days, SEXP field);
SEXP ztp_r_plain_date_format(SEXP days, SEXP show_calendar);
SEXP ztp_r_plain_time_from_fields(SEXP hour, SEXP minute, SEXP second,
                                  SEXP millisecond, SEXP microsecond,
                                  SEXP nanosecond, SEXP overflow);
SEXP ztp_r_plain_time_parse(SEXP x);
SEXP ztp_r_plain_time_field(SEXP ns, SEXP field);
SEXP ztp_r_plain_time_round(SEXP ns, SEXP increment, SEXP unit, SEXP mode);
SEXP ztp_r_plain_time_format(SEXP ns, SEXP precision);
SEXP ztp_r_plain_date_time_from_fields(SEXP year, SEXP month, SEXP day,
                                       SEXP hour, SEXP minute, SEXP second,
                                       SEXP millisecond, SEXP microsecond,
                                       SEXP nanosecond, SEXP overflow);
SEXP ztp_r_plain_date_time_parse(SEXP x);
SEXP ztp_r_plain_date_time_combine(SEXP days, SEXP ns);
SEXP ztp_r_plain_date_time_field(SEXP x, SEXP field);
SEXP ztp_r_plain_date_time_round(SEXP x, SEXP increment, SEXP unit, SEXP mode);
SEXP ztp_r_plain_date_time_format(SEXP x, SEXP precision, SEXP show_calendar);
SEXP ztp_r_plain_year_month_from_fields(SEXP year, SEXP month, SEXP overflow);
SEXP ztp_r_plain_year_month_parse(SEXP x);
SEXP ztp_r_plain_year_month_format(SEXP x, SEXP show_calendar);
SEXP ztp_r_plain_month_day_from_fields(SEXP year, SEXP month, SEXP day, SEXP overflow);
SEXP ztp_r_plain_month_day_parse(SEXP x);
SEXP ztp_r_plain_month_day_format(SEXP x, SEXP show_calendar);
SEXP ztp_r_parse_describe(SEXP x, SEXP goal, SEXP path);
SEXP ztp_r_parse_check(SEXP x, SEXP goal);
SEXP ztp_r_time_zone_string(SEXP x, SEXP index);
SEXP ztp_r_calendar_string(SEXP x);

/* ztp_r_instant.c */
SEXP ztp_r_instant_parse(SEXP x);
SEXP ztp_r_instant_from_epoch_ms(SEXP ms);
SEXP ztp_r_instant_from_epoch_ns(SEXP x);
SEXP ztp_r_instant_epoch_ms(SEXP x);
SEXP ztp_r_instant_epoch_ns_string(SEXP x);
SEXP ztp_r_instant_add(SEXP x, SEXP dur);
SEXP ztp_r_instant_until(SEXP x1, SEXP x2, SEXP largest, SEXP smallest,
                         SEXP increment, SEXP mode);
SEXP ztp_r_instant_round(SEXP x, SEXP increment, SEXP unit, SEXP mode);
SEXP ztp_r_instant_format(SEXP x, SEXP zone, SEXP precision);
SEXP ztp_r_zone_normalise(SEXP x);
SEXP ztp_r_instant_from_seconds(SEXP x);
SEXP ztp_r_instant_to_seconds(SEXP x);
SEXP ztp_r_seconds_split(SEXP x);

/* ztp_r_zoned.c */
ztp_zone *ztp_r_zones_open(SEXP zones);
SEXP ztp_r_zoned_interpret(SEXP days, SEXP ns, SEXP codes, SEXP zones, SEXP behaviour,
                           SEXP offset_ns, SEXP disambiguation, SEXP offset_option,
                           SEXP match_minutes);
SEXP ztp_r_zoned_parse(SEXP x);
SEXP ztp_r_zoned_local(SEXP x, SEXP codes, SEXP zones);
SEXP ztp_r_zoned_offset(SEXP x, SEXP codes, SEXP zones);
SEXP ztp_r_zoned_start_of_day(SEXP x, SEXP codes, SEXP zones);
SEXP ztp_r_zoned_hours_in_day(SEXP x, SEXP codes, SEXP zones);
SEXP ztp_r_zoned_format(SEXP x, SEXP codes, SEXP zones, SEXP precision, SEXP show_offset,
                        SEXP show_zone, SEXP show_calendar);
SEXP ztp_r_zone_equals(SEXP a, SEXP b);
SEXP ztp_r_format_offset_exact(SEXP offset_ns);
SEXP ztp_r_parse_offset_string(SEXP x);
SEXP ztp_r_zoned_add(SEXP x, SEXP codes, SEXP zones, SEXP dur, SEXP overflow);
SEXP ztp_r_zoned_until(SEXP x1, SEXP codes1, SEXP zones1, SEXP x2, SEXP codes2, SEXP zones2,
                       SEXP largest, SEXP smallest, SEXP increment, SEXP mode);
SEXP ztp_r_zoned_round(SEXP x, SEXP codes, SEXP zones, SEXP increment, SEXP unit, SEXP mode);
SEXP ztp_r_zoned_transition(SEXP x, SEXP codes, SEXP zones, SEXP direction);
/* The zones of a table, parsed (ztp_zone is declared in ztp_instant.h). */

/* ztp_r_tz.c */
SEXP ztp_r_tz_load(SEXP id, SEXP bytes);
SEXP ztp_r_tz_reset(void);
SEXP ztp_r_tz_loaded(SEXP id);
SEXP ztp_r_tz_utoff(SEXP id, SEXP seconds);
SEXP ztp_r_tz_possible(SEXP id, SEXP days, SEXP ns);
SEXP ztp_r_tz_transition(SEXP id, SEXP x, SEXP direction);
SEXP ztp_r_tz_last_explicit(SEXP id);
SEXP ztp_r_tz_links_version(void);
SEXP ztp_r_tz_link_target(SEXP ids);
SEXP ztp_r_tz_rule_utoff(SEXP rule, SEXP seconds);

/* ztp_r_duration.c */
SEXP ztp_r_duration_create(SEXP fields);
SEXP ztp_r_duration_parse(SEXP x);
SEXP ztp_r_duration_format(SEXP dur, SEXP precision, SEXP increment, SEXP unit,
                           SEXP mode);
SEXP ztp_r_duration_add(SEXP a, SEXP b);
SEXP ztp_r_duration_round(SEXP dur, SEXP largest, SEXP smallest, SEXP increment,
                          SEXP mode, SEXP smallest_present, SEXP relative_days,
                          SEXP relative_zoned, SEXP relative_codes, SEXP relative_zones);
SEXP ztp_r_duration_total(SEXP dur, SEXP unit, SEXP relative_days, SEXP relative_zoned,
                          SEXP relative_codes, SEXP relative_zones);
SEXP ztp_r_duration_compare(SEXP a, SEXP b, SEXP relative_days, SEXP relative_zoned,
                            SEXP relative_codes, SEXP relative_zones);
SEXP ztp_r_plain_date_add(SEXP days, SEXP dur, SEXP overflow);
SEXP ztp_r_plain_date_until(SEXP d1, SEXP d2, SEXP largest, SEXP smallest,
                            SEXP increment, SEXP mode);
SEXP ztp_r_plain_time_add(SEXP ns, SEXP dur);
SEXP ztp_r_plain_time_until(SEXP t1, SEXP t2, SEXP largest, SEXP smallest,
                            SEXP increment, SEXP mode);
SEXP ztp_r_plain_date_time_add(SEXP x, SEXP dur, SEXP overflow);
SEXP ztp_r_plain_date_time_until(SEXP x1, SEXP x2, SEXP largest, SEXP smallest,
                                 SEXP increment, SEXP mode);
SEXP ztp_r_plain_year_month_add(SEXP ym, SEXP dur, SEXP overflow);
SEXP ztp_r_plain_year_month_until(SEXP ym1, SEXP ym2, SEXP largest, SEXP smallest,
                                  SEXP increment, SEXP mode);

#endif /* ZTP_R_H */
