/*
 * ztp_relative.h -- calendar arithmetic and rounding relative to a date
 * (Temporal 12.2 CalendarDateAdd and CalendarDateUntil, 5.5
 * DifferenceISODateTime, 7.5 RoundRelativeDuration and
 * TotalRelativeDuration with and without a time zone, 6.5 AddZonedDateTime
 * and DifferenceZonedDateTime). Engine side: no R.
 */
#ifndef ZTP_RELATIVE_H
#define ZTP_RELATIVE_H

#include "ztp_duration.h"
#include "ztp_zoned.h"

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

/* RoundRelativeDuration: `duration` is the difference from the origin
   (its local date-time, its exact time, and its zone or NULL for ~unset~)
   to the destination; the result is rounded to `increment` units of
   smallest_unit and bubbled up to largest_unit. */
ztp_status ztp_round_relative_duration(ztp_ctx *ctx, size_t index,
                                       const ztp_internal_duration *duration,
                                       int32_t origin_day, int64_t origin_ns,
                                       zuf_i128 origin_epoch, zuf_i128 dest_epoch,
                                       const ztp_zone *zone, ztp_unit largest_unit,
                                       int64_t increment, ztp_unit smallest_unit,
                                       ztp_rounding_mode mode,
                                       ztp_internal_duration *out);

/* TotalRelativeDuration. */
ztp_status ztp_total_relative_duration(ztp_ctx *ctx, size_t index,
                                       const ztp_internal_duration *duration,
                                       int32_t origin_day, int64_t origin_ns,
                                       zuf_i128 origin_epoch, zuf_i128 dest_epoch,
                                       const ztp_zone *zone, ztp_unit unit, double *out);

/* DifferencePlainDateTimeWithRounding and ...WithTotal. */
ztp_status ztp_difference_plain_date_time_rounded(
    ztp_ctx *ctx, size_t index, int32_t day1, int64_t ns1, int32_t day2,
    int64_t ns2, ztp_unit largest_unit, int64_t increment,
    ztp_unit smallest_unit, ztp_rounding_mode mode, ztp_internal_duration *out);
ztp_status ztp_difference_plain_date_time_total(ztp_ctx *ctx, size_t index,
                                                int32_t day1, int64_t ns1,
                                                int32_t day2, int64_t ns2,
                                                ztp_unit unit, double *out);

/* AddZonedDateTime: date units through the local calendar, resolved
   ~compatible~, then the time units on the exact time. */
ztp_status ztp_add_zoned_date_time(ztp_ctx *ctx, size_t index, zuf_i128 epoch,
                                   const ztp_zone *zone,
                                   const ztp_internal_duration *duration,
                                   ztp_overflow overflow, zuf_i128 *out);

/* DifferenceZonedDateTime, ...WithRounding and ...WithTotal. */
ztp_status ztp_difference_zoned_date_time(ztp_ctx *ctx, size_t index, zuf_i128 ns1,
                                          zuf_i128 ns2, const ztp_zone *zone,
                                          ztp_unit largest_unit,
                                          ztp_internal_duration *out);
ztp_status ztp_difference_zoned_rounded(ztp_ctx *ctx, size_t index, zuf_i128 ns1,
                                        zuf_i128 ns2, const ztp_zone *zone,
                                        ztp_unit largest_unit, int64_t increment,
                                        ztp_unit smallest_unit, ztp_rounding_mode mode,
                                        ztp_internal_duration *out);
ztp_status ztp_difference_zoned_total(ztp_ctx *ctx, size_t index, zuf_i128 ns1,
                                      zuf_i128 ns2, const ztp_zone *zone, ztp_unit unit,
                                      double *out);

/* Temporal.ZonedDateTime.prototype.round: a day is the local day's length,
   a time unit rounds the local time and keeps the offset when it can. */
ztp_status ztp_round_zoned_date_time(ztp_ctx *ctx, size_t index, zuf_i128 epoch,
                                     const ztp_zone *zone, int64_t increment,
                                     ztp_unit unit, ztp_rounding_mode mode, zuf_i128 *out);

#endif /* ZTP_RELATIVE_H */
