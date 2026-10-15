/*
 * ztp_probe.h -- the stage 1 probe: one engine path through zufast's
 * calendar algorithms (datetime.h) and 128-bit integers (wide.h), reached
 * by an internal .Call so that a test proves the layering of design 4 end
 * to end. Later stages replace it with the real types.
 */
#ifndef ZTP_PROBE_H
#define ZTP_PROBE_H

#include "ztp.h"

/* Decimal digits of a signed 128-bit value plus the sign and a NUL. */
#define ZTP_PROBE_DECIMAL_CAP 41

/* Civil date of an epoch day through zuf_civil_from_days(). days must be
   integral and within int32_t; otherwise ZTP_ERR_RANGE with `index`. */
ztp_status ztp_probe_civil(ztp_ctx *ctx, double days, size_t index,
                           int32_t *year, uint32_t *month, uint32_t *day);

/* The exact product a * b as decimal text through zuf_i128_mul_i64_i64()
   and zuf_write_i128(). a and b must be integral and within int64_t;
   otherwise ZTP_ERR_RANGE with `index`. dst has ZTP_PROBE_DECIMAL_CAP
   bytes. */
ztp_status ztp_probe_mul(ztp_ctx *ctx, double a, double b, size_t index,
                         char *dst);

/* Fail with the status named by kind ("range", "parse", "type" or "tz")
   at `index`; an unknown kind is a ZTP_ERR_TYPE. Exists so that the glue's
   condition classes can be tested from R. */
ztp_status ztp_probe_fail(ztp_ctx *ctx, const char *kind, size_t index);

/* Whether wide.h is using the compiler's __int128 (design 4.3). */
bool ztp_probe_have_int128(void);

/* The zufast version the package was compiled against. */
const char *ztp_probe_zufast_version(void);

#endif /* ZTP_PROBE_H */
