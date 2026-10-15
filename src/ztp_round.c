/* ztp_round.c -- see ztp_round.h. Engine side: no R. */

#include "ztp_round.h"

int64_t ztp_unit_length_ns(ztp_unit unit)
{
    switch (unit) {
    case ZTP_UNIT_DAY:         return ZTP_NS_PER_DAY;
    case ZTP_UNIT_HOUR:        return ZTP_NS_PER_HOUR;
    case ZTP_UNIT_MINUTE:      return ZTP_NS_PER_MINUTE;
    case ZTP_UNIT_SECOND:      return ZTP_NS_PER_SECOND;
    case ZTP_UNIT_MILLISECOND: return ZTP_NS_PER_MILLISECOND;
    case ZTP_UNIT_MICROSECOND: return ZTP_NS_PER_MICROSECOND;
    case ZTP_UNIT_NANOSECOND:  return 1;
    default:                   return 0;
    }
}

int64_t ztp_unit_max_increment(ztp_unit unit)
{
    switch (unit) {
    case ZTP_UNIT_HOUR:        return 24;
    case ZTP_UNIT_MINUTE:      return 60;
    case ZTP_UNIT_SECOND:      return 60;
    case ZTP_UNIT_MILLISECOND: return 1000;
    case ZTP_UNIT_MICROSECOND: return 1000;
    case ZTP_UNIT_NANOSECOND:  return 1000;
    default:                   return 0;
    }
}

/* The "Unsigned Rounding Mode" column of Table 29. */
typedef enum {
    ZTP_UNSIGNED_ZERO,
    ZTP_UNSIGNED_INFINITY,
    ZTP_UNSIGNED_HALF_ZERO,
    ZTP_UNSIGNED_HALF_INFINITY,
    ZTP_UNSIGNED_HALF_EVEN
} ztp_unsigned_mode;

/* GetUnsignedRoundingMode. */
static ztp_unsigned_mode ztp_unsigned_rounding_mode(ztp_rounding_mode mode,
                                                    bool negative)
{
    switch (mode) {
    case ZTP_ROUND_CEIL:        return negative ? ZTP_UNSIGNED_ZERO : ZTP_UNSIGNED_INFINITY;
    case ZTP_ROUND_FLOOR:       return negative ? ZTP_UNSIGNED_INFINITY : ZTP_UNSIGNED_ZERO;
    case ZTP_ROUND_EXPAND:      return ZTP_UNSIGNED_INFINITY;
    case ZTP_ROUND_TRUNC:       return ZTP_UNSIGNED_ZERO;
    case ZTP_ROUND_HALF_CEIL:   return negative ? ZTP_UNSIGNED_HALF_ZERO : ZTP_UNSIGNED_HALF_INFINITY;
    case ZTP_ROUND_HALF_FLOOR:  return negative ? ZTP_UNSIGNED_HALF_INFINITY : ZTP_UNSIGNED_HALF_ZERO;
    case ZTP_ROUND_HALF_EXPAND: return ZTP_UNSIGNED_HALF_INFINITY;
    case ZTP_ROUND_HALF_TRUNC:  return ZTP_UNSIGNED_HALF_ZERO;
    case ZTP_ROUND_HALF_EVEN:   return ZTP_UNSIGNED_HALF_EVEN;
    }
    return ZTP_UNSIGNED_ZERO;
}

/* ApplyUnsignedRoundingMode on the quotient magnitude/increment: r1 is the
   floor of the quotient, `remainder` what is left, both non-negative. */
static uint64_t ztp_apply_unsigned(uint64_t r1, uint64_t remainder,
                                   uint64_t increment, ztp_unsigned_mode mode)
{
    if (remainder == 0) return r1;
    switch (mode) {
    case ZTP_UNSIGNED_ZERO:     return r1;
    case ZTP_UNSIGNED_INFINITY: return r1 + 1;
    default: break;
    }
    /* Compare remainder with half the increment without overflow:
       2 * remainder < increment  <=>  remainder < increment - remainder. */
    if (remainder < increment - remainder) return r1;
    if (remainder > increment - remainder) return r1 + 1;
    switch (mode) {
    case ZTP_UNSIGNED_HALF_ZERO:     return r1;
    case ZTP_UNSIGNED_HALF_INFINITY: return r1 + 1;
    default:                         return (r1 % 2 == 0) ? r1 : r1 + 1;
    }
}

static int64_t ztp_round_core(int64_t x, int64_t increment,
                              ztp_rounding_mode mode, bool as_if_positive)
{
    bool negative = x < 0;
    uint64_t magnitude = negative ? (uint64_t)0 - (uint64_t)x : (uint64_t)x;
    uint64_t inc = (uint64_t)increment;
    uint64_t r1 = magnitude / inc;
    uint64_t remainder = magnitude % inc;
    ztp_unsigned_mode umode =
        ztp_unsigned_rounding_mode(mode, as_if_positive ? false : negative);
    uint64_t rounded = ztp_apply_unsigned(r1, remainder, inc, umode) * inc;

    return negative ? -(int64_t)rounded : (int64_t)rounded;
}

int64_t ztp_round_to_increment(int64_t x, int64_t increment,
                               ztp_rounding_mode mode)
{
    return ztp_round_core(x, increment, mode, false);
}

int64_t ztp_round_to_increment_as_if_positive(int64_t x, int64_t increment,
                                              ztp_rounding_mode mode)
{
    return ztp_round_core(x, increment, mode, true);
}

void ztp_round_time(int64_t ns_of_day, int64_t increment, ztp_unit unit,
                    ztp_rounding_mode mode, int64_t *out_ns,
                    int64_t *out_delta_days)
{
    /* RoundTime rounds the quantity below the next larger unit and keeps
       the larger fields: for day and hour the whole time, for minute the
       part within the hour, and so on. The rebalanced total is the kept
       part plus the rounded quantity. */
    int64_t span;   /* the length of the next larger unit, or the day */
    int64_t quantity, kept, total;

    switch (unit) {
    case ZTP_UNIT_DAY:
    case ZTP_UNIT_HOUR:        span = ZTP_NS_PER_DAY; break;
    case ZTP_UNIT_MINUTE:      span = ZTP_NS_PER_HOUR; break;
    case ZTP_UNIT_SECOND:      span = ZTP_NS_PER_MINUTE; break;
    case ZTP_UNIT_MILLISECOND: span = ZTP_NS_PER_SECOND; break;
    case ZTP_UNIT_MICROSECOND: span = ZTP_NS_PER_MILLISECOND; break;
    default:                   span = ZTP_NS_PER_MICROSECOND; break;
    }
    quantity = ns_of_day % span;
    kept = ns_of_day - quantity;
    total = kept + ztp_round_to_increment(quantity,
                                          increment * ztp_unit_length_ns(unit),
                                          mode);
    *out_delta_days = total / ZTP_NS_PER_DAY;
    *out_ns = total % ZTP_NS_PER_DAY;
}
