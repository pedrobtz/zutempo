# Read strings as a Temporal type, with `NA` for those that fail

The bulk-reading escape of the string constructors. A constructor such
as
[`plain_date()`](https://pedrobtz.github.io/zutempo/reference/plain_date.md)
stops at the first string it cannot read; `zutempo_parse()` reads the
rest and returns `NA` for each string that fails, with the reasons in an
attribute.

## Usage

``` r
zutempo_parse(x, type, ..., na_on_error = TRUE)
```

## Arguments

- x:

  A character vector.

- type:

  The type to read, as the name of its constructor: `"plain_date"`,
  `"plain_time"`, `"plain_date_time"`, `"plain_year_month"`,
  `"plain_month_day"`, `"instant"`, `"zoned_date_time"` or `"duration"`.

- ...:

  Options for the constructor, such as `disambiguation` and `offset` for
  `"zoned_date_time"`.

- na_on_error:

  `TRUE` (the default) returns `NA` for a string that cannot be read.
  `FALSE` raises the constructor's error for the first one, as calling
  the constructor does.

## Value

A vector of the class `type` names, as long as `x`. With
`na_on_error = TRUE` it has the attribute `"parse_errors"`: a data frame
with one row per failed string, giving its `index` in `x`, the 1-based
byte `position` where reading stopped (`NA` when the string was read but
its value was rejected), the condition `class` and the `message`.

## Details

A string fails when it does not follow the type's ISO 8601 / RFC 9557
grammar, or when it does but names a value the type cannot hold: a date
out of range, an unknown time zone, an offset that does not match its
zone. Both kinds become `NA`.

## See also

[`zutempo_parse_errors()`](https://pedrobtz.github.io/zutempo/reference/zutempo_parse_errors.md)
to read the attribute.

## Examples

``` r
x <- c("2026-03-07", "2026-13-01", NA, "2026-02-30")
d <- zutempo_parse(x, "plain_date")
d
#> <zutempo_plain_date[4]>
#> [1] 2026-03-07 <NA>       <NA>       <NA>      
zutempo_parse_errors(d)
#>   index position               class
#> 1     2        6 zutempo_parse_error
#> 2     4        9 zutempo_parse_error
#>                                                                                 message
#> 1    cannot parse "2026-13-01" as a date or date-time: month must be 01 to 12 at byte 6
#> 2 cannot parse "2026-02-30" as a date or date-time: no such day in that month at byte 9
try(zutempo_parse(x, "plain_date", na_on_error = FALSE))
#> Error : cannot parse "2026-13-01" as a date or date-time: month must be 01 to 12 at byte 6 (element 2)
```
