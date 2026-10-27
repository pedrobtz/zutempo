/* ztp_parse.c -- see ztp_parse.h. Engine side: no R. */

#include "ztp_parse.h"

#include <string.h>

#include <zufast/datetime.h>

typedef struct {
    const unsigned char *s;
    size_t n;
    size_t pos;
    const char *reason;     /* set on failure */
    size_t fail_pos;
    size_t calendar_at;     /* where the first "u-ca" annotation starts */
} ztp_cursor;

static bool ztp_fail_at(ztp_cursor *c, size_t pos, const char *reason)
{
    /* Keep the furthest failure: it is the most informative one. */
    if (c->reason == NULL || pos >= c->fail_pos) {
        c->reason = reason;
        c->fail_pos = pos;
    }
    return false;
}

static bool ztp_at_end(const ztp_cursor *c) { return c->pos >= c->n; }

static int ztp_peek(const ztp_cursor *c, size_t ahead)
{
    return c->pos + ahead < c->n ? c->s[c->pos + ahead] : -1;
}

static bool ztp_is_digit(int ch) { return ch >= '0' && ch <= '9'; }

/* Exactly k digits, as a number. */
static bool ztp_digits(ztp_cursor *c, unsigned k, uint32_t *out,
                       const char *what)
{
    uint32_t v = 0;

    for (unsigned i = 0; i < k; i++) {
        int ch = ztp_peek(c, i);
        if (!ztp_is_digit(ch)) return ztp_fail_at(c, c->pos + i, what);
        v = v * 10 + (uint32_t)(ch - '0');
    }
    c->pos += k;
    *out = v;
    return true;
}

static bool ztp_in(uint32_t v, uint32_t lo, uint32_t hi)
{
    return v >= lo && v <= hi;
}

/* DateYear: four digits, or a sign and six digits, never "-000000". */
static bool ztp_parse_year(ztp_cursor *c, int32_t *year)
{
    int ch = ztp_peek(c, 0);
    uint32_t v;

    if (ch == '+' || ch == '-') {
        size_t start = c->pos;
        c->pos++;
        if (!ztp_digits(c, 6, &v, "expected six year digits after the sign"))
            return false;
        if (ch == '-' && v == 0)
            return ztp_fail_at(c, start, "the year -000000 is not allowed");
        *year = ch == '-' ? -(int32_t)v : (int32_t)v;
        return true;
    }
    if (!ztp_digits(c, 4, &v, "expected a four-digit year")) return false;
    *year = (int32_t)v;
    return true;
}

/* DateSpec: year, month and day, separated by "-" throughout or not at
   all; the grammar's IsValidDate applies. */
static bool ztp_parse_date(ztp_cursor *c, int32_t *year, uint32_t *month,
                           uint32_t *day)
{
    bool extended;
    size_t at;

    if (!ztp_parse_year(c, year)) return false;
    extended = ztp_peek(c, 0) == '-';
    if (extended) c->pos++;
    at = c->pos;
    if (!ztp_digits(c, 2, month, "expected a two-digit month")) return false;
    if (!ztp_in(*month, 1, 12)) return ztp_fail_at(c, at, "month must be 01 to 12");
    if (extended) {
        if (ztp_peek(c, 0) != '-')
            return ztp_fail_at(c, c->pos, "expected '-' before the day");
        c->pos++;
    }
    at = c->pos;
    if (!ztp_digits(c, 2, day, "expected a two-digit day")) return false;
    if (!ztp_in(*day, 1, 31)) return ztp_fail_at(c, at, "day must be 01 to 31");
    if (!ztp_is_valid_iso_date(*year, *month, *day))
        return ztp_fail_at(c, at, "no such day in that month");
    return true;
}

/* TemporalDecimalFraction after a seconds field: "." or "," then one to
   nine digits, scaled to nanoseconds. */
static bool ztp_parse_fraction(ztp_cursor *c, uint32_t *ns)
{
    int ch = ztp_peek(c, 0);
    uint32_t v = 0;
    unsigned k = 0;

    if (ch != '.' && ch != ',') {
        *ns = 0;
        return true;
    }
    c->pos++;
    while (ztp_is_digit(ztp_peek(c, 0))) {
        if (k == 9)
            return ztp_fail_at(c, c->pos,
                               "more than nine fractional second digits");
        v = v * 10 + (uint32_t)(ztp_peek(c, 0) - '0');
        k++;
        c->pos++;
    }
    if (k == 0)
        return ztp_fail_at(c, c->pos, "expected digits after the decimal mark");
    while (k++ < 9) v *= 10;
    *ns = v;
    return true;
}

