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
  smallest_unit,
  rounding_increment = 1,
  rounding_mode = "halfExpand"
)

# S3 method for class 'zutempo_plain_date_time'
temporal_round(
  x,
  smallest_unit,
  rounding_increment = 1,
  rounding_mode = "halfExpand"
)

# S3 method for class 'zutempo_plain_time'
temporal_round(
  x,
  smallest_unit,
  rounding_increment = 1,
  rounding_mode = "halfExpand"
)
```

## Arguments

- x:

  A zutempo value.

- smallest_unit:

  The unit to round to: `"hour"`, `"minute"`, `"second"`,
  `"millisecond"`, `"microsecond"` or `"nanosecond"`, or their plurals;
  `"day"` for a
  [`plain_date_time()`](https://pedrobtz.github.io/zutempo/reference/plain_date_time.md).

- rounding_increment:

  A positive integer that divides the next larger unit evenly: 24 hours,
  60 minutes or seconds, 1000 of the sub-second units, and 1 for
  `"day"`.

- rounding_mode:

  One of `"ceil"`, `"floor"`, `"expand"`, `"trunc"`, `"halfCeil"`,
  `"halfFloor"`, `"halfExpand"` (the default), `"halfTrunc"` or
  `"halfEven"`.

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
```
