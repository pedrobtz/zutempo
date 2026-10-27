/* ztp_common.c -- the context helpers of ztp.h. Engine side: no R. */

#include "ztp.h"

#include <stdarg.h>
#include <stdio.h>
#include <string.h>

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

/* The length of the valid UTF-8 sequence at s (n bytes available), or 0
   when the bytes there do not start one: a stray continuation byte, a
   truncated sequence, an overlong form, a surrogate or a code point past
   U+10FFFF. */
static size_t ztp_utf8_seq(const unsigned char *s, size_t n)
{
    unsigned char c = s[0];
    size_t len;
    unsigned char lo = 0x80, hi = 0xBF;

    if (c < 0x80) return 1;
    if (c >= 0xC2 && c <= 0xDF) len = 2;
    else if (c >= 0xE0 && c <= 0xEF) len = 3;
    else if (c >= 0xF0 && c <= 0xF4) len = 4;
    else return 0;
    if (c == 0xE0) lo = 0xA0;
    else if (c == 0xED) hi = 0x9F;
    else if (c == 0xF0) lo = 0x90;
    else if (c == 0xF4) hi = 0x8F;
    if (n < len || s[1] < lo || s[1] > hi) return 0;
    for (size_t k = 2; k < len; k++)
        if (s[k] < 0x80 || s[k] > 0xBF) return 0;
    return len;
}

size_t ztp_utf8_prefix(const char *s, size_t n, size_t max)
{
    const unsigned char *u = (const unsigned char *)s;
    size_t k = 0;

    if (n <= max) return n;
    while (k < max) {
        size_t len = ztp_utf8_seq(u + k, n - k);
        if (len == 0) len = 1;   /* a bad byte is a character of its own */
        if (k + len > max) break;
        k += len;
    }
    return k;
}

/* Drop every byte that is not part of a valid UTF-8 sequence, in place:
   the message reaches R marked as UTF-8 (ztp_r_raise), so it must be
   valid even when vsnprintf or a "%.*s" cut a character in two. */
static void ztp_utf8_clean(char *msg, size_t n)
{
    unsigned char *u = (unsigned char *)msg;
    size_t from = 0, to = 0;

    while (from < n) {
        size_t len = ztp_utf8_seq(u + from, n - from);
        if (len == 0) {
            from++;
            continue;
        }
        memmove(u + to, u + from, len);
        to += len;
        from += len;
    }
    u[to] = '\0';
}

ztp_status ztp_fail(ztp_ctx *ctx, ztp_status status, size_t index,
                    const char *fmt, ...)
{
    va_list ap;
    int len;

    ctx->status = status;
    ctx->index = index;
    ctx->position = 0;
    va_start(ap, fmt);
    len = vsnprintf(ctx->msg, sizeof ctx->msg, fmt, ap);
    va_end(ap);
    if (len < 0) len = 0;
    if ((size_t)len >= sizeof ctx->msg) len = (int)(sizeof ctx->msg - 1);
    ztp_utf8_clean(ctx->msg, (size_t)len);
    return status;
}
