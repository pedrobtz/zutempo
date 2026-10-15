# Round a Temporal value

Temporal's [`round()`](https://rdrr.io/r/base/Round.html), to an
increment of `smallest_unit` with one of the nine rounding modes (design
6.4).
[`plain_time()`](https://pedrobtz.github.io/zutempo/reference/plain_time.md)
rounds within the day;
[`plain_date_time()`](https://pedrobtz.github.io/zutempo/reference/plain_date_time.md)
carries into the date and also accepts `"day"`.

## Usage

``` r
temporal_round(
  x,
  smallest_unit = NULL,
  rounding_increment = 1,
  rounding_mode = "halfExpand",
  ...
)

# S3 method for class 'zutempo_duration'
temporal_round(
  x,
  smallest_unit = NULL,
  rounding_increment = 1,
  rounding_mode = "halfExpand",
  ...,
  largest_unit = NULL,
  relative_to = NULL
)

# S3 method for class 'zutempo_instant'
temporal_round(
  x,
  smallest_unit = NULL,
  rounding_increment = 1,
  rounding_mode = "halfExpand",
  ...
)

# S3 method for class 'zutempo_plain_date_time'
temporal_round(
  x,
  smallest_unit = NULL,
  rounding_increment = 1,
  rounding_mode = "halfExpand",
  ...
)

# S3 method for class 'zutempo_plain_time'
temporal_round(
  x,
  smallest_unit = NULL,
  rounding_increment = 1,
  rounding_mode = "halfExpand",
  ...
)
```

## Arguments

- x:

  A zutempo value.

- smallest_unit:

  The unit to round to: `"hour"`, `"minute"`, `"second"`,
  `"millisecond"`, `"microsecond"` or `"nanosecond"`, or their plurals;
  `"day"` for a
  [`plain_date_time()`](https://pedrobtz.github.io/zutempo/reference/plain_date_time.md);
  any unit for a
  [`duration()`](https://pedrobtz.github.io/zutempo/reference/duration.md),
  which may instead give only `largest_unit`.

- rounding_increment:

  A positive integer that divides the next larger unit evenly: 24 hours,
  60 minutes or seconds, 1000 of the sub-second units, and 1 for
  `"day"`.

- rounding_mode:

  One of `"ceil"`, `"floor"`, `"expand"`, `"trunc"`, `"halfCeil"`,
  `"halfFloor"`, `"halfExpand"` (the default), `"halfTrunc"` or
  `"halfEven"`.

- ...:

  Must be empty, except for a
  [`duration()`](https://pedrobtz.github.io/zutempo/reference/duration.md)'s
  `largest_unit` and `relative_to`.

- largest_unit:

  For a
  [`duration()`](https://pedrobtz.github.io/zutempo/reference/duration.md):
  the unit to balance up to, `"auto"` or `NULL` for the duration's own
  largest unit.

- relative_to:

  For a
  [`duration()`](https://pedrobtz.github.io/zutempo/reference/duration.md):
  a
  [`plain_date()`](https://pedrobtz.github.io/zutempo/reference/plain_date.md),
  [`plain_date_time()`](https://pedrobtz.github.io/zutempo/reference/plain_date_time.md)
  or a string either reads, required to round years, months or weeks
  (design 6.5).

## Value

A value of the same class as `x`.

## Examples

``` r
temporal_round(plain_time("12:34:56"), "minute")
#> <zutempo_plain_time[1]>
#> [1] 12:35:00
temporal_round(plain_time("12:34:56"), "hour", rounding_mode = "floor")
#> <zutempo_plain_time[1]>
#> [1] 12:00:00
temporal_round(plain_date_time("2026-01-31T23:59"), "hour")
#> <zutempo_plain_date_time[1]>
#> [1] 2026-02-01T00:00:00
temporal_round(duration(hours = 25), largest_unit = "day")
#> <zutempo_duration[1]>
#> [1] P1DT1H
temporal_round(duration(hours = 25), largest_unit = "day", relative_to = "2026-03-07")
#> <zutempo_duration[1]>
#> [1] P1DT1H
```
