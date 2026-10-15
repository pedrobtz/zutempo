# Durations

``` r

library(zutempo)
```

A
[`duration()`](https://pedrobtz.github.io/zutempo/reference/duration.md)
is an amount of time in ten fields, from years to nanoseconds, as
Temporal’s `Duration` has them. Each field is a whole number, and all of
them share a sign.

## Building them

``` r

duration(hours = 1, minutes = 30)
#> <zutempo_duration[1]>
#> [1] PT1H30M
duration("P1Y2M3DT4H5M6.789S")
#> <zutempo_duration[1]>
#> [1] P1Y2M3DT4H5M6.789S
duration(days = -2)
#> <zutempo_duration[1]>
#> [1] -P2D
duration(as.difftime(90, units = "mins"))
#> <zutempo_duration[1]>
#> [1] PT5400S
```

The fields stay as given; nothing is balanced on the way in:

``` r

d <- duration(minutes = 90)
d
#> <zutempo_duration[1]>
#> [1] PT90M
minutes(d)
#> [1] 90
hours(d)
#> [1] 0
```

## Balancing and rounding

[`temporal_round()`](https://pedrobtz.github.io/zutempo/reference/temporal_round.md)
balances a duration into larger units and rounds it. Hours, minutes and
smaller units have fixed lengths, so they need nothing else:

``` r

temporal_round(duration(minutes = 90), largest_unit = "hour")
#> <zutempo_duration[1]>
#> [1] PT1H30M
temporal_round(duration(seconds = 100000), largest_unit = "day")
#> <zutempo_duration[1]>
#> [1] P1DT3H46M40S
temporal_round(duration("PT1H23M45.6S"), smallest_unit = "minute")
#> <zutempo_duration[1]>
#> [1] PT1H24M
temporal_round(duration("PT1H23M45.6S"), smallest_unit = "minute", rounding_mode = "floor")
#> <zutempo_duration[1]>
#> [1] PT1H23M
```

## Calendar units need a reference

A month is 28 to 31 days and a year 365 or 366, so a duration with
years, months or weeks only has a length relative to a date. Arithmetic
that needs that length takes `relative_to`:

``` r

try(temporal_total(duration(months = 1), "day"))
#> Error : totalling years, months or weeks needs `relative_to` (element 1)
temporal_total(duration(months = 1), "day", relative_to = "2026-02-01")
#> [1] 28
temporal_total(duration(months = 1), "day", relative_to = "2026-03-01")
#> [1] 31
temporal_round(duration(days = 45), largest_unit = "month", relative_to = "2026-01-31")
#> <zutempo_duration[1]>
#> [1] P1M17D
```

With a zoned value as `relative_to`, a day follows the zone’s clock
changes, so 25 hours from noon before New York’s spring change is a day
and two hours:

``` r

temporal_round(
  duration(hours = 25),
  largest_unit = "day",
  relative_to = zoned_date_time("2026-03-07T12:00[America/New_York]")
)
#> <zutempo_duration[1]>
#> [1] P1DT2H
```

## Adding and comparing

``` r

temporal_add(duration(hours = 1), "PT45M")
#> <zutempo_duration[1]>
#> [1] PT1H45M
temporal_negated(duration(hours = 1))
#> <zutempo_duration[1]>
#> [1] -PT1H
temporal_abs(duration(minutes = -5))
#> <zutempo_duration[1]>
#> [1] PT5M
blank(duration())
#> [1] TRUE
```

`==` compares fields, so 90 minutes and an hour and a half are different
durations; `<`, [`sort()`](https://rdrr.io/r/base/sort.html) and
[`duration_compare()`](https://pedrobtz.github.io/zutempo/reference/duration.md)
compare lengths:

``` r

duration("PT90M") == duration("PT1H30M")
#> [1] FALSE
duration_compare("PT90M", "PT1H30M")
#> [1] 0
duration("PT90M") < duration("PT2H")
#> [1] TRUE
sort(duration(c("PT2H", "PT30M", "P1D")))
#> <zutempo_duration[3]>
#> [1] PT30M PT2H  P1D
```

With years, months or weeks the length depends on the date, so
[`duration_compare()`](https://pedrobtz.github.io/zutempo/reference/duration.md)
takes `relative_to`:

``` r

duration_compare("P1M", "P30D", relative_to = "2026-02-01")
#> [1] -1
duration_compare("P1M", "P30D", relative_to = "2026-03-01")
#> [1] 1
```

## Totals and strings

``` r

temporal_total(duration("P1DT12H"), "hour")
#> [1] 36
temporal_to_difftime(duration("PT1H30M"))
#> Time difference of 5400 secs
temporal_to_string(duration("PT1.987654321S"), fractional_second_digits = 2)
#> [1] "PT1.98S"
temporal_to_string(duration("PT1.5S"), smallest_unit = "second", rounding_mode = "halfExpand")
#> [1] "PT2S"
```
