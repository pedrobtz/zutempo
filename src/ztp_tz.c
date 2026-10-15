/* ztp_tz.c -- see ztp_tz.h. Engine side: no R. */

#include "ztp_tz.h"
#include "ztp_relative.h"

#include <stdlib.h>
#include <string.h>

#include <zufast/datetime.h>

/* --- links -------------------------------------------------------------- */

static int ztp_tz_casecmp(const char *a, const char *b)
{
    for (;; a++, b++) {
        int ca = (unsigned char)*a, cb = (unsigned char)*b;
        if (ca >= 'A' && ca <= 'Z') ca += 'a' - 'A';
        if (cb >= 'A' && cb <= 'Z') cb += 'a' - 'A';
        if (ca != cb) return ca - cb;
        if (ca == 0) return 0;
    }
}

const char *ztp_tz_link_target(const char *id)
{
    size_t lo = 0, hi = ztp_tz_links_count;

    while (lo < hi) {
        size_t mid = lo + (hi - lo) / 2;
        int c = ztp_tz_casecmp(ztp_tz_links[mid].link, id);
        if (c == 0) return ztp_tz_links[mid].target;
        if (c < 0) lo = mid + 1;
        else hi = mid;
    }
    return NULL;
}

/* --- the POSIX TZ footer ------------------------------------------------ */

typedef struct {
    const char *s;
    size_t n, pos;
} ztp_tz_cur;

static int ztp_tz_peek(const ztp_tz_cur *c) { return c->pos < c->n ? c->s[c->pos] : -1; }

