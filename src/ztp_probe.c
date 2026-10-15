/* ztp_probe.c -- see ztp_probe.h. Engine side: no R. */

#include "ztp_probe.h"

#include <string.h>

#include <zufast/datetime.h>
#include <zufast/version.h>
#include <zufast/wide.h>

static bool ztp_probe_integral_in(double x, double lo, double hi)
{
    /* NaN fails every comparison, so it is excluded too. */
    return x >= lo && x <= hi && x == (double)(int64_t)x;
}

ztp_status ztp_probe_civil(ztp_ctx *ctx, double days, size_t index,
                           int32_t *year, uint32_t *month, uint32_t *day)
{
    if (!ztp_probe_integral_in(days, (double)INT32_MIN, (double)INT32_MAX))
        return ztp_fail(ctx, ZTP_ERR_RANGE, index,
                        "epoch day %g is not an integer in the int32_t range",
                        days);
    zuf_civil_from_days((int32_t)days, year, month, day);
    return ZTP_OK;
}

ztp_status ztp_probe_mul(ztp_ctx *ctx, double a, double b, size_t index,
                         char *dst)
{
    /* 2^63 is representable as a double; INT64_MAX is not, and rounds up
       to it, so the inclusive bound is one below 2^63. */
    const double lim = 9223372036854775808.0;

    if (!ztp_probe_integral_in(a, -lim, lim - 1024.0) ||
        !ztp_probe_integral_in(b, -lim, lim - 1024.0))
        return ztp_fail(ctx, ZTP_ERR_RANGE, index,
                        "operands must be integers in the int64_t range");
    {
        zuf_i128 product = zuf_i128_mul_i64_i64((int64_t)a, (int64_t)b);
        char *end = zuf_write_i128(dst, product);
        *end = '\0';
    }
    return ZTP_OK;
}

ztp_status ztp_probe_fail(ztp_ctx *ctx, const char *kind, size_t index)
{
    if (strcmp(kind, "range") == 0)
        return ztp_fail(ctx, ZTP_ERR_RANGE, index, "probe: a range error");
    if (strcmp(kind, "parse") == 0)
        return ztp_fail(ctx, ZTP_ERR_PARSE, index, "probe: a parse error");
    if (strcmp(kind, "type") == 0)
        return ztp_fail(ctx, ZTP_ERR_TYPE, index, "probe: a type error");
    if (strcmp(kind, "tz") == 0)
        return ztp_fail(ctx, ZTP_ERR_TZ, index, "probe: a time zone error");
    return ztp_fail(ctx, ZTP_ERR_TYPE, index, "probe: unknown kind '%s'",
                    kind);
}

bool ztp_probe_have_int128(void)
{
#if ZUF_INT_HAVE_INT128
    return true;
#else
    return false;
#endif
}

const char *ztp_probe_zufast_version(void)
{
    return ZUFAST_VERSION;
}
