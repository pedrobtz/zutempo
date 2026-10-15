/*
 * ztp_parse.h -- the ISO 8601 / RFC 9557 grammar of Temporal 13.33 and
 * ParseISODateTime (13.36), for the goals the plain types use. Engine
 * side: no R.
 *
 * Dates, times and offsets; the time zone annotation ("[Europe/Madrid]",
 * "[+05:30]"), then any number of key-value annotations with the critical
 * flag rules of ParseISODateTime; "u-ca" is the only key understood.
 */
#ifndef ZTP_PARSE_H
#define ZTP_PARSE_H

#include "ztp_iso.h"

typedef enum {
    ZTP_PARSE_DATE_TIME = 0,   /* TemporalDateTimeString[~Zoned] */
    ZTP_PARSE_TIME = 1,        /* TemporalTimeString */
    ZTP_PARSE_YEAR_MONTH = 2,  /* TemporalYearMonthString */
    ZTP_PARSE_MONTH_DAY = 3,   /* TemporalMonthDayString */
    ZTP_PARSE_INSTANT = 4,     /* TemporalInstantString */
    ZTP_PARSE_ZONED = 5,       /* TemporalDateTimeString[+Zoned] */
    ZTP_PARSE_ANY = 6          /* every goal above, in the order of
                                  ParseTemporalTimeZoneString and
                                  ParseTemporalCalendarString */
} ztp_parse_goal;

#define ZTP_TZ_ANNOTATION_CAP 48
#define ZTP_CALENDAR_CAP 32

/* An ISO Date-Time Parse Record. The date is always present; a year-month
   string sets day to 1 with has_day false, a month-day string sets year to
   1972 with has_year false. The time is ~start-of-day~ when has_time is
   false. */
typedef struct {
    int32_t year;
    uint32_t month, day;
    bool has_year, has_day;
    bool has_time;
    ztp_iso_time time;
    bool has_offset;        /* a numeric UTC offset was present */
    int64_t offset_ns;      /* meaningful when has_offset */
    bool offset_has_seconds;    /* the offset had a seconds part (ToTemporalZonedDateTime's ~match-exactly~) */
    bool has_z;             /* the UTC designator was present */
    bool has_tz;            /* a time zone annotation was present */
    bool tz_critical;       /* ... with the "!" flag */
    char tz[ZTP_TZ_ANNOTATION_CAP];   /* its identifier as written */
    bool has_calendar;      /* a "u-ca" annotation was present */
    bool calendar_is_iso;   /* ... and its value is "iso8601" in any case */
    char calendar[ZTP_CALENDAR_CAP];  /* the value as written, truncated */
} ztp_parsed;

/* Parse s[0, n) against the goal. A failure is ZTP_ERR_PARSE with the
   0-based position of the first byte that could not be part of a valid
   string, as `position`, in the message and (1-based) in ctx->position.
   For the goals that carry a date (all but ZTP_PARSE_TIME,
   ZTP_PARSE_INSTANT and ZTP_PARSE_ANY) a calendar annotation other than
   "iso8601" is a ZTP_ERR_RANGE, as CanonicalizeCalendar throws for the
   calendars zutempo does not have (design D7). */
ztp_status ztp_parse(ztp_ctx *ctx, size_t index, const char *s, size_t n,
                     ztp_parse_goal goal, ztp_parsed *out, size_t *position);

/* The same, with the zufast fast path (design 9) disabled or forced; for
   tests that compare the two. A forced fast path that does not apply
   returns ZTP_ERR_TYPE. */
ztp_status ztp_parse_path(ztp_ctx *ctx, size_t index, const char *s, size_t n,
                          ztp_parse_goal goal, int path, ztp_parsed *out,
                          size_t *position);
/* ParseTemporalTimeZoneString: the identifier a time zone string names,
   as written, into dst (ZTP_TZ_ANNOTATION_CAP bytes): the string itself
   when it is a TimeZoneIdentifier, else the annotation, "UTC" for "Z", or
   the offset as "+HH:MM" of an ISO string. */
ztp_status ztp_parse_time_zone_string(ztp_ctx *ctx, size_t index, const char *s,
                                      size_t n, char *dst);

/* ParseTemporalCalendarString: the calendar identifier a string names,
   into dst (ZTP_CALENDAR_CAP bytes, truncated). The caller canonicalises
   it. */
ztp_status ztp_parse_calendar_string(ztp_ctx *ctx, size_t index, const char *s,
                                     size_t n, char *dst);

#define ZTP_PARSE_PATH_AUTO 0
#define ZTP_PARSE_PATH_SLOW 1
#define ZTP_PARSE_PATH_FAST 2

#endif /* ZTP_PARSE_H */
