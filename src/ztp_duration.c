/* ztp_duration.c -- see ztp_duration.h. Engine side: no R. */

#include "ztp_duration.h"
#include "ztp_format.h"

#include <math.h>
#include <stdio.h>
#include <string.h>

/* --- the records -------------------------------------------------------- */

double ztp_duration_field(const ztp_duration *d, int i)
{
    switch (i) {
    case 0: return d->years;
    case 1: return d->months;
    case 2: return d->weeks;
    case 3: return d->days;
    case 4: return d->hours;
    case 5: return d->minutes;
    case 6: return d->seconds;
    case 7: return d->milliseconds;
    case 8: return d->microseconds;
    default: return d->nanoseconds;
    }
}

void ztp_duration_set_field(ztp_duration *d, int i, double value)
{
    switch (i) {
    case 0: d->years = value; break;
    case 1: d->months = value; break;
    case 2: d->weeks = value; break;
    case 3: d->days = value; break;
    case 4: d->hours = value; break;
    case 5: d->minutes = value; break;
    case 6: d->seconds = value; break;
    case 7: d->milliseconds = value; break;
    case 8: d->microseconds = value; break;
    default: d->nanoseconds = value; break;
    }
}

/* --- 128-bit helpers ---------------------------------------------------- */

zuf_i128 ztp_max_time_duration(void)
{
    /* 2^53 * 10^9 - 1 */
    zuf_i128 v = zuf_i128_mul_i64_i64(INT64_C(9007199254740992), INT64_C(1000000000));
    return zuf_i128_sub_wrap(v, zuf_i128_from_i64(1));
}

bool ztp_time_duration_in_range(zuf_i128 t)
{
    return zuf_i128_cmp(ztp_i128_abs(t), ztp_max_time_duration()) <= 0;
}

zuf_i128 ztp_i128_abs(zuf_i128 v)
{
    zuf_i128 out;
    if (!zuf_i128_is_neg(v)) return v;
    if (!zuf_i128_neg(v, &out)) return v;   /* INT128_MIN: unreachable here */
    return out;
}

bool ztp_i128_from_double(double x, zuf_i128 *out)
{
    return zuf_i128_from_f64(x, out);
}

/* The nearest double: exact when the value has at most 53 significant
   bits, otherwise from the two words (rounded twice, within an ulp). */
static unsigned ztp_bit_width64(uint64_t x)
{
    unsigned w = 0;
    while (x) {
        w++;
        x >>= 1;
    }
    return w;
}

/* 2^k as an unsigned 128-bit integer, k in 0..127. */
static zuf_u128 ztp_pow2_u128(unsigned k)
{
    return k < 64 ? zuf_u128_make(0, (uint64_t)1 << k) : zuf_u128_make((uint64_t)1 << (k - 64), 0);
}

/* The nearest double, ties to even, as the specification's 𝔽(x) is: the
   top 53 significant bits, the rest rounded half to even. Adding the two
   64-bit halves as doubles would round twice. */
double ztp_i128_to_double(zuf_i128 v)
{
    double out;
    zuf_u128 m, q, r;
    unsigned w, shift;
    int c;

    if (zuf_i128_to_f64(v, &out)) return out;
    m = zuf_u128_from_i128(ztp_i128_abs(v));
    w = zuf_u128_high(m) ? 64 + ztp_bit_width64(zuf_u128_high(m)) : ztp_bit_width64(zuf_u128_low(m));
    shift = w - 53;   /* w > 53: the exact case returned above */
    zuf_u128_divmod(m, ztp_pow2_u128(shift), &q, &r);
    c = zuf_u128_cmp(r, ztp_pow2_u128(shift - 1));
    if (c > 0 || (c == 0 && (zuf_u128_low(q) & 1u)))
        q = zuf_u128_add_wrap(q, zuf_u128_from_u64(1));
    out = ldexp((double)zuf_u128_low(q), (int)shift);
    return zuf_i128_is_neg(v) ? -out : out;
}

