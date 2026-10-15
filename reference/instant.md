# Exact times: Temporal's Instant

An `instant()` is an exact point on the time line with nanosecond
precision and no calendar or time zone, stored as a complex vector whose
real part is the whole seconds since 1970-01-01T00:00Z and whose
imaginary part is the nanoseconds within that second (design 4.1). The
range is 10^8 days either side of the epoch. The constructor is
`Temporal.Instant` and `Temporal.Instant.from()` in one.

## Usage

``` r
instant(x)

instant_from_epoch_milliseconds(x)

instant_from_epoch_nanoseconds(x)

instant_compare(x, y)
```

## Arguments

- x:

  A string in ISO 8601 form with `Z` or a UTC offset
  (`"2026-01-31T12:30:45.123456789Z"`, `"2026-01-31T12:30+05:30"`), or
  an `instant()` to return as is. For
  `instant_from_epoch_milliseconds()`, integral milliseconds since the
  epoch; for `instant_from_epoch_nanoseconds()`, integral nanoseconds as
  numbers exact in a double or as decimal strings.

- y:

  An `instant()` or a string, for `instant_compare()`.

## Value

An `instant()` vector; `instant_compare()` returns an integer vector of
-1, 0 and 1.

## Members

Every member of `Temporal.Instant` in the pinned specification
(`inst/spec/PINS`) and the R function that implements it:

|  |  |
|----|----|
| Temporal | R |
| `new Temporal.Instant()` | `instant()` |
| `Temporal.Instant.from()` | `instant()` |
| `Temporal.Instant.fromEpochMilliseconds()` | `instant_from_epoch_milliseconds()` |
| `Temporal.Instant.fromEpochNanoseconds()` | `instant_from_epoch_nanoseconds()` |
| `Temporal.Instant.compare()` | `instant_compare()` |
| `.epochMilliseconds` | [`epoch_milliseconds()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md) |
| `.epochNanoseconds` | [`epoch_nanoseconds()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md) |
| `.add()` | [`temporal_add()`](https://pedrobtz.github.io/zutempo/reference/temporal_add.md) |
| `.subtract()` | [`temporal_subtract()`](https://pedrobtz.github.io/zutempo/reference/temporal_add.md) |
| `.until()` | [`temporal_until()`](https://pedrobtz.github.io/zutempo/reference/temporal_until.md) |
| `.since()` | [`temporal_since()`](https://pedrobtz.github.io/zutempo/reference/temporal_until.md) |
| `.round()` | [`temporal_round()`](https://pedrobtz.github.io/zutempo/reference/temporal_round.md) |
| `.equals()` | [`temporal_equals()`](https://pedrobtz.github.io/zutempo/reference/temporal_equals.md) |
| `.toString()` | [`temporal_to_string()`](https://pedrobtz.github.io/zutempo/reference/temporal_to_string.md) |
| `.toLocaleString()` | none: ECMA-402 (locale formatting) is out of scope |
| `.toJSON()` | none: format() covers it |
| `.valueOf()` | none: throws in JavaScript; no R counterpart |
| `.toZonedDateTimeISO()` | [`temporal_to_zoned_date_time_iso()`](https://pedrobtz.github.io/zutempo/reference/temporal_to_instant.md) |

## Examples

``` r
instant("2026-01-31T12:30:45.123456789Z")
#> <zutempo_instant[1]>
#> [1] 2026-01-31T12:30:45.123456789Z
instant("2026-01-31T12:30+05:30")
#> <zutempo_instant[1]>
#> [1] 2026-01-31T07:00:00Z
instant_from_epoch_milliseconds(0)
#> <zutempo_instant[1]>
#> [1] 1970-01-01T00:00:00Z
instant_from_epoch_nanoseconds("8640000000000000000000")
#> <zutempo_instant[1]>
#> [1] +275760-09-13T00:00:00Z
epoch_nanoseconds(instant("+275760-09-13T00:00Z"))
#> [1] "8640000000000000000000"
instant_compare("1969-12-31T23:59:59Z", "1970-01-01T00:00Z")
#> [1] -1
```
