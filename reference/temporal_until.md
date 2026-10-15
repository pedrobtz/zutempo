# Difference between two Temporal values

Temporal's `until()` and `since()`: the duration from `x` to `other`
(`until`), or from `other` to `x` (`since`), balanced up to
`largest_unit` and rounded to `smallest_unit` (design 6.6). Defaults
follow the type: days for dates and date-times, hours for times, years
for year-months.

## Usage

``` r
temporal_until(
  x,
  other,
  ...,
  largest_unit = NULL,
  smallest_unit = NULL,
  rounding_increment = 1,
  rounding_mode = "trunc"
)

temporal_since(
  x,
  other,
  ...,
  largest_unit = NULL,
  smallest_unit = NULL,
  rounding_increment = 1,
  rounding_mode = "trunc"
)

# S3 method for class 'zutempo_plain_date'
temporal_until(
  x,
  other,
  ...,
  largest_unit = NULL,
  smallest_unit = NULL,
  rounding_increment = 1,
  rounding_mode = "trunc"
)

# S3 method for class 'zutempo_plain_date'
temporal_since(
  x,
  other,
  ...,
  largest_unit = NULL,
  smallest_unit = NULL,
  rounding_increment = 1,
  rounding_mode = "trunc"
)

# S3 method for class 'zutempo_plain_time'
temporal_until(
  x,
  other,
  ...,
  largest_unit = NULL,
  smallest_unit = NULL,
  rounding_increment = 1,
  rounding_mode = "trunc"
)

# S3 method for class 'zutempo_plain_time'
temporal_since(
  x,
  other,
  ...,
  largest_unit = NULL,
  smallest_unit = NULL,
  rounding_increment = 1,
  rounding_mode = "trunc"
)

# S3 method for class 'zutempo_plain_date_time'
temporal_until(
  x,
  other,
  ...,
  largest_unit = NULL,
  smallest_unit = NULL,
  rounding_increment = 1,
  rounding_mode = "trunc"
)

# S3 method for class 'zutempo_plain_date_time'
temporal_since(
  x,
  other,
  ...,
  largest_unit = NULL,
  smallest_unit = NULL,
  rounding_increment = 1,
  rounding_mode = "trunc"
)

# S3 method for class 'zutempo_plain_year_month'
temporal_until(
  x,
  other,
  ...,
  largest_unit = NULL,
  smallest_unit = NULL,
  rounding_increment = 1,
  rounding_mode = "trunc"
)

# S3 method for class 'zutempo_plain_year_month'
temporal_since(
  x,
  other,
  ...,
  largest_unit = NULL,
  smallest_unit = NULL,
  rounding_increment = 1,
  rounding_mode = "trunc"
)

# S3 method for class 'zutempo_instant'
temporal_until(
  x,
  other,
  ...,
  largest_unit = NULL,
  smallest_unit = NULL,
  rounding_increment = 1,
  rounding_mode = "trunc"
)

# S3 method for class 'zutempo_instant'
temporal_since(
  x,
  other,
  ...,
  largest_unit = NULL,
  smallest_unit = NULL,
  rounding_increment = 1,
  rounding_mode = "trunc"
)
```

## Arguments

- x:

  A zutempo value.

- other:

  A value of the same class, or a string its constructor reads.

- ...:

  Must be empty.

- largest_unit, smallest_unit:

  Temporal units, singular or plural; `largest_unit` may be `"auto"`.

- rounding_increment:

  A positive integer that divides the next larger unit evenly for time
  units.

- rounding_mode:

  One of the nine rounding modes; `"trunc"` by default.

## Value

A
[`duration()`](https://pedrobtz.github.io/zutempo/reference/duration.md).

## Examples

``` r
temporal_until(plain_date("2026-01-31"), "2026-03-01")
#> <zutempo_duration[1]>
#> [1] P29D
temporal_until(plain_date("2026-01-31"), "2026-03-01", largest_unit = "month")
#> <zutempo_duration[1]>
#> [1] P1M1D
temporal_since(plain_time("13:30"), "12:00")
#> <zutempo_duration[1]>
#> [1] PT1H30M
```
