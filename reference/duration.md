# Durations: Temporal's Duration

A `duration()` is a length of time in ten fields, years to nanoseconds,
each a float64-representable integer as Temporal defines them, stored as
a list of ten double vectors (design 4.1). All fields share one sign.
Years, months and weeks are calendar units: operations that need their
length take `relative_to`, a date, and fail without it (design 6.5).

## Usage

``` r
duration(
  years = 0,
  months = 0,
  weeks = 0,
  days = 0,
  hours = 0,
  minutes = 0,
  seconds = 0,
  milliseconds = 0,
  microseconds = 0,
  nanoseconds = 0,
  ...
)

duration_compare(x, y, relative_to = NULL)
```

## Arguments

- years:

  The years, or a string in ISO 8601 form (`"P1Y2M3DT4H5M6.789S"`, a
  fraction only on the smallest unit present), or a `duration()` to
  return as is.

- months, weeks, days, hours, minutes, seconds, milliseconds,
  microseconds, nanoseconds:

  The remaining fields, 0 by default.

- ...:

  Must be empty.

- x, y:

  `duration()` values or strings, for `duration_compare()`.

- relative_to:

  A
  [`plain_date()`](https://pedrobtz.github.io/zutempo/reference/plain_date.md),
  [`plain_date_time()`](https://pedrobtz.github.io/zutempo/reference/plain_date_time.md)
  or a string either reads: the date the calendar units are counted
  from. Required when either duration has years, months or weeks.

## Value

A `duration()` vector; `duration_compare()` returns an integer vector of
-1, 0 and 1.

## Examples

``` r
duration("P1Y2M3DT4H5M6.789S")
#> <zutempo_duration[1]>
#> [1] P1Y2M3DT4H5M6.789S
duration(hours = 25)
#> <zutempo_duration[1]>
#> [1] PT25H
duration(milliseconds = 2^53 + 2)
#> <zutempo_duration[1]>
#> [1] PT9007199254740.994S
duration_compare("PT1H", "PT60M")
#> [1] 0
duration_compare("P1M", "P30D", relative_to = "2026-02-01")
#> [1] -1
```
