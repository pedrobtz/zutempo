# Benchmark results

`tools/bench/bench.R` measures the five operations of design §12 and the
operations zutempo shares with `clock`, at 10⁶ elements each: the median
of five `bench::mark()` iterations. Not run on CRAN or in CI.

## 2026-10-15

Apple M1 (macOS), R 4.6.1, zutempo 0.0.0.9000 (stage 11 branch),
clock 0.7.4, bench 1.1.4. Times in seconds; memory is what the call
allocated in R.

### Design §12 targets

| Operation, 10⁶ elements | Target | zutempo | Memory | clock | Issue |
| --- | --- | --- | --- | --- | --- |
| Parse RFC 3339 strings with offset into `Instant` | < 0.3 | 0.356 | 23 MB | 0.475 | [#35](https://github.com/pedrobtz/zutempo/issues/35) |
| Parse RFC 9557 strings with a bracketed zone into `ZonedDateTime` | < 0.5 | 1.183 | 241 MB | 1.547 | [#36](https://github.com/pedrobtz/zutempo/issues/36) |
| `Instant` to `ZonedDateTime` field access, one zone | < 0.1 | 0.511 | 165 MB | 0.964 | [#37](https://github.com/pedrobtz/zutempo/issues/37) |
| `PlainDateTime` to `ZonedDateTime`, `compatible`, one zone | < 0.2 | 0.661 | 153 MB | 0.947 | [#38](https://github.com/pedrobtz/zutempo/issues/38) |
| Format `ZonedDateTime` to strings | < 0.4 | 0.809 | 23 MB | 2.354 | [#39](https://github.com/pedrobtz/zutempo/issues/39) |

Every target is missed, by a factor between 1.2 and 5. zutempo is faster
than `clock` on all five.

### Operations shared with `clock`

| Operation, 10⁶ elements | zutempo | clock | Issue |
| --- | --- | --- | --- |
| Parse RFC 3339 strings with offset | 0.356 | 0.475 | |
| Parse RFC 9557 strings with a zone | 1.183 | 1.547 | |
| Exact time to zoned time, then the hour | 0.511 | 0.964 | |
| Wall-clock time to zoned time, one zone | 0.661 | 0.947 | |
| Format zoned times | 0.809 | 2.354 | |
| Parse ISO date-times without offset | 0.138 | 0.454 | |
| Add one month to dates | 0.849 | 0.0095 | [#40](https://github.com/pedrobtz/zutempo/issues/40) |
| Date fields: year, month, day | 0.071 | 0.00045 | [#41](https://github.com/pedrobtz/zutempo/issues/41) |
| Exact time to `POSIXct` and back | 0.888 | 0.018 | [#42](https://github.com/pedrobtz/zutempo/issues/42) |

zutempo is slower than `clock` on the last three. `clock` keeps a date's
fields and a `POSIXct`-compatible count where zutempo keeps epoch days and
nanoseconds, and zutempo's conversion to `POSIXct` finds the nearest
double exactly.

The comparisons are approximate in kind: `clock` and Temporal differ on
some semantics (`clock`'s `invalid = "previous"` where Temporal
constrains, its `nonexistent` and `ambiguous` where Temporal has
`disambiguation`). Each row times the nearest operation each package
has; the script does not check that the two results are identical.
