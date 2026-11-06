# Forget the parsed time zones

zutempo reads the time zone database the way base R does, and keeps the
zones it has parsed for the session. The cache clears by itself when the
option `zutempo.tzdir` or the `TZDIR` variable changes;
`zutempo_tz_reset()` clears it on demand, and looks for the database
again, for a database that appeared or changed under a running session.

## Usage

``` r
zutempo_tz_reset()
```

## Value

`NULL`, invisibly.

## Details

On macOS, base R's
[`Sys.timezone()`](https://rdrr.io/r/base/timezones.html) sets `TZDIR`
to the system's database the first time it runs. zutempo follows
`TZDIR`, so that it reads the database base R formats with. The first
call that reads the system zone, such as
[`now_time_zone_id()`](https://pedrobtz.github.io/zutempo/reference/now_time_zone_id.md)
or a conversion with `tz = ""`, can therefore move zutempo from R's own
copy to the system's and clear the cache.
[`zutempo_info()`](https://pedrobtz.github.io/zutempo/reference/zutempo_info.md)
shows the database in use.

## Examples

``` r
zutempo_tz_reset()
```
