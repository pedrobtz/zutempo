/* ztp_relative.c -- see ztp_relative.h. Engine side: no R. */

#include "ztp_relative.h"

#include <math.h>
#include <string.h>

static int64_t ztp_floor_div64(int64_t a, int64_t b)
{
    int64_t q = a / b;
    return (a % b != 0 && ((a < 0) != (b < 0))) ? q - 1 : q;
}

/* BalanceISOYearMonth over int64. */
static void ztp_balance_year_month(int64_t *year, int64_t *month)
{
    int64_t m0 = *month - 1;
    *year += ztp_floor_div64(m0, 12);
    *month = m0 - ztp_floor_div64(m0, 12) * 12 + 1;
}

ztp_status ztp_calendar_date_add(ztp_ctx *ctx, size_t index, int32_t epoch_day,
                                 const ztp_date_duration *duration,
                                 ztp_overflow overflow, int32_t *out)
{
    ztp_iso_date d, intermediate;
    int64_t year, month, days;

    ztp_iso_date_from_epoch_day(epoch_day, &d);
    year = (int64_t)d.year + (int64_t)duration->years;
    month = (int64_t)d.month + (int64_t)duration->months;
    ztp_balance_year_month(&year, &month);
    if (ztp_regulate_iso_date(ctx, index, year, month, d.day, overflow, &intermediate) != ZTP_OK)
        return ctx->status;
    days = (int64_t)ztp_epoch_day_from_iso_date(&intermediate) +
           (int64_t)duration->days + 7 * (int64_t)duration->weeks;
    if (!ztp_iso_date_within_limits(days))
        return ztp_fail(ctx, ZTP_ERR_RANGE, index,
                        "the result is outside the range of a PlainDate");
    *out = (int32_t)days;
    return ZTP_OK;
}

/* CompareSurpasses with integer months. */
static bool ztp_compare_surpasses(int sign, int64_t year, int64_t month,
                                  int64_t day, const ztp_iso_date *target)
{
    if (year != target->year) return sign * (year - target->year) > 0;
    if (month != (int64_t)target->month) return sign * (month - (int64_t)target->month) > 0;
    if (day != (int64_t)target->day) return sign * (day - (int64_t)target->day) > 0;
    return false;
}

/* ISODateSurpasses. */
static bool ztp_iso_date_surpasses(int sign, const ztp_iso_date *base,
                                   const ztp_iso_date *target, int64_t years,
                                   int64_t months, int64_t weeks, int64_t days)
{
    int64_t y0 = (int64_t)base->year + years, m0, y1;
    ztp_ctx scratch;
    ztp_iso_date regulated;
    int64_t balanced_day;
    ztp_iso_date balanced;

    if (ztp_compare_surpasses(sign, y0, base->month, base->day, target)) return true;
    /* The pinned text reads "If months = 0, return false" here, which would
       leave the day loop of CalendarDateUntil without an exit when no
       months are added. With months = 0 the comparison below repeats the
       one above, so going on is equivalent for every other input. */
    y1 = y0;
    m0 = (int64_t)base->month + months;
    ztp_balance_year_month(&y1, &m0);
    if (ztp_compare_surpasses(sign, y1, m0, base->day, target)) return true;
    if (weeks == 0 && days == 0) return false;
    ztp_ctx_init(&scratch);
    ztp_regulate_iso_date(&scratch, 0, y1, m0, base->day, ZTP_OVERFLOW_CONSTRAIN, &regulated);
    balanced_day = (int64_t)ztp_epoch_day_from_iso_date(&regulated) + 7 * weeks + days;
    ztp_iso_date_from_epoch_day((int32_t)balanced_day, &balanced);
    return ztp_compare_surpasses(sign, balanced.year, balanced.month, balanced.day, target);
}

/* The largest k >= 0 for which adding sign * k units does not surpass the
   target, found from a guess: the predicate is monotone in k. */
