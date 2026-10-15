# Total a duration in one unit

Temporal's `total()`: the whole duration as a possibly fractional count
of `unit`. Years, months and weeks need `relative_to`; without it a day
counts 24 hours (design 6.5).

## Usage

``` r
temporal_total(x, unit, relative_to = NULL)

# S3 method for class 'zutempo_duration'
temporal_total(x, unit, relative_to = NULL)
```

## Arguments

- x:

  A
  [`duration()`](https://pedrobtz.github.io/zutempo/reference/duration.md).

- unit:

  A Temporal unit, singular or plural.

- relative_to:

  A
  [`plain_date()`](https://pedrobtz.github.io/zutempo/reference/plain_date.md),
  [`plain_date_time()`](https://pedrobtz.github.io/zutempo/reference/plain_date_time.md)
  or a string either reads.

## Value

A double vector.

## Examples

``` r
temporal_total(duration(hours = 25), "day")
#> [1] 1.041667
temporal_total(duration(months = 1), "day", relative_to = "2026-02-01")
#> [1] 28
```