static bool ztp_tz_parse_abbr(ztp_tz_cur *c, char *out)
{
    size_t k = 0;

    if (ztp_tz_peek(c) == '<') {
        c->pos++;
        while (ztp_tz_peek(c) != '>' && ztp_tz_peek(c) >= 0) {
            if (k + 1 >= ZTP_TZ_ABBR_CAP) return false;
            out[k++] = c->s[c->pos++];
        }
        if (ztp_tz_peek(c) != '>') return false;
        c->pos++;
    } else {
        int ch;
        while ((ch = ztp_tz_peek(c)) >= 0 &&
               ((ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z'))) {
            if (k + 1 >= ZTP_TZ_ABBR_CAP) return false;
            out[k++] = (char)ch;
            c->pos++;
        }
    }
    out[k] = '\0';
    return k >= 1;   /* POSIX asks for three; files in the wild have fewer */
}

static bool ztp_tz_parse_int(ztp_tz_cur *c, int max_digits, int *out)
{
    int v = 0, k = 0;

    while (ztp_tz_peek(c) >= '0' && ztp_tz_peek(c) <= '9') {
        if (k == max_digits) return false;
        v = v * 10 + (ztp_tz_peek(c) - '0');
        k++;
        c->pos++;
    }
    if (k == 0) return false;
    *out = v;
    return true;
}

/* [+-]hh[:mm[:ss]], hours up to `max_hours`, as seconds. */
static bool ztp_tz_parse_hms(ztp_tz_cur *c, int max_hours, int64_t *out)
{
    int sign = 1, h, m = 0, s = 0;

    if (ztp_tz_peek(c) == '+') c->pos++;
    else if (ztp_tz_peek(c) == '-') { sign = -1; c->pos++; }
    if (!ztp_tz_parse_int(c, 3, &h) || h > max_hours) return false;
    if (ztp_tz_peek(c) == ':') {
        c->pos++;
        if (!ztp_tz_parse_int(c, 2, &m) || m > 59) return false;
        if (ztp_tz_peek(c) == ':') {
            c->pos++;
            if (!ztp_tz_parse_int(c, 2, &s) || s > 59) return false;
        }
    }
    *out = sign * ((int64_t)h * 3600 + m * 60 + s);
    return true;
}

static bool ztp_tz_parse_rule_date(ztp_tz_cur *c, ztp_tz_rule_date *out)
{
    int ch = ztp_tz_peek(c);

    memset(out, 0, sizeof *out);
    if (ch == 'J') {
        c->pos++;
        out->kind = ZTP_TZ_RULE_JULIAN;
        if (!ztp_tz_parse_int(c, 3, &out->day) || out->day < 1 || out->day > 365) return false;
    } else if (ch == 'M') {
        c->pos++;
        out->kind = ZTP_TZ_RULE_MONTH;
        if (!ztp_tz_parse_int(c, 2, &out->month) || out->month < 1 || out->month > 12) return false;
        if (ztp_tz_peek(c) != '.') return false;
        c->pos++;
        if (!ztp_tz_parse_int(c, 1, &out->week) || out->week < 1 || out->week > 5) return false;
        if (ztp_tz_peek(c) != '.') return false;
        c->pos++;
        if (!ztp_tz_parse_int(c, 1, &out->weekday) || out->weekday > 6) return false;
    } else {
        out->kind = ZTP_TZ_RULE_DAY;
        if (!ztp_tz_parse_int(c, 3, &out->day) || out->day > 365) return false;
    }
    out->time = 2 * 3600;   /* the default of 02:00:00 */
    if (ztp_tz_peek(c) == '/') {
        c->pos++;
        if (!ztp_tz_parse_hms(c, 167, &out->time)) return false;
    }
    return true;
}

ztp_status ztp_tz_posix_parse(ztp_ctx *ctx, size_t index, const char *s,
                              size_t n, ztp_tz_posix *out)
{
    ztp_tz_cur c = {s, n, 0};
    int64_t off;

    memset(out, 0, sizeof *out);
    if (!ztp_tz_parse_abbr(&c, out->std_abbr)) goto bad;
    /* POSIX offsets are west-positive; store east-positive. */
    if (!ztp_tz_parse_hms(&c, 24, &off)) goto bad;
    out->std_off = (int32_t)-off;
    if (c.pos == n) return ZTP_OK;
    if (!ztp_tz_parse_abbr(&c, out->dst_abbr)) goto bad;
    out->has_dst = true;
    if (ztp_tz_peek(&c) == ',' || c.pos == n) {
        out->dst_off = out->std_off + 3600;
    } else {
        if (!ztp_tz_parse_hms(&c, 24, &off)) goto bad;
        out->dst_off = (int32_t)-off;
    }
    if (c.pos == n) {
        /* No rule: POSIX says US rules apply; zic never writes this. */
        ztp_tz_cur r = {"M3.2.0,M11.1.0", 14, 0};
        ztp_tz_parse_rule_date(&r, &out->start);
        r.pos++;
        ztp_tz_parse_rule_date(&r, &out->end);
        return ZTP_OK;
    }
    if (ztp_tz_peek(&c) != ',') goto bad;
    c.pos++;
    if (!ztp_tz_parse_rule_date(&c, &out->start)) goto bad;
    if (ztp_tz_peek(&c) != ',') goto bad;
    c.pos++;
    if (!ztp_tz_parse_rule_date(&c, &out->end)) goto bad;
    if (c.pos != n) goto bad;
    return ZTP_OK;
bad:
    return ztp_fail(ctx, ZTP_ERR_TZ, index, "cannot parse the TZ rule \"%.*s\"",
                    (int)(n < 60 ? n : 60), s);
}

/* The epoch second at which the rule date falls in `year`, given the
   offset in force before it (the rule's time is local time then). */
static int64_t ztp_tz_rule_instant(const ztp_tz_rule_date *r, int32_t year,
                                   int32_t offset_before)
{
    int64_t jan1 = zuf_days_from_civil(year, 1, 1);
    int64_t day;

    switch (r->kind) {
    case ZTP_TZ_RULE_JULIAN:
        day = jan1 + r->day - 1;
        if (zuf_is_leap_year(year) && r->day >= 60) day++;
        break;
    case ZTP_TZ_RULE_DAY:
        day = jan1 + r->day;
        break;
    default: {
        int64_t first = zuf_days_from_civil(year, (uint32_t)r->month, 1);
        /* zufast: Monday 1 to Sunday 7; the rule: Sunday 0 to Saturday 6. */
        int wd_first = (int)(zuf_weekday_from_days((int32_t)first) % 7);
        int delta = (r->weekday - wd_first + 7) % 7;
        day = first + delta + (int64_t)(r->week - 1) * 7;
        if (r->week == 5) {
            int64_t dim = zuf_days_in_month(year, (uint32_t)r->month);
            while (day - first >= dim) day -= 7;
        }
        break;
    }
    }
    return day * 86400 + r->time - offset_before;
}

/* The two transitions of `year`: into DST and out of it, in UTC seconds. */
static void ztp_tz_rule_year(const ztp_tz_posix *p, int32_t year, int64_t *start,
                             int64_t *end)
{
    *start = ztp_tz_rule_instant(&p->start, year, p->std_off);
    *end = ztp_tz_rule_instant(&p->end, year, p->dst_off);
}

static int32_t ztp_tz_year_of(int64_t t)
{
    int64_t days = t >= 0 ? t / 86400 : -((-t + 86399) / 86400);
    ztp_iso_date d;
    ztp_iso_date_from_epoch_day((int32_t)days, &d);
    return d.year;
}

/* Whether the footer rule puts epoch second t in DST. */
static bool ztp_tz_rule_in_dst(const ztp_tz_posix *p, int64_t t)
{
    int32_t year;
    int64_t start, end;

    if (!p->has_dst) return false;
    year = ztp_tz_year_of(t + p->std_off);
    ztp_tz_rule_year(p, year, &start, &end);
    if (start < end) return t >= start && t < end;         /* northern */
    return t < end || t >= start;                           /* southern */
}

/* --- TZif --------------------------------------------------------------- */

static uint32_t ztp_tz_be32(const unsigned char *p)
{
    return ((uint32_t)p[0] << 24) | ((uint32_t)p[1] << 16) | ((uint32_t)p[2] << 8) | p[3];
}

static int64_t ztp_tz_be64(const unsigned char *p)
{
    return (int64_t)(((uint64_t)ztp_tz_be32(p) << 32) | ztp_tz_be32(p + 4));
}

typedef struct {
    uint32_t isutcnt, isstdcnt, leapcnt, timecnt, typecnt, charcnt;
    int version;
} ztp_tz_header;

static bool ztp_tz_read_header(const unsigned char *p, size_t avail, ztp_tz_header *h)
{
    if (avail < 44 || memcmp(p, "TZif", 4) != 0) return false;
    h->version = p[4] == 0 ? 1 : p[4] - '0';
    if (h->version < 1 || h->version > 4) return false;
    h->isutcnt = ztp_tz_be32(p + 20);
    h->isstdcnt = ztp_tz_be32(p + 24);
    h->leapcnt = ztp_tz_be32(p + 28);
    h->timecnt = ztp_tz_be32(p + 32);
    h->typecnt = ztp_tz_be32(p + 36);
    h->charcnt = ztp_tz_be32(p + 40);
    /* Sanity bounds far above any real file keep the size arithmetic safe. */
    return h->typecnt >= 1 && h->typecnt <= 256 && h->timecnt <= 1u << 20 &&
           h->charcnt <= 1u << 16 && h->leapcnt <= 1u << 16 &&
           h->isstdcnt <= 256 && h->isutcnt <= 256;
}

static size_t ztp_tz_block_size(const ztp_tz_header *h, size_t time_size)
{
    return (size_t)h->timecnt * (time_size + 1) + (size_t)h->typecnt * 6 + h->charcnt +
           (size_t)h->leapcnt * (time_size + 4) + h->isstdcnt + h->isutcnt;
}

void ztp_tz_data_free(ztp_tz_data *d)
{
    free(d->times);
    free(d->idx);
    free(d->types);
    free(d->abbrs);
    memset(d, 0, sizeof *d);
}

ztp_status ztp_tzif_parse(ztp_ctx *ctx, size_t index, const unsigned char *buf,
                          size_t n, ztp_tz_data *out)
{
    ztp_tz_header h;
    const unsigned char *p = buf;
    size_t time_size = 4, block;

    memset(out, 0, sizeof *out);
    if (!ztp_tz_read_header(p, n, &h))
        return ztp_fail(ctx, ZTP_ERR_TZ, index, "not a TZif file");
    out->version = h.version;
    p += 44;
    if (h.version >= 2) {
        /* Skip the 32-bit block, then read the 64-bit one. */
        block = ztp_tz_block_size(&h, 4);
        if ((size_t)(n - (p - buf)) < block + 44)
            return ztp_fail(ctx, ZTP_ERR_TZ, index, "TZif file is truncated");
        p += block;
        if (!ztp_tz_read_header(p, n - (size_t)(p - buf), &h))
            return ztp_fail(ctx, ZTP_ERR_TZ, index, "TZif second header is invalid");
        p += 44;
        time_size = 8;
    }
    block = ztp_tz_block_size(&h, time_size);
    if ((size_t)(n - (p - buf)) < block)
        return ztp_fail(ctx, ZTP_ERR_TZ, index, "TZif file is truncated");

    out->n_times = h.timecnt;
    out->n_types = h.typecnt;
    out->n_abbrs = h.charcnt;
    out->times = calloc(h.timecnt ? h.timecnt : 1, sizeof *out->times);
    out->idx = calloc(h.timecnt ? h.timecnt : 1, 1);
    out->types = calloc(h.typecnt, sizeof *out->types);
    out->abbrs = calloc(h.charcnt + 1, 1);
    if (!out->times || !out->idx || !out->types || !out->abbrs) {
        ztp_tz_data_free(out);
        return ztp_fail(ctx, ZTP_ERR_TZ, index, "out of memory reading a TZif file");
    }
    for (uint32_t i = 0; i < h.timecnt; i++) {
        out->times[i] = time_size == 8 ? ztp_tz_be64(p + 8 * i) : (int32_t)ztp_tz_be32(p + 4 * i);
        if (i > 0 && out->times[i] <= out->times[i - 1]) {
            ztp_tz_data_free(out);
            return ztp_fail(ctx, ZTP_ERR_TZ, index, "TZif transitions are not ascending");
        }
    }
    p += h.timecnt * time_size;
    for (uint32_t i = 0; i < h.timecnt; i++) {
        out->idx[i] = p[i];
        if (p[i] >= h.typecnt) {
            ztp_tz_data_free(out);
            return ztp_fail(ctx, ZTP_ERR_TZ, index, "TZif transition type out of range");
        }
    }
    p += h.timecnt;
    for (uint32_t i = 0; i < h.typecnt; i++) {
        out->types[i].utoff = (int32_t)ztp_tz_be32(p + 6 * i);
        out->types[i].isdst = p[6 * i + 4] != 0;
        out->types[i].abbr = p[6 * i + 5];
        if (out->types[i].abbr >= h.charcnt && h.charcnt > 0) {
            ztp_tz_data_free(out);
            return ztp_fail(ctx, ZTP_ERR_TZ, index, "TZif abbreviation index out of range");
        }
    }
    p += h.typecnt * 6;
    memcpy(out->abbrs, p, h.charcnt);
    out->abbrs[h.charcnt] = '\0';
    p += h.charcnt + (size_t)h.leapcnt * (time_size + 4) + h.isstdcnt + h.isutcnt;
    /* The footer: "\n" TZ-string "\n", in version 2 and later. */
    if (h.version >= 2) {
        size_t rest = n - (size_t)(p - buf);
        if (rest >= 2 && p[0] == '\n') {
            const unsigned char *end = memchr(p + 1, '\n', rest - 1);
            if (end == NULL) {
                ztp_tz_data_free(out);
                return ztp_fail(ctx, ZTP_ERR_TZ, index, "TZif footer is not terminated");
            }
            if (end > p + 1) {
                if (ztp_tz_posix_parse(ctx, index, (const char *)p + 1, (size_t)(end - p - 1),
                                       &out->footer) != ZTP_OK) {
                    ztp_tz_data_free(out);
                    return ctx->status;
                }
                out->has_footer = true;
            }
        }
    }
    return ZTP_OK;
}

/* --- offsets and transitions -------------------------------------------- */

/* The index of the last transition at or before t, or -1. */
static long ztp_tz_find(const ztp_tz_data *d, int64_t t)
{
    size_t lo = 0, hi = d->n_times;

    while (lo < hi) {
        size_t mid = lo + (hi - lo) / 2;
        if (d->times[mid] <= t) lo = mid + 1;
        else hi = mid;
    }
    return (long)lo - 1;
}

int32_t ztp_tz_utoff_at(const ztp_tz_data *d, int64_t t, bool *isdst,
                        const char **abbr)
{
    long i = ztp_tz_find(d, t);
    const ztp_tz_type *ty;

    if (d->n_times > 0 && i == (long)d->n_times - 1 && d->has_footer) {
        bool dst = ztp_tz_rule_in_dst(&d->footer, t);
        if (isdst) *isdst = dst;
        if (abbr) *abbr = dst ? d->footer.dst_abbr : d->footer.std_abbr;
        return dst ? d->footer.dst_off : d->footer.std_off;
    }
    if (d->n_times == 0 && d->has_footer) {
        bool dst = ztp_tz_rule_in_dst(&d->footer, t);
        if (isdst) *isdst = dst;
        if (abbr) *abbr = dst ? d->footer.dst_abbr : d->footer.std_abbr;
        return dst ? d->footer.dst_off : d->footer.std_off;
    }
    ty = i < 0 ? &d->types[0] : &d->types[d->idx[i]];
    if (isdst) *isdst = ty->isdst;
    if (abbr) *abbr = d->abbrs + ty->abbr;
    return ty->utoff;
}

bool ztp_tz_last_explicit(const ztp_tz_data *d, int64_t *out)
{
    if (d->n_times == 0) return false;
    *out = d->times[d->n_times - 1];
    return true;
}

/* The rule's transitions near t: the smallest one strictly after t, or
   the largest strictly before it. */
static bool ztp_tz_rule_next(const ztp_tz_posix *p, int64_t t, int64_t limit, int64_t *out)
{
    int32_t year;

    if (!p->has_dst) return false;
    year = ztp_tz_year_of(t + p->std_off) - 1;
    for (int k = 0; k < 4; k++, year++) {
        int64_t start, end, lo, hi;
        ztp_tz_rule_year(p, year, &start, &end);
        lo = start < end ? start : end;
        hi = start < end ? end : start;
        if (lo > t) { *out = lo; return lo <= limit; }
        if (hi > t) { *out = hi; return hi <= limit; }
    }
    return false;
}

static bool ztp_tz_rule_previous(const ztp_tz_posix *p, int64_t t, int64_t limit, int64_t *out)
{
    int32_t year;

    if (!p->has_dst) return false;
    year = ztp_tz_year_of(t + p->std_off) + 1;
    for (int k = 0; k < 4; k++, year--) {
        int64_t start, end, lo, hi;
        ztp_tz_rule_year(p, year, &start, &end);
        lo = start < end ? start : end;
        hi = start < end ? end : start;
        if (hi < t) { *out = hi; return hi >= -limit; }
        if (lo < t) { *out = lo; return lo >= -limit; }
    }
    return false;
}

bool ztp_tz_next_transition(const ztp_tz_data *d, int64_t t, int64_t limit, int64_t *out)
{
    long i = ztp_tz_find(d, t);

    /* Explicit transitions after t, skipping those that change nothing. */
    for (size_t k = (size_t)(i + 1); k < d->n_times; k++) {
        int32_t before = k == 0 ? d->types[0].utoff : d->types[d->idx[k - 1]].utoff;
        if (d->types[d->idx[k]].utoff != before) {
            *out = d->times[k];
            return *out <= limit;
        }
    }
    if (!d->has_footer) return false;
    {
        int64_t from = d->n_times ? d->times[d->n_times - 1] : t;
        if (from < t) from = t;
        return ztp_tz_rule_next(&d->footer, from, limit, out);
    }
}

bool ztp_tz_previous_transition(const ztp_tz_data *d, int64_t t, int64_t limit, int64_t *out)
{
    long i = ztp_tz_find(d, t - 1);   /* transitions strictly before t */

    if (d->has_footer && d->n_times > 0 && i == (long)d->n_times - 1) {
        int64_t last = d->times[d->n_times - 1];
        if (ztp_tz_rule_previous(&d->footer, t, limit, out) && *out > last) return true;
    } else if (d->has_footer && d->n_times == 0) {
        return ztp_tz_rule_previous(&d->footer, t, limit, out);
    }
    for (long k = i; k >= 0; k--) {
        int32_t before = k == 0 ? d->types[0].utoff : d->types[d->idx[k - 1]].utoff;
        if (d->types[d->idx[k]].utoff != before) {
            *out = d->times[k];
            return *out >= -limit;
        }
    }
    return false;
}

/* --- possible epoch nanoseconds ----------------------------------------- */

int ztp_tz_possible_epoch_ns(const ztp_tz_data *d, int32_t day, int64_t ns_of_day,
                             zuf_i128 out[2])
{
    /* The offsets in force a day either side of the local time (and at the
       local time itself) are the only ones that can apply; each gives a
       candidate that stands when the zone's offset at that instant is the
       offset assumed. */
    zuf_i128 local = ztp_epoch_ns_of(day, ns_of_day);
    int64_t local_s = (int64_t)day * 86400 + ns_of_day / ZTP_NS_PER_SECOND;
    int32_t probes[3];
    int n_probes = 0, n_out = 0;

    probes[n_probes++] = ztp_tz_utoff_at(d, local_s - 86400, NULL, NULL);
    {
        int32_t o = ztp_tz_utoff_at(d, local_s, NULL, NULL);
        bool seen = false;
        for (int i = 0; i < n_probes; i++) if (probes[i] == o) seen = true;
        if (!seen) probes[n_probes++] = o;
    }
    {
        int32_t o = ztp_tz_utoff_at(d, local_s + 86400, NULL, NULL);
        bool seen = false;
        for (int i = 0; i < n_probes; i++) if (probes[i] == o) seen = true;
        if (!seen) probes[n_probes++] = o;
    }
    for (int i = 0; i < n_probes; i++) {
        zuf_i128 candidate = zuf_i128_sub_wrap(local, zuf_i128_mul_i64_i64(probes[i], ZTP_NS_PER_SECOND));
        zuf_i128 q;
        int64_t r, cand_s;
        zuf_i128_divmod_floor_i64(candidate, ZTP_NS_PER_SECOND, &q, &r);
        zuf_i128_to_i64(q, &cand_s);
        if (ztp_tz_utoff_at(d, cand_s, NULL, NULL) == probes[i] && n_out < 2) {
            bool dup = false;
            for (int k = 0; k < n_out; k++) if (zuf_i128_cmp(out[k], candidate) == 0) dup = true;
            if (!dup) out[n_out++] = candidate;
        }
    }
    if (n_out == 2 && zuf_i128_cmp(out[0], out[1]) > 0) {
        zuf_i128 t = out[0];
        out[0] = out[1];
        out[1] = t;
    }
    return n_out;
}

const char *ztp_tz_primary(const char *id)
{
    const char *target = ztp_tz_link_target(id);
    return target ? target : id;
}
