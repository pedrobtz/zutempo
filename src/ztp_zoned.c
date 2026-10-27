/* ztp_zoned.c -- see ztp_zoned.h. Section numbers are the pinned
   proposal-temporal's. */

#include "ztp_zoned.h"
#include "ztp_tz.h"
#include "ztp_relative.h"
#include "ztp_format.h"
#include "ztp_round.h"

#include <string.h>

/* A local day the int32 arithmetic below can take; the candidates it
   yields are range-checked on their own. */
static bool ztp_zoned_day_ok(int64_t day)
{
    return day >= -ZTP_MAX_EPOCH_DAY - 2 && day <= ZTP_MAX_EPOCH_DAY + 2;
}

/* CheckISODaysRange: abs(epoch days) <= 10^8. */
static bool ztp_zoned_days_in_range(int64_t day)
{
    return day >= -ZTP_MAX_EPOCH_DAY && day <= ZTP_MAX_EPOCH_DAY;
}

static ztp_status ztp_zoned_range_error(ztp_ctx *ctx, size_t index)
{
    return ztp_fail(ctx, ZTP_ERR_RANGE, index, "the instant is outside the representable range");
}

ztp_status ztp_zone_possible(ztp_ctx *ctx, size_t index, const ztp_zone *zone,
                             int64_t day, int64_t ns_of_day, zuf_i128 out[2], int *n)
{
    if (!ztp_zoned_day_ok(day)) return ztp_zoned_range_error(ctx, index);
    if (zone->kind == ZTP_ZONE_IANA) {
        *n = ztp_tz_possible_epoch_ns(&zone->iana->data, (int32_t)day, ns_of_day, out);
    } else {
        int64_t offset = zone->kind == ZTP_ZONE_OFFSET ? zone->offset_ns : 0;
        out[0] = zuf_i128_sub_wrap(ztp_epoch_ns_of((int32_t)day, ns_of_day), zuf_i128_from_i64(offset));
        *n = 1;
    }
    for (int i = 0; i < *n; i++)
        if (!ztp_is_valid_epoch_ns(out[i])) return ztp_zoned_range_error(ctx, index);
    return ZTP_OK;
}

/* DisambiguatePossibleEpochNanoseconds (the gap case): the offsets a day
   before and after the local time bound the shift. */
static ztp_status ztp_zone_disambiguate(ztp_ctx *ctx, size_t index, const ztp_zone *zone,
                                        int64_t day, int64_t ns_of_day,
                                        const zuf_i128 *possible, int n,
                                        ztp_disambiguation disambiguation, zuf_i128 *out)
{
    zuf_i128 utc, before, after, cands[2];
    int64_t offset_before, offset_after, shift, shifted_ns;
    int64_t shifted_day;
    int k;

    if (n == 1) {
        *out = possible[0];
        return ZTP_OK;
    }
    if (n > 1) {
        if (disambiguation == ZTP_DISAMBIGUATION_REJECT)
            return ztp_fail(ctx, ZTP_ERR_RANGE, index,
                            "the local time is ambiguous in this time zone (a clock fold)");
        *out = disambiguation == ZTP_DISAMBIGUATION_LATER ? possible[n - 1] : possible[0];
        return ZTP_OK;
    }
    if (disambiguation == ZTP_DISAMBIGUATION_REJECT)
        return ztp_fail(ctx, ZTP_ERR_RANGE, index,
                        "the local time does not exist in this time zone (a clock gap)");
    utc = ztp_epoch_ns_of((int32_t)day, ns_of_day);
    before = zuf_i128_sub_wrap(utc, zuf_i128_from_i64(ZTP_NS_PER_DAY));
    after = zuf_i128_add_wrap(utc, zuf_i128_from_i64(ZTP_NS_PER_DAY));
    offset_before = ztp_zone_offset_at(zone, before);
    offset_after = ztp_zone_offset_at(zone, after);
    shift = offset_after - offset_before;
    if (disambiguation == ZTP_DISAMBIGUATION_EARLIER) shift = -shift;
    shifted_ns = ns_of_day + shift;
    shifted_day = day;
    while (shifted_ns < 0) {
        shifted_ns += ZTP_NS_PER_DAY;
        shifted_day--;
    }
    while (shifted_ns >= ZTP_NS_PER_DAY) {
        shifted_ns -= ZTP_NS_PER_DAY;
        shifted_day++;
    }
    if (ztp_zone_possible(ctx, index, zone, shifted_day, shifted_ns, cands, &k) != ZTP_OK)
        return ctx->status;
    if (k == 0) return ztp_fail(ctx, ZTP_ERR_RANGE, index, "cannot resolve the local time in this time zone");
    *out = disambiguation == ZTP_DISAMBIGUATION_EARLIER ? cands[0] : cands[k - 1];
    return ZTP_OK;
}

