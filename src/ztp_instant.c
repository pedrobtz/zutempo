/* ztp_instant.c -- see ztp_instant.h. Engine side: no R. */

#include "ztp_instant.h"
#include "ztp_tz.h"

#include <math.h>
#include <string.h>

zuf_i128 ztp_ns_max_instant(void)
{
    return zuf_i128_mul_i64_i64(ZTP_MAX_EPOCH_DAY, ZTP_NS_PER_DAY);
}

bool ztp_is_valid_epoch_ns(zuf_i128 ns)
{
    return zuf_i128_cmp(ztp_i128_abs(ns), ztp_ns_max_instant()) <= 0;
}

void ztp_epoch_ns_split(zuf_i128 ns, double *seconds, double *nanoseconds)
{
    zuf_i128 q;
    int64_t r;

    zuf_i128_divmod_floor_i64(ns, ZTP_NS_PER_SECOND, &q, &r);
    *seconds = ztp_i128_to_double(q);
    *nanoseconds = (double)r;
}

zuf_i128 ztp_epoch_ns_join(double seconds, double nanoseconds)
{
    zuf_i128 s, n;

    ztp_i128_from_double(seconds, &s);
    ztp_i128_from_double(nanoseconds, &n);
    return zuf_i128_add_wrap(zuf_i128_mul_wrap(s, zuf_i128_from_i64(ZTP_NS_PER_SECOND)), n);
}

/* --- zones -------------------------------------------------------------- */

static bool ztp_two_digits(const char *s, size_t n, size_t at, int *out)
{
    if (at + 2 > n || s[at] < '0' || s[at] > '9' || s[at + 1] < '0' || s[at + 1] > '9')
        return false;
    *out = (s[at] - '0') * 10 + (s[at + 1] - '0');
    return true;
}

