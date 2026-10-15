# Package index

## Types

Temporal’s eight types, each built by the function named after it from
fields, strings or other values. Each topic lists every member of the
type and the R function that implements it.

- [`instant()`](https://pedrobtz.github.io/zutempo/reference/instant.md)
  [`instant_from_epoch_milliseconds()`](https://pedrobtz.github.io/zutempo/reference/instant.md)
  [`instant_from_epoch_nanoseconds()`](https://pedrobtz.github.io/zutempo/reference/instant.md)
  [`instant_compare()`](https://pedrobtz.github.io/zutempo/reference/instant.md)
  : Exact times: Temporal's Instant
- [`zoned_date_time()`](https://pedrobtz.github.io/zutempo/reference/zoned_date_time.md)
  [`zoned_date_time_compare()`](https://pedrobtz.github.io/zutempo/reference/zoned_date_time.md)
  : Exact times in a time zone: Temporal's ZonedDateTime
- [`plain_date_time()`](https://pedrobtz.github.io/zutempo/reference/plain_date_time.md)
  [`plain_date_time_compare()`](https://pedrobtz.github.io/zutempo/reference/plain_date_time.md)
  : Calendar dates with clock times: Temporal's PlainDateTime
- [`plain_date()`](https://pedrobtz.github.io/zutempo/reference/plain_date.md)
  [`plain_date_compare()`](https://pedrobtz.github.io/zutempo/reference/plain_date.md)
  : Calendar dates: Temporal's PlainDate
- [`plain_time()`](https://pedrobtz.github.io/zutempo/reference/plain_time.md)
  [`plain_time_compare()`](https://pedrobtz.github.io/zutempo/reference/plain_time.md)
  : Clock times: Temporal's PlainTime
- [`plain_year_month()`](https://pedrobtz.github.io/zutempo/reference/plain_year_month.md)
  [`plain_year_month_compare()`](https://pedrobtz.github.io/zutempo/reference/plain_year_month.md)
  : Months: Temporal's PlainYearMonth
- [`plain_month_day()`](https://pedrobtz.github.io/zutempo/reference/plain_month_day.md)
  : Days of the year: Temporal's PlainMonthDay
- [`duration()`](https://pedrobtz.github.io/zutempo/reference/duration.md)
  [`duration_compare()`](https://pedrobtz.github.io/zutempo/reference/duration.md)
  : Durations: Temporal's Duration

## Properties

Temporal’s properties, as accessors named after them.

- [`calendar_id()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md)
  [`era()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md)
  [`era_year()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md)
  [`year()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md)
  [`month()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md)
  [`month_code()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md)
  [`day()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md)
  [`day_of_week()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md)
  [`day_of_year()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md)
  [`week_of_year()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md)
  [`year_of_week()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md)
  [`days_in_week()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md)
  [`days_in_month()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md)
  [`days_in_year()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md)
  [`months_in_year()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md)
  [`in_leap_year()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md)
  [`hour()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md)
  [`minute()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md)
  [`second()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md)
  [`millisecond()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md)
  [`microsecond()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md)
  [`nanosecond()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md)
  [`years()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md)
  [`months()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md)
  [`weeks()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md)
  [`days()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md)
  [`hours()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md)
  [`minutes()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md)
  [`seconds()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md)
  [`milliseconds()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md)
  [`microseconds()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md)
  [`nanoseconds()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md)
  [`blank()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md)
  [`Math(`*`<zutempo_duration>`*`)`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md)
  [`epoch_milliseconds()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md)
  [`epoch_nanoseconds()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md)
  [`offset_nanoseconds()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md)
  [`offset()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md)
  [`time_zone_id()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md)
  [`hours_in_day()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md)
  : Fields of a Temporal value

## Methods

Temporal’s prototype methods, as `temporal_` and the method name.

- [`temporal_add()`](https://pedrobtz.github.io/zutempo/reference/temporal_add.md)
  [`temporal_subtract()`](https://pedrobtz.github.io/zutempo/reference/temporal_add.md)
  : Add a duration to, or subtract one from, a Temporal value
- [`temporal_until()`](https://pedrobtz.github.io/zutempo/reference/temporal_until.md)
  [`temporal_since()`](https://pedrobtz.github.io/zutempo/reference/temporal_until.md)
  : Difference between two Temporal values
- [`temporal_round()`](https://pedrobtz.github.io/zutempo/reference/temporal_round.md)
  : Round a Temporal value
- [`temporal_total()`](https://pedrobtz.github.io/zutempo/reference/temporal_total.md)
  : Total a duration in one unit
- [`temporal_with()`](https://pedrobtz.github.io/zutempo/reference/temporal_with.md)
  [`temporal_with_plain_time()`](https://pedrobtz.github.io/zutempo/reference/temporal_with.md)
  [`temporal_with_calendar()`](https://pedrobtz.github.io/zutempo/reference/temporal_with.md)
  [`temporal_with_time_zone()`](https://pedrobtz.github.io/zutempo/reference/temporal_with.md)
  : Replace fields of a Temporal value
- [`temporal_equals()`](https://pedrobtz.github.io/zutempo/reference/temporal_equals.md)
  : Compare Temporal values
- [`temporal_negated()`](https://pedrobtz.github.io/zutempo/reference/temporal_negated.md)
  [`temporal_abs()`](https://pedrobtz.github.io/zutempo/reference/temporal_negated.md)
  : Negate or take the magnitude of a duration
- [`temporal_start_of_day()`](https://pedrobtz.github.io/zutempo/reference/temporal_start_of_day.md)
  : The start of a day in a time zone
- [`temporal_get_time_zone_transition()`](https://pedrobtz.github.io/zutempo/reference/temporal_get_time_zone_transition.md)
  : Time zone transitions
- [`temporal_to_instant()`](https://pedrobtz.github.io/zutempo/reference/temporal_to_instant.md)
  [`temporal_to_zoned_date_time_iso()`](https://pedrobtz.github.io/zutempo/reference/temporal_to_instant.md)
  [`temporal_to_zoned_date_time()`](https://pedrobtz.github.io/zutempo/reference/temporal_to_instant.md)
  : Convert to and from zoned values
- [`temporal_to_plain_date()`](https://pedrobtz.github.io/zutempo/reference/temporal_to_plain_date.md)
  [`temporal_to_plain_time()`](https://pedrobtz.github.io/zutempo/reference/temporal_to_plain_date.md)
  [`temporal_to_plain_date_time()`](https://pedrobtz.github.io/zutempo/reference/temporal_to_plain_date.md)
  [`temporal_to_plain_year_month()`](https://pedrobtz.github.io/zutempo/reference/temporal_to_plain_date.md)
  [`temporal_to_plain_month_day()`](https://pedrobtz.github.io/zutempo/reference/temporal_to_plain_date.md)
  : Convert between the plain types
- [`temporal_to_string()`](https://pedrobtz.github.io/zutempo/reference/temporal_to_string.md)
  : Format a Temporal value as an ISO 8601 string

## Now

`Temporal.Now`: the system time zone and the current time.

- [`now_time_zone_id()`](https://pedrobtz.github.io/zutempo/reference/now_time_zone_id.md)
  [`now_zoned_date_time_iso()`](https://pedrobtz.github.io/zutempo/reference/now_time_zone_id.md)
  [`now_plain_date_time_iso()`](https://pedrobtz.github.io/zutempo/reference/now_time_zone_id.md)
  [`now_plain_date_iso()`](https://pedrobtz.github.io/zutempo/reference/now_time_zone_id.md)
  [`now_plain_time_iso()`](https://pedrobtz.github.io/zutempo/reference/now_time_zone_id.md)
  : The current time in a time zone
- [`now_instant()`](https://pedrobtz.github.io/zutempo/reference/now_instant.md)
  : The current time

## Conversions and reading

- [`as.Date(`*`<zutempo_plain_date>`*`)`](https://pedrobtz.github.io/zutempo/reference/base-r.md)
  [`as.Date(`*`<zutempo_plain_date_time>`*`)`](https://pedrobtz.github.io/zutempo/reference/base-r.md)
  [`as.Date(`*`<zutempo_zoned_date_time>`*`)`](https://pedrobtz.github.io/zutempo/reference/base-r.md)
  [`as.Date(`*`<zutempo_instant>`*`)`](https://pedrobtz.github.io/zutempo/reference/base-r.md)
  [`as.POSIXct(`*`<zutempo_instant>`*`)`](https://pedrobtz.github.io/zutempo/reference/base-r.md)
  [`as.POSIXct(`*`<zutempo_zoned_date_time>`*`)`](https://pedrobtz.github.io/zutempo/reference/base-r.md)
  [`as.POSIXct(`*`<zutempo_plain_date_time>`*`)`](https://pedrobtz.github.io/zutempo/reference/base-r.md)
  [`as.POSIXlt(`*`<zutempo_zoned_date_time>`*`)`](https://pedrobtz.github.io/zutempo/reference/base-r.md)
  [`as.POSIXlt(`*`<zutempo_instant>`*`)`](https://pedrobtz.github.io/zutempo/reference/base-r.md)
  [`as.POSIXlt(`*`<zutempo_plain_date_time>`*`)`](https://pedrobtz.github.io/zutempo/reference/base-r.md)
  [`temporal_to_difftime()`](https://pedrobtz.github.io/zutempo/reference/base-r.md)
  : Convert Temporal values to base R dates and times

- [`zutempo_parse()`](https://pedrobtz.github.io/zutempo/reference/zutempo_parse.md)
  :

  Read strings as a Temporal type, with `NA` for those that fail

- [`zutempo_parse_errors()`](https://pedrobtz.github.io/zutempo/reference/zutempo_parse_errors.md)
  :

  The strings
  [`zutempo_parse()`](https://pedrobtz.github.io/zutempo/reference/zutempo_parse.md)
  could not read

## Options

- [`zutempo_options`](https://pedrobtz.github.io/zutempo/reference/zutempo_options.md)
  : Options shared by zutempo's functions

## The package

- [`zutempo`](https://pedrobtz.github.io/zutempo/reference/zutempo-package.md)
  [`zutempo-package`](https://pedrobtz.github.io/zutempo/reference/zutempo-package.md)
  : zutempo: Dates, Times and Durations Following the 'TC39' Temporal
  Specification
- [`zutempo_info()`](https://pedrobtz.github.io/zutempo/reference/zutempo_info.md)
  : What zutempo was built against
- [`zutempo_tz_reset()`](https://pedrobtz.github.io/zutempo/reference/zutempo_tz_reset.md)
  : Forget the parsed time zones