static zuf_i128 ztp_i128_mul_small(zuf_i128 a, int64_t b)
{
    return zuf_i128_mul_wrap(a, zuf_i128_from_i64(b));
}

/* --- validity and signs ------------------------------------------------- */

int ztp_duration_sign(const ztp_duration *d)
{
    for (int i = 0; i < ZTP_DURATION_FIELDS; i++) {
        double v = ztp_duration_field(d, i);
        if (v < 0) return -1;
        if (v > 0) return 1;
    }
    return 0;
}

int ztp_date_duration_sign(const ztp_date_duration *d)
{
    const double v[4] = {d->years, d->months, d->weeks, d->days};
    for (int i = 0; i < 4; i++) {
        if (v[i] < 0) return -1;
        if (v[i] > 0) return 1;
    }
    return 0;
}

int ztp_time_duration_sign(zuf_i128 t)
{
    if (zuf_i128_is_neg(t)) return -1;
    if (t.low == 0 && t.high == 0) return 0;
    return 1;
}

ztp_unit ztp_duration_default_largest_unit(const ztp_duration *d)
{
    for (int i = 0; i < ZTP_DURATION_FIELDS - 1; i++)
        if (ztp_duration_field(d, i) != 0) return (ztp_unit)i;
    return ZTP_UNIT_NANOSECOND;
}

/* The normalised nanoseconds of the day and time fields, exactly, or
   false when a product or sum leaves 128 bits (far past the bound). */
static bool ztp_duration_normalised_ns(const ztp_duration *d, zuf_i128 *out)
{
    const double fields[6] = {d->days, d->hours, d->minutes, d->seconds,
                              d->milliseconds, d->microseconds};
    const int64_t scale[6] = {ZTP_NS_PER_DAY, ZTP_NS_PER_HOUR, ZTP_NS_PER_MINUTE,
                              ZTP_NS_PER_SECOND, ZTP_NS_PER_MILLISECOND,
                              ZTP_NS_PER_MICROSECOND};
    zuf_i128 total, term;

    if (!ztp_i128_from_double(d->nanoseconds, &total)) return false;
    for (int i = 0; i < 6; i++) {
        zuf_i128 v;
        if (!ztp_i128_from_double(fields[i], &v)) return false;
        if (!zuf_i128_mul(v, zuf_i128_from_i64(scale[i]), &term)) return false;
        if (!zuf_i128_add(total, term, &total)) return false;
    }
    *out = total;
    return true;
}

bool ztp_duration_is_valid(const ztp_duration *d)
{
    int sign = 0;
    zuf_i128 ns;

    for (int i = 0; i < ZTP_DURATION_FIELDS; i++) {
        double v = ztp_duration_field(d, i);
        if (!(v == v) || v == HUGE_VAL || v == -HUGE_VAL) return false;
        if (v < 0) {
            if (sign > 0) return false;
            sign = -1;
        } else if (v > 0) {
            if (sign < 0) return false;
            sign = 1;
        }
    }
    if (fabs(d->years) >= 4294967296.0 || fabs(d->months) >= 4294967296.0 ||
        fabs(d->weeks) >= 4294967296.0)
        return false;
    /* A quick bound first: the normalised seconds in doubles, each term
       within a relative 2^-52 of the exact one, so a sum below 2^52 is
       certainly below the limit of 2^53. Only larger values need the
       exact sum in 128 bits. */
    if (fabs(d->days) * 86400.0 + fabs(d->hours) * 3600.0 + fabs(d->minutes) * 60.0 +
            fabs(d->seconds) + fabs(d->milliseconds) * 1e-3 + fabs(d->microseconds) * 1e-6 +
            fabs(d->nanoseconds) * 1e-9 <
        4503599627370496.0)
        return true;
    if (!ztp_duration_normalised_ns(d, &ns)) return false;
    return ztp_time_duration_in_range(ns);
}