typedef struct {
    int sign;
    const ztp_iso_date *base, *target;
    int64_t years, months, weeks;
    int which;   /* 0 years, 1 months, 2 weeks, 3 days */
} ztp_until_probe;

static bool ztp_probe_surpasses(const ztp_until_probe *p, int64_t k)
{
    int64_t v = p->sign * k;
    switch (p->which) {
    case 0:  return ztp_iso_date_surpasses(p->sign, p->base, p->target, v, 0, 0, 0);
    case 1:  return ztp_iso_date_surpasses(p->sign, p->base, p->target, p->years, v, 0, 0);
    case 2:  return ztp_iso_date_surpasses(p->sign, p->base, p->target, p->years, p->months, v, 0);
    default: return ztp_iso_date_surpasses(p->sign, p->base, p->target, p->years, p->months, p->weeks, v);
    }
}

static int64_t ztp_largest_not_surpassing(const ztp_until_probe *p, int64_t guess)
{
    int64_t k = guess < 0 ? 0 : guess;

    while (k > 0 && ztp_probe_surpasses(p, k)) k--;
    while (!ztp_probe_surpasses(p, k + 1)) k++;
    return k;
}

void ztp_calendar_date_until(int32_t one, int32_t two, ztp_unit largest_unit,
                             ztp_date_duration *out)
{
    ztp_iso_date base, target;
    ztp_until_probe p;
    int sign;
    int64_t years = 0, months = 0, weeks = 0, days;

    memset(out, 0, sizeof *out);
    if (one == two) return;
    sign = two > one ? 1 : -1;
    ztp_iso_date_from_epoch_day(one, &base);
    ztp_iso_date_from_epoch_day(two, &target);
    p.sign = sign;
    p.base = &base;
    p.target = &target;
    if (largest_unit == ZTP_UNIT_YEAR) {
        p.which = 0;
        years = ztp_largest_not_surpassing(&p, sign * ((int64_t)target.year - base.year));
    }
    p.years = sign * years;
    if (largest_unit == ZTP_UNIT_YEAR || largest_unit == ZTP_UNIT_MONTH) {
        int64_t guess = sign * (((int64_t)target.year - base.year - sign * years) * 12 +
                                ((int64_t)target.month - base.month));
        p.which = 1;
        months = ztp_largest_not_surpassing(&p, guess);
    }
    p.months = sign * months;
    {
        /* The date after the years and months, for the day count. */
        int64_t y = (int64_t)base.year + p.years, m = (int64_t)base.month + p.months;
        ztp_iso_date regulated;
        ztp_ctx scratch;
        int64_t remaining;

        ztp_balance_year_month(&y, &m);
        ztp_ctx_init(&scratch);
        ztp_regulate_iso_date(&scratch, 0, y, m, base.day, ZTP_OVERFLOW_CONSTRAIN, &regulated);
        remaining = sign * ((int64_t)two - ztp_epoch_day_from_iso_date(&regulated));
        if (largest_unit == ZTP_UNIT_WEEK) {
            p.which = 2;
            weeks = ztp_largest_not_surpassing(&p, remaining / 7);
        }
        p.weeks = sign * weeks;
        p.which = 3;
        days = ztp_largest_not_surpassing(&p, remaining - 7 * weeks);
    }
    out->years = (double)(sign * years);
    out->months = (double)(sign * months);
    out->weeks = (double)(sign * weeks);
    out->days = (double)(sign * days);
}

void ztp_add_time(int64_t ns_of_day, zuf_i128 duration, int64_t *out_ns,
                  int64_t *out_days)
{
    zuf_i128 total = zuf_i128_add_wrap(zuf_i128_from_i64(ns_of_day), duration);
    zuf_i128 q;
    int64_t r;

    zuf_i128_divmod_floor_i64(total, ZTP_NS_PER_DAY, &q, &r);
    zuf_i128_to_i64(q, out_days);
    *out_ns = r;
}

