/* ztp_iso.c -- see ztp_iso.h. Engine side: no R. */

#include "ztp_iso.h"

#include <zufast/datetime.h>

/* Years this far from the epoch have no date within limits, and keep the
   civil arithmetic inside int32_t days. */
#define ZTP_ISO_YEAR_GUARD INT64_C(1000000)

uint32_t ztp_iso_days_in_month(int32_t year, uint32_t month)
{
    return zuf_days_in_month(year, month);
}

uint32_t ztp_iso_days_in_year(int32_t year)
{
    return zuf_is_leap_year(year) ? 366u : 365u;
}

bool ztp_iso_in_leap_year(int32_t year)
{
    return zuf_is_leap_year(year);
}

bool ztp_is_valid_iso_date(int64_t year, int64_t month, int64_t day)
{
    if (year < -ZTP_ISO_YEAR_GUARD || year > ZTP_ISO_YEAR_GUARD) return false;
    if (month < 1 || month > 12) return false;
    if (day < 1 || day > (int64_t)zuf_days_in_month((int32_t)year, (uint32_t)month))
        return false;
    return true;
}

bool ztp_is_valid_time(int64_t hour, int64_t minute, int64_t second,
                       int64_t millisecond, int64_t microsecond,
                       int64_t nanosecond)
{
    return hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59 &&
           second >= 0 && second <= 59 && millisecond >= 0 &&
           millisecond <= 999 && microsecond >= 0 && microsecond <= 999 &&
           nanosecond >= 0 && nanosecond <= 999;
}

static int64_t ztp_clamp(int64_t x, int64_t lo, int64_t hi)
{
    return x < lo ? lo : (x > hi ? hi : x);
}

ztp_status ztp_regulate_iso_date(ztp_ctx *ctx, size_t index, int64_t year,
                                 int64_t month, int64_t day,
                                 ztp_overflow overflow, ztp_iso_date *out)
{
    if (year < -ZTP_ISO_YEAR_GUARD || year > ZTP_ISO_YEAR_GUARD)
        return ztp_fail(ctx, ZTP_ERR_RANGE, index,
                        "year %lld is outside the representable range",
                        (long long)year);
    if (overflow == ZTP_OVERFLOW_CONSTRAIN) {
        month = ztp_clamp(month, 1, 12);
        day = ztp_clamp(day, 1,
                        (int64_t)zuf_days_in_month((int32_t)year, (uint32_t)month));
    } else if (!ztp_is_valid_iso_date(year, month, day)) {
        return ztp_fail(ctx, ZTP_ERR_RANGE, index,
                        "%lld-%02lld-%02lld is not a valid date",
                        (long long)year, (long long)month, (long long)day);
    }
    out->year = (int32_t)year;
    out->month = (uint32_t)month;
    out->day = (uint32_t)day;
    return ZTP_OK;
}

ztp_status ztp_regulate_time(ztp_ctx *ctx, size_t index, int64_t hour,
                             int64_t minute, int64_t second,
                             int64_t millisecond, int64_t microsecond,
                             int64_t nanosecond, ztp_overflow overflow,
                             ztp_iso_time *out)
{
    if (overflow == ZTP_OVERFLOW_CONSTRAIN) {
        hour = ztp_clamp(hour, 0, 23);
        minute = ztp_clamp(minute, 0, 59);
        second = ztp_clamp(second, 0, 59);
        millisecond = ztp_clamp(millisecond, 0, 999);
        microsecond = ztp_clamp(microsecond, 0, 999);
        nanosecond = ztp_clamp(nanosecond, 0, 999);
    } else if (!ztp_is_valid_time(hour, minute, second, millisecond,
                                  microsecond, nanosecond)) {
        return ztp_fail(ctx, ZTP_ERR_RANGE, index,
                        "%lld:%02lld:%02lld.%03lld%03lld%03lld is not a valid time",
                        (long long)hour, (long long)minute, (long long)second,
                        (long long)millisecond, (long long)microsecond,
                        (long long)nanosecond);
    }
    out->hour = (uint32_t)hour;
    out->minute = (uint32_t)minute;
    out->second = (uint32_t)second;
    out->millisecond = (uint32_t)millisecond;
    out->microsecond = (uint32_t)microsecond;
    out->nanosecond = (uint32_t)nanosecond;
    return ZTP_OK;
}

int32_t ztp_epoch_day_from_iso_date(const ztp_iso_date *date)
{
    return zuf_days_from_civil(date->year, date->month, date->day);
}

void ztp_iso_date_from_epoch_day(int32_t epoch_day, ztp_iso_date *out)
{
    zuf_civil_from_days(epoch_day, &out->year, &out->month, &out->day);
}