ztp_status ztp_duration_create(ztp_ctx *ctx, size_t index,
                               const ztp_duration *in, ztp_duration *out)
{
    if (!ztp_duration_is_valid(in))
        return ztp_fail(ctx, ZTP_ERR_RANGE, index,
                        "the duration has mixed signs or exceeds the representable range");
    *out = *in;
    /* -0 is 0. */
    for (int i = 0; i < ZTP_DURATION_FIELDS; i++)
        if (ztp_duration_field(out, i) == 0) ztp_duration_set_field(out, i, 0.0);
    return ZTP_OK;
}

/* --- internal form ------------------------------------------------------ */

zuf_i128 ztp_time_duration_from_components(double hours, double minutes,
                                           double seconds, double milliseconds,
                                           double microseconds,
                                           double nanoseconds)
{
    const double fields[5] = {hours, minutes, seconds, milliseconds, microseconds};
    const int64_t scale[5] = {ZTP_NS_PER_HOUR, ZTP_NS_PER_MINUTE, ZTP_NS_PER_SECOND,
                              ZTP_NS_PER_MILLISECOND, ZTP_NS_PER_MICROSECOND};
    zuf_i128 total = zuf_i128_from_i64(0), v;

    /* The fields of a valid duration convert exactly (the glue checks
       every stored duration with ztp_duration_is_valid() first); the
       zero start keeps a misuse defined rather than reading garbage. */
    if (!ztp_i128_from_double(nanoseconds, &total)) total = zuf_i128_from_i64(0);
    for (int i = 0; i < 5; i++) {
        if (!ztp_i128_from_double(fields[i], &v)) v = zuf_i128_from_i64(0);
        total = zuf_i128_add_wrap(total, ztp_i128_mul_small(v, scale[i]));
    }
    return total;
}

ztp_internal_duration ztp_duration_to_internal(const ztp_duration *d)
{
    ztp_internal_duration out;

    out.date.years = d->years;
    out.date.months = d->months;
    out.date.weeks = d->weeks;
    out.date.days = d->days;
    out.time = ztp_time_duration_from_components(d->hours, d->minutes, d->seconds,
                                                 d->milliseconds, d->microseconds,
                                                 d->nanoseconds);
    return out;
}

ztp_internal_duration ztp_duration_to_internal_24h(const ztp_duration *d)
{
    ztp_internal_duration out = ztp_duration_to_internal(d);
    zuf_i128 days;

    if (!ztp_i128_from_double(d->days, &days)) days = zuf_i128_from_i64(0);   /* as above */
    out.time = zuf_i128_add_wrap(out.time, ztp_i128_mul_small(days, ZTP_NS_PER_DAY));
    out.date.days = 0;
    return out;
}

ztp_status ztp_time_duration_add(ztp_ctx *ctx, size_t index, zuf_i128 a,
                                 zuf_i128 b, zuf_i128 *out)
{
    zuf_i128 sum;

    if (!zuf_i128_add(a, b, &sum) || !ztp_time_duration_in_range(sum))
        return ztp_fail(ctx, ZTP_ERR_RANGE, index,
                        "the time duration exceeds the representable range");
    *out = sum;
    return ZTP_OK;
}

ztp_status ztp_time_duration_add_days(ztp_ctx *ctx, size_t index, zuf_i128 t,
                                      double days, zuf_i128 *out)
{
    zuf_i128 d, term;

    if (!ztp_i128_from_double(days, &d) ||
        !zuf_i128_mul(d, zuf_i128_from_i64(ZTP_NS_PER_DAY), &term))
        return ztp_fail(ctx, ZTP_ERR_RANGE, index,
                        "the time duration exceeds the representable range");
    return ztp_time_duration_add(ctx, index, t, term, out);
}

