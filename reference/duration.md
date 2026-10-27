# Durations: Temporal's Duration

A `duration()` is a length of time in ten fields, years to nanoseconds,
each a float64-representable integer as Temporal defines them, stored as
a list of ten double vectors. All fields share one sign. Years, months
and weeks are calendar units: operations that need their length take
`relative_to`, a date, and fail without it.

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
  fraction only on the smallest unit present), a `duration()` to return
  as is, or a `difftime`, whose exact seconds become seconds and
  nanoseconds.

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
  [`plain_date_time()`](https://pedrobtz.github.io/zutempo/reference/plain_date_time.md),
  [`zoned_date_time()`](https://pedrobtz.github.io/zutempo/reference/zoned_date_time.md)
  or a string one of them reads (a zone in brackets makes it zoned): the
  start the calendar units are counted from; with a zoned value, days
  follow the zone. Required when either duration has years, months or
  weeks.

## Value

A `duration()` vector; `duration_compare()` returns an integer vector of
-1, 0 and 1.

## Members

Every member of `Temporal.Duration` in the pinned specification
(`inst/spec/PINS`) and the R function that implements it:

|  |  |
|----|----|
| Temporal | R |
| `new Temporal.Duration()` | `duration()` |
| `Temporal.Duration.from()` | `duration()` |
| `Temporal.Duration.compare()` | `duration_compare()` |
| `.years` | [`years()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md) |
| `.months` | [`months()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md) |
| `.weeks` | [`weeks()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md) |
| `.days` | [`days()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md) |
| `.hours` | [`hours()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md) |
| `.minutes` | [`minutes()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md) |
| `.seconds` | [`seconds()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md) |
| `.milliseconds` | [`milliseconds()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md) |
| `.microseconds` | [`microseconds()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md) |
| `.nanoseconds` | [`nanoseconds()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md) |
| `.sign` | [`sign()`](https://rdrr.io/r/base/sign.html) |
| `.blank` | [`blank()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md) |
| `.with()` | [`temporal_with()`](https://pedrobtz.github.io/zutempo/reference/temporal_with.md) |
| `.negated()` | [`temporal_negated()`](https://pedrobtz.github.io/zutempo/reference/temporal_negated.md) |
| `.abs()` | [`temporal_abs()`](https://pedrobtz.github.io/zutempo/reference/temporal_negated.md) |
| `.add()` | [`temporal_add()`](https://pedrobtz.github.io/zutempo/reference/temporal_add.md) |
| `.subtract()` | [`temporal_subtract()`](https://pedrobtz.github.io/zutempo/reference/temporal_add.md) |
| `.round()` | [`temporal_round()`](https://pedrobtz.github.io/zutempo/reference/temporal_round.md) |
| `.total()` | [`temporal_total()`](https://pedrobtz.github.io/zutempo/reference/temporal_total.md) |
| `.toString()` | [`temporal_to_string()`](https://pedrobtz.github.io/zutempo/reference/temporal_to_string.md) |
| `.toJSON()` | none: format() covers it |
| `.toLocaleString()` | none: ECMA-402 (locale formatting) is out of scope |
| `.valueOf()` | none: throws in JavaScript; no R counterpart |

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
