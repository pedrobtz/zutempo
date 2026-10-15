# Convert between the plain types

Temporal's `toPlainDate()`, `toPlainTime()` and `toPlainDateTime()`.

## Usage

``` r
temporal_to_plain_date(x)

# S3 method for class 'zutempo_plain_date_time'
temporal_to_plain_date(x)

# S3 method for class 'zutempo_plain_date_time'
temporal_to_plain_time(x)

# S3 method for class 'zutempo_plain_date'
temporal_to_plain_date_time(x, time = NULL)

temporal_to_plain_time(x)

temporal_to_plain_date_time(x, time = NULL)
```

## Arguments

- x:

  A zutempo value.

- time:

  For `temporal_to_plain_date_time()` on a
  [`plain_date()`](https://pedrobtz.github.io/zutempo/reference/plain_date.md):
  a
  [`plain_time()`](https://pedrobtz.github.io/zutempo/reference/plain_time.md),
  a string a
  [`plain_time()`](https://pedrobtz.github.io/zutempo/reference/plain_time.md)
  reads, or `NULL` for midnight.

## Value

A
[`plain_date()`](https://pedrobtz.github.io/zutempo/reference/plain_date.md),
[`plain_time()`](https://pedrobtz.github.io/zutempo/reference/plain_time.md)
or
[`plain_date_time()`](https://pedrobtz.github.io/zutempo/reference/plain_date_time.md).

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
```
