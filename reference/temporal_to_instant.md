# Convert to and from zoned values

Temporal's `toInstant()`, `toZonedDateTimeISO()` and
`toZonedDateTime()`. An
[`instant()`](https://pedrobtz.github.io/zutempo/reference/instant.md)
becomes a
[`zoned_date_time()`](https://pedrobtz.github.io/zutempo/reference/zoned_date_time.md)
in any zone; a
[`plain_date_time()`](https://pedrobtz.github.io/zutempo/reference/plain_date_time.md)
is resolved in the zone with `disambiguation`; a
[`plain_date()`](https://pedrobtz.github.io/zutempo/reference/plain_date.md)
gives the start of that day in the zone, or the given `plain_time` on
that day.

## Usage

``` r
temporal_to_instant(x)

# S3 method for class 'zutempo_zoned_date_time'
temporal_to_instant(x)

temporal_to_zoned_date_time_iso(x, time_zone)

# S3 method for class 'zutempo_instant'
temporal_to_zoned_date_time_iso(x, time_zone)

temporal_to_zoned_date_time(x, time_zone, ...)

# S3 method for class 'zutempo_plain_date'
temporal_to_zoned_date_time(x, time_zone, ..., plain_time = NULL)

# S3 method for class 'zutempo_plain_date_time'
temporal_to_zoned_date_time(x, time_zone, ..., disambiguation = "compatible")
```

## Arguments

- x:

  A zutempo value.

- time_zone:

  A time zone identifier (`"Europe/Lisbon"`, `"UTC"`, `"+05:30"`), or a
  [`zoned_date_time()`](https://pedrobtz.github.io/zutempo/reference/zoned_date_time.md)
  of length one to take the zone from.

- ...:

  Must be empty.

- plain_time:

  For a
  [`plain_date()`](https://pedrobtz.github.io/zutempo/reference/plain_date.md):
  a
  [`plain_time()`](https://pedrobtz.github.io/zutempo/reference/plain_time.md),
  a string a
  [`plain_time()`](https://pedrobtz.github.io/zutempo/reference/plain_time.md)
  reads, or `NULL` for the start of the day.

- disambiguation:

  For a
  [`plain_date_time()`](https://pedrobtz.github.io/zutempo/reference/plain_date_time.md):
  how to resolve a local time in a clock gap or fold, as for
  [`zoned_date_time()`](https://pedrobtz.github.io/zutempo/reference/zoned_date_time.md).

## Value

An
[`instant()`](https://pedrobtz.github.io/zutempo/reference/instant.md)
or a
[`zoned_date_time()`](https://pedrobtz.github.io/zutempo/reference/zoned_date_time.md).

## Examples

``` r
x <- zoned_date_time("2026-03-07T12:00[America/New_York]")
temporal_to_instant(x)
#> <zutempo_instant[1]>
#> [1] 2026-03-07T17:00:00Z
temporal_to_zoned_date_time_iso(
  instant("2026-03-07T17:00Z"),
  "Europe/Lisbon"
)
#> <zutempo_zoned_date_time[1]>
#> [1] 2026-03-07T17:00:00+00:00[Europe/Lisbon]
temporal_to_zoned_date_time(plain_date("2026-03-08"), "America/New_York")
#> <zutempo_zoned_date_time[1]>
#> [1] 2026-03-08T00:00:00-05:00[America/New_York]
temporal_to_zoned_date_time(
  plain_date_time("2026-03-08T02:30"),
  "America/New_York",
  disambiguation = "earlier"
)
#> <zutempo_zoned_date_time[1]>
#> [1] 2026-03-08T01:30:00-05:00[America/New_York]
```