zuf_i128 ztp_epoch_ns_of(int32_t epoch_day, int64_t ns_of_day)
{
    return zuf_i128_add_wrap(zuf_i128_mul_i64_i64(epoch_day, ZTP_NS_PER_DAY),
                             zuf_i128_from_i64(ns_of_day));
}

void ztp_difference_iso_date_time(int32_t day1, int64_t ns1, int32_t day2,
                                  int64_t ns2, ztp_unit largest_unit,
                                  ztp_internal_duration *out)
{
    int64_t time = ns2 - ns1;
    int time_sign = time < 0 ? -1 : (time > 0 ? 1 : 0);
    int date_sign = day1 < day2 ? -1 : (day1 > day2 ? 1 : 0);
    int32_t adjusted = day2;
    ztp_unit date_largest = largest_unit < ZTP_UNIT_DAY ? largest_unit : ZTP_UNIT_DAY;

    if (time_sign == date_sign && time_sign != 0) {
        adjusted = (int32_t)(adjusted + time_sign);
        time -= (int64_t)time_sign * ZTP_NS_PER_DAY;
    }
    ztp_calendar_date_until(day1, adjusted, date_largest, &out->date);
    out->time = zuf_i128_from_i64(time);
    if (largest_unit != date_largest) {
        zuf_i128 days;
        ztp_i128_from_double(out->date.days, &days);
        out->time = zuf_i128_add_wrap(out->time,
                                      zuf_i128_mul_wrap(days, zuf_i128_from_i64(ZTP_NS_PER_DAY)));
        out->date.days = 0;
    }
}

/* --- relative rounding -------------------------------------------------- */

typedef struct {
    double r1, r2;
    zuf_i128 start_ns, end_ns;
    ztp_date_duration start_dur, end_dur;
} ztp_nudge_window;

static double ztp_round_double_trunc(double x, int64_t increment)
{
    return trunc(x / (double)increment) * (double)increment;
}

static ztp_status ztp_epoch_after(ztp_ctx *ctx, size_t index, int32_t origin_day,
                                  int64_t origin_ns, const ztp_date_duration *dd,
                                  zuf_i128 *out)
{
    int32_t day;
    if (ztp_calendar_date_add(ctx, index, origin_day, dd, ZTP_OVERFLOW_CONSTRAIN, &day) != ZTP_OK)
        return ctx->status;
    *out = ztp_epoch_ns_of(day, origin_ns);
    return ZTP_OK;
}

static ztp_status ztp_check_date_duration(ztp_ctx *ctx, size_t index,
                                          const ztp_date_duration *dd)
{
    ztp_duration d = {dd->years, dd->months, dd->weeks, dd->days, 0, 0, 0, 0, 0, 0};
    if (!ztp_duration_is_valid(&d))
        return ztp_fail(ctx, ZTP_ERR_RANGE, index,
                        "the duration exceeds the representable range");
    return ZTP_OK;
}

