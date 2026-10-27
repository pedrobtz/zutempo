# The current time in a time zone

Temporal's `Temporal.Now` functions: the system time zone, and the
current time as a
[`zoned_date_time()`](https://pedrobtz.github.io/zutempo/reference/zoned_date_time.md),
[`plain_date_time()`](https://pedrobtz.github.io/zutempo/reference/plain_date_time.md),
[`plain_date()`](https://pedrobtz.github.io/zutempo/reference/plain_date.md)
or
[`plain_time()`](https://pedrobtz.github.io/zutempo/reference/plain_time.md)
in that zone or in `time_zone`.

## Usage

``` r
now_time_zone_id()

now_zoned_date_time_iso(time_zone = NULL)

now_plain_date_time_iso(time_zone = NULL)

now_plain_date_iso(time_zone = NULL)

now_plain_time_iso(time_zone = NULL)
```

## Arguments

- time_zone:

  A time zone identifier, or `NULL` for the system zone.

## Value

`now_time_zone_id()` returns a string; the others the value named.

## Details

The system time zone is read as the C library that base R formats with
reads it. The `TZ` environment variable comes first, without a leading
`:`; a path under a zone directory, such as
`/usr/share/zoneinfo/Europe/Berlin`, names the zone at that path.
Without `TZ` it is
[`Sys.timezone()`](https://rdrr.io/r/base/timezones.html), and without
either it is `"UTC"`. A zone that is set but cannot be read, such as a
POSIX TZ string or a zone the database lacks, gives `"UTC"` with a
warning of class `zutempo_tz_warning`.

## Members

Every member of `Temporal.Now` in the pinned specification
(`inst/spec/PINS`) and the R function that implements it:

|  |  |
|----|----|
| Temporal | R |
| `Temporal.Now.timeZoneId()` | `now_time_zone_id()` |
| `Temporal.Now.instant()` | [`now_instant()`](https://pedrobtz.github.io/zutempo/reference/now_instant.md) |
| `Temporal.Now.plainDateTimeISO()` | `now_plain_date_time_iso()` |
| `Temporal.Now.zonedDateTimeISO()` | `now_zoned_date_time_iso()` |
| `Temporal.Now.plainDateISO()` | `now_plain_date_iso()` |
| `Temporal.Now.plainTimeISO()` | `now_plain_time_iso()` |

## Examples

``` r
now_time_zone_id()
#> [1] "UTC"
now_zoned_date_time_iso()
#> <zutempo_zoned_date_time[1]>
#> [1] 2026-10-27T20:30:02.943218231+00:00[UTC]
now_plain_date_time_iso("Asia/Tokyo")
#> <zutempo_plain_date_time[1]>
#> [1] 2026-10-28T05:30:02.947572947
now_plain_date_iso("Pacific/Auckland")
#> <zutempo_plain_date[1]>
#> [1] 2026-10-28
now_plain_time_iso("UTC")
#> <zutempo_plain_time[1]>
#> [1] 20:30:02.953391075
```
