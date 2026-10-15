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
