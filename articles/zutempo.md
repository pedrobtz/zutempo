# One zoned value, start to finish

This vignette follows one value, a meeting in New York, through what
zutempo does with it: building it, moving it in time, rounding it, and
handing it to base R.

## A meeting in New York

A
[`zoned_date_time()`](https://pedrobtz.github.io/zutempo/reference/zoned_date_time.md)
is an exact moment, the wall-clock time in a time zone, and the zone
itself. It reads RFC 9557 strings, with the zone in brackets:

``` r

meeting <- zoned_date_time("2026-03-07T09:30[America/New_York]")
meeting
#> <zutempo_zoned_date_time[1]>
#> [1] 2026-03-07T09:30:00-05:00[America/New_York]
offset(meeting)
#> [1] "-05:00"
hours_in_day(meeting)
#> [1] 24
```

The same moment can be built from fields and a zone:

``` r

zoned_date_time(2026, 3, 7, 9, 30, time_zone = "America/New_York")
#> <zutempo_zoned_date_time[1]>
#> [1] 2026-03-07T09:30:00-05:00[America/New_York]
```

## Moving it

New York’s clocks go forward at 02:00 on Sunday 8 March. A day later and
24 hours later are different moments:

``` r

temporal_add(meeting, "P1D")
#> <zutempo_zoned_date_time[1]>
#> [1] 2026-03-08T09:30:00-04:00[America/New_York]
temporal_add(meeting, "PT24H")
#> <zutempo_zoned_date_time[1]>
#> [1] 2026-03-08T10:30:00-04:00[America/New_York]
hours_in_day(temporal_add(meeting, "P1D"))
#> [1] 23
```

A wall-clock time can also fall in that gap. `disambiguation` says which
moment it means:

``` r

skipped <- plain_date_time("2026-03-08T02:30")
temporal_to_zoned_date_time(skipped, "America/New_York")
#> <zutempo_zoned_date_time[1]>
#> [1] 2026-03-08T03:30:00-04:00[America/New_York]
temporal_to_zoned_date_time(skipped, "America/New_York", disambiguation = "earlier")
#> <zutempo_zoned_date_time[1]>
#> [1] 2026-03-08T01:30:00-05:00[America/New_York]
try(temporal_to_zoned_date_time(skipped, "America/New_York", disambiguation = "reject"))
#> Error : the local time does not exist in this time zone (a clock gap) (element 1)
```

The time between two zoned values counts in hours by default, since days
need not be 24 hours long. Ask for days and they follow the calendar:

``` r

follow_up <- zoned_date_time("2026-03-09T09:30[America/New_York]")
temporal_until(meeting, follow_up)
#> <zutempo_duration[1]>
#> [1] PT47H
temporal_until(meeting, follow_up, largest_unit = "day")
#> <zutempo_duration[1]>
#> [1] P2D
```

## Rounding it

``` r

late <- zoned_date_time("2026-03-07T09:47:31.25[America/New_York]")
temporal_round(late, "minute")
#> <zutempo_zoned_date_time[1]>
#> [1] 2026-03-07T09:48:00-05:00[America/New_York]
temporal_round(late, "minute", rounding_increment = 15, rounding_mode = "floor")
#> <zutempo_zoned_date_time[1]>
#> [1] 2026-03-07T09:45:00-05:00[America/New_York]
temporal_to_string(late, smallest_unit = "second")
#> [1] "2026-03-07T09:47:31-05:00[America/New_York]"
```

Durations round too, relative to a moment when they hold days in a zone:

``` r

temporal_round(duration(hours = 47), largest_unit = "day", relative_to = meeting)
#> <zutempo_duration[1]>
#> [1] P2D
```

## The same moment elsewhere

``` r

tokyo <- temporal_with_time_zone(meeting, "Asia/Tokyo")
tokyo
#> <zutempo_zoned_date_time[1]>
#> [1] 2026-03-07T23:30:00+09:00[Asia/Tokyo]
```

[`temporal_equals()`](https://pedrobtz.github.io/zutempo/reference/temporal_equals.md)
compares the zone as well as the moment, so the two are not equal; their
instants are:

``` r

temporal_equals(meeting, tokyo)
#> [1] FALSE
temporal_equals(temporal_to_instant(meeting), temporal_to_instant(tokyo))
#> [1] TRUE
zoned_date_time_compare(meeting, tokyo)
#> [1] 0
```

## Handing it to base R

``` r

as.POSIXct(meeting)
#> [1] "2026-03-07 09:30:00 EST"
as.POSIXlt(meeting)
#> [1] "2026-03-07 09:30:00 EST"
as.Date(meeting)
#> [1] "2026-03-07"
```

And back, from a `POSIXct` with its `tzone`:

``` r

zoned_date_time(as.POSIXct("2026-03-07 09:30:00", tz = "America/New_York"))
#> <zutempo_zoned_date_time[1]>
#> [1] 2026-03-07T09:30:00-05:00[America/New_York]
```

A `POSIXct` is a double, precise to about a quarter of a microsecond at
today’s dates, where zutempo keeps nanoseconds. See `?base-r` for what
each conversion keeps and loses, and
[`?zutempo_options`](https://pedrobtz.github.io/zutempo/reference/zutempo_options.md)
for the options used above.
