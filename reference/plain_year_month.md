# Months: Temporal's PlainYearMonth

A `plain_year_month()` is a month of a year in the ISO 8601 calendar,
stored as an integer count of months since January 1970 (design 4.1).
The constructor is `Temporal.PlainYearMonth` and
`Temporal.PlainYearMonth.from()` in one: it reads fields, strings or a
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
  raises a `zutempo_range_error` (design 6.2).

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
