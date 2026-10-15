
<!-- README.md is generated from README.Rmd. Please edit that file -->

# zutempo

<!-- badges: start -->

[![R-CMD-check](https://github.com/pedrobtz/zutempo/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/pedrobtz/zutempo/actions/workflows/R-CMD-check.yaml)
[![coverage](https://raw.githubusercontent.com/pedrobtz/zutempo/gh-pages/badges/coverage.svg)](https://github.com/pedrobtz/zutempo/actions/workflows/coverage.yaml)
[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
<!-- badges: end -->

## Overview

Dates and times are hard to get right. A day is not always 24 hours, one
month after 31 January is not a date, a clock time can happen twice or
not at all, and the same moment is a different date in Tokyo than in New
York. Most code gets these cases right by accident, or not at all.

[Temporal](https://tc39.es/proposal-temporal/docs/) is JavaScript’s
answer: a date and time API designed by the committee that standardises
the language, specified to the last nanosecond and tested by thousands
of conformance tests. zutempo brings Temporal to R.

- **The right type for each job.** A `plain_date()` is a date on a
  calendar, a `plain_time()` a time on a wall clock, an `instant()` an
  exact moment, a `zoned_date_time()` a moment in a time zone, and a
  `duration()` an amount of time. Each does what it says, and never
  silently becomes another.

- **Arithmetic you can trust.** Adding a month, a day or 24 hours each
  mean what they should, across month ends, leap years and clock
  changes, and the ambiguous cases ask you how to resolve them instead
  of guessing.

- **The same answers everywhere.** zutempo follows the Temporal
  specification operation by operation, so a result in R is the result
  in a browser or in Node. It is checked against test262, the
  specification’s own conformance suite.

- **At home in R.** Values are vectors with `NA`, fit in data frames,
  convert to and from `Date` and `POSIXct`, and read time zones from the
  same database base R uses. The engine is in C, with no runtime
  dependencies.

## Installation

zutempo is not on CRAN yet. You can install the development version from
GitHub:

``` r
# install.packages("pak")
pak::pak("pedrobtz/zutempo")
```

## Usage

``` r
library(zutempo)
```

A team meets every day at 9:30 in New York. Clocks go forward on the
night of 7 March, so the next meeting is one day later, but only 23
hours later:

``` r
meeting <- zoned_date_time("2026-03-07T09:30[America/New_York]")
temporal_add(meeting, "P1D")
#> <zutempo_zoned_date_time[1]>
#> [1] 2026-03-08T09:30:00-04:00[America/New_York]
temporal_until(meeting, temporal_add(meeting, "P1D"))
#> <zutempo_duration[1]>
#> [1] PT23H
```

Where is everyone else at that moment?

``` r
temporal_with_time_zone(meeting, c("Europe/Lisbon", "Asia/Tokyo"))
#> <zutempo_zoned_date_time[2]>
#> [1] 2026-03-07T14:30:00+00:00[Europe/Lisbon]
#> [2] 2026-03-07T23:30:00+09:00[Asia/Tokyo]
```

Calendar arithmetic knows that months have different lengths:

``` r
due <- plain_date(c("2026-01-31", "2026-03-31", "2026-05-15"))
temporal_add(due, "P1M")
#> <zutempo_plain_date[3]>
#> [1] 2026-02-28 2026-04-30 2026-06-15
temporal_until(plain_date("2026-01-31"), "2026-12-25", largest_unit = "month")
#> <zutempo_duration[1]>
#> [1] P10M25D
```

And durations are values you can round, compare and total:

``` r
temporal_round(duration(minutes = 200), largest_unit = "hour")
#> <zutempo_duration[1]>
#> [1] PT3H20M
duration("PT90M") < duration("PT2H")
#> [1] TRUE
temporal_total(duration("P1M"), "day", relative_to = "2026-02-01")
#> [1] 28
```

Every function follows one naming rule: a Temporal type is a constructor
(`plain_date()`), a method is `temporal_` and its name
(`temporal_add()`), and a property is a function of its name (`year()`,
`hours_in_day()`). If you know Temporal, you already know zutempo.

## Learn more

- [Get
  started](https://pedrobtz.github.io/zutempo/articles/zutempo.html)
  follows one value from construction to base R.
- Articles on [plain dates and
  times](https://pedrobtz.github.io/zutempo/articles/plain-types.html),
  [durations](https://pedrobtz.github.io/zutempo/articles/durations.html),
  [instants and time
  zones](https://pedrobtz.github.io/zutempo/articles/time-zones.html),
  [strings and
  formatting](https://pedrobtz.github.io/zutempo/articles/strings.html),
  and [base R and data
  frames](https://pedrobtz.github.io/zutempo/articles/base-r.html).
- The
  [reference](https://pedrobtz.github.io/zutempo/reference/index.html)
  lists every Temporal member and the R function that implements it.

## Acknowledgements

zutempo is an implementation of the work of the [TC39 Temporal
champions](https://github.com/tc39/proposal-temporal), who designed the
API and wrote its specification and its
[test262](https://github.com/tc39/test262) tests.
[temporal-polyfill](https://github.com/fullcalendar/temporal-polyfill)
is the reference zutempo is checked against, and time zones come from
the [IANA time zone database](https://www.iana.org/time-zones).
[lubridate](https://lubridate.tidyverse.org) and
[clock](https://clock.r-lib.org) showed how much R users care about
getting dates and times right.
