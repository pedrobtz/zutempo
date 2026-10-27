/*
 * ztp_iso.h -- ISO 8601 calendar dates and clock times (Temporal 3.5, 4.5,
 * 5.5 and the iso8601 branches of 12.2). Engine side: no R.
 *
 * Dates travel as epoch days (int32_t, days since 1970-01-01) and times
 * as nanoseconds of day (int64_t, 0 <= ns < ZTP_NS_PER_DAY), the forms
 * the R vectors store (design 4.1). Field records exist for the edges:
 * validation, regulation and field access.
 */
#ifndef ZTP_ISO_H
#define ZTP_ISO_H

#include "ztp.h"

#define ZTP_NS_PER_DAY INT64_C(86400000000000)
#define ZTP_NS_PER_HOUR INT64_C(3600000000000)
#define ZTP_NS_PER_MINUTE INT64_C(60000000000)
#define ZTP_NS_PER_SECOND INT64_C(1000000000)
#define ZTP_NS_PER_MILLISECOND INT64_C(1000000)
#define ZTP_NS_PER_MICROSECOND INT64_C(1000)

/* nsMaxInstant is 10^8 days; a PlainDateTime may lie up to one day beyond
   either end (ISODateTimeWithinLimits). In epoch days: */
#define ZTP_MAX_EPOCH_DAY INT32_C(100000000)        /* +275760-09-13 */
#define ZTP_MIN_EPOCH_DAY (-ZTP_MAX_EPOCH_DAY - 1)  /* -271821-04-19 */

typedef enum { ZTP_OVERFLOW_CONSTRAIN = 0, ZTP_OVERFLOW_REJECT = 1 } ztp_overflow;

/* IsValidISODate holds for every ztp_iso_date; IsValidTime for every
   ztp_iso_time. */
typedef struct {
    int32_t year;
    uint32_t month, day;
} ztp_iso_date;

typedef struct {
    uint32_t hour, minute, second, millisecond, microsecond, nanosecond;
} ztp_iso_time;

/* ISODaysInMonth, MathematicalDaysInYear, MathematicalInLeapYear. */
uint32_t ztp_iso_days_in_month(int32_t year, uint32_t month);
uint32_t ztp_iso_days_in_year(int32_t year);
bool ztp_iso_in_leap_year(int32_t year);

/* IsValidISODate and IsValidTime over arbitrary integers. */
bool ztp_is_valid_iso_date(int64_t year, int64_t month, int64_t day);
bool ztp_is_valid_time(int64_t hour, int64_t minute, int64_t second,
                       int64_t millisecond, int64_t microsecond,
                       int64_t nanosecond);

/* RegulateISODate: month and day are positive (the caller has applied
   ToPositiveIntegerWithTruncation); year is any integer. Fails with
   ZTP_ERR_RANGE under `reject` for an invalid date, and for a year so far
   out that no date in it is within limits. */
ztp_status ztp_regulate_iso_date(ztp_ctx *ctx, size_t index, int64_t year,
                                 int64_t month, int64_t day,
                                 ztp_overflow overflow, ztp_iso_date *out);

/* RegulateTime over arbitrary integers. */
ztp_status ztp_regulate_time(ztp_ctx *ctx, size_t index, int64_t hour,
                             int64_t minute, int64_t second,
                             int64_t millisecond, int64_t microsecond,
                             int64_t nanosecond, ztp_overflow overflow,
                             ztp_iso_time *out);

/* Conversions between the field records and the stored forms. The date
   must be within a few million years of the epoch for the day to fit. */
int32_t ztp_epoch_day_from_iso_date(const ztp_iso_date *date);
void ztp_iso_date_from_epoch_day(int32_t epoch_day, ztp_iso_date *out);
int64_t ztp_ns_from_iso_time(const ztp_iso_time *time);
void ztp_iso_time_from_ns(int64_t ns_of_day, ztp_iso_time *out);

/* ISOYearMonthWithinLimits: every month that holds a representable day. */
bool ztp_iso_year_month_within_limits(int64_t year, int64_t month);

/* ISODateWithinLimits and ISODateTimeWithinLimits. */
bool ztp_iso_date_within_limits(int64_t epoch_day);
bool ztp_iso_date_time_within_limits(int64_t epoch_day, int64_t ns_of_day);

/* The fields of CalendarISOToDate that need computing. ISODayOfWeek is
   1 (Monday) to 7 (Sunday); ISODayOfYear is 1-based; ISOWeekOfYear
   returns the week number and the week-calendar year it belongs to. */
uint32_t ztp_iso_day_of_week(int32_t epoch_day);
uint32_t ztp_iso_day_of_year(int32_t epoch_day);
void ztp_iso_week_of_year(int32_t epoch_day, int32_t *week_year,
                          uint32_t *week);

#endif /* ZTP_ISO_H */
