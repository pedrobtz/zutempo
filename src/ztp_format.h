/*
 * ztp_format.h -- ISO 8601 / RFC 9557 text for the plain types (Temporal
 * 3.5.11 TemporalDateToString, 4.5.10 TimeRecordToString, 5.5.11
 * ISODateTimeToString, 13.22 FormatTimeString). Engine side: no R.
 */
#ifndef ZTP_FORMAT_H
#define ZTP_FORMAT_H

#include "ztp_iso.h"

/* Precision as ToSecondsStringPrecisionRecord leaves it: 0 to 9 digits,
   or one of these. */
#define ZTP_PRECISION_AUTO (-1)
#define ZTP_PRECISION_MINUTE (-2)

/* How the calendar annotation is shown (GetTemporalShowCalendarNameOption). */
typedef enum {
    ZTP_SHOW_CALENDAR_AUTO = 0,
    ZTP_SHOW_CALENDAR_ALWAYS = 1,
    ZTP_SHOW_CALENDAR_NEVER = 2,
    ZTP_SHOW_CALENDAR_CRITICAL = 3
} ztp_show_calendar;

/* Buffer sizes including the NUL: "+275760-09-13", "12:30:45.123456789",
   their combination with a "T" and "[!u-ca=iso8601]". */
#define ZTP_FORMAT_DATE_CAP 32
#define ZTP_FORMAT_TIME_CAP 24
#define ZTP_FORMAT_DATE_TIME_CAP 64

/* Each writes a NUL-terminated string and returns its length. */
size_t ztp_format_iso_date(char *dst, int32_t epoch_day,
                           ztp_show_calendar show);
size_t ztp_format_time(char *dst, int64_t ns_of_day, int precision);
size_t ztp_format_iso_date_time(char *dst, int32_t epoch_day,
                                int64_t ns_of_day, int precision,
                                ztp_show_calendar show);

#endif /* ZTP_FORMAT_H */