/* ComputeNudgeWindow. */
static ztp_status ztp_compute_nudge_window(ztp_ctx *ctx, size_t index, int sign,
                                           const ztp_internal_duration *dur,
                                           int32_t origin_day, int64_t origin_ns,
                                           int64_t increment, ztp_unit unit,
                                           bool additional_shift,
                                           ztp_nudge_window *w)
{
    const ztp_date_duration *d = &dur->date;

    switch (unit) {
    case ZTP_UNIT_YEAR: {
        double years = ztp_round_double_trunc(d->years, increment);
        w->r1 = additional_shift ? years + increment * sign : years;
        w->r2 = w->r1 + increment * sign;
        w->start_dur = (ztp_date_duration){w->r1, 0, 0, 0};
        w->end_dur = (ztp_date_duration){w->r2, 0, 0, 0};
        break;
    }
    case ZTP_UNIT_MONTH: {
        double months = ztp_round_double_trunc(d->months, increment);
        w->r1 = additional_shift ? months + increment * sign : months;
        w->r2 = w->r1 + increment * sign;
        w->start_dur = (ztp_date_duration){d->years, w->r1, 0, 0};
        w->end_dur = (ztp_date_duration){d->years, w->r2, 0, 0};
        break;
    }
    case ZTP_UNIT_WEEK: {
        ztp_date_duration years_months = {d->years, d->months, 0, 0};
        int32_t weeks_start;
        int64_t weeks_end;
        ztp_date_duration until;
        double weeks;

        if (ztp_calendar_date_add(ctx, index, origin_day, &years_months,
                                  ZTP_OVERFLOW_CONSTRAIN, &weeks_start) != ZTP_OK)
            return ctx->status;
        weeks_end = (int64_t)weeks_start + (int64_t)d->days;
        ztp_calendar_date_until(weeks_start, (int32_t)weeks_end, ZTP_UNIT_WEEK, &until);
        weeks = ztp_round_double_trunc(d->weeks + until.weeks, increment);
        w->r1 = weeks;
        w->r2 = weeks + increment * sign;
        w->start_dur = (ztp_date_duration){d->years, d->months, w->r1, 0};
        w->end_dur = (ztp_date_duration){d->years, d->months, w->r2, 0};
        break;
    }
    default: {
        double days = ztp_round_double_trunc(d->days, increment);
        w->r1 = days;
        w->r2 = days + increment * sign;
        w->start_dur = (ztp_date_duration){d->years, d->months, d->weeks, w->r1};
        w->end_dur = (ztp_date_duration){d->years, d->months, d->weeks, w->r2};
        break;
    }
    }
    if (ztp_check_date_duration(ctx, index, &w->start_dur) != ZTP_OK ||
        ztp_check_date_duration(ctx, index, &w->end_dur) != ZTP_OK)
        return ctx->status;
    /* The pinned text takes the origin itself when r1 is 0, which ignores
       the larger units kept in the start duration (P1Y rounded to months
       would start from the origin rather than a year later). Adding the
       start duration is the same thing when it is zero and right
       otherwise, and it is what the reference engines compute. */
    if (ztp_epoch_after(ctx, index, origin_day, origin_ns, &w->start_dur, &w->start_ns) != ZTP_OK)
        return ctx->status;
    return ztp_epoch_after(ctx, index, origin_day, origin_ns, &w->end_dur, &w->end_ns);
}

typedef struct {
    ztp_internal_duration duration;
    zuf_i128 nudged_ns;
    bool did_expand;
    double total;
} ztp_nudge_result;

static bool ztp_between(zuf_i128 lo, zuf_i128 x, zuf_i128 hi)
{
    return zuf_i128_cmp(lo, x) <= 0 && zuf_i128_cmp(x, hi) <= 0;
}

/* NudgeToCalendarUnit, with the rounding decision taken on exact
   differences rather than on the floating-point progress. */
