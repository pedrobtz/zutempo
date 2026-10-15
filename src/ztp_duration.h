/*
 * ztp_duration.h -- Temporal.Duration in the engine (Temporal 7.5). Engine
 * side: no R.
 *
 * A duration is ten float64-representable integers, as the specification
 * defines them (design 4.1). Arithmetic happens on the internal form: a
 * Date Duration Record of years, months, weeks and days, and a time
 * duration of total nanoseconds held in a zuf_i128, bounded by
 * maxTimeDuration = 2^53 * 10^9 - 1 (design 4.3).
 */
#ifndef ZTP_DURATION_H
#define ZTP_DURATION_H

#include "ztp_round.h"

#include <zufast/wide.h>

typedef struct {
    double years, months, weeks, days, hours, minutes, seconds,
        milliseconds, microseconds, nanoseconds;
} ztp_duration;

typedef struct {
    double years, months, weeks, days;
} ztp_date_duration;

/* An Internal Duration Record. */
typedef struct {
    ztp_date_duration date;
    zuf_i128 time;
} ztp_internal_duration;

#define ZTP_DURATION_FIELDS 10

/* The ten fields in the order of the records, for loops. */
double ztp_duration_field(const ztp_duration *d, int i);
void ztp_duration_set_field(ztp_duration *d, int i, double value);

/* maxTimeDuration, and whether |t| is within it. */
zuf_i128 ztp_max_time_duration(void);
bool ztp_time_duration_in_range(zuf_i128 t);

/* IsValidDuration over doubles that are already integral and finite. */
bool ztp_duration_is_valid(const ztp_duration *d);

/* CreateTemporalDuration: ZTP_ERR_RANGE when invalid. */
ztp_status ztp_duration_create(ztp_ctx *ctx, size_t index,
                               const ztp_duration *in, ztp_duration *out);

/* DurationSign, DateDurationSign, TimeDurationSign, DefaultTemporalLargestUnit. */
int ztp_duration_sign(const ztp_duration *d);
int ztp_date_duration_sign(const ztp_date_duration *d);
int ztp_time_duration_sign(zuf_i128 t);
ztp_unit ztp_duration_default_largest_unit(const ztp_duration *d);

/* TimeDurationFromComponents. The result always fits for a valid
   duration's fields. */
zuf_i128 ztp_time_duration_from_components(double hours, double minutes,
                                           double seconds, double milliseconds,
                                           double microseconds,
                                           double nanoseconds);

/* ToInternalDurationRecord and ToInternalDurationRecordWith24HourDays. */
ztp_internal_duration ztp_duration_to_internal(const ztp_duration *d);
ztp_internal_duration ztp_duration_to_internal_24h(const ztp_duration *d);

/* Add24HourDaysToTimeDuration and AddTimeDuration: ZTP_ERR_RANGE past
   maxTimeDuration. */
ztp_status ztp_time_duration_add_days(ztp_ctx *ctx, size_t index, zuf_i128 t,
                                      double days, zuf_i128 *out);
ztp_status ztp_time_duration_add(ztp_ctx *ctx, size_t index, zuf_i128 a,
                                 zuf_i128 b, zuf_i128 *out);

/* TemporalDurationFromInternal: balances the time up to largest_unit and
   checks the result with IsValidDuration. */
ztp_status ztp_duration_from_internal(ztp_ctx *ctx, size_t index,
                                      const ztp_internal_duration *in,
                                      ztp_unit largest_unit, ztp_duration *out);

/* RoundTimeDuration (increment in units of `unit`) and TotalTimeDuration
   (a double, the one division). */
ztp_status ztp_time_duration_round(ztp_ctx *ctx, size_t index, zuf_i128 t,
                                   int64_t increment, ztp_unit unit,
                                   ztp_rounding_mode mode, zuf_i128 *out);
double ztp_time_duration_total(zuf_i128 t, ztp_unit unit);

/* RoundNumberToIncrement over zuf_i128, with an i128 increment. */
zuf_i128 ztp_round_i128_to_increment(zuf_i128 x, zuf_i128 increment,
                                     ztp_rounding_mode mode, bool as_if_positive);

/* Exact or nearest conversions. */
bool ztp_i128_from_double(double x, zuf_i128 *out);
double ztp_i128_to_double(zuf_i128 v);
zuf_i128 ztp_i128_abs(zuf_i128 v);

/* ParseTemporalDurationString: ZTP_ERR_PARSE with the position of the
   first bad byte, or ZTP_ERR_RANGE when the fields exceed the bounds. */
ztp_status ztp_duration_parse(ztp_ctx *ctx, size_t index, const char *s,
                              size_t n, ztp_duration *out, size_t *position);

/* TemporalDurationToString. dst needs ZTP_DURATION_FORMAT_CAP bytes. */
#define ZTP_DURATION_FORMAT_CAP 256
size_t ztp_duration_format(char *dst, const ztp_duration *d, int precision);

#endif /* ZTP_DURATION_H */
