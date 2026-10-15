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
                        SEXP show_zone);
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
SEXP ztp_r_duration_format(SEXP dur, SEXP precision);
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
