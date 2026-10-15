# Negate or take the magnitude of a duration

Temporal's `negated()` and
[`abs()`](https://rdrr.io/r/base/MathFun.html). `abs(x)` and `sign(x)`
also work on a
[`duration()`](https://pedrobtz.github.io/zutempo/reference/duration.md)
through R's `Math` group generic.

## Usage

``` r
temporal_negated(x)

# S3 method for class 'zutempo_duration'
temporal_negated(x)

temporal_abs(x)

# S3 method for class 'zutempo_duration'
temporal_abs(x)
```

## Arguments

- x:

  A
  [`duration()`](https://pedrobtz.github.io/zutempo/reference/duration.md).

## Value

A
[`duration()`](https://pedrobtz.github.io/zutempo/reference/duration.md).

## Examples

``` r
temporal_negated(duration("P1DT2H"))
#> <zutempo_duration[1]>
#> [1] -P1DT2H
temporal_abs(duration("-P1DT2H"))
#> <zutempo_duration[1]>
#> [1] P1DT2H
sign(duration("-P1DT2H"))
#> [1] -1
```
