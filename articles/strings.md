# Strings and formatting

``` r

library(zutempo)
```

zutempo reads and writes the strings Temporal does: ISO 8601 with the
RFC 9557 extensions for a time zone and other annotations in brackets.

## Reading

Each constructor reads the strings for its type:

``` r

plain_date("2026-03-07")
#> <zutempo_plain_date[1]>
#> [1] 2026-03-07
plain_date("20260307") # the basic format
#> <zutempo_plain_date[1]>
#> [1] 2026-03-07
plain_time("09:30:15.123456789")
#> <zutempo_plain_time[1]>
#> [1] 09:30:15.123456789
plain_date_time("2026-03-07 09:30") # a space for the T
#> <zutempo_plain_date_time[1]>
#> [1] 2026-03-07T09:30:00
instant("2026-03-07T09:30:00+01:00")
#> <zutempo_instant[1]>
#> [1] 2026-03-07T08:30:00Z
plain_date("+275760-09-13") # years beyond 9999 have a sign
#> <zutempo_plain_date[1]>
#> [1] +275760-09-13
duration("P1Y2M3DT4H5M6.5S")
#> <zutempo_duration[1]>
#> [1] P1Y2M3DT4H5M6.5S
```

``` r

zoned_date_time("2026-03-07T09:30[Europe/Lisbon]")
#> <zutempo_zoned_date_time[1]>
#> [1] 2026-03-07T09:30:00+00:00[Europe/Lisbon]
zoned_date_time("2026-03-07T09:30+00:00[Europe/Lisbon][u-ca=iso8601]")
#> <zutempo_zoned_date_time[1]>
#> [1] 2026-03-07T09:30:00+00:00[Europe/Lisbon]
```

A string that does not read is an error naming the byte where it failed:

``` r

try(plain_date("2026-02-30"))
#> Error : cannot parse "2026-02-30" as a date or date-time: no such day in that month at byte 9 (element 1)
err <- tryCatch(plain_date("2026-13-01"), error = identity)
err$position
#> [1] 6
```

## Reading in bulk

[`zutempo_parse()`](https://pedrobtz.github.io/zutempo/reference/zutempo_parse.md)
reads a whole vector, gives `NA` for what it cannot read, and keeps the
reasons:

``` r

x <- c("2026-03-07", "2026-13-01", NA, "07/03/2026")
d <- zutempo_parse(x, "plain_date")
d
#> <zutempo_plain_date[4]>
#> [1] 2026-03-07 <NA>       <NA>       <NA>
zutempo_parse_errors(d)
#>   index position               class
#> 1     2        6 zutempo_parse_error
#> 2     4        3 zutempo_parse_error
#>                                                                                  message
#> 1     cannot parse "2026-13-01" as a date or date-time: month must be 01 to 12 at byte 6
#> 2 cannot parse "07/03/2026" as a date or date-time: expected a four-digit year at byte 3
```

## Writing

[`format()`](https://rdrr.io/r/base/format.html),
[`as.character()`](https://rdrr.io/r/base/character.html) and
[`temporal_to_string()`](https://pedrobtz.github.io/zutempo/reference/temporal_to_string.md)
write the same strings.
[`temporal_to_string()`](https://pedrobtz.github.io/zutempo/reference/temporal_to_string.md)
and [`format()`](https://rdrr.io/r/base/format.html) take Temporal’s
formatting options: how many fraction digits, the smallest unit, how to
round:

``` r

t <- plain_time("09:30:15.987654321")
format(t)
#> [1] "09:30:15.987654321"
temporal_to_string(t, fractional_second_digits = 3)
#> [1] "09:30:15.987"
temporal_to_string(t, smallest_unit = "second")
#> [1] "09:30:15"
temporal_to_string(t, smallest_unit = "minute", rounding_mode = "halfExpand")
#> [1] "09:30"
```

Zoned values choose what to show besides the time:

``` r

z <- zoned_date_time("2026-03-07T09:30[Europe/Lisbon]")
format(z)
#> [1] "2026-03-07T09:30:00+00:00[Europe/Lisbon]"
temporal_to_string(z, offset = "never")
#> [1] "2026-03-07T09:30:00[Europe/Lisbon]"
temporal_to_string(z, time_zone_name = "never")
#> [1] "2026-03-07T09:30:00+00:00"
temporal_to_string(z, calendar_name = "always")
#> [1] "2026-03-07T09:30:00+00:00[Europe/Lisbon][u-ca=iso8601]"
```

Sort the values, not their strings: a year beyond 9999 starts with a
sign, which sorts before the digits:

``` r

x <- c("2026-12-25", "+010000-01-01", "2026-03-07")
sort(x)
#> [1] "+010000-01-01" "2026-03-07"    "2026-12-25"
sort(plain_date(x))
#> <zutempo_plain_date[3]>
#> [1] 2026-03-07    2026-12-25    +010000-01-01
```

## Time zone and calendar arguments

A time zone or calendar argument also takes an ISO string that names
one, as in Temporal:

``` r

temporal_to_string(instant("2026-03-07T09:30Z"), time_zone = "2026-01-01T00:00+05:30")
#> [1] "2026-03-07T15:00:00+05:30"
temporal_with_calendar(plain_date("2026-03-07"), "2026-01-01[u-ca=iso8601]")
#> <zutempo_plain_date[1]>
#> [1] 2026-03-07
```
