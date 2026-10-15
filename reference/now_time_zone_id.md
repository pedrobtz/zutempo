# The current time in a time zone

Temporal's `Temporal.Now` functions: the system time zone as base R
reads it ([`Sys.timezone()`](https://rdrr.io/r/base/timezones.html),
falling back to `"UTC"`), and the current time as a
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
#> [1] 2026-10-15T19:19:36.99328351+00:00[UTC]
now_plain_date_time_iso("Asia/Tokyo")
#> <zutempo_plain_date_time[1]>
#> [1] 2026-10-16T04:19:36.995197773
now_plain_date_iso("Pacific/Auckland")
#> <zutempo_plain_date[1]>
#> [1] 2026-10-16
now_plain_time_iso("UTC")
#> <zutempo_plain_time[1]>
#> [1] 19:19:37.001838207
```
