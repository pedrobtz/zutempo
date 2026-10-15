# Convert between the plain types

Temporal's `toPlainDate()`, `toPlainTime()`, `toPlainDateTime()`,
`toPlainYearMonth()` and `toPlainMonthDay()`. A
[`plain_year_month()`](https://pedrobtz.github.io/zutempo/reference/plain_year_month.md)
needs the `day` and a
[`plain_month_day()`](https://pedrobtz.github.io/zutempo/reference/plain_month_day.md)
the `year` to become a date; both resolve it with
`overflow = "constrain"`, as Temporal does.

## Usage

``` r
temporal_to_plain_date(x, ...)

# S3 method for class 'zutempo_plain_date_time'
temporal_to_plain_date(x, ...)

# S3 method for class 'zutempo_plain_date_time'
temporal_to_plain_time(x)

# S3 method for class 'zutempo_plain_date'
temporal_to_plain_date_time(x, time = NULL)

# S3 method for class 'zutempo_plain_date'
temporal_to_plain_year_month(x)

# S3 method for class 'zutempo_plain_date'
temporal_to_plain_month_day(x)

# S3 method for class 'zutempo_plain_month_day'
temporal_to_plain_date(x, year, ...)

# S3 method for class 'zutempo_plain_year_month'
temporal_to_plain_date(x, day, ...)

temporal_to_plain_time(x)

temporal_to_plain_date_time(x, time = NULL)

temporal_to_plain_year_month(x)

temporal_to_plain_month_day(x)

# S3 method for class 'zutempo_zoned_date_time'
temporal_to_plain_date_time(x, time = NULL)

# S3 method for class 'zutempo_zoned_date_time'
temporal_to_plain_date(x, ...)

# S3 method for class 'zutempo_zoned_date_time'
temporal_to_plain_time(x)
```

## Arguments

- x:

  A zutempo value.

- ...:

  Must be empty.

- time:

  For `temporal_to_plain_date_time()` on a
  [`plain_date()`](https://pedrobtz.github.io/zutempo/reference/plain_date.md):
  a
  [`plain_time()`](https://pedrobtz.github.io/zutempo/reference/plain_time.md),
  a string a
  [`plain_time()`](https://pedrobtz.github.io/zutempo/reference/plain_time.md)
  reads, or `NULL` for midnight.

- year:

  The year that completes a
  [`plain_month_day()`](https://pedrobtz.github.io/zutempo/reference/plain_month_day.md).

- day:

  The day of the month that completes a
  [`plain_year_month()`](https://pedrobtz.github.io/zutempo/reference/plain_year_month.md).

## Value

A
[`plain_date()`](https://pedrobtz.github.io/zutempo/reference/plain_date.md),
[`plain_time()`](https://pedrobtz.github.io/zutempo/reference/plain_time.md),
[`plain_date_time()`](https://pedrobtz.github.io/zutempo/reference/plain_date_time.md),
[`plain_year_month()`](https://pedrobtz.github.io/zutempo/reference/plain_year_month.md)
or
[`plain_month_day()`](https://pedrobtz.github.io/zutempo/reference/plain_month_day.md).

## Examples

``` r
x <- plain_date_time("2026-01-31T12:30:45")
temporal_to_plain_date(x)
#> <zutempo_plain_date[1]>
#> [1] 2026-01-31
temporal_to_plain_time(x)
#> <zutempo_plain_time[1]>
#> [1] 12:30:45
temporal_to_plain_date_time(plain_date("2026-01-31"), "08:00")
#> <zutempo_plain_date_time[1]>
#> [1] 2026-01-31T08:00:00
temporal_to_plain_year_month(plain_date("2026-01-31"))
#> <zutempo_plain_year_month[1]>
#> [1] 2026-01
temporal_to_plain_month_day(plain_date("2026-01-31"))
#> <zutempo_plain_month_day[1]>
#> [1] 01-31
temporal_to_plain_date(plain_year_month("2026-02"), day = 31)
#> <zutempo_plain_date[1]>
#> [1] 2026-02-28
temporal_to_plain_date(plain_month_day("02-29"), year = 2025)
#> <zutempo_plain_date[1]>
#> [1] 2025-02-28
```
