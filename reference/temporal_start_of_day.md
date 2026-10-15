# The start of a day in a time zone

Temporal's `startOfDay()`: the first instant of the calendar day of each
value in its own zone, which is not always midnight (a day may start at
01:00 when a clock gap removes midnight, as in Asuncion or Havana).

## Usage

``` r
temporal_start_of_day(x)

# S3 method for class 'zutempo_zoned_date_time'
temporal_start_of_day(x)
```

## Arguments

- x:

  A
  [`zoned_date_time()`](https://pedrobtz.github.io/zutempo/reference/zoned_date_time.md).

## Value

A
[`zoned_date_time()`](https://pedrobtz.github.io/zutempo/reference/zoned_date_time.md).

## Examples

``` r
temporal_start_of_day(zoned_date_time("2026-03-07T12:00[America/New_York]"))
#> <zutempo_zoned_date_time[1]>
#> [1] 2026-03-07T00:00:00-05:00[America/New_York]
```
