# Convert Temporal values to base R dates and times

Methods for base R's [`as.Date()`](https://rdrr.io/r/base/as.Date.html),
[`as.POSIXct()`](https://rdrr.io/r/base/as.POSIXlt.html) and
[`as.POSIXlt()`](https://rdrr.io/r/base/as.POSIXlt.html), and
`temporal_to_difftime()`, which stands in for
[`as.difftime()`](https://rdrr.io/r/base/difftime.html) because base R's
is not a generic (design 6.10). The other direction is the constructors:
`plain_date(<Date>)`, `instant(<POSIXct>)`,
`zoned_date_time(<POSIXct>)`, `plain_date_time(<POSIXct>)`,
`plain_time(<difftime>)` and `duration(<difftime>)`.

## Usage

``` r
# S3 method for class 'zutempo_plain_date'
as.Date(x, ...)

# S3 method for class 'zutempo_plain_date_time'
as.Date(x, ...)

# S3 method for class 'zutempo_zoned_date_time'
as.Date(x, tz = NULL, ...)

# S3 method for class 'zutempo_instant'
as.Date(x, tz = "UTC", ...)

# S3 method for class 'zutempo_instant'
as.POSIXct(x, tz = "UTC", ...)

# S3 method for class 'zutempo_zoned_date_time'
as.POSIXct(x, tz = NULL, ...)

# S3 method for class 'zutempo_plain_date_time'
as.POSIXct(x, tz, ..., disambiguation = "compatible")

# S3 method for class 'zutempo_zoned_date_time'
as.POSIXlt(x, tz = NULL, ...)

# S3 method for class 'zutempo_instant'
as.POSIXlt(x, tz = "UTC", ...)

# S3 method for class 'zutempo_plain_date_time'
as.POSIXlt(x, tz, ..., disambiguation = "compatible")

temporal_to_difftime(x, ...)

# S3 method for class 'zutempo_plain_time'
temporal_to_difftime(x, ...)

# S3 method for class 'zutempo_duration'
temporal_to_difftime(x, ..., relative_to = NULL)
```

## Arguments

- x:

  A zutempo value.

- ...:

  Must be empty.

- tz:

  A time zone: for an
  [`instant()`](https://pedrobtz.github.io/zutempo/reference/instant.md),
  the zone to show it in (the default is `"UTC"`); for a
  [`plain_date_time()`](https://pedrobtz.github.io/zutempo/reference/plain_date_time.md),
  the zone its wall-clock time is in, which has no default (`""` is the
  system zone); for a
  [`zoned_date_time()`](https://pedrobtz.github.io/zutempo/reference/zoned_date_time.md),
  a zone to show it in instead of its own.

- disambiguation:

  For a
  [`plain_date_time()`](https://pedrobtz.github.io/zutempo/reference/plain_date_time.md):
  how to resolve a time a zone skips or repeats, as in
  [`temporal_to_zoned_date_time()`](https://pedrobtz.github.io/zutempo/reference/temporal_to_instant.md).

- relative_to:

  For a
  [`duration()`](https://pedrobtz.github.io/zutempo/reference/duration.md)
  with years, months or weeks: the date or zoned date-time they count
  from, as in
  [`temporal_total()`](https://pedrobtz.github.io/zutempo/reference/temporal_total.md).

## Value

A `Date`, `POSIXct`, `POSIXlt` or `difftime` (in seconds), `NA` where
`x` is `NA`.

## Details

What each conversion loses:

- [`plain_date()`](https://pedrobtz.github.io/zutempo/reference/plain_date.md)
  to `Date`: nothing; both count days from 1970-01-01.

- [`instant()`](https://pedrobtz.github.io/zutempo/reference/instant.md)
  to `POSIXct`: the nanoseconds, to the nearest double second (ties to
  even), which keeps about 240 ns at today's dates. The other way takes
  the double's exact value, rounded half to even to the nanosecond, so
  0.1 s is 100 ms.

- [`zoned_date_time()`](https://pedrobtz.github.io/zutempo/reference/zoned_date_time.md)
  to `POSIXct`: as
  [`instant()`](https://pedrobtz.github.io/zutempo/reference/instant.md),
  with the zone as `tzone`. A vector mixing zones gets `"UTC"`, and so
  does a fixed offset that is not a whole number of hours, which base R
  cannot name; a whole-hour offset becomes its `Etc/GMT` zone.

- [`zoned_date_time()`](https://pedrobtz.github.io/zutempo/reference/zoned_date_time.md)
  to `POSIXlt`: the fields in each element's own zone, with its offset
  in `gmtoff`; the seconds lose precision as above.

- [`plain_date_time()`](https://pedrobtz.github.io/zutempo/reference/plain_date_time.md)
  to `POSIXct` or `POSIXlt`: needs `tz`, and resolves a wall-clock time
  a zone skips or repeats with `disambiguation`, as
  [`temporal_to_zoned_date_time()`](https://pedrobtz.github.io/zutempo/reference/temporal_to_instant.md)
  does.

- [`instant()`](https://pedrobtz.github.io/zutempo/reference/instant.md),
  [`zoned_date_time()`](https://pedrobtz.github.io/zutempo/reference/zoned_date_time.md)
  and
  [`plain_date_time()`](https://pedrobtz.github.io/zutempo/reference/plain_date_time.md)
  to `Date`: the date, in `tz` for an
  [`instant()`](https://pedrobtz.github.io/zutempo/reference/instant.md).

- [`plain_time()`](https://pedrobtz.github.io/zutempo/reference/plain_time.md)
  to `difftime`: seconds since midnight, as a double.

- [`duration()`](https://pedrobtz.github.io/zutempo/reference/duration.md)
  to `difftime`: its total in seconds, as
  [`temporal_total()`](https://pedrobtz.github.io/zutempo/reference/temporal_total.md)
  gives it, so years, months and weeks need `relative_to` and a day is
  24 hours without it.

[`plain_year_month()`](https://pedrobtz.github.io/zutempo/reference/plain_year_month.md)
and
[`plain_month_day()`](https://pedrobtz.github.io/zutempo/reference/plain_month_day.md)
have no base R counterpart;
[`temporal_to_plain_date()`](https://pedrobtz.github.io/zutempo/reference/temporal_to_plain_date.md)
supplies the missing day or year first.

## Examples

``` r
as.Date(plain_date("2026-03-07"))
#> [1] "2026-03-07"
as.POSIXct(instant("2026-03-07T12:00:00.123456789Z"))
#> [1] "2026-03-07 12:00:00 UTC"
as.POSIXct(zoned_date_time("2026-03-07T12:00[Europe/Lisbon]"))
#> [1] "2026-03-07 12:00:00 WET"
as.POSIXlt(zoned_date_time("2026-03-07T12:00[Europe/Lisbon]"))
#> [1] "2026-03-07 12:00:00 WET"
as.POSIXct(plain_date_time("2026-03-29T01:30"), tz = "Europe/Lisbon")
#> [1] "2026-03-29 02:30:00 WEST"
temporal_to_difftime(plain_time("12:30"))
#> Time difference of 45000 secs
temporal_to_difftime(duration("P1M"), relative_to = "2026-02-01")
#> Time difference of 2419200 secs

# And back.
plain_date(as.Date("2026-03-07"))
#> <zutempo_plain_date[1]>
#> [1] 2026-03-07
instant(as.POSIXct("2026-03-07 12:00:00", tz = "UTC"))
#> <zutempo_instant[1]>
#> [1] 2026-03-07T12:00:00Z
duration(as.difftime(90, units = "mins"))
#> <zutempo_duration[1]>
#> [1] PT5400S
```
