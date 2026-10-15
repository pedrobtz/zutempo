/*
 * ztp_relative.h -- calendar arithmetic and rounding relative to a date
 * (Temporal 12.2 CalendarDateAdd and CalendarDateUntil, 5.5
 * DifferenceISODateTime, 7.5 RoundRelativeDuration and
 * TotalRelativeDuration, for the case without a time zone). Engine side:
 * no R.
 */
#ifndef ZTP_RELATIVE_H
#define ZTP_RELATIVE_H

#include "ztp_duration.h"

/* CalendarDateAdd for the ISO calendar on an epoch day: years and months
   first with overflow, then weeks and days; ZTP_ERR_RANGE outside the
   limits of a PlainDate. */
ztp_status ztp_calendar_date_add(ztp_ctx *ctx, size_t index, int32_t epoch_day,
                                 const ztp_date_duration *duration,
                                 ztp_overflow overflow, int32_t *out);

/* CalendarDateUntil for the ISO calendar: the duration from one to two
   with no field larger than largest_unit (a date unit). */
void ztp_calendar_date_until(int32_t one, int32_t two, ztp_unit largest_unit,
                             ztp_date_duration *out);

/* AddTime: a time of day plus a time duration gives a time of day and a
   count of days carried (any sign). */
void ztp_add_time(int64_t ns_of_day, zuf_i128 duration, int64_t *out_ns,
                  int64_t *out_days);

/* GetUTCEpochNanoseconds of a date-time. */
zuf_i128 ztp_epoch_ns_of(int32_t epoch_day, int64_t ns_of_day);

/* DifferenceISODateTime. */
void ztp_difference_iso_date_time(int32_t day1, int64_t ns1, int32_t day2,
                                  int64_t ns2, ztp_unit largest_unit,
                                  ztp_internal_duration *out);

/* RoundRelativeDuration with no time zone: `duration` is the difference
   from the origin date-time to the destination; the result is rounded to
   `increment` units of smallest_unit and bubbled up to largest_unit. */
ztp_status ztp_round_relative_duration(ztp_ctx *ctx, size_t index,
                                       const ztp_internal_duration *duration,
                                       int32_t origin_day, int64_t origin_ns,
                                       int32_t dest_day, int64_t dest_ns,
                                       ztp_unit largest_unit, int64_t increment,
                                       ztp_unit smallest_unit,
                                       ztp_rounding_mode mode,
                                       ztp_internal_duration *out);

/* TotalRelativeDuration with no time zone. */
ztp_status ztp_total_relative_duration(ztp_ctx *ctx, size_t index,
                                       const ztp_internal_duration *duration,
                                       int32_t origin_day, int64_t origin_ns,
                                       int32_t dest_day, int64_t dest_ns,
                                       ztp_unit unit, double *out);

/* DifferencePlainDateTimeWithRounding and ...WithTotal. */
ztp_status ztp_difference_plain_date_time_rounded(
    ztp_ctx *ctx, size_t index, int32_t day1, int64_t ns1, int32_t day2,
    int64_t ns2, ztp_unit largest_unit, int64_t increment,
    ztp_unit smallest_unit, ztp_rounding_mode mode, ztp_internal_duration *out);
ztp_status ztp_difference_plain_date_time_total(ztp_ctx *ctx, size_t index,
                                                int32_t day1, int64_t ns1,
                                                int32_t day2, int64_t ns2,
                                                ztp_unit unit, double *out);

#endif /* ZTP_RELATIVE_H */
