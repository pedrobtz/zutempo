# zutempo 0.0.0.9000

* Named IANA time zones resolve from the time zone database base R reads,
  in base R's lookup order (option `zutempo.tzdir`, `TZDIR`, then the
  platform's copies), on fat and slim files alike, with case-insensitive
  identifiers returned in the database's case. `temporal_to_string()` on an
  `instant()` takes a named `time_zone`; `zutempo_tz_reset()` forgets the
  parsed zones; `zutempo_info()` reports the database's directory, tzdata
  version and form (fat or slim) and the link table's version. A named zone
  without a database is a `zutempo_tz_error` naming the directories tried.
* `instant()`: Temporal's `Instant` over its full range, from strings with
  `Z` or an offset, `instant_from_epoch_milliseconds()` and
  `instant_from_epoch_nanoseconds()` (numbers or decimal strings), with
  `epoch_milliseconds()`, `epoch_nanoseconds()` as a decimal string,
  `instant_compare()`, `temporal_equals()`, `temporal_add()`,
  `temporal_subtract()`, `temporal_since()`, `temporal_until()`,
  `temporal_round()` as if positive, and `temporal_to_string()` with a
  `time_zone` of `"UTC"` or a fixed offset; `now_instant()`.
* `duration()`: Temporal's `Duration` as an R vector of ten exact fields,
  from fields or ISO 8601 strings, with `years()` to `nanoseconds()`,
  `blank()`, `sign()` and `abs()`, `temporal_with()`, `temporal_negated()`,
  `temporal_abs()`, `temporal_add()`, `temporal_subtract()`,
  `temporal_round()`, `temporal_total()`, `duration_compare()` and
  `temporal_to_string()`; calendar units take `relative_to`. `==` compares
  fields, and `<` and `sort()` order durations free of calendar units.
* `temporal_add()`, `temporal_subtract()`, `temporal_since()` and
  `temporal_until()` on `plain_date()`, `plain_time()`,
  `plain_date_time()` and `plain_year_month()`, with `overflow`,
  `largest_unit`, `smallest_unit`, `rounding_increment` and
  `rounding_mode`.
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