static ztp_status ztp_nudge_to_calendar_unit(ztp_ctx *ctx, size_t index, int sign,
                                             const ztp_internal_duration *dur,
                                             int32_t origin_day, int64_t origin_ns,
                                             zuf_i128 dest_ns, int64_t increment,
                                             ztp_unit unit, ztp_rounding_mode mode,
                                             ztp_nudge_result *res)
{
    ztp_nudge_window w;
    bool did_expand = false, in_window, round_up;
    zuf_i128 d1, d2;
    int cmp;

    if (ztp_compute_nudge_window(ctx, index, sign, dur, origin_day, origin_ns,
                                 increment, unit, false, &w) != ZTP_OK)
        return ctx->status;
    in_window = sign == 1 ? ztp_between(w.start_ns, dest_ns, w.end_ns)
                          : ztp_between(w.end_ns, dest_ns, w.start_ns);
    if (!in_window) {
        if (ztp_compute_nudge_window(ctx, index, sign, dur, origin_day, origin_ns,
                                     increment, unit, true, &w) != ZTP_OK)
            return ctx->status;
        did_expand = true;
    }
    /* |dest - start| and |end - dest|: progress is d1 / (d1 + d2). */
    d1 = ztp_i128_abs(zuf_i128_sub_wrap(dest_ns, w.start_ns));
    d2 = ztp_i128_abs(zuf_i128_sub_wrap(w.end_ns, dest_ns));
    res->total = w.r1 + ztp_i128_to_double(d1) /
                            ztp_i128_to_double(zuf_i128_add_wrap(d1, d2)) *
                            (double)increment * sign;
    if (d2.low == 0 && d2.high == 0) {
        round_up = true;              /* progress = 1 */
    } else if (d1.low == 0 && d1.high == 0) {
        round_up = false;             /* x = r1 */
    } else {
        /* ApplyUnsignedRoundingMode on |total| between |r1| and |r2|, with
           the half comparison done on d1 against d2. */
        bool negative = sign < 0;
        switch (mode) {
        case ZTP_ROUND_CEIL:        round_up = !negative; break;
        case ZTP_ROUND_FLOOR:       round_up = negative; break;
        case ZTP_ROUND_EXPAND:      round_up = true; break;
        case ZTP_ROUND_TRUNC:       round_up = false; break;
        default:
            cmp = zuf_i128_cmp(d1, d2);
            if (cmp < 0) round_up = false;
            else if (cmp > 0) round_up = true;
            else if (mode == ZTP_ROUND_HALF_CEIL) round_up = !negative;
            else if (mode == ZTP_ROUND_HALF_FLOOR) round_up = negative;
            else if (mode == ZTP_ROUND_HALF_EXPAND) round_up = true;
            else if (mode == ZTP_ROUND_HALF_TRUNC) round_up = false;
            else round_up = fmod(fabs(w.r1) / (double)increment, 2.0) != 0.0;  /* half-even */
            break;
        }
    }
    if (round_up) {
        did_expand = true;
        res->duration.date = w.end_dur;
        res->nudged_ns = w.end_ns;
    } else {
        res->duration.date = w.start_dur;
        res->nudged_ns = w.start_ns;
    }
    res->duration.time = zuf_i128_from_i64(0);
    res->did_expand = did_expand;
    return ZTP_OK;
}

/* NudgeToDayOrTime. */
static ztp_status ztp_nudge_to_day_or_time(ztp_ctx *ctx, size_t index,
                                           const ztp_internal_duration *dur,
                                           zuf_i128 dest_ns, ztp_unit largest_unit,
                                           int64_t increment, ztp_unit smallest_unit,
                                           ztp_rounding_mode mode,
                                           ztp_nudge_result *res)
{
    zuf_i128 time, rounded, diff, whole_days, rounded_whole_days, remainder;
    zuf_i128 step = zuf_i128_mul_i64_i64(ztp_unit_length_ns(smallest_unit), increment);
    int64_t r, wd, rwd, day_delta;
    int day_delta_sign;

    if (ztp_time_duration_add_days(ctx, index, dur->time, dur->date.days, &time) != ZTP_OK)
        return ctx->status;
    rounded = ztp_round_i128_to_increment(time, step, mode, false);
    if (!ztp_time_duration_in_range(rounded))
        return ztp_fail(ctx, ZTP_ERR_RANGE, index,
                        "the rounded duration exceeds the representable range");
    diff = zuf_i128_sub_wrap(rounded, time);
    zuf_i128_divmod_trunc_i64(time, ZTP_NS_PER_DAY, &whole_days, &r);
    zuf_i128_divmod_trunc_i64(rounded, ZTP_NS_PER_DAY, &rounded_whole_days, &r);
    zuf_i128_to_i64(whole_days, &wd);
    zuf_i128_to_i64(rounded_whole_days, &rwd);
    day_delta = rwd - wd;
    day_delta_sign = day_delta < 0 ? -1 : (day_delta > 0 ? 1 : 0);
    res->did_expand = day_delta_sign == ztp_time_duration_sign(time);
    res->nudged_ns = zuf_i128_add_wrap(dest_ns, diff);
    res->duration.date = dur->date;
    res->duration.date.days = 0;
    remainder = rounded;
    if (largest_unit <= ZTP_UNIT_DAY) {
        res->duration.date.days = (double)rwd;
        remainder = zuf_i128_sub_wrap(rounded, zuf_i128_mul_i64_i64(rwd, ZTP_NS_PER_DAY));
    }
    res->duration.time = remainder;
    res->total = 0;
    return ZTP_OK;
}