int64_t ztp_ns_from_iso_time(const ztp_iso_time *t)
{
    return ((((int64_t)t->hour * 60 + t->minute) * 60 + t->second) *
                ZTP_NS_PER_SECOND) +
           (int64_t)t->millisecond * ZTP_NS_PER_MILLISECOND +
           (int64_t)t->microsecond * ZTP_NS_PER_MICROSECOND + t->nanosecond;
}

void ztp_iso_time_from_ns(int64_t ns, ztp_iso_time *out)
{
    out->hour = (uint32_t)(ns / ZTP_NS_PER_HOUR);
    ns %= ZTP_NS_PER_HOUR;
    out->minute = (uint32_t)(ns / ZTP_NS_PER_MINUTE);
    ns %= ZTP_NS_PER_MINUTE;
    out->second = (uint32_t)(ns / ZTP_NS_PER_SECOND);
    ns %= ZTP_NS_PER_SECOND;
    out->millisecond = (uint32_t)(ns / ZTP_NS_PER_MILLISECOND);
    ns %= ZTP_NS_PER_MILLISECOND;
    out->microsecond = (uint32_t)(ns / ZTP_NS_PER_MICROSECOND);
    out->nanosecond = (uint32_t)(ns % ZTP_NS_PER_MICROSECOND);
}

bool ztp_iso_date_time_within_limits(int64_t epoch_day, int64_t ns_of_day)
{
    /* ns > nsMinInstant - nsPerDay and ns < nsMaxInstant + nsPerDay, with
       nsMaxInstant = ZTP_MAX_EPOCH_DAY days, done in days so that nothing
       overflows: the lower bound is exclusive at exactly midnight of the
       minimum day, the upper bound admits every time of the maximum day. */
    if (epoch_day < ZTP_MIN_EPOCH_DAY || epoch_day > ZTP_MAX_EPOCH_DAY)
        return false;
    if (epoch_day == ZTP_MIN_EPOCH_DAY && ns_of_day == 0) return false;
    return true;
}

bool ztp_iso_year_month_within_limits(int64_t year, int64_t month)
{
    if (year < -271821 || year > 275760) return false;
    if (year == -271821 && month < 4) return false;
    if (year == 275760 && month > 9) return false;
    return true;
}

bool ztp_iso_date_within_limits(int64_t epoch_day)
{
    /* ISODateWithinLimits defers to the date-time check at noon. */
    return ztp_iso_date_time_within_limits(epoch_day, 12 * ZTP_NS_PER_HOUR);
}

uint32_t ztp_iso_day_of_week(int32_t epoch_day)
{
    /* zufast numbers Monday 1 to Sunday 7, as ISO 8601 does. */
    return zuf_weekday_from_days(epoch_day);
}

uint32_t ztp_iso_day_of_year(int32_t epoch_day)
{
    ztp_iso_date d;

    ztp_iso_date_from_epoch_day(epoch_day, &d);
    return (uint32_t)(epoch_day - zuf_days_from_civil(d.year, 1, 1)) + 1u;
}

void ztp_iso_week_of_year(int32_t epoch_day, int32_t *week_year,
                          uint32_t *week)
{
    zuf_iso_week_from_days(epoch_day, week_year, week);
}

static int64_t ztp_floor_div(int64_t a, int64_t b)
{
    int64_t q = a / b;
    return (a % b != 0 && ((a < 0) != (b < 0))) ? q - 1 : q;
}

void ztp_balance_time(int64_t hour, int64_t minute, int64_t second,
                      int64_t millisecond, int64_t microsecond,
                      int64_t nanosecond, ztp_iso_time *out,
                      int64_t *delta_days)
{
    int64_t carry;

    carry = ztp_floor_div(nanosecond, 1000);
    nanosecond -= carry * 1000;
    microsecond += carry;
    carry = ztp_floor_div(microsecond, 1000);
    microsecond -= carry * 1000;
    millisecond += carry;
    carry = ztp_floor_div(millisecond, 1000);
    millisecond -= carry * 1000;
    second += carry;
    carry = ztp_floor_div(second, 60);
    second -= carry * 60;
    minute += carry;
    carry = ztp_floor_div(minute, 60);
    minute -= carry * 60;
    hour += carry;
    carry = ztp_floor_div(hour, 24);
    hour -= carry * 24;
    *delta_days = carry;
    out->hour = (uint32_t)hour;
    out->minute = (uint32_t)minute;
    out->second = (uint32_t)second;
    out->millisecond = (uint32_t)millisecond;
    out->microsecond = (uint32_t)microsecond;
    out->nanosecond = (uint32_t)nanosecond;
}