/* TimeSpec: hour, then optionally minutes and seconds with a fraction,
   separated by ":" throughout or not at all. A leap second reads as 59. */
static bool ztp_parse_time(ztp_cursor *c, ztp_iso_time *t)
{
    uint32_t v, frac = 0;
    size_t at = c->pos;
    bool extended;

    memset(t, 0, sizeof *t);
    if (!ztp_digits(c, 2, &v, "expected a two-digit hour")) return false;
    if (v > 23) return ztp_fail_at(c, at, "hour must be 00 to 23");
    t->hour = v;
    extended = ztp_peek(c, 0) == ':';
    if (!extended && !ztp_is_digit(ztp_peek(c, 0))) return true;
    if (extended) c->pos++;
    at = c->pos;
    if (!ztp_digits(c, 2, &v, "expected two minute digits")) return false;
    if (v > 59) return ztp_fail_at(c, at, "minute must be 00 to 59");
    t->minute = v;
    if (extended) {
        if (ztp_peek(c, 0) != ':') return true;
        c->pos++;
    } else if (!ztp_is_digit(ztp_peek(c, 0))) {
        return true;
    }
    at = c->pos;
    if (!ztp_digits(c, 2, &v, "expected two second digits")) return false;
    if (v > 60) return ztp_fail_at(c, at, "second must be 00 to 60");
    t->second = v == 60 ? 59 : v;
    if (!ztp_parse_fraction(c, &frac)) return false;
    t->millisecond = frac / 1000000u;
    t->microsecond = (frac / 1000u) % 1000u;
    t->nanosecond = frac % 1000u;
    return true;
}

/* UTCOffset[+SubMinutePrecision]: a sign, hours, then optionally minutes,
   seconds and a fraction, extended or basic. */
static bool ztp_parse_offset(ztp_cursor *c, int64_t *offset_ns, bool *has_seconds)
{
    int sign = ztp_peek(c, 0);
    uint32_t h, m = 0, s = 0, frac = 0;
    size_t at;
    bool extended;

    if (has_seconds) *has_seconds = false;
    c->pos++;
    at = c->pos;
    if (!ztp_digits(c, 2, &h, "expected two offset hour digits")) return false;
    if (h > 23) return ztp_fail_at(c, at, "offset hour must be 00 to 23");
    extended = ztp_peek(c, 0) == ':';
    if (extended || ztp_is_digit(ztp_peek(c, 0))) {
        if (extended) c->pos++;
        at = c->pos;
        if (!ztp_digits(c, 2, &m, "expected two offset minute digits")) return false;
        if (m > 59) return ztp_fail_at(c, at, "offset minute must be 00 to 59");
        if ((extended && ztp_peek(c, 0) == ':') ||
            (!extended && ztp_is_digit(ztp_peek(c, 0)))) {
            if (extended) c->pos++;
            at = c->pos;
            if (!ztp_digits(c, 2, &s, "expected two offset second digits"))
                return false;
            if (s > 59) return ztp_fail_at(c, at, "offset second must be 00 to 59");
            if (!ztp_parse_fraction(c, &frac)) return false;
            if (has_seconds) *has_seconds = true;
        }
    }
    *offset_ns = ((int64_t)h * 3600 + (int64_t)m * 60 + s) * ZTP_NS_PER_SECOND + frac;
    if (sign == '-') *offset_ns = -*offset_ns;
    return true;
}

/* After a time: an optional offset, where "Z" is never allowed for the
   plain types; then the annotations and the end of the string. */
static bool ztp_is_separator(int ch);
static bool ztp_parse_tail(ztp_cursor *c, ztp_parsed *out);

static bool ztp_parse_time_suffix_z(ztp_cursor *c, ztp_parsed *out, bool allow_z)
{
    int ch = ztp_peek(c, 0);

    if (ch == 'Z' || ch == 'z') {
        if (!allow_z)
            return ztp_fail_at(c, c->pos,
                               "a UTC designator is not allowed for a plain type");
        c->pos++;
        out->has_z = true;
        return true;
    }
    if (ch == '+' || ch == '-') {
        if (!ztp_parse_offset(c, &out->offset_ns, &out->offset_has_seconds)) return false;
        out->has_offset = true;
    }
    return true;
}

static bool ztp_parse_time_suffix(ztp_cursor *c, ztp_parsed *out)
{
    return ztp_parse_time_suffix_z(c, out, false);
}

