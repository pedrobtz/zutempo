# Calendar dates: Temporal's PlainDate

A `plain_date()` is a calendar date in the ISO 8601 calendar with no
time of day and no time zone, stored as an integer count of days since
1970-01-01 (design 4.1). The constructor is `Temporal.PlainDate` and
`Temporal.PlainDate.from()` in one: it reads fields, strings or another
zutempo value.

## Usage

``` r
plain_date(
  year,
  month = NULL,
  day = NULL,
  ...,
  month_code = NULL,
  overflow = "constrain"
)

plain_date_compare(x, y)
```

## Arguments

- year:

  The year, or a string in ISO 8601 form (`"2026-01-31"`, a date-time
  whose time is ignored, or a year with a sign and six digits such as
  `"+275760-09-13"`), or a `plain_date()` or
  [`plain_date_time()`](https://pedrobtz.github.io/zutempo/reference/plain_date_time.md)
  to convert.

- month, day:

  The month (1 to 12) and day of the month, when `year` is a number.
  `month` may be replaced by `month_code`.

- ...:

  Must be empty.

- month_code:

  The month as `"M01"` to `"M12"`, instead of `month`.

- overflow:

  `"constrain"` (the default) clamps `month` and `day` to their valid
  ranges, `"reject"` raises a `zutempo_range_error` for them (design
  6.2).

- x, y:

  `plain_date()` values or strings, for `plain_date_compare()`.

## Value

A `plain_date()` vector; `plain_date_compare()` returns an integer
vector of -1, 0 and 1.

## Details

Dates run from -271821-04-19 to +275760-09-13. A result outside that
range is a `zutempo_range_error`, never `NA`.

## Members

Every member of `Temporal.PlainDate` in the pinned specification
(`inst/spec/PINS`) and the R function that implements it:

|  |  |
|----|----|
| Temporal | R |
| `new Temporal.PlainDate()` | `plain_date()` |
| `Temporal.PlainDate.from()` | `plain_date()` |
| `Temporal.PlainDate.compare()` | `plain_date_compare()` |
| `.calendarId` | [`calendar_id()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md) |
| `.era` | [`era()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md) |
| `.eraYear` | [`era_year()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md) |
| `.year` | [`year()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md) |
| `.month` | [`month()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md) |
| `.monthCode` | [`month_code()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md) |
| `.day` | [`day()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md) |
| `.dayOfWeek` | [`day_of_week()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md) |
| `.dayOfYear` | [`day_of_year()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md) |
| `.weekOfYear` | [`week_of_year()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md) |
| `.yearOfWeek` | [`year_of_week()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md) |
| `.daysInWeek` | [`days_in_week()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md) |
| `.daysInMonth` | [`days_in_month()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md) |
| `.daysInYear` | [`days_in_year()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md) |
| `.monthsInYear` | [`months_in_year()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md) |
| `.inLeapYear` | [`in_leap_year()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md) |
| `.toPlainYearMonth()` | [`temporal_to_plain_year_month()`](https://pedrobtz.github.io/zutempo/reference/temporal_to_plain_date.md) |
| `.toPlainMonthDay()` | [`temporal_to_plain_month_day()`](https://pedrobtz.github.io/zutempo/reference/temporal_to_plain_date.md) |
| `.add()` | [`temporal_add()`](https://pedrobtz.github.io/zutempo/reference/temporal_add.md) |
| `.subtract()` | [`temporal_subtract()`](https://pedrobtz.github.io/zutempo/reference/temporal_add.md) |
| `.with()` | [`temporal_with()`](https://pedrobtz.github.io/zutempo/reference/temporal_with.md) |
| `.withCalendar()` | [`temporal_with_calendar()`](https://pedrobtz.github.io/zutempo/reference/temporal_with.md) |
| `.until()` | [`temporal_until()`](https://pedrobtz.github.io/zutempo/reference/temporal_until.md) |
| `.since()` | [`temporal_since()`](https://pedrobtz.github.io/zutempo/reference/temporal_until.md) |
| `.equals()` | [`temporal_equals()`](https://pedrobtz.github.io/zutempo/reference/temporal_equals.md) |
| `.toPlainDateTime()` | [`temporal_to_plain_date_time()`](https://pedrobtz.github.io/zutempo/reference/temporal_to_plain_date.md) |
| `.toZonedDateTime()` | [`temporal_to_zoned_date_time()`](https://pedrobtz.github.io/zutempo/reference/temporal_to_instant.md) |
| `.toString()` | [`temporal_to_string()`](https://pedrobtz.github.io/zutempo/reference/temporal_to_string.md) |
| `.toLocaleString()` | none: ECMA-402 (locale formatting) is out of scope |
| `.toJSON()` | none: format() covers it |
| `.valueOf()` | none: throws in JavaScript; no R counterpart |

## Examples

``` r
plain_date("2026-01-31")
#> <zutempo_plain_date[1]>
#> [1] 2026-01-31
plain_date(2026, 2, 31)
#> <zutempo_plain_date[1]>
#> [1] 2026-02-28
plain_date(2026, month_code = "M02", day = 29, overflow = "constrain")
#> <zutempo_plain_date[1]>
#> [1] 2026-02-28
plain_date(c("2026-01-31", NA, "+275760-09-13"))
#> <zutempo_plain_date[3]>
#> [1] 2026-01-31    <NA>          +275760-09-13
plain_date_compare(plain_date("2026-01-31"), "2026-02-01")
#> [1] -1
```
