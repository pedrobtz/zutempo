# Clock times: Temporal's PlainTime

A `plain_time()` is a time of day with nanosecond precision and no date
or time zone, stored as a double count of nanoseconds since midnight
(design 4.1). The constructor is `Temporal.PlainTime` and
`Temporal.PlainTime.from()` in one: it reads fields, strings or another
zutempo value.

## Usage

``` r
plain_time(
  hour = 0,
  minute = 0,
  second = 0,
  millisecond = 0,
  microsecond = 0,
  nanosecond = 0,
  ...,
  overflow = "constrain"
)

plain_time_compare(x, y)
```

## Arguments

- hour:

  The hour (0 to 23), or a string in ISO 8601 form (`"12:30"`,
  `"12:30:45.123456789"`, `"T12"`, or a date-time whose date is ignored;
  a bare time that could also read as a month-day or year-month must
  carry the `T` prefix), or a `plain_time()` or
  [`plain_date_time()`](https://pedrobtz.github.io/zutempo/reference/plain_date_time.md)
  to convert.

- minute, second, millisecond, microsecond, nanosecond:

  The remaining fields, 0 by default.

- ...:

  Must be empty.

- overflow:

  `"constrain"` (the default) clamps each field to its range, `"reject"`
  raises a `zutempo_range_error` (design 6.2).

- x, y:

  `plain_time()` values or strings, for `plain_time_compare()`.

## Value

A `plain_time()` vector; `plain_time_compare()` returns an integer
vector of -1, 0 and 1.

## Members

Every member of `Temporal.PlainTime` in the pinned specification
(`inst/spec/PINS`) and the R function that implements it:

|  |  |
|----|----|
| Temporal | R |
| `new Temporal.PlainTime()` | `plain_time()` |
| `Temporal.PlainTime.from()` | `plain_time()` |
| `Temporal.PlainTime.compare()` | `plain_time_compare()` |
| `.hour` | [`hour()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md) |
| `.minute` | [`minute()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md) |
| `.second` | [`second()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md) |
| `.millisecond` | [`millisecond()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md) |
| `.microsecond` | [`microsecond()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md) |
| `.nanosecond` | [`nanosecond()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md) |
| `.add()` | [`temporal_add()`](https://pedrobtz.github.io/zutempo/reference/temporal_add.md) |
| `.subtract()` | [`temporal_subtract()`](https://pedrobtz.github.io/zutempo/reference/temporal_add.md) |
| `.with()` | [`temporal_with()`](https://pedrobtz.github.io/zutempo/reference/temporal_with.md) |
| `.until()` | [`temporal_until()`](https://pedrobtz.github.io/zutempo/reference/temporal_until.md) |
| `.since()` | [`temporal_since()`](https://pedrobtz.github.io/zutempo/reference/temporal_until.md) |
| `.round()` | [`temporal_round()`](https://pedrobtz.github.io/zutempo/reference/temporal_round.md) |
| `.equals()` | [`temporal_equals()`](https://pedrobtz.github.io/zutempo/reference/temporal_equals.md) |
| `.toString()` | [`temporal_to_string()`](https://pedrobtz.github.io/zutempo/reference/temporal_to_string.md) |
| `.toLocaleString()` | none: ECMA-402 (locale formatting) is out of scope |
| `.toJSON()` | none: format() covers it |
| `.valueOf()` | none: throws in JavaScript; no R counterpart |

## Examples

``` r
plain_time("12:30:45.5")
#> <zutempo_plain_time[1]>
#> [1] 12:30:45.5
plain_time(12, 30)
#> <zutempo_plain_time[1]>
#> [1] 12:30:00
plain_time(25, overflow = "constrain")
#> <zutempo_plain_time[1]>
#> [1] 23:00:00
plain_time()
#> <zutempo_plain_time[1]>
#> [1] 00:00:00
plain_time_compare("12:30", "12:31")
#> [1] -1
```
