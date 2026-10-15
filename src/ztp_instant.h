/*
 * ztp_instant.h -- Temporal.Instant and the time zone object's fixed
 * kinds (Temporal 8.5, 11.1 for UTC and offset identifiers). Engine side:
 * no R.
 *
 * An instant is epoch nanoseconds in a zuf_i128 within nsMaxInstant
 * (design 4.3); R stores it as a complex value of integral epoch seconds
 * and nanoseconds in [0, 10^9) with the floor convention (design 4.1).
 * The zone object has the UTC and fixed-offset kinds here; the IANA kind
 * arrives with the database in stage 6.
 */
#ifndef ZTP_INSTANT_H
#define ZTP_INSTANT_H

#include "ztp_duration.h"
#include "ztp_format.h"

/* IsValidEpochNanoseconds: |ns| <= 10^8 days. */
bool ztp_is_valid_epoch_ns(zuf_i128 ns);
zuf_i128 ztp_ns_max_instant(void);

/* The stored form: floor(ns / 10^9) seconds and the remainder. */
void ztp_epoch_ns_split(zuf_i128 ns, double *seconds, double *nanoseconds);
zuf_i128 ztp_epoch_ns_join(double seconds, double nanoseconds);

/* --- zones -------------------------------------------------------------- */

typedef enum {
    ZTP_ZONE_UTC = 0,       /* the identifier "UTC" */
    ZTP_ZONE_OFFSET = 1     /* "+HH:MM": a fixed offset in whole minutes */
} ztp_zone_kind;

#define ZTP_ZONE_ID_CAP 48

typedef struct {
    ztp_zone_kind kind;
    int64_t offset_ns;             /* the offset for ZTP_ZONE_OFFSET */
    char id[ZTP_ZONE_ID_CAP];      /* the normalised identifier */
} ztp_zone;

/* ToTemporalTimeZoneIdentifier for the kinds above: "UTC" in any case,
   or an offset "+HH", "+HHMM" or "+HH:MM". A sub-minute offset or an
   unknown form is ZTP_ERR_RANGE; an IANA name is ZTP_ERR_TZ until the
   database arrives (stage 6). */
ztp_status ztp_zone_parse(ztp_ctx *ctx, size_t index, const char *s, size_t n,
                          ztp_zone *out);

/* GetOffsetNanosecondsFor and TimeZoneEquals ("+00:00" and "UTC" are not
   equal, design 6.7). */
int64_t ztp_zone_offset_at(const ztp_zone *zone, zuf_i128 epoch_ns);
bool ztp_zone_equals(const ztp_zone *a, const ztp_zone *b);

/* FormatDateTimeUTCOffsetRounded: "+HH:MM" from an offset in ns. dst has
   room for 8 bytes. */
size_t ztp_format_offset(char *dst, int64_t offset_ns);

/* --- instants and wall-clock times -------------------------------------- */

/* GetISODateTimeFor with a known offset: the local date and time. */
void ztp_instant_to_local(zuf_i128 epoch_ns, int64_t offset_ns, int32_t *day,
                          int64_t *ns_of_day);

/* The epoch nanoseconds of a local date-time at a known offset, with
   CheckISODaysRange and IsValidEpochNanoseconds. */
ztp_status ztp_instant_from_local(ztp_ctx *ctx, size_t index, int64_t day,
                                  int64_t ns_of_day, int64_t offset_ns,
                                  zuf_i128 *out);

/* RoundTemporalInstant: as if positive. */
zuf_i128 ztp_round_instant(zuf_i128 ns, int64_t increment, ztp_unit unit,
                           ztp_rounding_mode mode);

/* TemporalInstantToString: "Z" when zone is NULL, else the local time in
   the zone with its offset. dst has ZTP_FORMAT_DATE_TIME_CAP bytes. */
size_t ztp_format_instant(char *dst, zuf_i128 epoch_ns, const ztp_zone *zone,
                          int precision);

#endif /* ZTP_INSTANT_H */
