/*
 * ztp_r.h -- the glue between R and the engine (design 4, 10).
 *
 * Only files named ztp_r_*.c and init.c include R headers. The glue
 * unpacks R vectors, loops over elements, handles NA, calls the engine
 * with a ztp_ctx, and turns a failed context into an R condition through
 * ztp_r_raise(), which evaluates zutempo:::stop_zutempo() in the package
 * namespace and never returns.
 */
#ifndef ZTP_R_H
#define ZTP_R_H

#define R_NO_REMAP
#include <R.h>
#include <Rinternals.h>

#include "ztp.h"

/* Raise the condition that ctx describes. Never returns. */
#if defined(__GNUC__) || defined(__clang__)
__attribute__((noreturn))
#endif
void ztp_r_raise(const ztp_ctx *ctx);

/* Raise if ctx holds a failure; otherwise return. */
static inline void ztp_r_check(const ztp_ctx *ctx)
{
    if (ctx->status != ZTP_OK) ztp_r_raise(ctx);
}

/* .Call entry points, registered in init.c. */
SEXP ztp_r_info(void);
SEXP ztp_r_probe_civil(SEXP days);
SEXP ztp_r_probe_mul(SEXP a, SEXP b);
SEXP ztp_r_probe_fail(SEXP kind, SEXP index);

#endif /* ZTP_R_H */