/* Split |t| into a quotient and remainder by a positive divisor. */
static void ztp_i128_split(zuf_i128 t, int64_t divisor, zuf_i128 *q, int64_t *r)
{
    zuf_i128_divmod_floor_i64(t, divisor, q, r);
}

ztp_status ztp_duration_from_internal(ztp_ctx *ctx, size_t index,
                                      const ztp_internal_duration *in,
                                      ztp_unit largest_unit, ztp_duration *out)
{
    ztp_duration d;
    int sign = ztp_time_duration_sign(in->time);
    zuf_i128 rest = ztp_i128_abs(in->time);
    int64_t r;
    double days = 0, hours = 0, minutes = 0, seconds = 0, milliseconds = 0,
           microseconds = 0, nanoseconds;
    bool date = largest_unit <= ZTP_UNIT_DAY;

    /* Each step peels the next unit off the remaining nanoseconds, up to
       the largest unit; what remains is expressed in that unit. */
    if (largest_unit <= ZTP_UNIT_MICROSECOND) {
        ztp_i128_split(rest, 1000, &rest, &r);
        nanoseconds = (double)r;
    } else {
        nanoseconds = ztp_i128_to_double(rest);
        rest = zuf_i128_from_i64(0);
    }
    if (largest_unit <= ZTP_UNIT_MILLISECOND) {
        ztp_i128_split(rest, 1000, &rest, &r);
        microseconds = (double)r;
    } else if (largest_unit == ZTP_UNIT_MICROSECOND) {
        microseconds = ztp_i128_to_double(rest);
        rest = zuf_i128_from_i64(0);
    }
    if (largest_unit <= ZTP_UNIT_SECOND) {
        ztp_i128_split(rest, 1000, &rest, &r);
        milliseconds = (double)r;
    } else if (largest_unit == ZTP_UNIT_MILLISECOND) {
        milliseconds = ztp_i128_to_double(rest);
        rest = zuf_i128_from_i64(0);
    }
    if (largest_unit <= ZTP_UNIT_MINUTE) {
        ztp_i128_split(rest, 60, &rest, &r);
        seconds = (double)r;
    } else if (largest_unit == ZTP_UNIT_SECOND) {
        seconds = ztp_i128_to_double(rest);
        rest = zuf_i128_from_i64(0);
    }
    if (largest_unit <= ZTP_UNIT_HOUR) {
        ztp_i128_split(rest, 60, &rest, &r);
        minutes = (double)r;
    } else if (largest_unit == ZTP_UNIT_MINUTE) {
        minutes = ztp_i128_to_double(rest);
        rest = zuf_i128_from_i64(0);
    }
    if (date) {
        ztp_i128_split(rest, 24, &rest, &r);
        hours = (double)r;
        days = ztp_i128_to_double(rest);
    } else if (largest_unit == ZTP_UNIT_HOUR) {
        hours = ztp_i128_to_double(rest);
    }
    d.years = in->date.years;
    d.months = in->date.months;
    d.weeks = in->date.weeks;
    d.days = in->date.days + days * sign;
    d.hours = hours * sign;
    d.minutes = minutes * sign;
    d.seconds = seconds * sign;
    d.milliseconds = milliseconds * sign;
    d.microseconds = microseconds * sign;
    d.nanoseconds = nanoseconds * sign;
    return ztp_duration_create(ctx, index, &d, out);
}

/* --- rounding and totals ------------------------------------------------ */

typedef enum {
    ZTP_U_ZERO, ZTP_U_INFINITY, ZTP_U_HALF_ZERO, ZTP_U_HALF_INFINITY, ZTP_U_HALF_EVEN
} ztp_unsigned_mode128;