ztp_status ztp_zone_epoch_ns_for(ztp_ctx *ctx, size_t index, const ztp_zone *zone,
                                 int64_t day, int64_t ns_of_day,
                                 ztp_disambiguation disambiguation, zuf_i128 *out)
{
    zuf_i128 cands[2];
    int n;

    if (ztp_zone_possible(ctx, index, zone, day, ns_of_day, cands, &n) != ZTP_OK) return ctx->status;
    return ztp_zone_disambiguate(ctx, index, zone, day, ns_of_day, cands, n, disambiguation, out);
}

ztp_status ztp_zone_start_of_day(ztp_ctx *ctx, size_t index, const ztp_zone *zone,
                                 int64_t day, zuf_i128 *out)
{
    zuf_i128 cands[2];
    int n;
    int64_t midnight_s, t, found;
    const int64_t limit = (int64_t)(ZTP_MAX_EPOCH_DAY + 2) * 86400;

    if (ztp_zone_possible(ctx, index, zone, day, 0, cands, &n) != ZTP_OK) return ctx->status;
    if (n > 0) {
        *out = cands[0];
        return ZTP_OK;
    }
    /* Midnight falls in a gap: the day starts at the transition, the first
       instant whose local time is on or after midnight. */
    midnight_s = day * 86400;
    t = midnight_s - 2 * 86400;
    for (int guard = 0; guard < 8; guard++) {
        if (!ztp_tz_next_transition(&zone->iana->data, t, limit, &found)) break;
        if (found + ztp_tz_utoff_at(&zone->iana->data, found, NULL, NULL) >= midnight_s) {
            *out = zuf_i128_mul_i64_i64(found, ZTP_NS_PER_SECOND);
            if (!ztp_is_valid_epoch_ns(*out)) return ztp_zoned_range_error(ctx, index);
            return ZTP_OK;
        }
        t = found;
    }
    /* Unreachable from R: a gap at midnight means a transition in the two
       days before it, which the first steps of the search find. Kept as
       a guard against zone data with a run of transitions that close. */
    return ztp_fail(ctx, ZTP_ERR_RANGE, index, "cannot find the start of the day in this time zone");
}

ztp_status ztp_interpret_iso_date_time_offset(ztp_ctx *ctx, size_t index,
                                              int64_t day, int64_t ns_of_day,
                                              ztp_offset_behaviour behaviour,
                                              int64_t offset_ns, const ztp_zone *zone,
                                              ztp_disambiguation disambiguation,
                                              ztp_offset_option offset_option,
                                              bool match_minutes, zuf_i128 *out)
{
    zuf_i128 utc, cands[2];
    int n;

    if (behaviour == ZTP_OFFSET_BEHAVIOUR_START_OF_DAY)
        return ztp_zone_start_of_day(ctx, index, zone, day, out);
    if (behaviour == ZTP_OFFSET_BEHAVIOUR_WALL ||
        (behaviour == ZTP_OFFSET_BEHAVIOUR_OPTION && offset_option == ZTP_OFFSET_IGNORE))
        return ztp_zone_epoch_ns_for(ctx, index, zone, day, ns_of_day, disambiguation, out);
    if (behaviour == ZTP_OFFSET_BEHAVIOUR_EXACT ||
        (behaviour == ZTP_OFFSET_BEHAVIOUR_OPTION && offset_option == ZTP_OFFSET_USE))
        return ztp_instant_from_local(ctx, index, day, ns_of_day, offset_ns, out);
    /* ~option~ with ~prefer~ or ~reject~: a candidate whose offset matches
       wins; to the minute for a string that only had minutes. */
    if (!ztp_zoned_days_in_range(day)) return ztp_zoned_range_error(ctx, index);
    utc = ztp_epoch_ns_of((int32_t)day, ns_of_day);
    if (ztp_zone_possible(ctx, index, zone, day, ns_of_day, cands, &n) != ZTP_OK) return ctx->status;
    for (int i = 0; i < n; i++) {
        int64_t candidate_offset;
        zuf_i128_to_i64(zuf_i128_sub_wrap(utc, cands[i]), &candidate_offset);
        if (candidate_offset == offset_ns) {
            *out = cands[i];
            return ZTP_OK;
        }
        if (match_minutes &&
            ztp_round_to_increment(candidate_offset, ZTP_NS_PER_MINUTE, ZTP_ROUND_HALF_EXPAND) == offset_ns) {
            *out = cands[i];
            return ZTP_OK;
        }
    }
    if (offset_option == ZTP_OFFSET_REJECT) {
        char shown[16];
        ztp_format_offset_exact(shown, offset_ns);
        return ztp_fail(ctx, ZTP_ERR_RANGE, index,
                        "the UTC offset %s does not match the time zone \"%s\" at that local time",
                        shown, zone->id);
    }
    return ztp_zone_disambiguate(ctx, index, zone, day, ns_of_day, cands, n, disambiguation, out);
}

