# What zutempo was built against

The versions and pins that decide zutempo's behaviour: the package and
`zufast` versions, whether the 128-bit arithmetic uses the compiler's
`__int128`, and the commits of the Temporal specification and of test262
the package follows, with the tzdata release its fixtures come from. The
pins live in `inst/spec/PINS` and move only on purpose.

## Usage

``` r
zutempo_info()
```

## Value

A list of class `zutempo_info` with elements `package`, `zufast`,
`int128`, `spec_repository`, `spec_commit`, `spec_date`,
`test262_repository`, `test262_commit`, `test262_date` and `tzdata`.

## Examples

``` r
zutempo_info()
#> zutempo 0.0.0.9000
#>   zufast 0.1.0, 128-bit arithmetic: __int128
#>   specification: tc39/proposal-temporal@e8cc03fc970a (2026-07-27)
#>   test262: tc39/test262@d53ebc8b1931 (2026-10-13)
#>   tzdata: 2026d
```