static ztp_unsigned_mode128 ztp_unsigned_mode_of(ztp_rounding_mode mode, bool negative)
{
    switch (mode) {
    case ZTP_ROUND_CEIL:        return negative ? ZTP_U_ZERO : ZTP_U_INFINITY;
    case ZTP_ROUND_FLOOR:       return negative ? ZTP_U_INFINITY : ZTP_U_ZERO;
    case ZTP_ROUND_EXPAND:      return ZTP_U_INFINITY;
    case ZTP_ROUND_TRUNC:       return ZTP_U_ZERO;
    case ZTP_ROUND_HALF_CEIL:   return negative ? ZTP_U_HALF_ZERO : ZTP_U_HALF_INFINITY;
    case ZTP_ROUND_HALF_FLOOR:  return negative ? ZTP_U_HALF_INFINITY : ZTP_U_HALF_ZERO;
    case ZTP_ROUND_HALF_EXPAND: return ZTP_U_HALF_INFINITY;
    case ZTP_ROUND_HALF_TRUNC:  return ZTP_U_HALF_ZERO;
    default:                    return ZTP_U_HALF_EVEN;
    }
}

zuf_i128 ztp_round_i128_to_increment(zuf_i128 x, zuf_i128 increment,
                                     ztp_rounding_mode mode, bool as_if_positive)
{
    zuf_i128 q, r, half_gap, rounded;
    bool negative, up;
    ztp_unsigned_mode128 umode;

    if (as_if_positive) {
        /* RoundNumberToIncrementAsIfPositive: the quotient is bracketed by
           its floor and the next integer, and "up" is toward positive
           infinity whatever the sign; the remainder of the floor division
           is in [0, increment). */
        zuf_i128_divmod_floor(x, increment, &q, &r);
        umode = ztp_unsigned_mode_of(mode, false);
    } else {
        /* RoundNumberToIncrement: on the magnitude, with the mode read for
           the sign. */
        negative = zuf_i128_is_neg(x);
        zuf_i128_divmod_trunc(ztp_i128_abs(x), increment, &q, &r);
        umode = ztp_unsigned_mode_of(mode, negative);
    }
    if (r.low == 0 && r.high == 0) {
        up = false;
    } else {
        switch (umode) {
        case ZTP_U_ZERO:     up = false; break;
        case ZTP_U_INFINITY: up = true; break;
        default: {
            /* Compare r with increment - r: below half rounds down, above
               rounds up, a tie follows the half mode. */
            int cmp;
            half_gap = zuf_i128_sub_wrap(increment, r);
            cmp = zuf_i128_cmp(r, half_gap);
            if (cmp < 0) up = false;
            else if (cmp > 0) up = true;
            else if (umode == ZTP_U_HALF_ZERO) up = false;
            else if (umode == ZTP_U_HALF_INFINITY) up = true;
            else up = (q.low & 1) != 0;
        }
        }
    }
    if (up) q = zuf_i128_add_wrap(q, zuf_i128_from_i64(1));
    rounded = zuf_i128_mul_wrap(q, increment);
    if (!as_if_positive && zuf_i128_is_neg(x)) zuf_i128_neg(rounded, &rounded);
    return rounded;
}

ztp_status ztp_time_duration_round(ztp_ctx *ctx, size_t index, zuf_i128 t,
                                   int64_t increment, ztp_unit unit,
                                   ztp_rounding_mode mode, zuf_i128 *out)
{
    zuf_i128 step = zuf_i128_mul_i64_i64(ztp_unit_length_ns(unit), increment);
    zuf_i128 rounded = ztp_round_i128_to_increment(t, step, mode, false);

    if (!ztp_time_duration_in_range(rounded))
        return ztp_fail(ctx, ZTP_ERR_RANGE, index,
                        "the rounded duration exceeds the representable range");
    *out = rounded;
    return ZTP_OK;
}

double ztp_time_duration_total(zuf_i128 t, ztp_unit unit)
{
    int64_t divisor = ztp_unit_length_ns(unit);
    zuf_i128 q;
    int64_t r;

    /* Integer part exactly, then the remainder as a fraction: the sum is
       one rounding away from the exact quotient when the integer part is
       a safe integer. */
    zuf_i128_divmod_trunc_i64(t, divisor, &q, &r);
    return ztp_i128_to_double(q) + (double)r / (double)divisor;
}

