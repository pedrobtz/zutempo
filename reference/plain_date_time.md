# Calendar dates with clock times: Temporal's PlainDateTime

A `plain_date_time()` is a calendar date in the ISO 8601 calendar with a
time of day to the nanosecond and no time zone, stored as a complex
vector whose real part is the epoch day and whose imaginary part is the
nanoseconds of day (design 4.1). The constructor is
`Temporal.PlainDateTime` and `Temporal.PlainDateTime.from()` in one: it
reads fields, strings or another zutempo value.

## Usage

``` r
plain_date_time(
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
  month_code = NULL,
  overflow = "constrain"
)

plain_date_time_compare(x, y)
```

## Arguments

- year:

  The year, or a string in ISO 8601 form (`"2026-01-31T12:30:45.5"`, a
  date alone for midnight, an offset is ignored and `Z` is rejected), or
  a
  [`plain_date()`](https://pedrobtz.github.io/zutempo/reference/plain_date.md)
  (for midnight) or `plain_date_time()` to convert.

- month, day:

  The month (1 to 12) and day of the month, when `year` is a number.
  `month` may be replaced by `month_code`.

- hour, minute, second, millisecond, microsecond, nanosecond:

  The time fields, 0 by default.

- ...:

  Must be empty.

- month_code:

  The month as `"M01"` to `"M12"`, instead of `month`.

- overflow:

  `"constrain"` (the default) clamps each field to its range, `"reject"`
  raises a `zutempo_range_error` (design 6.2).

- x, y:

  `plain_date_time()` values or strings, for
  `plain_date_time_compare()`.

## Value

A `plain_date_time()` vector; `plain_date_time_compare()` returns an
integer vector of -1, 0 and 1.

## Details

Values may lie up to a day beyond the range of a
[`plain_date()`](https://pedrobtz.github.io/zutempo/reference/plain_date.md),
from just after -271821-04-19T00:00 to the end of +275760-09-13. A
result outside that range is a `zutempo_range_error`, never `NA`.

## Examples

``` r
plain_date_time("2026-01-31T12:30:45.5")
#> <zutempo_plain_date_time[1]>
#> [1] 2026-01-31T12:30:45.5
plain_date_time(2026, 1, 31, 12, 30)
#> <zutempo_plain_date_time[1]>
#> [1] 2026-01-31T12:30:00
plain_date_time(plain_date("2026-01-31"))
#> <zutempo_plain_date_time[1]>
#> [1] 2026-01-31T00:00:00
plain_date_time_compare("2026-01-31T12:30", "2026-01-31T12:31")
#> [1] -1
```
