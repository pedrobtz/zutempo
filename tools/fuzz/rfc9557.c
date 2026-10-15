/*
 * tools/fuzz/rfc9557.c -- libFuzzer harness for the ISO 8601 / RFC 9557
 * parser (design 9, 11): every goal, the time zone and calendar string
 * readers, and the zufast fast path against the slow path. Built by
 * .github/workflows/hardening.yaml against src/ztp_*.c without R; the
 * corpus is seeded from tools/fuzz/corpus/rfc9557.
 */
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>

#include "../../src/ztp_parse.h"

/* The fast path may decline a string, but whatever it accepts the slow
   path must read the same way (design 9). */
static void ztp_fuzz_paths_agree(const char *s, size_t n, ztp_parse_goal goal)
{
    ztp_ctx a, b;
    ztp_parsed fast, slow;

    ztp_ctx_init(&a);
    ztp_ctx_init(&b);
    if (ztp_parse_path(&a, 1, s, n, goal, ZTP_PARSE_PATH_FAST, &fast, NULL) != ZTP_OK) return;
    if (ztp_parse_path(&b, 1, s, n, goal, ZTP_PARSE_PATH_SLOW, &slow, NULL) != ZTP_OK) abort();
    if (fast.year != slow.year || fast.month != slow.month || fast.day != slow.day ||
        fast.has_time != slow.has_time || fast.time.hour != slow.time.hour ||
        fast.time.minute != slow.time.minute || fast.time.second != slow.time.second ||
        fast.time.millisecond != slow.time.millisecond ||
        fast.time.microsecond != slow.time.microsecond ||
        fast.time.nanosecond != slow.time.nanosecond || fast.has_offset != slow.has_offset ||
        (fast.has_offset && fast.offset_ns != slow.offset_ns) || fast.has_z != slow.has_z)
        abort();
}

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
    const char *s = (const char *)data;
    char zone[ZTP_TZ_ANNOTATION_CAP];
    char calendar[ZTP_CALENDAR_CAP];
    ztp_ctx ctx;
    ztp_parsed p;
    size_t position;

    for (int goal = ZTP_PARSE_DATE_TIME; goal <= ZTP_PARSE_ANY; goal++) {
        ztp_ctx_init(&ctx);
        if (ztp_parse(&ctx, 1, s, size, (ztp_parse_goal)goal, &p, &position) == ZTP_OK) {
            /* A successful parse leaves a valid ISO date and time. */
            if (p.month < 1 || p.month > 12 || p.day < 1 || p.day > 31 || p.time.hour > 23 ||
                p.time.minute > 59 || p.time.second > 59)
                abort();
        } else if (ctx.status == ZTP_ERR_PARSE && (position > size || ctx.position != position + 1)) {
            abort();
        }
        if (goal != ZTP_PARSE_ANY) ztp_fuzz_paths_agree(s, size, (ztp_parse_goal)goal);
    }
    ztp_ctx_init(&ctx);
    ztp_parse_time_zone_string(&ctx, 1, s, size, zone);
    ztp_ctx_init(&ctx);
    ztp_parse_calendar_string(&ctx, 1, s, size, calendar);
    return 0;
}