/* --- strings ------------------------------------------------------------ */

typedef struct {
    const unsigned char *s;
    size_t n, pos;
    size_t fail_pos;
    const char *reason;
} ztp_dcursor;

static bool ztp_dfail(ztp_dcursor *c, size_t pos, const char *reason)
{
    c->fail_pos = pos;
    c->reason = reason;
    return false;
}

static int ztp_dpeek(const ztp_dcursor *c)
{
    return c->pos < c->n ? c->s[c->pos] : -1;
}

/* DecimalDigits as a double, exactly while it fits; more than 20 digits
   can only be out of range, which the validity check reports. */
static bool ztp_dparse_digits(ztp_dcursor *c, double *out, bool *present)
{
    double v = 0;
    size_t k = 0;

    *present = false;
    while (ztp_dpeek(c) >= '0' && ztp_dpeek(c) <= '9') {
        if (k < 20) v = v * 10 + (ztp_dpeek(c) - '0');
        else v = HUGE_VAL;
        k++;
        c->pos++;
    }
    if (k == 0) return true;
    *present = true;
    *out = v;
    return true;
}

/* TemporalDecimalFraction: "." or "," and one to nine digits, as a count
   of billionths. */
static bool ztp_dparse_fraction(ztp_dcursor *c, int64_t *billionths, bool *present)
{
    int ch = ztp_dpeek(c);
    int64_t v = 0;
    unsigned k = 0;

    *present = false;
    if (ch != '.' && ch != ',') return true;
    c->pos++;
    while (ztp_dpeek(c) >= '0' && ztp_dpeek(c) <= '9') {
        if (k == 9) return ztp_dfail(c, c->pos, "more than nine fraction digits");
        v = v * 10 + (ztp_dpeek(c) - '0');
        k++;
        c->pos++;
    }
    if (k == 0) return ztp_dfail(c, c->pos, "expected digits after the decimal mark");
    while (k++ < 9) v *= 10;
    *billionths = v;
    *present = true;
    return true;
}

static bool ztp_designator(int ch, char upper)
{
    return ch == upper || ch == upper + ('a' - 'A');
}

