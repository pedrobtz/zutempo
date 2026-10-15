# Add a duration to, or subtract one from, a Temporal value

Temporal's `add()` and `subtract()`. On a
[`plain_date()`](https://pedrobtz.github.io/zutempo/reference/plain_date.md)
or
[`plain_year_month()`](https://pedrobtz.github.io/zutempo/reference/plain_year_month.md)
the time part of the duration counts in 24-hour days; on a
[`plain_time()`](https://pedrobtz.github.io/zutempo/reference/plain_time.md)
only the time part applies and the result wraps within the day. On a
[`zoned_date_time()`](https://pedrobtz.github.io/zutempo/reference/zoned_date_time.md)
the date part moves through the calendar in the value's zone, resolved
as `"compatible"`, and the time part moves the exact time, so a day
across a clock change is not 24 hours (design 6.5). On a
[`duration()`](https://pedrobtz.github.io/zutempo/reference/duration.md)
the result is a balanced duration, and calendar units are an error.

## Usage

``` r
temporal_add(x, other, ...)

temporal_subtract(x, other, ...)

# S3 method for class 'zutempo_plain_date'
temporal_add(x, other, ..., overflow = "constrain")

# S3 method for class 'zutempo_plain_date'
temporal_subtract(x, other, ..., overflow = "constrain")

# S3 method for class 'zutempo_plain_time'
temporal_add(x, other, ...)

# S3 method for class 'zutempo_plain_time'
temporal_subtract(x, other, ...)

# S3 method for class 'zutempo_plain_date_time'
temporal_add(x, other, ..., overflow = "constrain")

# S3 method for class 'zutempo_plain_date_time'
temporal_subtract(x, other, ..., overflow = "constrain")

# S3 method for class 'zutempo_plain_year_month'
temporal_add(x, other, ..., overflow = "constrain")

# S3 method for class 'zutempo_plain_year_month'
temporal_subtract(x, other, ..., overflow = "constrain")

# S3 method for class 'zutempo_duration'
temporal_add(x, other, ...)

# S3 method for class 'zutempo_duration'
temporal_subtract(x, other, ...)

# S3 method for class 'zutempo_instant'
temporal_add(x, other, ...)

# S3 method for class 'zutempo_instant'
temporal_subtract(x, other, ...)

# S3 method for class 'zutempo_zoned_date_time'
temporal_add(x, other, ..., overflow = "constrain")

# S3 method for class 'zutempo_zoned_date_time'
temporal_subtract(x, other, ..., overflow = "constrain")
```

## Arguments

- x:

  A zutempo value.

- other:

  A
  [`duration()`](https://pedrobtz.github.io/zutempo/reference/duration.md),
  or a string that
  [`duration()`](https://pedrobtz.github.io/zutempo/reference/duration.md)
  reads.

- ...:

  Must be empty.

- overflow:

  `"constrain"` (the default) clamps a day that the target month lacks,
  `"reject"` raises a `zutempo_range_error` (design 6.2). Not for a
  [`plain_time()`](https://pedrobtz.github.io/zutempo/reference/plain_time.md)
  or a
  [`duration()`](https://pedrobtz.github.io/zutempo/reference/duration.md).

## Value

A value of the same class as `x`.

## Examples

``` r
temporal_add(plain_date("2026-01-31"), "P1M")
#> <zutempo_plain_date[1]>
#> [1] 2026-02-28
temporal_subtract(plain_date_time("2026-03-01T00:30"), duration(hours = 1))
#> <zutempo_plain_date_time[1]>
#> [1] 2026-02-28T23:30:00
temporal_add(plain_time("23:00"), "PT2H")
#> <zutempo_plain_time[1]>
#> [1] 01:00:00
temporal_add(duration(hours = 1), "PT30M")
#> <zutempo_duration[1]>
#> [1] PT1H30M
```
