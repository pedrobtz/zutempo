# Time zone transitions

Temporal's `getTimeZoneTransition()`: the next or previous instant at
which each value's zone changes its UTC offset, as a
[`zoned_date_time()`](https://pedrobtz.github.io/zutempo/reference/zoned_date_time.md)
in that zone, or `NA` when there is none within the representable range
or the zone is a fixed offset.

## Usage

``` r
temporal_get_time_zone_transition(x, direction)

# S3 method for class 'zutempo_zoned_date_time'
temporal_get_time_zone_transition(x, direction)
```

## Arguments

- x:

  A
  [`zoned_date_time()`](https://pedrobtz.github.io/zutempo/reference/zoned_date_time.md).

- direction:

  `"next"` or `"previous"`.

## Value

A
[`zoned_date_time()`](https://pedrobtz.github.io/zutempo/reference/zoned_date_time.md).

## Examples

``` r
x <- zoned_date_time("2026-01-15T12:00[America/New_York]")
temporal_get_time_zone_transition(x, "next")
#> <zutempo_zoned_date_time[1]>
#> [1] 2026-03-08T03:00:00-04:00[America/New_York]
temporal_get_time_zone_transition(x, "previous")
#> <zutempo_zoned_date_time[1]>
#> [1] 2025-11-02T01:00:00-05:00[America/New_York]
```