ztp_status ztp_duration_parse(ztp_ctx *ctx, size_t index, const char *s,
                              size_t n, ztp_duration *out, size_t *position)
{
    ztp_dcursor c = {(const unsigned char *)s, n, 0, 0, NULL};
    int factor = 1;
    double years = 0, months = 0, weeks = 0, days = 0, hours = 0, minutes = 0,
           seconds = 0;
    int64_t frac = 0;            /* billionths of the unit it follows */
    ztp_unit frac_unit = ZTP_UNIT_NANOSECOND;   /* hour, minute or second */
    bool any = false, present, fpresent;
    /* Which date designators may still follow: Y, M, W, D in order. */
    int date_stage = 0;
    bool ok = true;
    ztp_duration d;

    if (ztp_dpeek(&c) == '+' || ztp_dpeek(&c) == '-') {
        if (c.s[c.pos] == '-') factor = -1;
        c.pos++;
    }
    if (!ztp_designator(ztp_dpeek(&c), 'P')) {
        ok = ztp_dfail(&c, c.pos, "expected 'P'");
        goto done;
    }
    c.pos++;
    /* Date part. */
    while (ok && ztp_dpeek(&c) >= '0' && ztp_dpeek(&c) <= '9') {
        double v;
        size_t at = c.pos;
        int ch;

        ztp_dparse_digits(&c, &v, &present);
        ch = ztp_dpeek(&c);
        if (ch == '.' || ch == ',') {
            ok = ztp_dfail(&c, c.pos, "a date unit cannot have a fraction");
            break;
        }
        if (ztp_designator(ch, 'Y') && date_stage < 1) {
            years = v;
            date_stage = 1;
        } else if (ztp_designator(ch, 'M') && date_stage < 2) {
            months = v;
            date_stage = 2;
        } else if (ztp_designator(ch, 'W') && date_stage < 3) {
            weeks = v;
            date_stage = 3;
        } else if (ztp_designator(ch, 'D') && date_stage < 4) {
            days = v;
            date_stage = 4;
        } else {
            ok = ztp_dfail(&c, ch < 0 ? c.pos : at, "expected a duration designator");
            break;
        }
        any = true;
        c.pos++;
    }
    /* Time part. */
    if (ok && ztp_designator(ztp_dpeek(&c), 'T')) {
        int time_stage = 0;   /* H, M, S in order */
        bool time_any = false;

        c.pos++;
        while (ok && ztp_dpeek(&c) >= '0' && ztp_dpeek(&c) <= '9') {
            double v;
            size_t at = c.pos;
            int ch;

            ztp_dparse_digits(&c, &v, &present);
            if (!ztp_dparse_fraction(&c, &frac, &fpresent)) {
                ok = false;
                break;
            }
            ch = ztp_dpeek(&c);
            if (ztp_designator(ch, 'H') && time_stage < 1) {
                hours = v;
                time_stage = 1;
                if (fpresent) frac_unit = ZTP_UNIT_HOUR;
            } else if (ztp_designator(ch, 'M') && time_stage < 2) {
                minutes = v;
                time_stage = 2;
                if (fpresent) frac_unit = ZTP_UNIT_MINUTE;
            } else if (ztp_designator(ch, 'S') && time_stage < 3) {
                seconds = v;
                time_stage = 3;
                if (fpresent) frac_unit = ZTP_UNIT_SECOND;
            } else {
                ok = ztp_dfail(&c, ch < 0 ? c.pos : at, "expected a time designator");
                break;
            }
            c.pos++;
            time_any = true;
            any = true;
            /* A fraction ends the string: only the smallest unit present
               may have one. */
            if (fpresent && c.pos < c.n) {
                ok = ztp_dfail(&c, c.pos, "only the last unit may have a fraction");
                break;
            }
        }
        if (ok && !time_any) ok = ztp_dfail(&c, c.pos, "expected a time unit after 'T'");
    }
    if (ok && !any) ok = ztp_dfail(&c, c.pos, "expected at least one unit");
    if (ok && c.pos < c.n) ok = ztp_dfail(&c, c.pos, "unexpected character");

done:
    if (!ok) {
        char shown[41];
        size_t k = n <= 40 ? n : ztp_utf8_prefix(s, n, 37);
        if (position) *position = c.fail_pos;
        memcpy(shown, s, k);
        if (n > 40) memcpy(shown + k, "...", 3), k += 3;
        shown[k] = '\0';
        ztp_fail(ctx, ZTP_ERR_PARSE, index,
                 "cannot parse \"%s\" as a duration: %s at byte %lu", shown,
                 c.reason ? c.reason : "invalid", (unsigned long)(c.fail_pos + 1));
        ctx->position = c.fail_pos + 1;
        return ZTP_ERR_PARSE;
    }
    if (position) *position = 0;
    /* The fraction of an hour or minute becomes the smaller units, as the
       specification's chain of remainders does: billionths of the unit
       times its length in nanoseconds, split from the top. */
    {
        int64_t frac_ns = 0;
        int64_t ms = 0, us = 0, ns = 0;
        double fminutes = 0, fseconds = 0;

        if (frac_unit == ZTP_UNIT_HOUR) frac_ns = frac * 3600;
        else if (frac_unit == ZTP_UNIT_MINUTE) frac_ns = frac * 60;
        else if (frac_unit == ZTP_UNIT_SECOND) frac_ns = frac;
        if (frac_unit == ZTP_UNIT_HOUR) {
            fminutes = (double)(frac_ns / ZTP_NS_PER_MINUTE);
            frac_ns %= ZTP_NS_PER_MINUTE;
        }
        if (frac_unit == ZTP_UNIT_HOUR || frac_unit == ZTP_UNIT_MINUTE) {
            fseconds = (double)(frac_ns / ZTP_NS_PER_SECOND);
            frac_ns %= ZTP_NS_PER_SECOND;
        }
        ms = frac_ns / 1000000;
        us = (frac_ns / 1000) % 1000;
        ns = frac_ns % 1000;
        d.years = years * factor;
        d.months = months * factor;
        d.weeks = weeks * factor;
        d.days = days * factor;
        d.hours = hours * factor;
        d.minutes = (minutes + fminutes) * factor;
        d.seconds = (seconds + fseconds) * factor;
        d.milliseconds = (double)ms * factor;
        d.microseconds = (double)us * factor;
        d.nanoseconds = (double)ns * factor;
    }
    return ztp_duration_create(ctx, index, &d, out);
}

