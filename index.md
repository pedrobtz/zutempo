# zutempo

zutempo implements [Temporal](https://tc39.es/proposal-temporal/), the
date and time model of ECMA-262, in R. It has the eight Temporal types
and `Temporal.Now`, in the ISO 8601 calendar, with IANA time zones read
from the same database base R uses. The arithmetic follows the
specification’s own operations in C, over the specification’s full
ranges, so a result in R is the result in a browser or in Node.

## Installation

zutempo is not on CRAN yet. Install the development version from GitHub:

``` r

# install.packages("pak")
pak::pak("pedrobtz/zutempo")
```

## Example

``` r

library(zutempo)
```

``` r

x <- zoned_date_time("2026-03-07T12:00[America/New_York]")
x
#> <zutempo_zoned_date_time[1]>
#> [1] 2026-03-07T12:00:00-05:00[America/New_York]

# Clocks go forward overnight, so 25 hours later is 14:00 the next day.
temporal_add(x, duration(hours = 25))
#> <zutempo_zoned_date_time[1]>
#> [1] 2026-03-08T14:00:00-04:00[America/New_York]

# The same 25 hours are a day and two hours of that calendar day.
temporal_round(duration(hours = 25), largest_unit = "day", relative_to = x)
#> <zutempo_duration[1]>
#> [1] P1DT2H

# One month after 31 January, constrained to the month's last day.
plain_date("2026-01-31") |> temporal_add(duration(months = 1))
#> <zutempo_plain_date[1]>
#> [1] 2026-02-28

# The last instant Temporal represents, in exact nanoseconds.
epoch_nanoseconds(instant("+275760-09-13T00:00Z"))
#> [1] "8640000000000000000000"
```

Values are vectors, with `NA`, and work in data frames:

``` r

d <- plain_date(c("2026-01-31", "2026-02-28", NA))
temporal_until(d, "2026-12-25", largest_unit = "month")
#> <zutempo_duration[3]>
#> [1] P10M25D P9M27D  <NA>
data.frame(date = d, weekday = day_of_week(d))
#>         date weekday
#> 1 2026-01-31       6
#> 2 2026-02-28       6
#> 3       <NA>      NA
```

## From Temporal to R

Names follow Temporal’s, in snake case, by one rule per kind of member:

| Temporal | R | Examples |
|----|----|----|
| a type and its `from()` | the constructor named after the type | [`plain_date()`](https://pedrobtz.github.io/zutempo/reference/plain_date.md), [`instant()`](https://pedrobtz.github.io/zutempo/reference/instant.md), [`zoned_date_time()`](https://pedrobtz.github.io/zutempo/reference/zoned_date_time.md), [`duration()`](https://pedrobtz.github.io/zutempo/reference/duration.md) |
| another static method | the type name, then the method name | [`duration_compare()`](https://pedrobtz.github.io/zutempo/reference/duration.md), [`instant_compare()`](https://pedrobtz.github.io/zutempo/reference/instant.md) |
| a prototype method | `temporal_` and the method name | [`temporal_add()`](https://pedrobtz.github.io/zutempo/reference/temporal_add.md), [`temporal_round()`](https://pedrobtz.github.io/zutempo/reference/temporal_round.md), [`temporal_since()`](https://pedrobtz.github.io/zutempo/reference/temporal_until.md) |
| a property | an accessor named after it | [`year()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md), [`epoch_nanoseconds()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md), [`hours_in_day()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md) |
| a `Temporal.Now` function | `now_` and the function name | [`now_instant()`](https://pedrobtz.github.io/zutempo/reference/now_instant.md), [`now_zoned_date_time_iso()`](https://pedrobtz.github.io/zutempo/reference/now_time_zone_id.md) |

Options are named arguments, as in
`temporal_round(x, "hour", rounding_mode = "halfEven")`. Each type’s
help page lists every member of the type with its R function.

The accessors are generics that mask functions of the same name: base
R’s
[`months()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md),
stats’
[`offset()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md),
and lubridate’s
[`year()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md),
[`month()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md),
[`day()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md)
and the like when it is attached. For any object that is not zutempo’s
they call the function they mask, so `months(Sys.Date())` and
lubridate’s own objects keep working.

## Base R’s dates and times

``` r

as.Date(plain_date("2026-03-07"))
#> [1] "2026-03-07"
as.POSIXct(zoned_date_time("2026-03-07T12:00[Europe/Lisbon]"))
#> [1] "2026-03-07 12:00:00 WET"
instant(as.POSIXct("2026-03-07 12:00:00", tz = "UTC"))
#> <zutempo_instant[1]>
#> [1] 2026-03-07T12:00:00Z
duration(as.difftime(90, units = "mins"))
#> <zutempo_duration[1]>
#> [1] PT5400S
```

A `Date` and a
[`plain_date()`](https://pedrobtz.github.io/zutempo/reference/plain_date.md)
convert exactly. A `POSIXct` is a double, so an instant converts to the
nearest double second;
[`zutempo_parse()`](https://pedrobtz.github.io/zutempo/reference/zutempo_parse.md)
reads character vectors in bulk, with `NA` for what it cannot read.

## Not in 0.1.0

- Calendars other than ISO 8601 (Hebrew, Japanese and the others come
  from ECMA-402, with CLDR data).
- Locale formatting (`toLocaleString()`).
- Custom time zones, and POSIX TZ strings as zone identifiers.
- [`strftime()`](https://rdrr.io/r/base/strptime.html)-style formats:
  convert to `POSIXct` for those.
- Arithmetic and comparison operators on dates (`x + d`, `x < y`): use
  the functions. Durations do compare with `==` and `<`.
