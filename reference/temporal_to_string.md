# Format a Temporal value as an ISO 8601 string

Temporal's [`toString()`](https://rdrr.io/r/base/toString.html) with its
default options; [`format()`](https://rdrr.io/r/base/format.html) and
[`as.character()`](https://rdrr.io/r/base/character.html) give the same
strings. Years outside 0 to 9999 are written with a sign and six digits,
and a time's fraction keeps only its significant digits.

## Usage

``` r
temporal_to_string(x)

# S3 method for class 'zutempo_duration'
temporal_to_string(x)

# S3 method for class 'zutempo_plain_date_time'
temporal_to_string(x)

# S3 method for class 'zutempo_plain_date'
temporal_to_string(x)

# S3 method for class 'zutempo_plain_month_day'
temporal_to_string(x)

# S3 method for class 'zutempo_plain_time'
temporal_to_string(x)

# S3 method for class 'zutempo_plain_year_month'
temporal_to_string(x)
```

## Arguments

- x:

  A zutempo value.

## Value

A character vector, `NA` where `x` is `NA`.

## Examples

``` r
temporal_to_string(plain_date(c(2026, 275760), c(1, 9), c(31, 13)))
#> [1] "2026-01-31"    "+275760-09-13"
temporal_to_string(plain_time(12, 30, 45, 500))
#> [1] "12:30:45.5"
```
