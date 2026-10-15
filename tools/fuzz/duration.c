/*
 * tools/fuzz/duration.c -- libFuzzer harness for the duration parser
 * (ParseTemporalDurationString, design 9, 11). A string that parses is
 * written back with TemporalDurationToString, which must read again as the
 * same duration. Built by .github/workflows/hardening.yaml against
 * src/ztp_*.c without R; the corpus is seeded from
 * tools/fuzz/corpus/duration.
 */
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "../../src/ztp_duration.h"

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
    ztp_ctx ctx;
    ztp_duration d, again;
    ztp_internal_duration a, b;
    char buf[ZTP_DURATION_FORMAT_CAP];
    size_t position, n;

    ztp_ctx_init(&ctx);
    if (ztp_duration_parse(&ctx, 1, (const char *)data, size, &d, &position) != ZTP_OK) {
        if (ctx.status == ZTP_ERR_PARSE && (position > size || ctx.position != position + 1))
            abort();
        return 0;
    }
    if (!ztp_duration_is_valid(&d)) abort();
    for (int precision = -1; precision <= 9; precision++) {
        n = ztp_duration_format(buf, &d, precision);
        if (n >= sizeof buf || strlen(buf) != n) abort();
    }
    n = ztp_duration_format(buf, &d, -1);
    ztp_ctx_init(&ctx);
    if (ztp_duration_parse(&ctx, 1, buf, n, &again, NULL) != ZTP_OK) abort();
    a = ztp_duration_to_internal(&d);
    b = ztp_duration_to_internal(&again);
    if (memcmp(&a.date, &b.date, sizeof a.date) != 0 || zuf_i128_cmp(a.time, b.time) != 0) abort();
    return 0;
}
