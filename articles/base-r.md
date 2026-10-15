# Base R and data frames

``` r

library(zutempo)
```

zutempo’s values are R vectors: they subset, combine, repeat, sort and
sit in data frames like base R’s dates. And they convert to and from
`Date`, `POSIXct`, `POSIXlt` and `difftime`.

## Vectors

``` r

d <- plain_date(c("2026-03-07", "2026-01-31", NA, "2026-12-25"))
length(d)
#> [1] 4
d[2:3]
#> <zutempo_plain_date[2]>
#> [1] 2026-01-31 <NA>
c(d[1], plain_date("2027-01-01"))
#> <zutempo_plain_date[2]>
#> [1] 2026-03-07 2027-01-01
rev(d)
#> <zutempo_plain_date[4]>
#> [1] 2026-12-25 <NA>       2026-01-31 2026-03-07
sort(d)
#> <zutempo_plain_date[3]>
#> [1] 2026-01-31 2026-03-07 2026-12-25
unique(rep(d[1], 3))
#> <zutempo_plain_date[1]>
#> [1] 2026-03-07
is.na(d)
#> [1] FALSE FALSE  TRUE FALSE
```

## Data frames

``` r

meetings <- data.frame(
  who = c("Ana", "Ben", "Chen"),
  start = zoned_date_time(c(
    "2026-03-07T09:00[America/New_York]",
    "2026-03-07T10:00[Europe/Lisbon]",
    "2026-03-07T18:00[Asia/Tokyo]"
  )),
  length = duration(c("PT30M", "PT1H", "PT45M"))
)
meetings$end <- temporal_add(meetings$start, meetings$length)
meetings
#>    who                                       start length
#> 1  Ana 2026-03-07T09:00:00-05:00[America/New_York]  PT30M
#> 2  Ben    2026-03-07T10:00:00+00:00[Europe/Lisbon]   PT1H
#> 3 Chen       2026-03-07T18:00:00+09:00[Asia/Tokyo]  PT45M
#>                                           end
#> 1 2026-03-07T09:30:00-05:00[America/New_York]
#> 2    2026-03-07T11:00:00+00:00[Europe/Lisbon]
#> 3       2026-03-07T18:45:00+09:00[Asia/Tokyo]
```

Ordered by their wall-clock times they are Ana, Ben, Chen; by the
moments they happen, Chen is first (09:00 UTC) and Ana last (14:00 UTC):

``` r

meetings[order(temporal_to_instant(meetings$start)), c("who", "start")]
#>    who                                       start
#> 3 Chen       2026-03-07T18:00:00+09:00[Asia/Tokyo]
#> 2  Ben    2026-03-07T10:00:00+00:00[Europe/Lisbon]
#> 1  Ana 2026-03-07T09:00:00-05:00[America/New_York]
```

## From base R

``` r

plain_date(as.Date("2026-03-07"))
#> <zutempo_plain_date[1]>
#> [1] 2026-03-07
instant(as.POSIXct("2026-03-07 09:30:00", tz = "UTC"))
#> <zutempo_instant[1]>
#> [1] 2026-03-07T09:30:00Z
zoned_date_time(as.POSIXct("2026-03-07 09:30:00", tz = "America/New_York"))
#> <zutempo_zoned_date_time[1]>
#> [1] 2026-03-07T09:30:00-05:00[America/New_York]
plain_date_time(as.POSIXlt("2026-03-07 09:30:00", tz = "Asia/Tokyo"))
#> <zutempo_plain_date_time[1]>
#> [1] 2026-03-07T09:30:00
duration(as.difftime(90, units = "mins"))
#> <zutempo_duration[1]>
#> [1] PT5400S
plain_time(as.difftime(34200, units = "secs"))
#> <zutempo_plain_time[1]>
#> [1] 09:30:00
```

## To base R

``` r

as.Date(plain_date("2026-03-07"))
#> [1] "2026-03-07"
as.POSIXct(zoned_date_time("2026-03-07T09:30[Europe/Lisbon]"))
#> [1] "2026-03-07 09:30:00 WET"
as.POSIXlt(zoned_date_time("2026-03-07T09:30[Europe/Lisbon]"))
#> [1] "2026-03-07 09:30:00 WET"
as.POSIXct(plain_date_time("2026-03-07T09:30"), tz = "America/New_York")
#> [1] "2026-03-07 09:30:00 EST"
temporal_to_difftime(plain_time("09:30"))
#> Time difference of 34200 secs
temporal_to_difftime(duration("P1M"), relative_to = "2026-02-01")
#> Time difference of 2419200 secs
```

A `Date` and a
[`plain_date()`](https://pedrobtz.github.io/zutempo/reference/plain_date.md)
convert exactly. A `POSIXct` is a double, so an instant goes to the
nearest double second, which at today’s dates is within a quarter of a
microsecond, and a `POSIXct` comes back at its exact binary value:

``` r

x <- instant("2026-03-07T09:30:00.123456789Z")
instant(as.POSIXct(x))
#> <zutempo_instant[1]>
#> [1] 2026-03-07T09:30:00.123456717Z
```

## Formatting through base R

zutempo writes ISO 8601 and RFC 9557. For other layouts, convert to
`POSIXct` and use base R’s
[`format()`](https://rdrr.io/r/base/format.html):

``` r

z <- zoned_date_time("2026-03-07T09:30[Europe/Lisbon]")
format(as.POSIXct(z), "%A %d %B %Y, %H:%M %Z")
#> [1] "Saturday 07 March 2026, 09:30 WET"
```

## Masked functions

The accessors
[`months()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md)
and
[`offset()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md)
share their names with base R’s and stats’. They are generics: for any
object that is not zutempo’s they call the function they mask.

``` r

months(as.Date("2026-03-07"))
#> [1] "March"
# a duration's months field
months(temporal_until(plain_date("2026-03-07"), "2026-09-07", largest_unit = "month"))
#> [1] 6
```
