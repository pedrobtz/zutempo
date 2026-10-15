# Forget the parsed time zones

zutempo reads the time zone database the way base R does, and keeps the
zones it has parsed for the session (design 8.4). The cache clears by
itself when the option `zutempo.tzdir` or the `TZDIR` variable changes;
`zutempo_tz_reset()` clears it on demand, for a database that changed
under a running session.

## Usage

``` r
zutempo_tz_reset()
```

## Value

`NULL`, invisibly.

## Examples

``` r
zutempo_tz_reset()
```
