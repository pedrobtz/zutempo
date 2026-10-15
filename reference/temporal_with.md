# Replace fields of a Temporal value

`temporal_with()` is Temporal's
[`with()`](https://rdrr.io/r/base/with.html): it returns a copy of `x`
with the named fields replaced and the rest kept, resolving the result
with `overflow`. `temporal_with_plain_time()` is `withPlainTime()`, and
`temporal_with_calendar()` is `withCalendar()`, which accepts only
`"iso8601"` in this version (design D7).

## Usage

``` r
temporal_with(x, ..., overflow = "constrain")

# S3 method for class 'zutempo_plain_date_time'
temporal_with(x, ..., overflow = "constrain")

# S3 method for class 'zutempo_plain_date_time'
temporal_with_plain_time(x, time = NULL)

# S3 method for class 'zutempo_plain_date_time'
temporal_with_calendar(x, calendar)

# S3 method for class 'zutempo_plain_date'
temporal_with(x, ..., overflow = "constrain")

# S3 method for class 'zutempo_plain_date'
temporal_with_calendar(x, calendar)

# S3 method for class 'zutempo_plain_time'
temporal_with(x, ..., overflow = "constrain")

temporal_with_plain_time(x, time = NULL)

temporal_with_calendar(x, calendar)
```

## Arguments

- x:

  A zutempo value.

- ...:

  Fields to replace, named: `year`, `month`, `month_code`, `day`,
  `hour`, `minute`, `second`, `millisecond`, `microsecond`,
  `nanosecond`, as the type allows. At least one is required. Giving
  `month` or `month_code` discards the other from `x`; giving both
  requires them to agree.

- overflow:

  `"constrain"` (the default) clamps out-of-range fields, `"reject"`
  raises a `zutempo_range_error` for them (design 6.2).

- time:

  A
  [`plain_time()`](https://pedrobtz.github.io/zutempo/reference/plain_time.md),
  a string a
  [`plain_time()`](https://pedrobtz.github.io/zutempo/reference/plain_time.md)
  reads, or `NULL` for midnight.

- calendar:

  A calendar identifier; only `"iso8601"` is supported.

## Value

A value of the same class as `x`.

## Examples

``` r
temporal_with(plain_date("2026-01-31"), month = 2)
#> <zutempo_plain_date[1]>
#> [1] 2026-02-28
try(temporal_with(plain_date("2026-01-31"), month = 2, overflow = "reject"))
#> Error : 2026-02-31 is not a valid date (element 1)
temporal_with_plain_time(plain_date_time("2026-01-31T12:00"), "08:30")
#> <zutempo_plain_date_time[1]>
#> [1] 2026-01-31T08:30:00
```
