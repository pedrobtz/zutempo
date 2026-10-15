/*
 * ztp_zoned.h -- ZonedDateTime over the zone object of ztp_instant.h
 * (design 4.2, 6.3): the candidates a local date-time may denote, their
 * disambiguation, the start of a day, and the string form. Engine side:
 * no R.
 */
#ifndef ZTP_ZONED_H
#define ZTP_ZONED_H

#include "ztp_instant.h"

typedef enum {
    ZTP_DISAMBIGUATION_COMPATIBLE = 0,
    ZTP_DISAMBIGUATION_EARLIER = 1,
    ZTP_DISAMBIGUATION_LATER = 2,
    ZTP_DISAMBIGUATION_REJECT = 3
} ztp_disambiguation;

typedef enum {
    ZTP_OFFSET_PREFER = 0,
    ZTP_OFFSET_USE = 1,
    ZTP_OFFSET_IGNORE = 2,
    ZTP_OFFSET_REJECT = 3
} ztp_offset_option;

/* InterpretISODateTimeOffset's offsetBehaviour, plus ~start-of-day~ for a
   string without a time. */
typedef enum {
    ZTP_OFFSET_BEHAVIOUR_OPTION = 0,
    ZTP_OFFSET_BEHAVIOUR_EXACT = 1,
    ZTP_OFFSET_BEHAVIOUR_WALL = 2,
    ZTP_OFFSET_BEHAVIOUR_START_OF_DAY = 3
} ztp_offset_behaviour;

/* GetPossibleEpochNanoseconds: 0, 1 or 2 candidates in ascending order,
   each a valid epoch value (ZTP_ERR_RANGE otherwise). */
ztp_status ztp_zone_possible(ztp_ctx *ctx, size_t index, const ztp_zone *zone,
                             int64_t day, int64_t ns_of_day, zuf_i128 out[2], int *n);

/* GetEpochNanosecondsFor: the candidates, disambiguated. */
ztp_status ztp_zone_epoch_ns_for(ztp_ctx *ctx, size_t index, const ztp_zone *zone,
                                 int64_t day, int64_t ns_of_day,
                                 ztp_disambiguation disambiguation, zuf_i128 *out);

/* GetStartOfDay. */
ztp_status ztp_zone_start_of_day(ztp_ctx *ctx, size_t index, const ztp_zone *zone,
                                 int64_t day, zuf_i128 *out);

/* InterpretISODateTimeOffset. */
ztp_status ztp_interpret_iso_date_time_offset(ztp_ctx *ctx, size_t index,
                                              int64_t day, int64_t ns_of_day,
                                              ztp_offset_behaviour behaviour,
                                              int64_t offset_ns, const ztp_zone *zone,
                                              ztp_disambiguation disambiguation,
                                              ztp_offset_option offset_option,
                                              bool match_minutes, zuf_i128 *out);

/* GetISODateTimeFor and GetOffsetNanosecondsFor together. */
void ztp_zoned_local(const ztp_zone *zone, zuf_i128 epoch_ns, int32_t *day,
                     int64_t *ns_of_day, int64_t *offset_ns);

/* Temporal.ZonedDateTime.prototype.hoursInDay. */
ztp_status ztp_zoned_hours_in_day(ztp_ctx *ctx, size_t index, const ztp_zone *zone,
                                  zuf_i128 epoch_ns, double *out);

/* FormatUTCOffsetNanoseconds: to the minute, or with seconds and a
   fraction when the offset has them. */
size_t ztp_format_offset_exact(char *dst, int64_t offset_ns);

typedef enum { ZTP_SHOW_ZONE_AUTO = 0, ZTP_SHOW_ZONE_NEVER = 1, ZTP_SHOW_ZONE_CRITICAL = 2 } ztp_show_zone;

#define ZTP_FORMAT_ZONED_CAP (ZTP_FORMAT_DATE_TIME_CAP + 8 + ZTP_ZONE_ID_CAP + 16)

/* TemporalZonedDateTimeToString without rounding (stage 9 adds it). dst
   has ZTP_FORMAT_ZONED_CAP bytes. */
size_t ztp_format_zoned(char *dst, zuf_i128 epoch_ns, const ztp_zone *zone,
                        int precision, bool show_offset, ztp_show_zone show_zone);

#endif /* ZTP_ZONED_H */