/* BubbleRelativeDuration. */
static ztp_status ztp_bubble_relative_duration(ztp_ctx *ctx, size_t index, int sign,
                                               ztp_internal_duration *dur,
                                               zuf_i128 nudged_ns, int32_t origin_day,
                                               int64_t origin_ns, ztp_unit largest_unit,
                                               ztp_unit smallest_unit)
{
    int unit_index;

    if (smallest_unit == largest_unit) return ZTP_OK;
    for (unit_index = (int)smallest_unit - 1; unit_index >= (int)largest_unit; unit_index--) {
        ztp_unit unit = (ztp_unit)unit_index;
        ztp_date_duration end_dur;
        zuf_i128 end_ns, beyond;
        int beyond_sign;

        if (unit == ZTP_UNIT_WEEK && largest_unit != ZTP_UNIT_WEEK) continue;
        if (unit == ZTP_UNIT_YEAR) {
            end_dur = (ztp_date_duration){dur->date.years + sign, 0, 0, 0};
        } else if (unit == ZTP_UNIT_MONTH) {
            end_dur = (ztp_date_duration){dur->date.years, dur->date.months + sign, 0, 0};
        } else {
            end_dur = (ztp_date_duration){dur->date.years, dur->date.months,
                                          dur->date.weeks + sign, 0};
        }
        if (ztp_check_date_duration(ctx, index, &end_dur) != ZTP_OK) return ctx->status;
        if (ztp_epoch_after(ctx, index, origin_day, origin_ns, &end_dur, &end_ns) != ZTP_OK)
            return ctx->status;
        beyond = zuf_i128_sub_wrap(nudged_ns, end_ns);
        beyond_sign = ztp_time_duration_sign(beyond);
        if (beyond_sign != -sign) {
            dur->date = end_dur;
            dur->time = zuf_i128_from_i64(0);
        } else {
            break;
        }
    }
    return ZTP_OK;
}

static int ztp_internal_sign(const ztp_internal_duration *d)
{
    int s = ztp_date_duration_sign(&d->date);
    return s != 0 ? s : ztp_time_duration_sign(d->time);
}

ztp_status ztp_round_relative_duration(ztp_ctx *ctx, size_t index,
                                       const ztp_internal_duration *duration,
                                       int32_t origin_day, int64_t origin_ns,
                                       int32_t dest_day, int64_t dest_ns,
                                       ztp_unit largest_unit, int64_t increment,
                                       ztp_unit smallest_unit,
                                       ztp_rounding_mode mode,
                                       ztp_internal_duration *out)
{
    zuf_i128 dest = ztp_epoch_ns_of(dest_day, dest_ns);
    int sign = ztp_internal_sign(duration) < 0 ? -1 : 1;
    ztp_nudge_result res;

    if (smallest_unit <= ZTP_UNIT_WEEK) {
        if (ztp_nudge_to_calendar_unit(ctx, index, sign, duration, origin_day, origin_ns,
                                       dest, increment, smallest_unit, mode, &res) != ZTP_OK)
            return ctx->status;
    } else if (ztp_nudge_to_day_or_time(ctx, index, duration, dest, largest_unit,
                                        increment, smallest_unit, mode, &res) != ZTP_OK) {
        return ctx->status;
    }
    *out = res.duration;
    if (res.did_expand && smallest_unit != ZTP_UNIT_WEEK) {
        ztp_unit start_unit = smallest_unit < ZTP_UNIT_DAY ? smallest_unit : ZTP_UNIT_DAY;
        if (ztp_bubble_relative_duration(ctx, index, sign, out, res.nudged_ns, origin_day,
                                         origin_ns, largest_unit, start_unit) != ZTP_OK)
            return ctx->status;
    }
    return ZTP_OK;
}

