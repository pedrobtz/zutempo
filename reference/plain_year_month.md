# Months: Temporal's PlainYearMonth

A `plain_year_month()` is a month of a year in the ISO 8601 calendar,
stored as an integer count of months since January 1970. The constructor
is `Temporal.PlainYearMonth` and `Temporal.PlainYearMonth.from()` in
one: it reads fields, strings or a
[`plain_date()`](https://pedrobtz.github.io/zutempo/reference/plain_date.md)
or
[`plain_date_time()`](https://pedrobtz.github.io/zutempo/reference/plain_date_time.md).

## Usage

``` r
plain_year_month(
  year,
  month = NULL,
  ...,
  month_code = NULL,
  overflow = "constrain"
)

plain_year_month_compare(x, y)
```

## Arguments

- year:

  The year, or a string in ISO 8601 form (`"2026-03"`, `"202603"`, or a
  full date or date-time whose day and time are ignored), or a
  `plain_year_month()`,
  [`plain_date()`](https://pedrobtz.github.io/zutempo/reference/plain_date.md)
  or
  [`plain_date_time()`](https://pedrobtz.github.io/zutempo/reference/plain_date_time.md)
  to convert.

- month:

  The month (1 to 12), when `year` is a number. May be replaced by
  `month_code`.

- ...:

  Must be empty.

- month_code:

  The month as `"M01"` to `"M12"`, instead of `month`.

- overflow:

  `"constrain"` (the default) clamps `month` to 1 to 12, `"reject"`
  raises a `zutempo_range_error`.

- x, y:

  `plain_year_month()` values or strings, for
  `plain_year_month_compare()`.

## Value

A `plain_year_month()` vector; `plain_year_month_compare()` returns an
integer vector of -1, 0 and 1.

## Details

Months run from -271821-04 to +275760-09, every month that holds a
representable
[`plain_date()`](https://pedrobtz.github.io/zutempo/reference/plain_date.md).

## Members

Every member of `Temporal.PlainYearMonth` in the pinned specification
(`inst/spec/PINS`) and the R function that implements it:

|  |  |
|----|----|
| Temporal | R |
| `new Temporal.PlainYearMonth()` | `plain_year_month()` |
| `Temporal.PlainYearMonth.from()` | `plain_year_month()` |
| `Temporal.PlainYearMonth.compare()` | `plain_year_month_compare()` |
| `.calendarId` | [`calendar_id()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md) |
| `.era` | [`era()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md) |
| `.eraYear` | [`era_year()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md) |
| `.year` | [`year()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md) |
| `.month` | [`month()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md) |
| `.monthCode` | [`month_code()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md) |
| `.daysInYear` | [`days_in_year()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md) |
| `.daysInMonth` | [`days_in_month()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md) |
| `.monthsInYear` | [`months_in_year()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md) |
| `.inLeapYear` | [`in_leap_year()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md) |
| `.with()` | [`temporal_with()`](https://pedrobtz.github.io/zutempo/reference/temporal_with.md) |
| `.add()` | [`temporal_add()`](https://pedrobtz.github.io/zutempo/reference/temporal_add.md) |
| `.subtract()` | [`temporal_subtract()`](https://pedrobtz.github.io/zutempo/reference/temporal_add.md) |
| `.until()` | [`temporal_until()`](https://pedrobtz.github.io/zutempo/reference/temporal_until.md) |
| `.since()` | [`temporal_since()`](https://pedrobtz.github.io/zutempo/reference/temporal_until.md) |
| `.equals()` | [`temporal_equals()`](https://pedrobtz.github.io/zutempo/reference/temporal_equals.md) |
| `.toString()` | [`temporal_to_string()`](https://pedrobtz.github.io/zutempo/reference/temporal_to_string.md) |
| `.toLocaleString()` | none: ECMA-402 (locale formatting) is out of scope |
| `.toJSON()` | none: format() covers it |
| `.valueOf()` | none: throws in JavaScript; no R counterpart |
| `.toPlainDate()` | [`temporal_to_plain_date()`](https://pedrobtz.github.io/zutempo/reference/temporal_to_plain_date.md) |

## Examples

``` r
plain_year_month("2026-03")
#> <zutempo_plain_year_month[1]>
#> [1] 2026-03
plain_year_month(2026, 3)
#> <zutempo_plain_year_month[1]>
#> [1] 2026-03
plain_year_month(plain_date("2026-03-15"))
#> <zutempo_plain_year_month[1]>
#> [1] 2026-03
temporal_to_plain_date(plain_year_month("2026-02"), day = 31)
#> <zutempo_plain_date[1]>
#> [1] 2026-02-28
plain_year_month_compare("2026-02", "2026-03")
#> [1] -1
```
