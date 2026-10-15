/* ztp_tz_cache.c -- the session cache of parsed zones (design 8.4). Engine
   side: no R. The R side reads files and hands over their bytes. */

#include "ztp_tz.h"

#include <stdlib.h>
#include <string.h>

static ztp_tz_entry *ztp_tz_entries = NULL;
static size_t ztp_tz_n = 0, ztp_tz_cap = 0;

static void ztp_tz_fold(const char *id, char *out)
{
    size_t i;
    for (i = 0; i + 1 < ZTP_ZONE_ID_CAP && id[i]; i++) {
        char ch = id[i];
        out[i] = (ch >= 'A' && ch <= 'Z') ? (char)(ch + ('a' - 'A')) : ch;
    }
    out[i] = '\0';
}

const ztp_tz_entry *ztp_tz_cache_find(const char *id)
{
    char key[ZTP_ZONE_ID_CAP];

    ztp_tz_fold(id, key);
    for (size_t i = 0; i < ztp_tz_n; i++)
        if (strcmp(ztp_tz_entries[i].key, key) == 0) return &ztp_tz_entries[i];
    return NULL;
}

ztp_status ztp_tz_cache_put(ztp_ctx *ctx, size_t index, const char *id,
                            const unsigned char *bytes, size_t n)
{
    ztp_tz_data data;
    char key[ZTP_ZONE_ID_CAP];
    ztp_tz_entry *slot = NULL;

    if (strlen(id) + 1 > ZTP_ZONE_ID_CAP)
        return ztp_fail(ctx, ZTP_ERR_TZ, index, "time zone identifier \"%.40s...\" is too long", id);
    if (ztp_tzif_parse(ctx, index, bytes, n, &data) != ZTP_OK) return ctx->status;
    ztp_tz_fold(id, key);
    for (size_t i = 0; i < ztp_tz_n; i++)
        if (strcmp(ztp_tz_entries[i].key, key) == 0) slot = &ztp_tz_entries[i];
    if (slot == NULL) {
        if (ztp_tz_n == ztp_tz_cap) {
            size_t cap = ztp_tz_cap ? ztp_tz_cap * 2 : 16;
            ztp_tz_entry *grown = realloc(ztp_tz_entries, cap * sizeof *grown);
            if (grown == NULL) {
                ztp_tz_data_free(&data);
                return ztp_fail(ctx, ZTP_ERR_TZ, index, "out of memory caching a time zone");
            }
            ztp_tz_entries = grown;
            ztp_tz_cap = cap;
        }
        slot = &ztp_tz_entries[ztp_tz_n++];
        memset(slot, 0, sizeof *slot);
    } else {
        ztp_tz_data_free(&slot->data);
    }
    memcpy(slot->key, key, sizeof key);
    strcpy(slot->id, id);
    slot->data = data;
    return ZTP_OK;
}

void ztp_tz_cache_reset(void)
{
    for (size_t i = 0; i < ztp_tz_n; i++) ztp_tz_data_free(&ztp_tz_entries[i].data);
    free(ztp_tz_entries);
    ztp_tz_entries = NULL;
    ztp_tz_n = 0;
    ztp_tz_cap = 0;
}

size_t ztp_tz_cache_size(void)
{
    return ztp_tz_n;
}