ztp_status ztp_total_relative_duration(ztp_ctx *ctx, size_t index,
                                       const ztp_internal_duration *duration,
                                       int32_t origin_day, int64_t origin_ns,
                                       int32_t dest_day, int64_t dest_ns,
                                       ztp_unit unit, double *out)
{
    if (unit <= ZTP_UNIT_WEEK) {
        int sign = ztp_internal_sign(duration) < 0 ? -1 : 1;
        ztp_nudge_result res;
        if (ztp_nudge_to_calendar_unit(ctx, index, sign, duration, origin_day, origin_ns,
                                       ztp_epoch_ns_of(dest_day, dest_ns), 1, unit,
                                       ZTP_ROUND_TRUNC, &res) != ZTP_OK)
            return ctx->status;
        *out = res.total;
        return ZTP_OK;
    }
    {
        zuf_i128 time;
        if (ztp_time_duration_add_days(ctx, index, duration->time, duration->date.days, &time) != ZTP_OK)
            return ctx->status;
        *out = ztp_time_duration_total(time, unit);
        return ZTP_OK;
    }
}

ztp_status ztp_difference_plain_date_time_rounded(
    ztp_ctx *ctx, size_t index, int32_t day1, int64_t ns1, int32_t day2,
    int64_t ns2, ztp_unit largest_unit, int64_t increment,
    ztp_unit smallest_unit, ztp_rounding_mode mode, ztp_internal_duration *out)
{
    ztp_internal_duration diff;

    if (day1 == day2 && ns1 == ns2) {
        memset(out, 0, sizeof *out);
        out->time = zuf_i128_from_i64(0);
        return ZTP_OK;
    }
    if (!ztp_iso_date_time_within_limits(day1, ns1) || !ztp_iso_date_time_within_limits(day2, ns2))
        return ztp_fail(ctx, ZTP_ERR_RANGE, index,
                        "a date-time is outside the range of a PlainDateTime");
    ztp_difference_iso_date_time(day1, ns1, day2, ns2, largest_unit, &diff);
    if (smallest_unit == ZTP_UNIT_NANOSECOND && increment == 1) {
        *out = diff;
        return ZTP_OK;
    }
    return ztp_round_relative_duration(ctx, index, &diff, day1, ns1, day2, ns2, largest_unit,
                                       increment, smallest_unit, mode, out);
}

ztp_status ztp_difference_plain_date_time_total(ztp_ctx *ctx, size_t index,
                                                int32_t day1, int64_t ns1,
                                                int32_t day2, int64_t ns2,
                                                ztp_unit unit, double *out)
{
    ztp_internal_duration diff;

    if (day1 == day2 && ns1 == ns2) {
        *out = 0;
        return ZTP_OK;
    }
    if (!ztp_iso_date_time_within_limits(day1, ns1) || !ztp_iso_date_time_within_limits(day2, ns2))
        return ztp_fail(ctx, ZTP_ERR_RANGE, index,
                        "a date-time is outside the range of a PlainDateTime");
    ztp_difference_iso_date_time(day1, ns1, day2, ns2, unit, &diff);
    if (unit == ZTP_UNIT_NANOSECOND) {
        *out = ztp_i128_to_double(diff.time);
        return ZTP_OK;
    }
    return ztp_total_relative_duration(ctx, index, &diff, day1, ns1, day2, ns2, unit, out);
}
