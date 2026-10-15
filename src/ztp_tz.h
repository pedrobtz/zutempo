/*
 * ztp_tz.h -- the time zone database in the engine (design 8): a TZif
 * reader for versions 1 to 4, the POSIX TZ footer rule, offsets and
 * transitions over the explicit list and the rule, and the IANA link
 * table. Engine side: no R, and no file system; the caller hands over the
 * bytes of a file.
 */
#ifndef ZTP_TZ_H
#define ZTP_TZ_H

#include "ztp_instant.h"

/* --- links (src/ztp_tz_links.c, generated) ----------------------------- */

typedef struct {
    const char *link;
    const char *target;
} ztp_tz_link;

extern const ztp_tz_link ztp_tz_links[];
extern const size_t ztp_tz_links_count;
extern const char *const ztp_tz_links_version;

/* The primary identifier a link resolves to, matched ASCII case
   insensitively, or NULL when `id` is not a link. */
const char *ztp_tz_link_target(const char *id);

/* --- the POSIX TZ footer ------------------------------------------------ */

typedef enum {
    ZTP_TZ_RULE_JULIAN,   /* Jn: 1 to 365, never counting February 29 */
    ZTP_TZ_RULE_DAY,      /* n: 0 to 365, counting it */
    ZTP_TZ_RULE_MONTH     /* Mm.w.d: month, week (5 = last), weekday (0 = Sunday) */
} ztp_tz_rule_kind;

typedef struct {
    ztp_tz_rule_kind kind;
    int day, month, week, weekday;
    int64_t time;         /* seconds after local midnight, -167h to 167h */
} ztp_tz_rule_date;

#define ZTP_TZ_ABBR_CAP 24

typedef struct {
    int32_t std_off;              /* seconds east of UTC */
    char std_abbr[ZTP_TZ_ABBR_CAP];
    bool has_dst;
    int32_t dst_off;
    char dst_abbr[ZTP_TZ_ABBR_CAP];
    ztp_tz_rule_date start, end;
} ztp_tz_posix;

/* Parse a TZ string: "EST5EDT,M3.2.0,M11.1.0", "<+1030>-10:30<+11>-11,
   M10.1.0,M4.1.0", "<+13>-13". */
ztp_status ztp_tz_posix_parse(ztp_ctx *ctx, size_t index, const char *s,
                              size_t n, ztp_tz_posix *out);

/* --- parsed zone data --------------------------------------------------- */

typedef struct {
    int32_t utoff;
    bool isdst;
    uint8_t abbr;         /* index into abbrs */
} ztp_tz_type;

typedef struct {
    int version;              /* 1 to 4 */
    int64_t *times;           /* transition times, epoch seconds, ascending */
    uint8_t *idx;             /* type of each transition */
    size_t n_times;
    ztp_tz_type *types;
    size_t n_types;
    char *abbrs;
    size_t n_abbrs;
    bool has_footer;
    ztp_tz_posix footer;
} ztp_tz_data;

/* Parse the bytes of a TZif file. Every count and offset is checked
   against `n` before use; a malformed file is ZTP_ERR_TZ. The result owns
   heap memory until ztp_tz_data_free(). */
ztp_status ztp_tzif_parse(ztp_ctx *ctx, size_t index, const unsigned char *buf,
                          size_t n, ztp_tz_data *out);
void ztp_tz_data_free(ztp_tz_data *data);

/* The UTC offset in seconds in force at epoch second t, with the DST flag
   and abbreviation of that period. */
int32_t ztp_tz_utoff_at(const ztp_tz_data *data, int64_t t, bool *isdst,
                        const char **abbr);

/* GetNamedTimeZoneNextTransition and ...PreviousTransition over the
   explicit list then the footer rule: the first transition strictly after
   t, or the last strictly before it, within `limit` epoch seconds of the
   epoch either side. false when there is none. */
bool ztp_tz_next_transition(const ztp_tz_data *data, int64_t t, int64_t limit,
                            int64_t *out);
bool ztp_tz_previous_transition(const ztp_tz_data *data, int64_t t,
                                int64_t limit, int64_t *out);

/* The epoch second of the last explicit transition, or false when the
   file has none (how fat or slim a file is shows here). */
bool ztp_tz_last_explicit(const ztp_tz_data *data, int64_t *out);

/* GetNamedTimeZoneEpochNanoseconds: the exact times a local date-time may
   denote, 0, 1 or 2 of them in ascending order. */
int ztp_tz_possible_epoch_ns(const ztp_tz_data *data, int32_t day, int64_t ns_of_day,
                             zuf_i128 out[2]);

/* --- the session cache (src/ztp_tz_cache.c) ----------------------------- */

typedef struct ztp_tz_entry {
    char key[ZTP_ZONE_ID_CAP];   /* ASCII-case-folded identifier */
    char id[ZTP_ZONE_ID_CAP];    /* the identifier in the database's case */
    ztp_tz_data data;
} ztp_tz_entry;

/* Parsed zones for the session, keyed by the case-folded identifier. The
   caller (the R side) reads the file and decides which identifiers exist;
   the cache only holds what it was given. */
const ztp_tz_entry *ztp_tz_cache_find(const char *id);
ztp_status ztp_tz_cache_put(ztp_ctx *ctx, size_t index, const char *id,
                            const unsigned char *bytes, size_t n);
void ztp_tz_cache_reset(void);
size_t ztp_tz_cache_size(void);

/* The primary identifier of a named zone: its link target, or itself. */
const char *ztp_tz_primary(const char *id);

#endif /* ZTP_TZ_H */
