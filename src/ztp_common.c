/* ztp_common.c -- the context helpers of ztp.h. Engine side: no R. */

#include "ztp.h"

#include <stdarg.h>
#include <stdio.h>

const char *ztp_status_kind(ztp_status status)
{
    switch (status) {
    case ZTP_OK:        return "ok";
    case ZTP_ERR_RANGE: return "range";
    case ZTP_ERR_PARSE: return "parse";
    case ZTP_ERR_TYPE:  return "type";
    case ZTP_ERR_TZ:    return "tz";
    }
    return "range";
}

ztp_status ztp_fail(ztp_ctx *ctx, ztp_status status, size_t index,
                    const char *fmt, ...)
{
    va_list ap;

    ctx->status = status;
    ctx->index = index;
    ctx->position = 0;
    va_start(ap, fmt);
    vsnprintf(ctx->msg, sizeof ctx->msg, fmt, ap);
    va_end(ap);
    return status;
}