static char *ztp_put_decimal(char *dst, double v)
{
    /* Integral doubles up to 2^64 print exactly through a u128 writer. */
    zuf_i128 w;
    char *end;

    if (!ztp_i128_from_double(fabs(v), &w)) {
        int k = snprintf(dst, 32, "%.0f", fabs(v));
        return dst + k;
    }
    end = zuf_write_i128(dst, w);
    return end;
}

size_t ztp_duration_format(char *dst, const ztp_duration *d, int precision)
{
    char *p = dst;
    bool time_part = false;
    zuf_i128 secs_ns;
    bool zero_minutes_and_higher = ztp_duration_default_largest_unit(d) >= ZTP_UNIT_SECOND;

    if (ztp_duration_sign(d) < 0) *p++ = '-';
    *p++ = 'P';
    if (d->years != 0) { p = ztp_put_decimal(p, d->years); *p++ = 'Y'; }
    if (d->months != 0) { p = ztp_put_decimal(p, d->months); *p++ = 'M'; }
    if (d->weeks != 0) { p = ztp_put_decimal(p, d->weeks); *p++ = 'W'; }
    if (d->days != 0) { p = ztp_put_decimal(p, d->days); *p++ = 'D'; }
    {
        char *time_start = p;
        *p++ = 'T';
        if (d->hours != 0) { p = ztp_put_decimal(p, d->hours); *p++ = 'H'; time_part = true; }
        if (d->minutes != 0) { p = ztp_put_decimal(p, d->minutes); *p++ = 'M'; time_part = true; }
        secs_ns = ztp_time_duration_from_components(0, 0, d->seconds, d->milliseconds,
                                                    d->microseconds, d->nanoseconds);
        if (ztp_time_duration_sign(secs_ns) != 0 || zero_minutes_and_higher ||
            precision != ZTP_PRECISION_AUTO) {
            zuf_i128 whole, mag = ztp_i128_abs(secs_ns);
            int64_t sub;
            zuf_i128_divmod_trunc_i64(mag, ZTP_NS_PER_SECOND, &whole, &sub);
            p = zuf_write_i128(p, whole);
            if (precision == ZTP_PRECISION_AUTO ? sub != 0 : precision > 0) {
                char digits[9];
                int k = precision == ZTP_PRECISION_AUTO ? 9 : precision;
                uint64_t v = (uint64_t)sub;
                for (int i = 9; i > 0; i--) { digits[i - 1] = (char)('0' + v % 10); v /= 10; }
                if (precision == ZTP_PRECISION_AUTO)
                    while (k > 0 && digits[k - 1] == '0') k--;
                *p++ = '.';
                memcpy(p, digits, (size_t)k);
                p += k;
            }
            *p++ = 'S';
            time_part = true;
        }
        if (!time_part) p = time_start;
    }
    *p = '\0';
    return (size_t)(p - dst);
}
