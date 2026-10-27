# Changelog

## zutempo 0.0.0.9000

- Operators on dates and times are a `zutempo_type_error` that names the
  function to use, such as
  [`temporal_add()`](https://pedrobtz.github.io/zutempo/reference/temporal_add.md)
  or
  [`temporal_equals()`](https://pedrobtz.github.io/zutempo/reference/temporal_equals.md).
  Before, base R’s operators ran on the stored numbers and gave wrong
  values (`instant(x) + 0.5`) or answers that disagreed with
  [`temporal_equals()`](https://pedrobtz.github.io/zutempo/reference/temporal_equals.md)
  (`z1 == z2`). [`min()`](https://rdrr.io/r/base/Extremes.html),
  [`max()`](https://rdrr.io/r/base/Extremes.html) and
  [`range()`](https://rdrr.io/r/base/range.html) return a value of the
  same type, in the order [`sort()`](https://rdrr.io/r/base/sort.html)
  uses; a
  [`plain_month_day()`](https://pedrobtz.github.io/zutempo/reference/plain_month_day.md)
  has no order, so they are errors there, as
  [`sum()`](https://rdrr.io/r/base/sum.html) and the others are on every
  type.

- The system time zone reads `TZ` in the forms the C library accepts: a
  leading `:` is dropped, and a path under a zone directory names its
  zone. A zone that is set but cannot be read gives `"UTC"` with a
  `zutempo_tz_warning`, where before it gave `"UTC"` silently.

- [`as.POSIXct()`](https://rdrr.io/r/base/as.POSIXlt.html) and
  [`as.POSIXlt()`](https://rdrr.io/r/base/as.POSIXlt.html) of a zoned
  value give an offset of `-13:00` or `-14:00` the tzone `"UTC"` rather
  than an `Etc/GMT` zone tzdata lacks, and keep the tzone of zones that
  are equal under `TimeZoneEquals`, such as `Asia/Calcutta` and
  `Asia/Kolkata`. The help page says that
  [`as.POSIXlt()`](https://rdrr.io/r/base/as.POSIXlt.html) of mixed
  zones does not round-trip.

- Documentation: a README from Temporal to R, a table of every Temporal
  member and its R function on each type’s help page,
  [`?zutempo_options`](https://pedrobtz.github.io/zutempo/reference/zutempo_options.md)
  for the options the functions share, and articles on the package
  website: “Get started”, following one zoned value from construction to
  base R, and articles on plain dates and times, durations, instants and
  time zones, strings and formatting, and base R and data frames.

- Checked against test262’s Temporal tests (39,263 cases from 2,715
  files) and against base R’s offsets for every zone. Fixes from that:
  the constructors read a
  [`zoned_date_time()`](https://pedrobtz.github.io/zutempo/reference/zoned_date_time.md)
  (`plain_date(z)`, `plain_time(z)`, `plain_date_time(z)`,
  `instant(z)`); `relative_to = "-271821-04-19"` works;
  [`temporal_since()`](https://pedrobtz.github.io/zutempo/reference/temporal_until.md)
  and
  [`temporal_until()`](https://pedrobtz.github.io/zutempo/reference/temporal_until.md)
  on year-months raise a range error when the first of a month is not a
  valid date; a time zone string whose offset has seconds is an error
  even when they are zero; and a duration field computed from a large
  total is the nearest double.

- On macOS the time zone database is R’s own copy first, then the
  system’s, as base R reads it, so zutempo and `POSIXct` agree;
  `TZDIR = "macOS"` selects the system’s.

- Operations on zoned values no longer look for the time zone database
  on every call: the directory is found once per setting of
  `zutempo.tzdir` and `TZDIR`, and again after
  [`zutempo_tz_reset()`](https://pedrobtz.github.io/zutempo/reference/zutempo_tz_reset.md).
  Many short calls run several times faster.

- Conversions with base R’s dates and times:
  [`as.Date()`](https://rdrr.io/r/base/as.Date.html),
  [`as.POSIXct()`](https://rdrr.io/r/base/as.POSIXlt.html) and
  [`as.POSIXlt()`](https://rdrr.io/r/base/as.POSIXlt.html) on the
  zutempo types,
  [`temporal_to_difftime()`](https://pedrobtz.github.io/zutempo/reference/base-r.md)
  for a
  [`plain_time()`](https://pedrobtz.github.io/zutempo/reference/plain_time.md)
  or
  [`duration()`](https://pedrobtz.github.io/zutempo/reference/duration.md),
  and the other way through the constructors: `plain_date(<Date>)`,
  `instant(<POSIXct>)`, `zoned_date_time(<POSIXct>)`,
  `plain_date_time(<POSIXlt>)`, `plain_time(<difftime>)` and
  `duration(<difftime>)`. A `POSIXct` is read at its double’s exact
  value, rounded half to even to the nanosecond, and written as the
  nearest double second.

- Strings are read with every RFC 9557 annotation: any number of
  key-value annotations after the time zone, `[u-ca=iso8601]` in any
  case, and the `!` critical flag, which makes an unknown annotation or
  a second calendar an error. A calendar other than ISO 8601 is a
  `zutempo_range_error` on the types with a date and is ignored by
  [`instant()`](https://pedrobtz.github.io/zutempo/reference/instant.md)
  and
  [`plain_time()`](https://pedrobtz.github.io/zutempo/reference/plain_time.md),
  as in Temporal. A `zutempo_parse_error` carries `position`, the byte
  where the string failed. Time zone and calendar arguments take an ISO
  string that names one (`time_zone = "2026-03-07T12:00+01:00"`).

- [`temporal_to_string()`](https://pedrobtz.github.io/zutempo/reference/temporal_to_string.md)
  and [`format()`](https://rdrr.io/r/base/format.html) take the options
  of each type’s Temporal
  [`toString()`](https://rdrr.io/r/base/toString.html):
  `fractional_second_digits`, `smallest_unit` and `rounding_mode` on the
  types with a time and on durations, `calendar_name` on the types with
  a date, and `time_zone_name` and `offset` on a
  [`zoned_date_time()`](https://pedrobtz.github.io/zutempo/reference/zoned_date_time.md).

- `zutempo_parse(x, type)` reads a character vector as any of the eight
  types, with `NA` for the strings it cannot read, and
  [`zutempo_parse_errors()`](https://pedrobtz.github.io/zutempo/reference/zutempo_parse_errors.md)
  lists them with their index, byte position, class and message.

- Zone-aware arithmetic:
  [`temporal_add()`](https://pedrobtz.github.io/zutempo/reference/temporal_add.md),
  [`temporal_subtract()`](https://pedrobtz.github.io/zutempo/reference/temporal_add.md),
  [`temporal_since()`](https://pedrobtz.github.io/zutempo/reference/temporal_until.md),
  [`temporal_until()`](https://pedrobtz.github.io/zutempo/reference/temporal_until.md)
  and
  [`temporal_round()`](https://pedrobtz.github.io/zutempo/reference/temporal_round.md)
  on a
  [`zoned_date_time()`](https://pedrobtz.github.io/zutempo/reference/zoned_date_time.md),
  with date units through the calendar in the value’s zone and time
  units on the exact time, so a day across a clock change is not 24
  hours;
  [`temporal_get_time_zone_transition()`](https://pedrobtz.github.io/zutempo/reference/temporal_get_time_zone_transition.md);
  and
  [`temporal_round()`](https://pedrobtz.github.io/zutempo/reference/temporal_round.md),
  [`temporal_total()`](https://pedrobtz.github.io/zutempo/reference/temporal_total.md)
  and
  [`duration_compare()`](https://pedrobtz.github.io/zutempo/reference/duration.md)
  with a
  [`zoned_date_time()`](https://pedrobtz.github.io/zutempo/reference/zoned_date_time.md)
  as `relative_to`, where days follow the zone (`PT25H` rounded to days
  relative to 2026-03-07 in New York is `P1DT2H`).

- [`zoned_date_time()`](https://pedrobtz.github.io/zutempo/reference/zoned_date_time.md):
  Temporal’s `ZonedDateTime` as an R vector with a time zone per
  element, from RFC 9557 strings with the zone in brackets
  (`"2026-03-07T12:00[America/New_York]"`) or from fields with
  `time_zone`, resolving clock gaps and folds with `disambiguation` and
  a disagreeing UTC offset with `offset`. Every calendar and clock
  field,
  [`offset()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md),
  [`offset_nanoseconds()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md),
  [`time_zone_id()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md),
  [`hours_in_day()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md),
  [`temporal_start_of_day()`](https://pedrobtz.github.io/zutempo/reference/temporal_start_of_day.md),
  [`temporal_with()`](https://pedrobtz.github.io/zutempo/reference/temporal_with.md),
  [`temporal_with_plain_time()`](https://pedrobtz.github.io/zutempo/reference/temporal_with.md),
  [`temporal_with_time_zone()`](https://pedrobtz.github.io/zutempo/reference/temporal_with.md),
  [`temporal_to_instant()`](https://pedrobtz.github.io/zutempo/reference/temporal_to_instant.md),
  the conversions to the plain types,
  [`temporal_equals()`](https://pedrobtz.github.io/zutempo/reference/temporal_equals.md)
  through `TimeZoneEquals`,
  [`zoned_date_time_compare()`](https://pedrobtz.github.io/zutempo/reference/zoned_date_time.md)
  and
  [`temporal_to_string()`](https://pedrobtz.github.io/zutempo/reference/temporal_to_string.md);
  [`temporal_to_zoned_date_time_iso()`](https://pedrobtz.github.io/zutempo/reference/temporal_to_instant.md)
  on an
  [`instant()`](https://pedrobtz.github.io/zutempo/reference/instant.md)
  and
  [`temporal_to_zoned_date_time()`](https://pedrobtz.github.io/zutempo/reference/temporal_to_instant.md)
  on a
  [`plain_date()`](https://pedrobtz.github.io/zutempo/reference/plain_date.md)
  or
  [`plain_date_time()`](https://pedrobtz.github.io/zutempo/reference/plain_date_time.md);
  [`now_time_zone_id()`](https://pedrobtz.github.io/zutempo/reference/now_time_zone_id.md),
  [`now_zoned_date_time_iso()`](https://pedrobtz.github.io/zutempo/reference/now_time_zone_id.md),
  [`now_plain_date_time_iso()`](https://pedrobtz.github.io/zutempo/reference/now_time_zone_id.md),
  [`now_plain_date_iso()`](https://pedrobtz.github.io/zutempo/reference/now_time_zone_id.md)
  and
  [`now_plain_time_iso()`](https://pedrobtz.github.io/zutempo/reference/now_time_zone_id.md).
  Mixed zones combine, subset, sort and sit in data frames; `vctrs` sees
  a record of instant and zone.

- Named IANA time zones resolve from the time zone database base R
  reads, in base R’s lookup order (option `zutempo.tzdir`, `TZDIR`, then
  the platform’s copies), on fat and slim files alike, with
  case-insensitive identifiers returned in the database’s case.
  [`temporal_to_string()`](https://pedrobtz.github.io/zutempo/reference/temporal_to_string.md)
  on an
  [`instant()`](https://pedrobtz.github.io/zutempo/reference/instant.md)
  takes a named `time_zone`;
  [`zutempo_tz_reset()`](https://pedrobtz.github.io/zutempo/reference/zutempo_tz_reset.md)
  forgets the parsed zones;
  [`zutempo_info()`](https://pedrobtz.github.io/zutempo/reference/zutempo_info.md)
  reports the database’s directory, tzdata version and form (fat or
  slim) and the link table’s version. A named zone without a database is
  a `zutempo_tz_error` naming the directories tried.

- [`instant()`](https://pedrobtz.github.io/zutempo/reference/instant.md):
  Temporal’s `Instant` over its full range, from strings with `Z` or an
  offset,
  [`instant_from_epoch_milliseconds()`](https://pedrobtz.github.io/zutempo/reference/instant.md)
  and
  [`instant_from_epoch_nanoseconds()`](https://pedrobtz.github.io/zutempo/reference/instant.md)
  (numbers or decimal strings), with
  [`epoch_milliseconds()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md),
  [`epoch_nanoseconds()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md)
  as a decimal string,
  [`instant_compare()`](https://pedrobtz.github.io/zutempo/reference/instant.md),
  [`temporal_equals()`](https://pedrobtz.github.io/zutempo/reference/temporal_equals.md),
  [`temporal_add()`](https://pedrobtz.github.io/zutempo/reference/temporal_add.md),
  [`temporal_subtract()`](https://pedrobtz.github.io/zutempo/reference/temporal_add.md),
  [`temporal_since()`](https://pedrobtz.github.io/zutempo/reference/temporal_until.md),
  [`temporal_until()`](https://pedrobtz.github.io/zutempo/reference/temporal_until.md),
  [`temporal_round()`](https://pedrobtz.github.io/zutempo/reference/temporal_round.md)
  as if positive, and
  [`temporal_to_string()`](https://pedrobtz.github.io/zutempo/reference/temporal_to_string.md)
  with a `time_zone` of `"UTC"` or a fixed offset;
  [`now_instant()`](https://pedrobtz.github.io/zutempo/reference/now_instant.md).

- [`duration()`](https://pedrobtz.github.io/zutempo/reference/duration.md):
  Temporal’s `Duration` as an R vector of ten exact fields, from fields
  or ISO 8601 strings, with
  [`years()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md)
  to
  [`nanoseconds()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md),
  [`blank()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md),
  [`sign()`](https://rdrr.io/r/base/sign.html) and
  [`abs()`](https://rdrr.io/r/base/MathFun.html),
  [`temporal_with()`](https://pedrobtz.github.io/zutempo/reference/temporal_with.md),
  [`temporal_negated()`](https://pedrobtz.github.io/zutempo/reference/temporal_negated.md),
  [`temporal_abs()`](https://pedrobtz.github.io/zutempo/reference/temporal_negated.md),
  [`temporal_add()`](https://pedrobtz.github.io/zutempo/reference/temporal_add.md),
  [`temporal_subtract()`](https://pedrobtz.github.io/zutempo/reference/temporal_add.md),
  [`temporal_round()`](https://pedrobtz.github.io/zutempo/reference/temporal_round.md),
  [`temporal_total()`](https://pedrobtz.github.io/zutempo/reference/temporal_total.md),
  [`duration_compare()`](https://pedrobtz.github.io/zutempo/reference/duration.md)
  and
  [`temporal_to_string()`](https://pedrobtz.github.io/zutempo/reference/temporal_to_string.md);
  calendar units take `relative_to`. `==` compares fields, and `<` and
  [`sort()`](https://rdrr.io/r/base/sort.html) order durations free of
  calendar units.

- [`temporal_add()`](https://pedrobtz.github.io/zutempo/reference/temporal_add.md),
  [`temporal_subtract()`](https://pedrobtz.github.io/zutempo/reference/temporal_add.md),
  [`temporal_since()`](https://pedrobtz.github.io/zutempo/reference/temporal_until.md)
  and
  [`temporal_until()`](https://pedrobtz.github.io/zutempo/reference/temporal_until.md)
  on
  [`plain_date()`](https://pedrobtz.github.io/zutempo/reference/plain_date.md),
  [`plain_time()`](https://pedrobtz.github.io/zutempo/reference/plain_time.md),
  [`plain_date_time()`](https://pedrobtz.github.io/zutempo/reference/plain_date_time.md)
  and
  [`plain_year_month()`](https://pedrobtz.github.io/zutempo/reference/plain_year_month.md),
  with `overflow`, `largest_unit`, `smallest_unit`, `rounding_increment`
  and `rounding_mode`.

- [`plain_year_month()`](https://pedrobtz.github.io/zutempo/reference/plain_year_month.md)
  and
  [`plain_month_day()`](https://pedrobtz.github.io/zutempo/reference/plain_month_day.md):
  Temporal’s `PlainYearMonth` and `PlainMonthDay` as R vectors, from
  fields, strings or dates, with their fields,
  [`temporal_with()`](https://pedrobtz.github.io/zutempo/reference/temporal_with.md),
  [`temporal_equals()`](https://pedrobtz.github.io/zutempo/reference/temporal_equals.md),
  [`plain_year_month_compare()`](https://pedrobtz.github.io/zutempo/reference/plain_year_month.md),
  [`temporal_to_string()`](https://pedrobtz.github.io/zutempo/reference/temporal_to_string.md)
  and
  [`temporal_to_plain_date()`](https://pedrobtz.github.io/zutempo/reference/temporal_to_plain_date.md)
  taking the missing `day` or `year`;
  [`temporal_to_plain_year_month()`](https://pedrobtz.github.io/zutempo/reference/temporal_to_plain_date.md)
  and
  [`temporal_to_plain_month_day()`](https://pedrobtz.github.io/zutempo/reference/temporal_to_plain_date.md)
  on a
  [`plain_date()`](https://pedrobtz.github.io/zutempo/reference/plain_date.md).

- [`plain_date()`](https://pedrobtz.github.io/zutempo/reference/plain_date.md),
  [`plain_time()`](https://pedrobtz.github.io/zutempo/reference/plain_time.md)
  and
  [`plain_date_time()`](https://pedrobtz.github.io/zutempo/reference/plain_date_time.md):
  Temporal’s `PlainDate`, `PlainTime` and `PlainDateTime` as R vectors,
  built from fields with `overflow`, from ISO 8601 strings, or from each
  other, with every field accessor
  ([`year()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md),
  [`month_code()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md),
  [`day_of_week()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md),
  [`week_of_year()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md),
  [`hour()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md),
  …),
  [`temporal_with()`](https://pedrobtz.github.io/zutempo/reference/temporal_with.md),
  [`temporal_with_plain_time()`](https://pedrobtz.github.io/zutempo/reference/temporal_with.md),
  [`temporal_with_calendar()`](https://pedrobtz.github.io/zutempo/reference/temporal_with.md),
  [`temporal_to_plain_date()`](https://pedrobtz.github.io/zutempo/reference/temporal_to_plain_date.md),
  [`temporal_to_plain_time()`](https://pedrobtz.github.io/zutempo/reference/temporal_to_plain_date.md),
  [`temporal_to_plain_date_time()`](https://pedrobtz.github.io/zutempo/reference/temporal_to_plain_date.md),
  [`temporal_equals()`](https://pedrobtz.github.io/zutempo/reference/temporal_equals.md),
  the `*_compare()` statics,
  [`temporal_round()`](https://pedrobtz.github.io/zutempo/reference/temporal_round.md)
  with the nine rounding modes, and
  [`temporal_to_string()`](https://pedrobtz.github.io/zutempo/reference/temporal_to_string.md).
  The vectors subset, combine, sort, print and sit in data frames;
  `vctrs` and `pillar` methods register when those packages load.

- [`zutempo_info()`](https://pedrobtz.github.io/zutempo/reference/zutempo_info.md)
  reports the package and `zufast` versions, whether the 128-bit
  arithmetic uses the compiler’s `__int128`, and the pinned commits of
  the Temporal specification and of test262 with the tzdata release the
  fixtures come from.

- The condition classes of the design: `zutempo_error`,
  `zutempo_range_error`, `zutempo_parse_error`, `zutempo_type_error` and
  `zutempo_tz_error`, each carrying the index of the first failing
  element.
