# Format a Temporal value as an ISO 8601 string

Temporal's [`toString()`](https://rdrr.io/r/base/toString.html).
[`format()`](https://rdrr.io/r/base/format.html) takes the same options
and [`as.character()`](https://rdrr.io/r/base/character.html) gives the
default strings. Years outside 0 to 9999 are written with a sign and six
digits. By default a time's fraction keeps only its significant digits,
and a UTC offset is written as `+HH:MM` or `-HH:MM`, rounded to the
minute (design 9).

## Usage

``` r
temporal_to_string(x, ...)

# S3 method for class 'zutempo_duration'
temporal_to_string(
  x,
  ...,
  fractional_second_digits = "auto",
  smallest_unit = NULL,
  rounding_mode = "trunc"
)

# S3 method for class 'zutempo_instant'
temporal_to_string(
  x,
  ...,
  fractional_second_digits = "auto",
  smallest_unit = NULL,
  rounding_mode = "trunc",
  time_zone = NULL
)

# S3 method for class 'zutempo_plain_date_time'
temporal_to_string(
  x,
  ...,
  fractional_second_digits = "auto",
  smallest_unit = NULL,
  rounding_mode = "trunc",
  calendar_name = "auto"
)

# S3 method for class 'zutempo_plain_date'
temporal_to_string(x, ..., calendar_name = "auto")

# S3 method for class 'zutempo_plain_month_day'
temporal_to_string(x, ..., calendar_name = "auto")

# S3 method for class 'zutempo_plain_time'
temporal_to_string(
  x,
  ...,
  fractional_second_digits = "auto",
  smallest_unit = NULL,
  rounding_mode = "trunc"
)

# S3 method for class 'zutempo_plain_year_month'
temporal_to_string(x, ..., calendar_name = "auto")

# S3 method for class 'zutempo_zoned_date_time'
temporal_to_string(
  x,
  ...,
  fractional_second_digits = "auto",
  smallest_unit = NULL,
  rounding_mode = "trunc",
  calendar_name = "auto",
  time_zone_name = "auto",
  offset = "auto"
)
```

## Arguments

- x:

  A zutempo value.

- ...:

  Must be empty.

- fractional_second_digits:

  `"auto"` (the default) for the significant digits of the fraction, or
  0 to 9 for exactly that many.

- smallest_unit:

  `NULL` (the default), or the smallest unit to write: `"minute"` (not
  for a duration), `"second"`, `"millisecond"`, `"microsecond"` or
  `"nanosecond"`. It wins over `fractional_second_digits`.

- rounding_mode:

  How a value is rounded to the precision: `"trunc"` (the default) or
  another of the nine Temporal modes, as in
  [`temporal_round()`](https://pedrobtz.github.io/zutempo/reference/temporal_round.md).

- time_zone:

  For an
  [`instant()`](https://pedrobtz.github.io/zutempo/reference/instant.md):
  a time zone to show the time in, `"UTC"`, a fixed offset such as
  `"+05:30"`, an IANA identifier such as `"Europe/Lisbon"`, or an ISO
  string that names one; `NULL` (the default) writes the time in UTC
  with `Z`.

- calendar_name:

  Whether to write the `[u-ca=iso8601]` annotation: `"auto"` (the
  default) and `"never"` leave it out, `"always"` writes it,
  `"critical"` writes it with the `!` flag. A year-month or month-day
  written with the annotation also shows its reference day or year.

- time_zone_name:

  For a
  [`zoned_date_time()`](https://pedrobtz.github.io/zutempo/reference/zoned_date_time.md):
  `"auto"` (the default) writes the time zone annotation, `"never"`
  leaves it out, `"critical"` writes it with the `!` flag.

- offset:

  For a
  [`zoned_date_time()`](https://pedrobtz.github.io/zutempo/reference/zoned_date_time.md):
  `"auto"` (the default) writes the UTC offset, `"never"` leaves it out.

## Value

A character vector, `NA` where `x` is `NA`.

## Details

Each type takes the options its Temporal
[`toString()`](https://rdrr.io/r/base/toString.html) has: the precision
options on the types with a time, `calendar_name` on the types with a
date, and `time_zone_name` and `offset` on a
[`zoned_date_time()`](https://pedrobtz.github.io/zutempo/reference/zoned_date_time.md).
A value rounded by `smallest_unit` or `fractional_second_digits` is
rounded before it is written: a time wraps past midnight, a date-time
moves to the next day, and a duration rounds its time part only.

## Examples

``` r
temporal_to_string(plain_date(c(2026, 275760), c(1, 9), c(31, 13)))
#> [1] "2026-01-31"    "+275760-09-13"
temporal_to_string(instant("2026-01-31T12:30Z"), time_zone = "+05:30")
#> [1] "2026-01-31T18:00:00+05:30"
temporal_to_string(plain_time(12, 30, 45, 500))
#> [1] "12:30:45.5"
temporal_to_string(plain_time("23:59:59.987"), fractional_second_digits = 1)
#> [1] "23:59:59.9"
temporal_to_string(
  plain_date_time("2026-01-31T12:30:45.5"),
  smallest_unit = "second",
  rounding_mode = "halfExpand",
  calendar_name = "always"
)
#> [1] "2026-01-31T12:30:46[u-ca=iso8601]"
format(duration("PT1M30.25S"), smallest_unit = "second", rounding_mode = "ceil")
#> [1] "PT1M31S"
```
