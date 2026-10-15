/*
 * ztp.h -- the engine's status and context conventions (design 4, 10).
 *
 * The engine (src/ztp_*.c) never calls R. Every engine function that can
 * fail takes a ztp_ctx and returns a ztp_status; on failure it records the
 * status, the 1-based index of the element that failed (0 when no element
 * applies) and a message in the context, through ztp_fail(). The glue
 * (src/ztp_r_*.c) turns a failed context into an R condition of the class
 * the status names (ztp_r.h). Nothing in this header includes an R header,
 * which is what lets the same engine serve C callers after v0.1.0
 * (design 7).
 */
#ifndef ZTP_H
#define ZTP_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

/* One value per condition class of design 10. Enumerator values are
   permanent: they will be part of the C table. */
typedef enum {
    ZTP_OK = 0,
    ZTP_ERR_RANGE = 1,   /* zutempo_range_error */
    ZTP_ERR_PARSE = 2,   /* zutempo_parse_error, a range error */
    ZTP_ERR_TYPE = 3,    /* zutempo_type_error */
    ZTP_ERR_TZ = 4       /* zutempo_tz_error, a range error */
} ztp_status;

#define ZTP_MSG_CAP 256

/* Per-call state. Initialise with ztp_ctx_init() before the first engine
   call; read status, index and msg after a failure. */
typedef struct {
    ztp_status status;
    size_t index;             /* 1-based element index, 0 for none */
    char msg[ZTP_MSG_CAP];    /* NUL-terminated, empty while ZTP_OK */
} ztp_ctx;

static inline void ztp_ctx_init(ztp_ctx *ctx)
{
    ctx->status = ZTP_OK;
    ctx->index = 0;
    ctx->msg[0] = '\0';
}

/* The short name of a status, as the R side spells the condition kind:
   "ok", "range", "parse", "type" or "tz". */
const char *ztp_status_kind(ztp_status status);

/* Record a failure and return its status, so a caller can write
   `return ztp_fail(ctx, ZTP_ERR_RANGE, i, "...", ...);`. The message is
   formatted with vsnprintf into ctx->msg and truncated to ZTP_MSG_CAP. */
#if defined(__GNUC__) || defined(__clang__)
__attribute__((format(printf, 4, 5)))
#endif
ztp_status ztp_fail(ztp_ctx *ctx, ztp_status status, size_t index,
                    const char *fmt, ...);

#endif /* ZTP_H */
