# Compare Temporal values

`temporal_equals()` is Temporal's `equals()`. The `*_compare()`
functions are the `compare()` statics: they return -1, 0 or 1 as the
first value comes before, at or after the second. All recycle their
arguments and propagate `NA`.

## Usage

``` r
temporal_equals(x, other)

# S3 method for class 'zutempo_instant'
temporal_equals(x, other)

# S3 method for class 'zutempo_plain_date_time'
temporal_equals(x, other)

# S3 method for class 'zutempo_plain_date'
temporal_equals(x, other)

# S3 method for class 'zutempo_plain_month_day'
temporal_equals(x, other)

# S3 method for class 'zutempo_plain_time'
temporal_equals(x, other)

# S3 method for class 'zutempo_plain_year_month'
temporal_equals(x, other)
```

## Arguments

- x, other:

  Values of one zutempo class, or strings that its constructor reads.

## Value

A logical vector for `temporal_equals()`, an integer vector for the
comparisons.

## Examples

``` r
temporal_equals(plain_date("2026-01-31"), "2026-01-31")
#> [1] TRUE
plain_date_compare(plain_date("2026-01-31"), plain_date("2026-02-01"))
#> [1] -1
plain_time_compare("12:30", "12:30")
#> [1] 0
```
