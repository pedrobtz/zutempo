/* ztp_format.c -- see ztp_format.h. Engine side: no R. */

#include "ztp_format.h"

#include <string.h>

static char *ztp_put_digits(char *dst, uint64_t v, unsigned width)
{
    for (unsigned i = width; i > 0; i--) {
        dst[i - 1] = (char)('0' + v % 10);
        v /= 10;
    }
    return dst + width;
}

/* PadISOYear: four digits for 0 to 9999, else a sign and six digits. */
static char *ztp_put_year(char *dst, int32_t year)
{
    if (year >= 0 && year <= 9999) return ztp_put_digits(dst, (uint64_t)year, 4);
    *dst++ = year < 0 ? '-' : '+';
    return ztp_put_digits(dst, (uint64_t)(year < 0 ? -(int64_t)year : year), 6);
}

/* FormatCalendarAnnotation for the ISO 8601 calendar. */
static char *ztp_put_calendar(char *dst, ztp_show_calendar show)
{
    const char *text;

    switch (show) {
    case ZTP_SHOW_CALENDAR_ALWAYS:   text = "[u-ca=iso8601]"; break;
    case ZTP_SHOW_CALENDAR_CRITICAL: text = "[!u-ca=iso8601]"; break;
    default:                         return dst;
    }
    memcpy(dst, text, strlen(text));
    return dst + strlen(text);
}

static char *ztp_put_date(char *dst, int32_t epoch_day)
{
    ztp_iso_date d;

    ztp_iso_date_from_epoch_day(epoch_day, &d);
    dst = ztp_put_year(dst, d.year);
    *dst++ = '-';
    dst = ztp_put_digits(dst, d.month, 2);
    *dst++ = '-';
    return ztp_put_digits(dst, d.day, 2);
}

/* FormatTimeString with FormatFractionalSeconds. */
static char *ztp_put_time(char *dst, int64_t ns_of_day, int precision)
{
    ztp_iso_time t;
    uint64_t sub;

    ztp_iso_time_from_ns(ns_of_day, &t);
    dst = ztp_put_digits(dst, t.hour, 2);
    *dst++ = ':';
    dst = ztp_put_digits(dst, t.minute, 2);
    if (precision == ZTP_PRECISION_MINUTE) return dst;
    *dst++ = ':';
    dst = ztp_put_digits(dst, t.second, 2);
    sub = (uint64_t)t.millisecond * 1000000u + (uint64_t)t.microsecond * 1000u +
          t.nanosecond;
    if (precision == 0 || (precision == ZTP_PRECISION_AUTO && sub == 0))
        return dst;
    *dst++ = '.';
    if (precision == ZTP_PRECISION_AUTO) {
        char *start = dst;
        dst = ztp_put_digits(dst, sub, 9);
        while (dst > start && dst[-1] == '0') dst--;
        return dst;
    }
    {
        char digits[9];
        ztp_put_digits(digits, sub, 9);
        memcpy(dst, digits, (size_t)precision);
        return dst + precision;
    }
}

size_t ztp_format_iso_date(char *dst, int32_t epoch_day,
                           ztp_show_calendar show)
{
    char *end = ztp_put_calendar(ztp_put_date(dst, epoch_day), show);
    *end = '\0';
    return (size_t)(end - dst);
}

size_t ztp_format_time(char *dst, int64_t ns_of_day, int precision)
{
    char *end = ztp_put_time(dst, ns_of_day, precision);
    *end = '\0';
    return (size_t)(end - dst);
}

size_t ztp_format_iso_date_time(char *dst, int32_t epoch_day,
                                int64_t ns_of_day, int precision,
                                ztp_show_calendar show)
{
    char *end = ztp_put_date(dst, epoch_day);
    *end++ = 'T';
    end = ztp_put_time(end, ns_of_day, precision);
    end = ztp_put_calendar(end, show);
    *end = '\0';
    return (size_t)(end - dst);
}
