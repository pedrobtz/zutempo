/*
 * ztp_parse.h -- the ISO 8601 / RFC 9557 grammar of Temporal 13.33 and
 * ParseISODateTime (13.36), for the goals the plain types use. Engine
 * side: no R.
 *
 * Stage 2 reads dates, times and offsets. Annotations ("[...]") are a
 * parse error until stage 9 (roadmap).
 */
#ifndef ZTP_PARSE_H
#define ZTP_PARSE_H

#include "ztp_iso.h"

typedef enum {
    ZTP_PARSE_DATE_TIME = 0,   /* TemporalDateTimeString[~Zoned] */
    ZTP_PARSE_TIME = 1,        /* TemporalTimeString */
    ZTP_PARSE_YEAR_MONTH = 2,  /* TemporalYearMonthString */
    ZTP_PARSE_MONTH_DAY = 3    /* TemporalMonthDayString */
} ztp_parse_goal;

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
} ztp_parsed;

/* Parse s[0, n) against the goal. A failure is ZTP_ERR_PARSE with the
   0-based position of the first byte that could not be part of a valid
   string, as `position` and in the message. */
ztp_status ztp_parse(ztp_ctx *ctx, size_t index, const char *s, size_t n,
                     ztp_parse_goal goal, ztp_parsed *out, size_t *position);

/* The same, with the zufast fast path (design 9) disabled or forced; for
   tests that compare the two. A forced fast path that does not apply
   returns ZTP_ERR_TYPE. */
ztp_status ztp_parse_path(ztp_ctx *ctx, size_t index, const char *s, size_t n,
                          ztp_parse_goal goal, int path, ztp_parsed *out,
                          size_t *position);
#define ZTP_PARSE_PATH_AUTO 0
#define ZTP_PARSE_PATH_SLOW 1
#define ZTP_PARSE_PATH_FAST 2

#endif /* ZTP_PARSE_H */
