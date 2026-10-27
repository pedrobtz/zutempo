# Instants and time zones

``` r

library(zutempo)
```

Two of Temporal’s types name an exact moment. An
[`instant()`](https://pedrobtz.github.io/zutempo/reference/instant.md)
is the moment alone, a count of nanoseconds since 1970 in UTC. A
[`zoned_date_time()`](https://pedrobtz.github.io/zutempo/reference/zoned_date_time.md)
is the moment with a time zone, so it also knows the local date and time
there.

## Instants

``` r

i <- instant("2026-03-07T14:30:00Z")
i
#> <zutempo_instant[1]>
#> [1] 2026-03-07T14:30:00Z
format(epoch_milliseconds(i), scientific = FALSE)
#> [1] "1772893800000"
epoch_nanoseconds(i) # a decimal string: R has no 64-bit integer
#> [1] "1772893800000000000"
instant_from_epoch_milliseconds(1772893800000)
#> <zutempo_instant[1]>
#> [1] 2026-03-07T14:30:00Z
temporal_add(i, "PT90M")
#> <zutempo_instant[1]>
#> [1] 2026-03-07T16:00:00Z
temporal_until(i, "2026-03-08T14:30:00Z", largest_unit = "hour")
#> <zutempo_duration[1]>
#> [1] PT24H
```

An instant shows its moment in any zone, without becoming zoned:

``` r

temporal_to_string(i, time_zone = "Asia/Kolkata")
#> [1] "2026-03-07T20:00:00+05:30"
```

## Zoned values

``` r

meeting <- temporal_to_zoned_date_time_iso(i, "America/New_York")
meeting
#> <zutempo_zoned_date_time[1]>
#> [1] 2026-03-07T09:30:00-05:00[America/New_York]
time_zone_id(meeting)
#> [1] "America/New_York"
offset(meeting)
#> [1] "-05:00"
hour(meeting)
#> [1] 9
temporal_to_instant(meeting)
#> <zutempo_instant[1]>
#> [1] 2026-03-07T14:30:00Z
```

The zone travels with the value, per element, so one vector can mix
zones:

``` r

offices <- c("America/New_York", "Europe/Lisbon", "Asia/Tokyo")
z <- zoned_date_time(paste0("2026-03-07T09:00[", offices, "]"))
z
#> <zutempo_zoned_date_time[3]>
#> [1] 2026-03-07T09:00:00-05:00[America/New_York]
#> [2] 2026-03-07T09:00:00+00:00[Europe/Lisbon]   
#> [3] 2026-03-07T09:00:00+09:00[Asia/Tokyo]
temporal_to_instant(z)
#> <zutempo_instant[3]>
#> [1] 2026-03-07T14:00:00Z 2026-03-07T09:00:00Z 2026-03-07T00:00:00Z
```

[`temporal_with_time_zone()`](https://pedrobtz.github.io/zutempo/reference/temporal_with.md)
keeps the moment and changes the zone:

``` r

temporal_with_time_zone(meeting, "Europe/Lisbon")
#> <zutempo_zoned_date_time[1]>
#> [1] 2026-03-07T14:30:00+00:00[Europe/Lisbon]
```

## Days are not always 24 hours

New York moves its clocks forward at 02:00 on 8 March 2026. A day added
to a zoned value follows the calendar and the wall clock; 24 hours are
24 hours of exact time:

``` r

temporal_add(meeting, "P1D")
#> <zutempo_zoned_date_time[1]>
#> [1] 2026-03-08T09:30:00-04:00[America/New_York]
temporal_add(meeting, "PT24H")
#> <zutempo_zoned_date_time[1]>
#> [1] 2026-03-08T10:30:00-04:00[America/New_York]
hours_in_day(zoned_date_time("2026-03-08T12:00[America/New_York]"))
#> [1] 23
temporal_start_of_day(meeting)
#> <zutempo_zoned_date_time[1]>
#> [1] 2026-03-07T00:00:00-05:00[America/New_York]
```

## Gaps, folds and offsets

When clocks go forward, some wall-clock times do not happen; when they
go back, some happen twice. Turning such a time into a moment needs
`disambiguation`:

``` r

gap <- plain_date_time("2026-03-08T02:30")
temporal_to_zoned_date_time(gap, "America/New_York")
#> <zutempo_zoned_date_time[1]>
#> [1] 2026-03-08T03:30:00-04:00[America/New_York]
temporal_to_zoned_date_time(gap, "America/New_York", disambiguation = "earlier")
#> <zutempo_zoned_date_time[1]>
#> [1] 2026-03-08T01:30:00-05:00[America/New_York]

fold <- plain_date_time("2026-11-01T01:30")
temporal_to_zoned_date_time(fold, "America/New_York", disambiguation = "earlier")
#> <zutempo_zoned_date_time[1]>
#> [1] 2026-11-01T01:30:00-04:00[America/New_York]
temporal_to_zoned_date_time(fold, "America/New_York", disambiguation = "later")
#> <zutempo_zoned_date_time[1]>
#> [1] 2026-11-01T01:30:00-05:00[America/New_York]
```

A string with both an offset and a zone says the moment twice. By
default they must agree; `offset` says what to do when a zone’s rules
changed after the string was written:

``` r

s <- "2026-03-07T09:00-04:00[America/New_York]"
try(zoned_date_time(s))
#> Error : the UTC offset -04:00 does not match the time zone "America/New_York" at that local time (element 1)
zoned_date_time(s, offset = "use")
#> <zutempo_zoned_date_time[1]>
#> [1] 2026-03-07T08:00:00-05:00[America/New_York]
zoned_date_time(s, offset = "ignore")
#> <zutempo_zoned_date_time[1]>
#> [1] 2026-03-07T09:00:00-05:00[America/New_York]
```

## Transitions

``` r

temporal_get_time_zone_transition(meeting, "next")
#> <zutempo_zoned_date_time[1]>
#> [1] 2026-03-08T03:00:00-04:00[America/New_York]
temporal_get_time_zone_transition(meeting, "previous")
#> <zutempo_zoned_date_time[1]>
#> [1] 2025-11-02T01:00:00-05:00[America/New_York]
```

## The database

Named zones come from the same IANA database base R reads, and the
lookup is case-insensitive:

``` r

zutempo_info()
#> zutempo 0.0.0.9000
#>   zufast 0.1.0, 128-bit arithmetic: __int128
#>   specification: tc39/proposal-temporal@e8cc03fc970a (2026-07-27)
#>   test262: tc39/test262@d53ebc8b1931 (2026-10-13)
#>   tzdata pin: 2026d; link table: 2026d
#>   tz database: /usr/share/zoneinfo (2026e, fat)
time_zone_id(zoned_date_time("2026-03-07T09:00[europe/lisbon]"))
#> [1] "Europe/Lisbon"
```

Fixed offsets and `UTC` need no database:

``` r

zoned_date_time("2026-03-07T09:00[+05:30]")
#> <zutempo_zoned_date_time[1]>
#> [1] 2026-03-07T09:00:00+05:30[+05:30]
now_time_zone_id()
#> [1] "UTC"
```
