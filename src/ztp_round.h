/*
 * ztp_round.h -- Temporal units and rounding (Temporal 13.17 to 13.21,
 * 4.5.14 RoundTime). Engine side: no R.
 */
#ifndef ZTP_ROUND_H
#define ZTP_ROUND_H

#include "ztp_iso.h"

/* The units table (13.17), in its order. The R side passes these codes. */
typedef enum {
    ZTP_UNIT_YEAR = 0,
    ZTP_UNIT_MONTH = 1,
    ZTP_UNIT_WEEK = 2,
    ZTP_UNIT_DAY = 3,
    ZTP_UNIT_HOUR = 4,
    ZTP_UNIT_MINUTE = 5,
    ZTP_UNIT_SECOND = 6,
    ZTP_UNIT_MILLISECOND = 7,
    ZTP_UNIT_MICROSECOND = 8,
    ZTP_UNIT_NANOSECOND = 9
} ztp_unit;

/* The nine rounding modes of Table 28, in its order. */
typedef enum {
    ZTP_ROUND_CEIL = 0,
    ZTP_ROUND_FLOOR = 1,
    ZTP_ROUND_EXPAND = 2,
    ZTP_ROUND_TRUNC = 3,
    ZTP_ROUND_HALF_CEIL = 4,
    ZTP_ROUND_HALF_FLOOR = 5,
    ZTP_ROUND_HALF_EXPAND = 6,
    ZTP_ROUND_HALF_TRUNC = 7,
    ZTP_ROUND_HALF_EVEN = 8
} ztp_rounding_mode;

/* "Length in nanoseconds" for day and the time units. */
int64_t ztp_unit_length_ns(ztp_unit unit);

/* "Maximum duration rounding increment" for the time units, 0 for the
   date units (~unset~). */
int64_t ztp_unit_max_increment(ztp_unit unit);

/* RoundNumberToIncrement and RoundNumberToIncrementAsIfPositive over
   int64_t. increment > 0, and |x| + increment must fit. */
int64_t ztp_round_to_increment(int64_t x, int64_t increment,
                               ztp_rounding_mode mode);
int64_t ztp_round_to_increment_as_if_positive(int64_t x, int64_t increment,
                                              ztp_rounding_mode mode);

/* RoundTime: rounds a time of day to `increment` units; the result is a
   time of day plus the days it carried (0 or 1). unit is day or a time
   unit. */
void ztp_round_time(int64_t ns_of_day, int64_t increment, ztp_unit unit,
                    ztp_rounding_mode mode, int64_t *out_ns,
                    int64_t *out_delta_days);

#endif /* ZTP_ROUND_H */
