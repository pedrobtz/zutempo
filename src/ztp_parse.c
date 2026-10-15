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
static bool ztp_parse_offset(ztp_cursor *c, int64_t *offset_ns)
{
    int sign = ztp_peek(c, 0);
    uint32_t h, m = 0, s = 0, frac = 0;
    size_t at;
    bool extended;

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
        }
    }
    *offset_ns = ((int64_t)h * 3600 + (int64_t)m * 60 + s) * ZTP_NS_PER_SECOND + frac;
    if (sign == '-') *offset_ns = -*offset_ns;
    return true;
}

/* After a time: an optional offset, where "Z" is never allowed for the
   plain types; then no annotations (stage 9) and the end of the string. */
static bool ztp_parse_time_suffix(ztp_cursor *c, ztp_parsed *out)
{
    int ch = ztp_peek(c, 0);

    if (ch == 'Z' || ch == 'z')
        return ztp_fail_at(c, c->pos,
                           "a UTC designator is not allowed for a plain type");
    if (ch == '+' || ch == '-') {
        if (!ztp_parse_offset(c, &out->offset_ns)) return false;
        out->has_offset = true;
    }
    return true;
}

static bool ztp_parse_tail(ztp_cursor *c)
{
    if (ztp_peek(c, 0) == '[')
        return ztp_fail_at(c, c->pos,
                           "annotations in brackets are not supported yet");
    if (!ztp_at_end(c))
        return ztp_fail_at(c, c->pos, "unexpected character");
    return true;
}

static bool ztp_is_separator(int ch)
{
    return ch == 'T' || ch == 't' || ch == ' ';
}

/* DateSpecMonthDay over s[0, n), with its IsValidMonthDay early error. */
static bool ztp_looks_like_month_day(const unsigned char *s, size_t n)
{
    ztp_cursor c = {s, n, 0, NULL, 0};
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
    ztp_cursor c = {s, n, 0, NULL, 0};
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
                                     bool time_required)
{
    if (!ztp_parse_date(c, &out->year, &out->month, &out->day)) return false;
    if (ztp_is_separator(ztp_peek(c, 0))) {
        c->pos++;
        if (!ztp_parse_time(c, &out->time)) return false;
        out->has_time = true;
        if (!ztp_parse_time_suffix(c, out)) return false;
    } else if (time_required) {
        return ztp_fail_at(c, c->pos, "expected a time after the date");
    }
    return ztp_parse_tail(c);
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
    return ztp_parse_tail(c);
}

static bool ztp_parse_slow(ztp_cursor *c, ztp_parse_goal goal, ztp_parsed *out)
{
    memset(out, 0, sizeof *out);
    if (goal == ZTP_PARSE_DATE_TIME) return ztp_parse_goal_date_time(c, out, false);

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
            if (ztp_parse_goal_date_time(&attempt, &tmp, true)) {
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

    if (goal != ZTP_PARSE_DATE_TIME || n == 0) return false;
    if (memchr(s, '[', n) != NULL) return false;
    r = zuf_parse_datetime_opt(s, s + n, &dt, ZUF_DT_EXPANDED_YEAR);
    if (r.status != ZUF_OK || r.ptr != s + n) return false;
    /* zufast reads "Z" and "-00:00" as offset 0; Temporal forbids Z here,
       and zufast accepts more than nine fraction digits where Temporal
       rejects them. Let the slow path judge both. */
    if (dt.has_offset && (s[n - 1] == 'Z' || s[n - 1] == 'z')) return false;
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
    }
    return true;
}

ztp_status ztp_parse_path(ztp_ctx *ctx, size_t index, const char *s, size_t n,
                          ztp_parse_goal goal, int path, ztp_parsed *out,
                          size_t *position)
{
    ztp_cursor c = {(const unsigned char *)s, n, 0, NULL, 0};

    if (position) *position = 0;
    if (path != ZTP_PARSE_PATH_SLOW && ztp_parse_fast(s, n, goal, out))
        return ZTP_OK;
    if (path == ZTP_PARSE_PATH_FAST)
        return ztp_fail(ctx, ZTP_ERR_TYPE, index, "the fast path does not apply");
    if (ztp_parse_slow(&c, goal, out)) return ZTP_OK;
    if (position) *position = c.fail_pos;
    {
        char shown[41];
        size_t k = n < 40 ? n : 37;
        memcpy(shown, s, k);
        if (n > 40) memcpy(shown + 37, "...", 3), k = 40;
        shown[k] = '\0';
        return ztp_fail(ctx, ZTP_ERR_PARSE, index,
                        "cannot parse \"%s\" as a %s: %s at byte %zu", shown,
                        goal == ZTP_PARSE_TIME ? "time" : "date or date-time",
                        c.reason ? c.reason : "invalid", c.fail_pos + 1);
    }
}

ztp_status ztp_parse(ztp_ctx *ctx, size_t index, const char *s, size_t n,
                     ztp_parse_goal goal, ztp_parsed *out, size_t *position)
{
    return ztp_parse_path(ctx, index, s, n, goal, ZTP_PARSE_PATH_AUTO, out,
                          position);
}
