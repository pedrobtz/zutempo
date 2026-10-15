/*
 * tools/fuzz/tzif.c -- libFuzzer harness for the TZif reader and the POSIX
 * footer rules (design 8.2, 11). Built by .github/workflows/hardening.yaml
 * against src/ztp_*.c without R; the corpus is seeded from the committed
 * fixtures under tests/testthat/tzdata.
 */
#include <stddef.h>
#include <stdint.h>

#include "../../src/ztp_tz.h"

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
    ztp_ctx ctx;
    ztp_tz_data zone;
    zuf_i128 cands[2];
    int64_t t;
    const int64_t limit = (int64_t)ZTP_MAX_EPOCH_DAY * 86400;

    ztp_ctx_init(&ctx);
    if (ztp_tzif_parse(&ctx, 0, data, size, &zone) != ZTP_OK) return 0;
    /* Exercise every reader path on the parsed zone. */
    for (int64_t s = -4000000000LL; s < 5000000000LL; s += 97000000LL)
        ztp_tz_utoff_at(&zone, s, NULL, NULL);
    ztp_tz_next_transition(&zone, 0, limit, &t);
    ztp_tz_previous_transition(&zone, 0, limit, &t);
    ztp_tz_next_transition(&zone, limit - 1, limit, &t);
    ztp_tz_previous_transition(&zone, -limit + 1, limit, &t);
    ztp_tz_possible_epoch_ns(&zone, 20520, 9000000000000LL, cands);
    ztp_tz_possible_epoch_ns(&zone, -100000000, 0, cands);
    ztp_tz_data_free(&zone);
    return 0;
}
