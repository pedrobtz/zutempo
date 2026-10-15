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

#endif /* ZTP_R_H */
