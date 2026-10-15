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
`test262_repository`, `test262_commit`, `test262_date`, `tzdata`,
`tzdir`, `tz_version`, `tz_form` and `tz_links_version`.

## Details

The time zone fields describe the database zutempo reads (design 8):
`tzdir`, the directory found by base R's lookup order (`NA` when none
exists), `tz_version`, the tzdata release it declares, `tz_form`,
whether its files carry explicit transitions far into the future
(`"fat"`) or stop at the last rule change (`"slim"`), and
`tz_links_version`, the tzdata release the built-in link table comes
from.

## Examples

``` r
zutempo_info()
#> zutempo 0.0.0.9000
#>   zufast 0.1.0, 128-bit arithmetic: __int128
#>   specification: tc39/proposal-temporal@e8cc03fc970a (2026-07-27)
#>   test262: tc39/test262@d53ebc8b1931 (2026-10-13)
#>   tzdata pin: 2026d; link table: 2026d
#>   tz database: /usr/share/zoneinfo (2026c, fat)
```
