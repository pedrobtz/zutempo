# zutempo 0.0.0.9000

* `plain_year_month()` and `plain_month_day()`: Temporal's `PlainYearMonth`
  and `PlainMonthDay` as R vectors, from fields, strings or dates, with
  their fields, `temporal_with()`, `temporal_equals()`,
  `plain_year_month_compare()`, `temporal_to_string()` and
  `temporal_to_plain_date()` taking the missing `day` or `year`;
  `temporal_to_plain_year_month()` and `temporal_to_plain_month_day()` on
  a `plain_date()`.
* `plain_date()`, `plain_time()` and `plain_date_time()`: Temporal's
  `PlainDate`, `PlainTime` and `PlainDateTime` as R vectors, built from
  fields with `overflow`, from ISO 8601 strings, or from each other, with
  every field accessor (`year()`, `month_code()`, `day_of_week()`,
  `week_of_year()`, `hour()`, ...), `temporal_with()`,
  `temporal_with_plain_time()`, `temporal_with_calendar()`,
  `temporal_to_plain_date()`, `temporal_to_plain_time()`,
  `temporal_to_plain_date_time()`, `temporal_equals()`, the `*_compare()`
  statics, `temporal_round()` with the nine rounding modes, and
  `temporal_to_string()`. The vectors subset, combine, sort, print and sit
  in data frames; `vctrs` and `pillar` methods register when those
  packages load.
* `zutempo_info()` reports the package and `zufast` versions, whether the
  128-bit arithmetic uses the compiler's `__int128`, and the pinned commits
  of the Temporal specification and of test262 with the tzdata release the
  fixtures come from.
* The condition classes of the design: `zutempo_error`,
  `zutempo_range_error`, `zutempo_parse_error`, `zutempo_type_error` and
  `zutempo_tz_error`, each carrying the index of the first failing element.
