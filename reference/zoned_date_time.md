# Exact times in a time zone: Temporal's ZonedDateTime

A `zoned_date_time()` is an exact time together with the time zone it is
read in, so that it has both an
[`instant()`](https://pedrobtz.github.io/zutempo/reference/instant.md)
and a wall-clock date and time. Every element carries its own zone
(design 4.2): the vector is an
[`instant()`](https://pedrobtz.github.io/zutempo/reference/instant.md)
with an integer zone code per element into the `zones` attribute, the
identifiers in the database's case. The constructor is
`Temporal.ZonedDateTime` and `Temporal.ZonedDateTime.from()` in one.

## Usage

``` r
zoned_date_time(
  year,
  month = NULL,
  day = NULL,
  hour = 0,
  minute = 0,
  second = 0,
  millisecond = 0,
  microsecond = 0,
  nanosecond = 0,
  ...,
  time_zone = NULL,
  month_code = NULL,
  offset_string = NULL,
  disambiguation = "compatible",
  offset = "reject",
  overflow = "constrain"
)

zoned_date_time_compare(x, y)
```

## Arguments

- year:

  The year, or a string in RFC 9557 form with the zone in brackets
  (`"2026-03-07T12:00[America/New_York]"`,
  `"2026-03-07T12:00-05:00[America/New_York]"`,
  `"2026-03-07T17:00Z[Europe/Lisbon]"` for the instant shown in that
  zone, `"2026-03-07[+05:30]"` for the start of that day), or a
  `zoned_date_time()` to return as is.

- month, day:

  The month (1 to 12) and day of the month, when `year` is a number.
  `month` may be replaced by `month_code`.

- hour, minute, second, millisecond, microsecond, nanosecond:

  The time fields, 0 by default.

- ...:

  Must be empty.

- time_zone:

  The time zone of each value, when `year` is a number: an IANA
  identifier such as `"Europe/Lisbon"`, `"UTC"`, or a fixed offset such
  as `"+05:30"`; recycled with the fields. Identifiers match regardless
  of case and are stored in the database's case.

- month_code:

  The month as `"M01"` to `"M12"`, instead of `month`.

- offset_string:

  The UTC offset the fields are given in, such as `"-05:00"`, when the
  fields carry one (Temporal's `offset` field); `offset` decides what
  happens when it disagrees with the zone.

- disambiguation:

  How to resolve a local time in a clock gap or fold: `"compatible"`,
  `"earlier"`, `"later"` or `"reject"`.

- offset:

  What to do with a UTC offset that disagrees with the zone: `"reject"`,
  `"use"`, `"ignore"` or `"prefer"`.

- overflow:

  `"constrain"` (the default) clamps each field to its range, `"reject"`
  raises a `zutempo_range_error` (design 6.2).

- x, y:

  `zoned_date_time()` values or strings, for
  `zoned_date_time_compare()`, which orders by the instant alone.

## Value

A `zoned_date_time()` vector; `zoned_date_time_compare()` returns an
integer vector of -1, 0 and 1.

## Details

A local time that does not exist (a clock gap) or exists twice (a fold)
is resolved by `disambiguation` (design 6.3): `"compatible"` (the
default) moves a gap forward by its length and takes the earlier of a
fold, `"earlier"` and `"later"` take that side, `"reject"` raises a
`zutempo_range_error`. When the fields or the string carry a UTC offset
as well as a zone, `offset` says what to do when the two disagree:
`"reject"` (the default for the constructor) raises, `"use"` trusts the
offset, `"ignore"` trusts the zone, `"prefer"` (the default for
[`temporal_with()`](https://pedrobtz.github.io/zutempo/reference/temporal_with.md))
trusts the offset when it is one of the zone's candidates and the zone
otherwise.

## Examples

``` r
zoned_date_time("2026-03-07T12:00[America/New_York]")
#> <zutempo_zoned_date_time[1]>
#> [1] 2026-03-07T12:00:00-05:00[America/New_York]
zoned_date_time(2026, 3, 8, 2, 30, time_zone = "America/New_York")
#> <zutempo_zoned_date_time[1]>
#> [1] 2026-03-08T03:30:00-04:00[America/New_York]
zoned_date_time(2026, 11, 1, 1, 30, time_zone = "America/New_York",
  disambiguation = "later")
#> <zutempo_zoned_date_time[1]>
#> [1] 2026-11-01T01:30:00-05:00[America/New_York]
zoned_date_time("2026-07-01T12:00+05:30[Asia/Kolkata]")
#> <zutempo_zoned_date_time[1]>
#> [1] 2026-07-01T12:00:00+05:30[Asia/Kolkata]
zoned_date_time_compare(
  "2026-03-07T12:00[America/New_York]",
  "2026-03-07T18:00[Europe/Lisbon]"
)
#> [1] -1
```
