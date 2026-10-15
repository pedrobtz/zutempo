# The strings `zutempo_parse()` could not read

The strings
[`zutempo_parse()`](https://pedrobtz.github.io/zutempo/reference/zutempo_parse.md)
could not read

## Usage

``` r
zutempo_parse_errors(x)
```

## Arguments

- x:

  The result of
  [`zutempo_parse()`](https://pedrobtz.github.io/zutempo/reference/zutempo_parse.md).

## Value

The data frame of its `"parse_errors"` attribute: `index`, `position`,
`class` and `message` of each failed string. It has no rows when every
string was read, and is `NULL` for a value that
[`zutempo_parse()`](https://pedrobtz.github.io/zutempo/reference/zutempo_parse.md)
did not return.

## Examples

``` r
zutempo_parse_errors(zutempo_parse(c("12:30", "25:00"), "plain_time"))
#>   index position               class
#> 1     2        1 zutempo_parse_error
#>                                                           message
#> 1 cannot parse "25:00" as a time: hour must be 00 to 23 at byte 1
```