ztp_status ztp_zone_parse(ztp_ctx *ctx, size_t index, const char *s, size_t n,
                          ztp_zone *out)
{
    memset(out, 0, sizeof *out);
    if (n == 3 && (s[0] == 'U' || s[0] == 'u') && (s[1] == 'T' || s[1] == 't') &&
        (s[2] == 'C' || s[2] == 'c')) {
        out->kind = ZTP_ZONE_UTC;
        memcpy(out->id, "UTC", 4);
        return ZTP_OK;
    }
    if (n >= 3 && (s[0] == '+' || s[0] == '-')) {
        int hours, minutes = 0, seconds = -1;
        size_t at = 1;
        bool extended;

        if (!ztp_two_digits(s, n, at, &hours) || hours > 23)
            return ztp_fail(ctx, ZTP_ERR_RANGE, index, "\"%.*s\" is not a valid UTC offset",
                            (int)(n < 40 ? n : 40), s);
        at += 2;
        extended = at < n && s[at] == ':';
        if (extended) at++;
        if (at < n) {
            if (!ztp_two_digits(s, n, at, &minutes) || minutes > 59)
                return ztp_fail(ctx, ZTP_ERR_RANGE, index, "\"%.*s\" is not a valid UTC offset",
                                (int)(n < 40 ? n : 40), s);
            at += 2;
            if (at < n) {
                /* Seconds, with or without ':', are a well-formed offset
                   string but not a time zone identifier. */
                size_t rest = at;
                if (extended && s[rest] == ':') rest++;
                if (ztp_two_digits(s, n, rest, &seconds))
                    return ztp_fail(ctx, ZTP_ERR_RANGE, index,
                                    "a time zone offset must be a whole number of minutes");
                return ztp_fail(ctx, ZTP_ERR_RANGE, index, "\"%.*s\" is not a valid UTC offset",
                                (int)(n < 40 ? n : 40), s);
            }
        } else if (extended) {
            return ztp_fail(ctx, ZTP_ERR_RANGE, index, "\"%.*s\" is not a valid UTC offset",
                            (int)(n < 40 ? n : 40), s);
        }
        out->kind = ZTP_ZONE_OFFSET;
        out->offset_ns = ((int64_t)hours * 60 + minutes) * ZTP_NS_PER_MINUTE;
        if (s[0] == '-') out->offset_ns = -out->offset_ns;
        ztp_format_offset(out->id, out->offset_ns);
        return ZTP_OK;
    }
    /* A name: TZLeadingChar then TZChar, with "/" between components. */
    {
        bool name = n > 0 && n < ZTP_ZONE_ID_CAP;
        for (size_t i = 0; name && i < n; i++) {
            char ch = s[i];
            bool alpha = (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z');
            bool digit = ch >= '0' && ch <= '9';
            if (i == 0 || s[i - 1] == '/') {
                if (!(alpha || ch == '.' || ch == '_')) name = false;
            } else if (!(alpha || digit || ch == '.' || ch == '_' || ch == '-' || ch == '+' || ch == '/')) {
                name = false;
            }
        }
        if (name) {
            char id[ZTP_ZONE_ID_CAP];
            const ztp_tz_entry *entry;
            memcpy(id, s, n);
            id[n] = '\0';
            entry = ztp_tz_cache_find(id);
            if (entry == NULL)
                return ztp_fail(ctx, ZTP_ERR_TZ, index,
                                "time zone \"%s\" is not available", id);
            out->kind = ZTP_ZONE_IANA;
            out->iana = entry;
            strcpy(out->id, entry->id);
            return ZTP_OK;
        }
    }
    return ztp_fail(ctx, ZTP_ERR_RANGE, index, "\"%.*s\" is not a time zone identifier",
                    (int)(n < 40 ? n : 40), s);
}

int64_t ztp_zone_offset_at(const ztp_zone *zone, zuf_i128 epoch_ns)
{
    if (zone->kind == ZTP_ZONE_IANA) {
        zuf_i128 q;
        int64_t r, seconds;
        zuf_i128_divmod_floor_i64(epoch_ns, ZTP_NS_PER_SECOND, &q, &r);
        zuf_i128_to_i64(q, &seconds);
        return (int64_t)ztp_tz_utoff_at(&zone->iana->data, seconds, NULL, NULL) * ZTP_NS_PER_SECOND;
    }
    return zone->kind == ZTP_ZONE_OFFSET ? zone->offset_ns : 0;
}

static int ztp_zone_casecmp(const char *a, const char *b)
{
    for (;; a++, b++) {
        int ca = (unsigned char)*a, cb = (unsigned char)*b;
        if (ca >= 'A' && ca <= 'Z') ca += 'a' - 'A';
        if (cb >= 'A' && cb <= 'Z') cb += 'a' - 'A';
        if (ca != cb) return ca - cb;
        if (ca == 0) return 0;
    }
}

/* TimeZoneEquals (design 6.7): offsets by value, named zones (UTC among
   them) by their primary identifier, never across the two. */
bool ztp_zone_equals(const ztp_zone *a, const ztp_zone *b)
{
    bool a_offset = a->kind == ZTP_ZONE_OFFSET, b_offset = b->kind == ZTP_ZONE_OFFSET;

    if (a_offset || b_offset) return a_offset && b_offset && a->offset_ns == b->offset_ns;
    return ztp_zone_casecmp(ztp_tz_primary(a->id), ztp_tz_primary(b->id)) == 0;
}

size_t ztp_format_offset(char *dst, int64_t offset_ns)
{
    /* Rounded to the minute, half-expand. */
    int64_t minutes = ztp_round_to_increment(offset_ns, ZTP_NS_PER_MINUTE, ZTP_ROUND_HALF_EXPAND) /
                      ZTP_NS_PER_MINUTE;
    int64_t a = minutes < 0 ? -minutes : minutes;
    char *p = dst;

    *p++ = minutes < 0 ? '-' : '+';
    *p++ = (char)('0' + (a / 60) / 10);
    *p++ = (char)('0' + (a / 60) % 10);
    *p++ = ':';
    *p++ = (char)('0' + (a % 60) / 10);
    *p++ = (char)('0' + (a % 60) % 10);
    *p = '\0';
    return (size_t)(p - dst);
}

/* --- instants ----------------------------------------------------------- */

void ztp_instant_to_local(zuf_i128 epoch_ns, int64_t offset_ns, int32_t *day,
                          int64_t *ns_of_day)
{
    zuf_i128 local = zuf_i128_add_wrap(epoch_ns, zuf_i128_from_i64(offset_ns));
    zuf_i128 q;
    int64_t r, d;

    zuf_i128_divmod_floor_i64(local, ZTP_NS_PER_DAY, &q, &r);
    zuf_i128_to_i64(q, &d);
    *day = (int32_t)d;
    *ns_of_day = r;
}

ztp_status ztp_instant_from_local(ztp_ctx *ctx, size_t index, int64_t day,
                                  int64_t ns_of_day, int64_t offset_ns,
                                  zuf_i128 *out)
{
    zuf_i128 ns;

    /* CheckISODaysRange keeps the multiplication exact. */
    if (day < -ZTP_MAX_EPOCH_DAY - 1 || day > ZTP_MAX_EPOCH_DAY + 1)
        return ztp_fail(ctx, ZTP_ERR_RANGE, index,
                        "the instant is outside the representable range");
    ns = zuf_i128_add_wrap(zuf_i128_mul_i64_i64(day, ZTP_NS_PER_DAY), zuf_i128_from_i64(ns_of_day));
    ns = zuf_i128_sub_wrap(ns, zuf_i128_from_i64(offset_ns));
    if (!ztp_is_valid_epoch_ns(ns))
        return ztp_fail(ctx, ZTP_ERR_RANGE, index,
                        "the instant is outside the representable range");
    *out = ns;
    return ZTP_OK;
}

zuf_i128 ztp_round_instant(zuf_i128 ns, int64_t increment, ztp_unit unit,
                           ztp_rounding_mode mode)
{
    zuf_i128 step = zuf_i128_mul_i64_i64(ztp_unit_length_ns(unit), increment);
    return ztp_round_i128_to_increment(ns, step, mode, true);
}

size_t ztp_format_instant(char *dst, zuf_i128 epoch_ns, const ztp_zone *zone,
                          int precision)
{
    int64_t offset = zone ? ztp_zone_offset_at(zone, epoch_ns) : 0;
    int32_t day;
    int64_t ns_of_day;
    size_t k;

    ztp_instant_to_local(epoch_ns, offset, &day, &ns_of_day);
    k = ztp_format_iso_date_time(dst, day, ns_of_day, precision, ZTP_SHOW_CALENDAR_NEVER);
    if (zone == NULL) {
        dst[k++] = 'Z';
        dst[k] = '\0';
        return k;
    }
    return k + ztp_format_offset(dst + k, offset);
}

/* 2^k as an unsigned 128-bit integer, k in 0..127. */
static zuf_u128 ztp_u128_pow2(unsigned k)
{
    return k < 64 ? zuf_u128_make(0, (uint64_t)1 << k) : zuf_u128_make((uint64_t)1 << (k - 64), 0);
}

/* A finite double as m * 2^k with m an integer below 2^53. */
static void ztp_double_decompose(double x, uint64_t *m, int *k)
{
    int e;
    double f = frexp(fabs(x), &e);   /* x = f * 2^e, f in [0.5, 1) */

    *m = (uint64_t)ldexp(f, 53);
    *k = e - 53;
    if (x == 0) {
        *m = 0;
        *k = 0;
    }
}

bool ztp_epoch_ns_from_seconds(double x, zuf_i128 *out)
{
    uint64_t m;
    int k;
    zuf_u128 n, q, r, mag;

    if (!isfinite(x)) return false;
    ztp_double_decompose(x, &m, &k);
    /* The exact value in nanoseconds is m * 10^9 * 2^k, with m * 10^9
       below 2^83. */
    n = zuf_u128_mul_u64_u64(m, 1000000000u);
    if (k >= 0) {
        if (k > 40 || !zuf_u128_mul(n, ztp_u128_pow2((unsigned)k), &mag)) return false;
    } else if (-k >= 90) {
        mag = zuf_u128_from_u64(0);   /* below half a nanosecond */
    } else {
        zuf_u128 d = ztp_u128_pow2((unsigned)-k), half = ztp_u128_pow2((unsigned)(-k - 1));
        int c;
        zuf_u128_divmod(n, d, &q, &r);
        c = zuf_u128_cmp(r, half);
        if (c > 0 || (c == 0 && (zuf_u128_low(q) & 1u)))
            q = zuf_u128_add_wrap(q, zuf_u128_from_u64(1));
        mag = q;
    }
    if (zuf_u128_cmp(mag, ztp_u128_pow2(126)) >= 0) return false;
    *out = zuf_i128_from_u128(mag);
    if (x < 0) zuf_i128_neg(*out, out);
    return true;
}

/* Whether a double's last significand bit is 0: the tie rule. */
static bool ztp_double_is_even(double x)
{
    uint64_t m;
    int k;
    ztp_double_decompose(x, &m, &k);
    return (m & 1u) == 0;
}

/* |candidate * 10^9 * 2^s - ns * 2^s| for a common scale 2^s, as the
   distance between a double and the exact value ns / 10^9. */
static zuf_i128 ztp_seconds_distance(double candidate, zuf_i128 ns, unsigned s)
{
    uint64_t m;
    int k;
    zuf_i128 a, b, d;

    ztp_double_decompose(candidate, &m, &k);
    a = zuf_i128_from_u128(zuf_u128_mul_wrap(zuf_u128_mul_u64_u64(m, 1000000000u),
                                             ztp_u128_pow2((unsigned)(k + (int)s))));
    if (candidate < 0) zuf_i128_neg(a, &a);
    b = zuf_i128_mul_wrap(ns, zuf_i128_from_u128(ztp_u128_pow2(s)));
    d = zuf_i128_sub_wrap(a, b);
    if (zuf_i128_is_neg(d)) zuf_i128_neg(d, &d);
    return d;
}

double ztp_seconds_from_epoch_ns(zuf_i128 ns)
{
    double approx, best;
    zuf_i128 best_d;
    int64_t small;
    unsigned s = 0;

    /* Below 2^53 nanoseconds (about 104 days) ns is exact as a double and
       one division rounds correctly. */
    if (zuf_i128_to_i64(ns, &small) && small > -((int64_t)1 << 53) && small < ((int64_t)1 << 53))
        return (double)small / 1e9;
    /* Further out the result is at least 2^23 s, so its neighbours are the
       only other candidates, and a scale of 2^29 makes all three integers
       times 10^-9 without leaving 128 bits. */
    {
        double seconds, nanoseconds;
        ztp_epoch_ns_split(ns, &seconds, &nanoseconds);
        approx = seconds + nanoseconds / 1e9;   /* within one ulp */
    }
    {
        double cand[3] = {nextafter(approx, -INFINITY), approx, nextafter(approx, INFINITY)};
        for (int i = 0; i < 3; i++) {
            uint64_t m;
            int k;
            ztp_double_decompose(cand[i], &m, &k);
            if (k < 0 && (unsigned)-k > s) s = (unsigned)-k;
        }
        best = cand[1];
        best_d = ztp_seconds_distance(cand[1], ns, s);
        for (int i = 0; i < 3; i += 2) {
            zuf_i128 d = ztp_seconds_distance(cand[i], ns, s);
            int c = zuf_i128_cmp(d, best_d);
            if (c < 0 || (c == 0 && ztp_double_is_even(cand[i]))) {
                best = cand[i];
                best_d = d;
            }
        }
    }
    return best;
}