/* TemporalInstantString: a date, a time and "Z" or an offset. */
static bool ztp_parse_goal_instant(ztp_cursor *c, ztp_parsed *out)
{
    if (!ztp_parse_date(c, &out->year, &out->month, &out->day)) return false;
    out->has_year = true;
    out->has_day = true;
    if (!ztp_is_separator(ztp_peek(c, 0)))
        return ztp_fail_at(c, c->pos, "expected a time after the date");
    c->pos++;
    if (!ztp_parse_time(c, &out->time)) return false;
    out->has_time = true;
    if (!ztp_parse_time_suffix_z(c, out, true)) return false;
    if (!out->has_z && !out->has_offset)
        return ztp_fail_at(c, c->pos, "an instant needs 'Z' or a UTC offset");
    return ztp_parse_tail(c, out);
}

/* TimeZoneAnnotation: "[", an optional "!", a TimeZoneIdentifier (an
   offset to the minute or an IANA name), "]". The cursor is on "[". */
static bool ztp_parse_tz_annotation(ztp_cursor *c, ztp_parsed *out)
{
    size_t start, len;
    int ch;

    c->pos++;
    if (ztp_peek(c, 0) == '!') {
        out->tz_critical = true;
        c->pos++;
    }
    start = c->pos;
    ch = ztp_peek(c, 0);
    if (ch == '+' || ch == '-') {
        /* UTCOffset[~SubMinutePrecision]: sign, HH, optionally ":MM" or
           "MM". */
        uint32_t h, m;
        c->pos++;
        if (!ztp_digits(c, 2, &h, "expected two offset hour digits")) return false;
        if (h > 23) return ztp_fail_at(c, start + 1, "offset hour must be 00 to 23");
        if (ztp_peek(c, 0) == ':') c->pos++;
        if (ztp_is_digit(ztp_peek(c, 0))) {
            size_t at = c->pos;
            if (!ztp_digits(c, 2, &m, "expected two offset minute digits")) return false;
            if (m > 59) return ztp_fail_at(c, at, "offset minute must be 00 to 59");
        } else if (c->pos > start + 3) {
            return ztp_fail_at(c, c->pos, "expected offset minutes after ':'");
        }
    } else {
        /* TimeZoneIANAName: components of TZLeadingChar then TZChar,
           joined by "/". */
        bool lead = true;
        for (;;) {
            ch = ztp_peek(c, 0);
            bool alpha = (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z');
            bool digit = ch >= '0' && ch <= '9';
            if (lead) {
                if (!(alpha || ch == '.' || ch == '_'))
                    return ztp_fail_at(c, c->pos, "expected a time zone identifier");
                lead = false;
            } else if (ch == '/') {
                lead = true;
            } else if (!(alpha || digit || ch == '.' || ch == '_' || ch == '-' || ch == '+')) {
                break;
            }
            c->pos++;
        }
    }
    len = c->pos - start;
    if (ztp_peek(c, 0) != ']')
        return ztp_fail_at(c, c->pos, "expected ']' after the time zone identifier");
    if (len == 0) return ztp_fail_at(c, start, "expected a time zone identifier");
    if (len >= ZTP_TZ_ANNOTATION_CAP)
        return ztp_fail_at(c, start, "the time zone identifier is too long");
    memcpy(out->tz, c->s + start, len);
    out->tz[len] = '\0';
    out->has_tz = true;
    c->pos++;
    return true;
}

/* AKeyLeadingChar, AKeyChar and AnnotationValueComponent's characters. */
static bool ztp_is_key_lead(int ch) { return (ch >= 'a' && ch <= 'z') || ch == '_'; }

static bool ztp_is_key_char(int ch)
{
    return ztp_is_key_lead(ch) || ztp_is_digit(ch) || ch == '-';
}

static bool ztp_is_alnum(int ch)
{
    return ztp_is_digit(ch) || (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z');
}

/* Whether the bracket at the cursor holds a key-value Annotation rather
   than a TimeZoneAnnotation: an "=" comes before the closing "]". No time
   zone identifier contains "=". */
static bool ztp_annotation_has_key(const ztp_cursor *c)
{
    for (size_t i = c->pos + 1; i < c->n; i++) {
        if (c->s[i] == '=') return true;
        if (c->s[i] == ']') return false;
    }
    return false;
}

/* Annotation: "[", an optional "!", AnnotationKey "=" AnnotationValue, "]",
   with the rules ParseISODateTime applies to each: the first "u-ca" sets
   the calendar, a second one is an error when either is critical, and any
   other key is an error when it is critical. The cursor is on "[". */
static bool ztp_parse_annotation(ztp_cursor *c, ztp_parsed *out,
                                 bool *calendar_critical)
{
    size_t open = c->pos, key_start, key_len, value_start, value_len;
    bool critical = false;

    c->pos++;
    if (ztp_peek(c, 0) == '!') {
        critical = true;
        c->pos++;
    }
    key_start = c->pos;
    if (!ztp_is_key_lead(ztp_peek(c, 0)))
        return ztp_fail_at(c, c->pos, "expected a lowercase annotation key");
    while (ztp_is_key_char(ztp_peek(c, 0))) c->pos++;
    key_len = c->pos - key_start;
    if (ztp_peek(c, 0) != '=')
        return ztp_fail_at(c, c->pos, "expected '=' after the annotation key");
    c->pos++;
    value_start = c->pos;
    for (;;) {
        if (!ztp_is_alnum(ztp_peek(c, 0)))
            return ztp_fail_at(c, c->pos, "expected letters or digits in the annotation value");
        while (ztp_is_alnum(ztp_peek(c, 0))) c->pos++;
        if (ztp_peek(c, 0) != '-') break;
        c->pos++;
    }
    value_len = c->pos - value_start;
    if (ztp_peek(c, 0) != ']')
        return ztp_fail_at(c, c->pos, "expected ']' after the annotation");
    c->pos++;
    if (key_len == 4 && memcmp(c->s + key_start, "u-ca", 4) == 0) {
        if (!out->has_calendar) {
            static const char iso[] = "iso8601";
            size_t k = value_len < ZTP_CALENDAR_CAP - 1 ? value_len : ZTP_CALENDAR_CAP - 1;
            bool is_iso = value_len == 7;
            for (size_t i = 0; is_iso && i < 7; i++) {
                int ch = c->s[value_start + i];
                if (ch >= 'A' && ch <= 'Z') ch += 'a' - 'A';
                is_iso = ch == iso[i];
            }
            out->has_calendar = true;
            out->calendar_is_iso = is_iso;
            memcpy(out->calendar, c->s + value_start, k);
            out->calendar[k] = '\0';
            c->calendar_at = open;
            *calendar_critical = critical;
        } else if (critical || *calendar_critical) {
            return ztp_fail_at(c, open,
                               "a second calendar annotation where one is critical");
        }
    } else if (critical) {
        return ztp_fail_at(c, open, "an unknown annotation is marked critical with '!'");
    }
    return true;
}

/* TimeZoneAnnotation? Annotations?, then the end of the string. */
static bool ztp_parse_tail(ztp_cursor *c, ztp_parsed *out)
{
    bool calendar_critical = false, first = true;

    while (ztp_peek(c, 0) == '[') {
        if (ztp_annotation_has_key(c)) {
            if (!ztp_parse_annotation(c, out, &calendar_critical)) return false;
        } else if (first) {
            if (!ztp_parse_tz_annotation(c, out)) return false;
        } else {
            return ztp_fail_at(c, c->pos,
                               out->has_tz ? "a second time zone annotation"
                                           : "the time zone annotation must come first");
        }
        first = false;
    }
    if (!ztp_at_end(c))
        return ztp_fail_at(c, c->pos, "unexpected character");
    return true;
}

/* The early rule of ParseISODateTime for a year-month without a day and a
   month-day without a year: only the ISO 8601 calendar has those forms. */
static bool ztp_partial_calendar_ok(ztp_cursor *c, const ztp_parsed *out)
{
    if (out->has_calendar && !out->calendar_is_iso)
        return ztp_fail_at(c, c->calendar_at,
                           "only the ISO 8601 calendar reads a partial date");
    return true;
}

static bool ztp_is_separator(int ch)
{
    return ch == 'T' || ch == 't' || ch == ' ';
}

/* DateSpecMonthDay over s[0, n), with its IsValidMonthDay early error. */
static bool ztp_looks_like_month_day(const unsigned char *s, size_t n)
{
    ztp_cursor c = {s, n, 0, NULL, 0, 0};
    uint32_t m, d;

    if (ztp_peek(&c, 0) == '-' && ztp_peek(&c, 1) == '-') c.pos += 2;
    if (!ztp_digits(&c, 2, &m, "") || !ztp_in(m, 1, 12)) return false;
    if (ztp_peek(&c, 0) == '-') c.pos++;
    if (!ztp_digits(&c, 2, &d, "") || !ztp_in(d, 1, 31)) return false;
    if (!ztp_at_end(&c)) return false;
    return ztp_is_valid_iso_date(1972, m, d);
}

/* DateSpecYearMonth over s[0, n). */
static bool ztp_looks_like_year_month(const unsigned char *s, size_t n)
{
    ztp_cursor c = {s, n, 0, NULL, 0, 0};
    int32_t y;
    uint32_t m;

    if (!ztp_parse_year(&c, &y)) return false;
    if (ztp_peek(&c, 0) == '-') c.pos++;
    if (!ztp_digits(&c, 2, &m, "") || !ztp_in(m, 1, 12)) return false;
    return ztp_at_end(&c);
}

/* TemporalDateTimeString[~Zoned]: a date, optionally followed by a
   separator, a time and an offset. */
static bool ztp_parse_goal_date_time(ztp_cursor *c, ztp_parsed *out,
                                     bool time_required, bool allow_z)
{
    if (!ztp_parse_date(c, &out->year, &out->month, &out->day)) return false;
    out->has_year = true;
    out->has_day = true;
    if (ztp_is_separator(ztp_peek(c, 0))) {
        c->pos++;
        if (!ztp_parse_time(c, &out->time)) return false;
        out->has_time = true;
        if (!ztp_parse_time_suffix_z(c, out, allow_z)) return false;
    } else if (time_required) {
        return ztp_fail_at(c, c->pos, "expected a time after the date");
    }
    return ztp_parse_tail(c, out);
}

/* TemporalDateTimeString[+Zoned]: a date-time, "Z" allowed, and the time
   zone annotation required. */
static bool ztp_parse_goal_zoned(ztp_cursor *c, ztp_parsed *out)
{
    if (!ztp_parse_goal_date_time(c, out, false, true)) return false;
    if (!out->has_tz)
        return ztp_fail_at(c, c->pos, "a zoned date-time needs a time zone in brackets");
    return true;
}

/* AnnotatedTime: an optional "T", a time, an optional offset; without the
   "T" the time and offset must not read as a month-day or year-month. */
static bool ztp_parse_goal_time_only(ztp_cursor *c, ztp_parsed *out)
{
    bool designated = ztp_peek(c, 0) == 'T' || ztp_peek(c, 0) == 't';
    size_t start;

    if (designated) c->pos++;
    start = c->pos;
    if (!ztp_parse_time(c, &out->time)) return false;
    out->has_time = true;
    if (!ztp_parse_time_suffix(c, out)) return false;
    if (!designated) {
        const unsigned char *text = c->s + start;
        size_t len = c->pos - start;
        if (ztp_looks_like_month_day(text, len) ||
            ztp_looks_like_year_month(text, len))
            return ztp_fail_at(c, start,
                               "ambiguous with a date; prefix the time with 'T'");
    }
    /* The reference year of a time-only string. */
    out->year = 1972;
    out->month = 1;
    out->day = 1;
    return ztp_parse_tail(c, out);
}

/* DateSpecYearMonth: a year, an optional "-", a month. */
static bool ztp_parse_goal_year_month_only(ztp_cursor *c, ztp_parsed *out)
{
    size_t at;

    if (!ztp_parse_year(c, &out->year)) return false;
    if (ztp_peek(c, 0) == '-') c->pos++;
    at = c->pos;
    if (!ztp_digits(c, 2, &out->month, "expected a two-digit month")) return false;
    if (!ztp_in(out->month, 1, 12)) return ztp_fail_at(c, at, "month must be 01 to 12");
    out->has_year = true;
    out->has_day = false;
    out->day = 1;
    return ztp_parse_tail(c, out) && ztp_partial_calendar_ok(c, out);
}

/* DateSpecMonthDay: an optional "--", a month, an optional "-", a day,
   valid in some year (IsValidMonthDay). */
static bool ztp_parse_goal_month_day_only(ztp_cursor *c, ztp_parsed *out)
{
    size_t at;

    if (ztp_peek(c, 0) == '-' && ztp_peek(c, 1) == '-') c->pos += 2;
    at = c->pos;
    if (!ztp_digits(c, 2, &out->month, "expected a two-digit month")) return false;
    if (!ztp_in(out->month, 1, 12)) return ztp_fail_at(c, at, "month must be 01 to 12");
    if (ztp_peek(c, 0) == '-') c->pos++;
    at = c->pos;
    if (!ztp_digits(c, 2, &out->day, "expected a two-digit day")) return false;
    if (!ztp_in(out->day, 1, 31)) return ztp_fail_at(c, at, "day must be 01 to 31");
    if (!ztp_is_valid_iso_date(1972, out->month, out->day))
        return ztp_fail_at(c, at, "no such day in that month");
    out->has_year = false;
    out->has_day = true;
    out->year = 1972;
    return ztp_parse_tail(c, out) && ztp_partial_calendar_ok(c, out);
}

/* A goal with two forms: a full date-time (time optional) or the partial
   form. The date-time form is tried first when the string could start a
   year; the error of the attempt that read further is kept. */
static bool ztp_parse_goal_partial(ztp_cursor *c, ztp_parsed *out,
                                   bool (*partial)(ztp_cursor *, ztp_parsed *))
{
    ztp_cursor attempt = *c;
    ztp_parsed tmp;
    int ch = ztp_peek(c, 0);
    bool date_shaped = ztp_is_digit(ch) || ch == '+' ||
                       (ch == '-' && ztp_peek(c, 1) != '-');

    if (date_shaped) {
        memset(&tmp, 0, sizeof tmp);
        if (ztp_parse_goal_date_time(&attempt, &tmp, false, false)) {
            *c = attempt;
            *out = tmp;
            return true;
        }
    }
    memset(out, 0, sizeof *out);
    if (partial(c, out)) return true;
    if (date_shaped && attempt.reason != NULL && attempt.fail_pos > c->fail_pos) {
        c->reason = attempt.reason;
        c->fail_pos = attempt.fail_pos;
    }
    return false;
}

static bool ztp_parse_slow(ztp_cursor *c, ztp_parse_goal goal, ztp_parsed *out)
{
    memset(out, 0, sizeof *out);
    if (goal == ZTP_PARSE_DATE_TIME) return ztp_parse_goal_date_time(c, out, false, false);
    if (goal == ZTP_PARSE_ZONED) return ztp_parse_goal_zoned(c, out);
    if (goal == ZTP_PARSE_YEAR_MONTH)
        return ztp_parse_goal_partial(c, out, ztp_parse_goal_year_month_only);
    if (goal == ZTP_PARSE_MONTH_DAY)
        return ztp_parse_goal_partial(c, out, ztp_parse_goal_month_day_only);
    if (goal == ZTP_PARSE_INSTANT) return ztp_parse_goal_instant(c, out);
    if (goal == ZTP_PARSE_ANY) {
        /* The goals of ParseTemporalTimeZoneString in its order; the first
           that matches wins, and the failure that read furthest is kept. */
        static const ztp_parse_goal order[] = {
            ZTP_PARSE_ZONED, ZTP_PARSE_DATE_TIME, ZTP_PARSE_INSTANT,
            ZTP_PARSE_TIME, ZTP_PARSE_MONTH_DAY, ZTP_PARSE_YEAR_MONTH};
        const char *reason = NULL;
        size_t fail_pos = 0;

        for (size_t g = 0; g < sizeof order / sizeof order[0]; g++) {
            ztp_cursor attempt = *c;
            if (ztp_parse_slow(&attempt, order[g], out)) {
                *c = attempt;
                return true;
            }
            if (attempt.reason != NULL && (reason == NULL || attempt.fail_pos > fail_pos)) {
                reason = attempt.reason;
                fail_pos = attempt.fail_pos;
            }
        }
        c->reason = reason;
        c->fail_pos = fail_pos;
        return false;
    }

    /* TemporalTimeString: a date-time with the time required, or a bare
       time. Try the date-time form when the string can start with a year
       and is not a time with a designator. */
    {
        ztp_cursor attempt = *c;
        ztp_parsed tmp;
        int ch = ztp_peek(c, 0);
        bool date_shaped = ztp_is_digit(ch) || ch == '+' || ch == '-';

        if (date_shaped) {
            memset(&tmp, 0, sizeof tmp);
            if (ztp_parse_goal_date_time(&attempt, &tmp, true, false)) {
                *c = attempt;
                *out = tmp;
                return true;
            }
        }
        memset(out, 0, sizeof *out);
        if (ztp_parse_goal_time_only(c, out)) return true;
        /* Report the date-time attempt only when the string has a
           date-time separator past a full date; otherwise the bare-time
           diagnosis is the useful one. */
        if (date_shaped && attempt.reason != NULL) {
            bool has_separator = false;
            for (size_t i = 8; i < c->n; i++)
                if (ztp_is_separator(c->s[i])) has_separator = true;
            if (has_separator) {
                c->reason = attempt.reason;
                c->fail_pos = attempt.fail_pos;
            }
        }
        return false;
    }
}

/* The fast path (design 9): zufast's RFC 3339 parser for a date-time
   string it accepts whole, followed by Temporal's extra rules. Returns
   false when the path does not apply; the slow path then decides. */
static bool ztp_parse_fast(const char *s, size_t n, ztp_parse_goal goal,
                           ztp_parsed *out)
{
    zuf_datetime dt;
    zuf_result r;

    if (goal == ZTP_PARSE_TIME || goal == ZTP_PARSE_ZONED || goal == ZTP_PARSE_ANY ||
        n == 0)
        return false;
    if (memchr(s, '[', n) != NULL) return false;
    r = zuf_parse_datetime_opt(s, s + n, &dt, ZUF_DT_EXPANDED_YEAR);
    if (r.status != ZUF_OK || r.ptr != s + n) return false;
    /* zufast reads "Z" and "-00:00" as offset 0; Temporal forbids Z here,
       and zufast accepts more than nine fraction digits where Temporal
       rejects them. Let the slow path judge both. */
    if (dt.has_offset && (s[n - 1] == 'Z' || s[n - 1] == 'z')) {
        if (goal != ZTP_PARSE_INSTANT) return false;
    } else if (goal == ZTP_PARSE_INSTANT && (!dt.has_time || !dt.has_offset)) {
        return false;
    }
    if (dt.has_time) {
        const char *dot = memchr(s, '.', n);
        if (dot == NULL) dot = memchr(s, ',', n);
        if (dot != NULL) {
            size_t k = 0;
            for (const char *p = dot + 1; p < s + n && *p >= '0' && *p <= '9'; p++) k++;
            if (k > 9) return false;
        }
    }
    memset(out, 0, sizeof *out);
    out->year = dt.year;
    out->month = dt.month;
    out->day = dt.day;
    out->has_year = true;
    out->has_day = true;
    out->has_time = dt.has_time;
    if (dt.has_time) {
        out->time.hour = dt.hour;
        out->time.minute = dt.minute;
        out->time.second = dt.second == 60 ? 59 : dt.second;
        out->time.millisecond = dt.nanosecond / 1000000u;
        out->time.microsecond = (dt.nanosecond / 1000u) % 1000u;
        out->time.nanosecond = dt.nanosecond % 1000u;
        out->has_offset = dt.has_offset;
        out->offset_ns = (int64_t)dt.offset_seconds * ZTP_NS_PER_SECOND;
        if (dt.has_offset && (s[n - 1] == 'Z' || s[n - 1] == 'z')) {
            out->has_z = true;
            out->has_offset = false;
        }
    }
    return true;
}

ztp_status ztp_parse_path(ztp_ctx *ctx, size_t index, const char *s, size_t n,
                          ztp_parse_goal goal, int path, ztp_parsed *out,
                          size_t *position)
{
    ztp_cursor c = {(const unsigned char *)s, n, 0, NULL, 0, 0};

    if (position) *position = 0;
    if (path != ZTP_PARSE_PATH_SLOW && ztp_parse_fast(s, n, goal, out))
        return ZTP_OK;
    if (path == ZTP_PARSE_PATH_FAST)
        return ztp_fail(ctx, ZTP_ERR_TYPE, index, "the fast path does not apply");
    if (ztp_parse_slow(&c, goal, out)) {
        if (out->has_calendar && !out->calendar_is_iso && goal != ZTP_PARSE_TIME &&
            goal != ZTP_PARSE_INSTANT && goal != ZTP_PARSE_ANY)
            return ztp_fail(ctx, ZTP_ERR_RANGE, index,
                            "calendar \"%s\" is not supported; only \"iso8601\" is",
                            out->calendar);
        return ZTP_OK;
    }
    if (position) *position = c.fail_pos;
    {
        char shown[41];
        size_t k = n <= 40 ? n : ztp_utf8_prefix(s, n, 37);
        ztp_status st;
        memcpy(shown, s, k);
        if (n > 40) memcpy(shown + k, "...", 3), k += 3;
        shown[k] = '\0';
        st = ztp_fail(ctx, ZTP_ERR_PARSE, index,
                        "cannot parse \"%s\" as a %s: %s at byte %lu", shown,
                        goal == ZTP_PARSE_TIME ? "time"
                        : goal == ZTP_PARSE_INSTANT ? "instant"
                        : goal == ZTP_PARSE_YEAR_MONTH ? "year-month"
                        : goal == ZTP_PARSE_MONTH_DAY ? "month-day"
                        : goal == ZTP_PARSE_ZONED ? "zoned date-time"
                        : goal == ZTP_PARSE_ANY ? "date, time or time zone"
                        : "date or date-time",
                        c.reason ? c.reason : "invalid",
                        (unsigned long)(c.fail_pos + 1));
        ctx->position = c.fail_pos + 1;
        return st;
    }
}

ztp_status ztp_parse(ztp_ctx *ctx, size_t index, const char *s, size_t n,
                     ztp_parse_goal goal, ztp_parsed *out, size_t *position)
{
    return ztp_parse_path(ctx, index, s, n, goal, ZTP_PARSE_PATH_AUTO, out,
                          position);
}

/* ParseTemporalTimeZoneString: a TimeZoneIdentifier stands for itself;
   any other string is read as an ISO string, whose time zone annotation,
   "Z" or UTC offset names the zone (ParseTimeZoneIdentifier then rejects
   an offset finer than minutes). */
ztp_status ztp_parse_time_zone_string(ztp_ctx *ctx, size_t index, const char *s,
                                      size_t n, char *dst)
{
    ztp_parsed p;

    if (n > 0 && n + 2 <= ZTP_TZ_ANNOTATION_CAP) {
        unsigned char buf[ZTP_TZ_ANNOTATION_CAP];
        ztp_cursor c = {buf, n + 2, 0, NULL, 0, 0};
        buf[0] = '[';
        memcpy(buf + 1, s, n);
        buf[n + 1] = ']';
        memset(&p, 0, sizeof p);
        if (ztp_parse_tz_annotation(&c, &p) && ztp_at_end(&c) && !p.tz_critical) {
            memcpy(dst, s, n);
            dst[n] = '\0';
            return ZTP_OK;
        }
    }
    if (ztp_parse(ctx, index, s, n, ZTP_PARSE_ANY, &p, NULL) != ZTP_OK) return ctx->status;
    if (p.has_tz) {
        strcpy(dst, p.tz);
        return ZTP_OK;
    }
    if (p.has_z) {
        strcpy(dst, "UTC");
        return ZTP_OK;
    }
    if (p.has_offset) {
        int64_t minutes = p.offset_ns / (60 * ZTP_NS_PER_SECOND);
        int64_t a = minutes < 0 ? -minutes : minutes;
        /* ParseTimeZoneIdentifier reads UTCOffset[~SubMinutePrecision]: a
           seconds part is an error even when it is zero. */
        if (p.offset_has_seconds)
            return ztp_fail(ctx, ZTP_ERR_RANGE, index,
                            "a time zone offset cannot have seconds");
        dst[0] = p.offset_ns < 0 ? '-' : '+';
        dst[1] = (char)('0' + a / 600);
        dst[2] = (char)('0' + a / 60 % 10);
        dst[3] = ':';
        dst[4] = (char)('0' + a % 60 / 10);
        dst[5] = (char)('0' + a % 10);
        dst[6] = '\0';
        return ZTP_OK;
    }
    return ztp_fail(ctx, ZTP_ERR_RANGE, index,
                    "the string names no time zone, UTC designator or UTC offset");
}

/* ParseTemporalCalendarString: the calendar annotation of an ISO string,
   "iso8601" when it has none; otherwise the string itself, which must be
   an AnnotationValue. */
ztp_status ztp_parse_calendar_string(ztp_ctx *ctx, size_t index, const char *s,
                                     size_t n, char *dst)
{
    ztp_ctx scratch;
    ztp_parsed p;
    size_t k;
    bool valid = n > 0;

    ztp_ctx_init(&scratch);
    if (ztp_parse(&scratch, index, s, n, ZTP_PARSE_ANY, &p, NULL) == ZTP_OK) {
        strcpy(dst, p.has_calendar ? p.calendar : "iso8601");
        return ZTP_OK;
    }
    for (size_t i = 0; valid && i < n; i++) {
        int ch = (unsigned char)s[i];
        if (ch == '-')
            valid = i > 0 && i + 1 < n && s[i - 1] != '-';
        else
            valid = ztp_is_alnum(ch);
    }
    if (!valid)
        return ztp_fail(ctx, ZTP_ERR_RANGE, index, "\"%.*s\" is not a calendar identifier",
                        (int)ztp_utf8_prefix(s, n, 40), s);
    k = n < ZTP_CALENDAR_CAP - 1 ? n : ZTP_CALENDAR_CAP - 1;
    memcpy(dst, s, k);
    dst[k] = '\0';
    return ZTP_OK;
}