void ztp_zoned_local(const ztp_zone *zone, zuf_i128 epoch_ns, int32_t *day,
                     int64_t *ns_of_day, int64_t *offset_ns)
{
    int64_t offset = ztp_zone_offset_at(zone, epoch_ns);

    ztp_instant_to_local(epoch_ns, offset, day, ns_of_day);
    if (offset_ns) *offset_ns = offset;
}

ztp_status ztp_zoned_hours_in_day(ztp_ctx *ctx, size_t index, const ztp_zone *zone,
                                  zuf_i128 epoch_ns, double *out)
{
    int32_t day;
    int64_t ns_of_day, diff;
    zuf_i128 today, tomorrow;

    ztp_zoned_local(zone, epoch_ns, &day, &ns_of_day, NULL);
    if (ztp_zone_start_of_day(ctx, index, zone, day, &today) != ZTP_OK) return ctx->status;
    if (ztp_zone_start_of_day(ctx, index, zone, (int64_t)day + 1, &tomorrow) != ZTP_OK) return ctx->status;
    zuf_i128_to_i64(zuf_i128_sub_wrap(tomorrow, today), &diff);
    *out = (double)diff / 3.6e12;
    return ZTP_OK;
}

size_t ztp_format_offset_exact(char *dst, int64_t offset_ns)
{
    int64_t a = offset_ns < 0 ? -offset_ns : offset_ns;
    int64_t hour = a / ZTP_NS_PER_HOUR, minute = (a / ZTP_NS_PER_MINUTE) % 60,
            second = (a / ZTP_NS_PER_SECOND) % 60, sub = a % ZTP_NS_PER_SECOND;
    char *p = dst;

    *p++ = offset_ns < 0 ? '-' : '+';
    *p++ = (char)('0' + hour / 10);
    *p++ = (char)('0' + hour % 10);
    *p++ = ':';
    *p++ = (char)('0' + minute / 10);
    *p++ = (char)('0' + minute % 10);
    if (second != 0 || sub != 0) {
        *p++ = ':';
        *p++ = (char)('0' + second / 10);
        *p++ = (char)('0' + second % 10);
        if (sub != 0) {
            int digits = 9;
            while (sub % 10 == 0) {
                sub /= 10;
                digits--;
            }
            *p++ = '.';
            for (int i = digits - 1; i >= 0; i--) {
                p[i] = (char)('0' + sub % 10);
                sub /= 10;
            }
            p += digits;
        }
    }
    *p = '\0';
    return (size_t)(p - dst);
}

size_t ztp_format_zoned(char *dst, zuf_i128 epoch_ns, const ztp_zone *zone,
                        int precision, bool show_offset, ztp_show_zone show_zone,
                        ztp_show_calendar show_calendar)
{
    int32_t day;
    int64_t ns_of_day, offset;
    size_t k;

    ztp_zoned_local(zone, epoch_ns, &day, &ns_of_day, &offset);
    k = ztp_format_iso_date_time(dst, day, ns_of_day, precision, ZTP_SHOW_CALENDAR_NEVER);
    if (show_offset) k += ztp_format_offset(dst + k, offset);
    if (show_zone != ZTP_SHOW_ZONE_NEVER) {
        dst[k++] = '[';
        if (show_zone == ZTP_SHOW_ZONE_CRITICAL) dst[k++] = '!';
        strcpy(dst + k, zone->id);
        k += strlen(zone->id);
        dst[k++] = ']';
        dst[k] = '\0';
    }
    /* FormatCalendarAnnotation: only "always" and "critical" show the ISO
       calendar. */
    if (show_calendar == ZTP_SHOW_CALENDAR_ALWAYS || show_calendar == ZTP_SHOW_CALENDAR_CRITICAL) {
        const char *text = show_calendar == ZTP_SHOW_CALENDAR_CRITICAL ? "[!u-ca=iso8601]"
                                                                       : "[u-ca=iso8601]";
        strcpy(dst + k, text);
        k += strlen(text);
    }
    return k;
}
