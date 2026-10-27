# Days of the year: Temporal's PlainMonthDay

A `plain_month_day()` is a month and day with no year, such as a
birthday, in the ISO 8601 calendar, stored as an integer
`month * 32 + day`. Temporal keeps the day valid in a reference year,
1972, so February 29 is a `plain_month_day()`. The constructor is
`Temporal.PlainMonthDay` and `Temporal.PlainMonthDay.from()` in one: it
reads fields, strings or a
[`plain_date()`](https://pedrobtz.github.io/zutempo/reference/plain_date.md)
or
[`plain_date_time()`](https://pedrobtz.github.io/zutempo/reference/plain_date_time.md).

## Usage

``` r
plain_month_day(
  month,
  day = NULL,
  ...,
  month_code = NULL,
  year = NULL,
  overflow = "constrain"
)
```

## Arguments

- month:

  The month (1 to 12), or a string in ISO 8601 form (`"03-14"`,
  `"--03-14"`, `"0314"`, or a full date or date-time whose year and time
  are ignored), or a `plain_month_day()`,
  [`plain_date()`](https://pedrobtz.github.io/zutempo/reference/plain_date.md)
  or
  [`plain_date_time()`](https://pedrobtz.github.io/zutempo/reference/plain_date_time.md)
  to convert. May be replaced by `month_code`.

- day:

  The day of the month, when `month` is a number.

- ...:

  Must be empty.

- month_code:

  The month as `"M01"` to `"M12"`, instead of `month`.

- year:

  A year in which the day must exist; without it the reference year
  1972, a leap year, is used.

- overflow:

  `"constrain"` (the default) clamps `month` and `day`, `"reject"`
  raises a `zutempo_range_error`.

## Value

A `plain_month_day()` vector.

## Members

Every member of `Temporal.PlainMonthDay` in the pinned specification
(`inst/spec/PINS`) and the R function that implements it:

|  |  |
|----|----|
| Temporal | R |
| `new Temporal.PlainMonthDay()` | `plain_month_day()` |
| `Temporal.PlainMonthDay.from()` | `plain_month_day()` |
| `.calendarId` | [`calendar_id()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md) |
| `.monthCode` | [`month_code()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md) |
| `.day` | [`day()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md) |
| `.with()` | [`temporal_with()`](https://pedrobtz.github.io/zutempo/reference/temporal_with.md) |
| `.equals()` | [`temporal_equals()`](https://pedrobtz.github.io/zutempo/reference/temporal_equals.md) |
| `.toString()` | [`temporal_to_string()`](https://pedrobtz.github.io/zutempo/reference/temporal_to_string.md) |
| `.toLocaleString()` | none: ECMA-402 (locale formatting) is out of scope |
| `.toJSON()` | none: format() covers it |
| `.valueOf()` | none: throws in JavaScript; no R counterpart |
| `.toPlainDate()` | [`temporal_to_plain_date()`](https://pedrobtz.github.io/zutempo/reference/temporal_to_plain_date.md) |

## Examples

``` r
plain_month_day("02-29")
#> <zutempo_plain_month_day[1]>
#> [1] 02-29
plain_month_day(2, 29, year = 2025)
#> <zutempo_plain_month_day[1]>
#> [1] 02-28
plain_month_day(plain_date("2026-03-14"))
#> <zutempo_plain_month_day[1]>
#> [1] 03-14
temporal_to_plain_date(plain_month_day("02-29"), year = 2025)
#> <zutempo_plain_date[1]>
#> [1] 2025-02-28
```
