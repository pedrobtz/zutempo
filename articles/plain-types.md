# Plain dates and times

``` r

library(zutempo)
```

A *plain* value is a date, a time or both, with no time zone: what is
written on a calendar or shown on a wall clock. zutempo has five, after
Temporal’s five plain types.

| R | Temporal | Holds | Example |
|----|----|----|----|
| [`plain_date()`](https://pedrobtz.github.io/zutempo/reference/plain_date.md) | `PlainDate` | a calendar date | `2026-03-07` |
| [`plain_time()`](https://pedrobtz.github.io/zutempo/reference/plain_time.md) | `PlainTime` | a wall-clock time | `09:30:00` |
| [`plain_date_time()`](https://pedrobtz.github.io/zutempo/reference/plain_date_time.md) | `PlainDateTime` | both | `2026-03-07T09:30:00` |
| [`plain_year_month()`](https://pedrobtz.github.io/zutempo/reference/plain_year_month.md) | `PlainYearMonth` | a month of a year | `2026-03` |
| [`plain_month_day()`](https://pedrobtz.github.io/zutempo/reference/plain_month_day.md) | `PlainMonthDay` | a day of every year | `03-07` |

## Building them

Each type is built by the function named after it, from a string, from
fields, or from another value:

``` r

plain_date("2026-03-07")
#> <zutempo_plain_date[1]>
#> [1] 2026-03-07
plain_date(2026, 3, 7)
#> <zutempo_plain_date[1]>
#> [1] 2026-03-07
plain_time(9, 30)
#> <zutempo_plain_time[1]>
#> [1] 09:30:00
plain_date_time("2026-03-07T09:30")
#> <zutempo_plain_date_time[1]>
#> [1] 2026-03-07T09:30:00
plain_year_month("2026-03")
#> <zutempo_plain_year_month[1]>
#> [1] 2026-03
plain_month_day("03-07")
#> <zutempo_plain_month_day[1]>
#> [1] 03-07
```

They are vectors, recycled as R recycles, with `NA` where a value is
missing:

``` r

d <- plain_date(2026, 1:4, 31)
d
#> <zutempo_plain_date[4]>
#> [1] 2026-01-31 2026-02-28 2026-03-31 2026-04-30
plain_date(c("2026-03-07", NA))
#> <zutempo_plain_date[2]>
#> [1] 2026-03-07 <NA>
```

`plain_date(2026, 1:4, 31)` asked for 31 February and 31 April. By
default a field out of range is *constrained* to its nearest valid
value; `overflow = "reject"` makes it an error:

``` r

try(plain_date(2026, 2, 31, overflow = "reject"))
#> Error : 2026-02-31 is not a valid date (element 1)
```

## Reading their fields

Every Temporal property is an accessor named after it:

``` r

x <- plain_date_time("2026-03-07T09:30:15.25")
year(x)
#> [1] 2026
month(x)
#> [1] 3
day_of_week(x) # 1 is Monday, 7 is Sunday
#> [1] 6
day_of_year(x)
#> [1] 66
week_of_year(x)
#> [1] 10
days_in_month(x)
#> [1] 31
in_leap_year(x)
#> [1] FALSE
second(x)
#> [1] 15
millisecond(x)
#> [1] 250
```

## Changing them

[`temporal_with()`](https://pedrobtz.github.io/zutempo/reference/temporal_with.md)
replaces fields and keeps the rest, constraining by default:

``` r

temporal_with(plain_date("2026-01-31"), month = 2)
#> <zutempo_plain_date[1]>
#> [1] 2026-02-28
temporal_with(x, hour = 18, minute = 0)
#> <zutempo_plain_date_time[1]>
#> [1] 2026-03-07T18:00:15.25
temporal_with_plain_time(plain_date_time("2026-03-07T09:30"), plain_time(12))
#> <zutempo_plain_date_time[1]>
#> [1] 2026-03-07T12:00:00
```

## Arithmetic

[`temporal_add()`](https://pedrobtz.github.io/zutempo/reference/temporal_add.md)
and
[`temporal_subtract()`](https://pedrobtz.github.io/zutempo/reference/temporal_add.md)
take a
[`duration()`](https://pedrobtz.github.io/zutempo/reference/duration.md)
or an ISO 8601 duration string. Months and years move through the
calendar, so adding one month to 31 January gives the last day of
February:

``` r

temporal_add(plain_date("2026-01-31"), "P1M")
#> <zutempo_plain_date[1]>
#> [1] 2026-02-28
temporal_add(plain_date("2026-01-31"), duration(months = 1, days = 1))
#> <zutempo_plain_date[1]>
#> [1] 2026-03-01
temporal_subtract(plain_time("00:30"), "PT1H") # times wrap around midnight
#> <zutempo_plain_time[1]>
#> [1] 23:30:00
```

[`temporal_until()`](https://pedrobtz.github.io/zutempo/reference/temporal_until.md)
and
[`temporal_since()`](https://pedrobtz.github.io/zutempo/reference/temporal_until.md)
give the duration between two values, in days by default and in larger
units on request:

``` r

start <- plain_date("2026-01-31")
temporal_until(start, "2026-12-25")
#> <zutempo_duration[1]>
#> [1] P328D
temporal_until(start, "2026-12-25", largest_unit = "month")
#> <zutempo_duration[1]>
#> [1] P10M25D
temporal_until(start, "2026-12-25", largest_unit = "week")
#> <zutempo_duration[1]>
#> [1] P46W6D
temporal_since(plain_time("17:45"), "09:30")
#> <zutempo_duration[1]>
#> [1] PT8H15M
```

## Rounding and comparing

``` r

temporal_round(plain_time("09:47:31"), "minute", rounding_increment = 15)
#> <zutempo_plain_time[1]>
#> [1] 09:45:00
temporal_round(plain_date_time("2026-03-07T13:00"), "day")
#> <zutempo_plain_date_time[1]>
#> [1] 2026-03-08T00:00:00
plain_date_compare(plain_date("2026-03-07"), "2026-03-08")
#> [1] -1
temporal_equals(plain_date("2026-03-07"), "2026-03-07")
#> [1] TRUE
sort(plain_date(c("2026-12-25", "2026-03-07", "2026-07-04")))
#> <zutempo_plain_date[3]>
#> [1] 2026-03-07 2026-07-04 2026-12-25
```

## Year-months and month-days

A
[`plain_year_month()`](https://pedrobtz.github.io/zutempo/reference/plain_year_month.md)
is a month of a year, for things like card expiry dates; a
[`plain_month_day()`](https://pedrobtz.github.io/zutempo/reference/plain_month_day.md)
is a day that recurs every year, such as a birthday. Each becomes a date
once the missing part is given:

``` r

expiry <- plain_year_month("2027-02")
days_in_month(expiry)
#> [1] 28
temporal_to_plain_date(expiry, day = 28)
#> <zutempo_plain_date[1]>
#> [1] 2027-02-28

birthday <- plain_month_day("02-29")
temporal_to_plain_date(birthday, year = 2027) # no 29 February: constrained
#> <zutempo_plain_date[1]>
#> [1] 2027-02-28
temporal_to_plain_date(birthday, year = 2028)
#> <zutempo_plain_date[1]>
#> [1] 2028-02-29
```

## Combining them

``` r

date <- plain_date("2026-03-07")
temporal_to_plain_date_time(date, plain_time("09:30"))
#> <zutempo_plain_date_time[1]>
#> [1] 2026-03-07T09:30:00
temporal_to_plain_year_month(date)
#> <zutempo_plain_year_month[1]>
#> [1] 2026-03
temporal_to_plain_month_day(date)
#> <zutempo_plain_month_day[1]>
#> [1] 03-07
temporal_to_plain_time(plain_date_time("2026-03-07T09:30"))
#> <zutempo_plain_time[1]>
#> [1] 09:30:00
```

A plain value has no time zone, so it does not say which moment it is.
Moments and zones are in [Instants and time
zones](https://pedrobtz.github.io/zutempo/articles/time-zones.md).
