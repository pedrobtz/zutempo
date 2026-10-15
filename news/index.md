# Changelog

## zutempo 0.0.0.9000

- [`plain_date()`](https://pedrobtz.github.io/zutempo/reference/plain_date.md),
  [`plain_time()`](https://pedrobtz.github.io/zutempo/reference/plain_time.md)
  and
  [`plain_date_time()`](https://pedrobtz.github.io/zutempo/reference/plain_date_time.md):
  Temporal’s `PlainDate`, `PlainTime` and `PlainDateTime` as R vectors,
  built from fields with `overflow`, from ISO 8601 strings, or from each
  other, with every field accessor
  ([`year()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md),
  [`month_code()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md),
  [`day_of_week()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md),
  [`week_of_year()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md),
  [`hour()`](https://pedrobtz.github.io/zutempo/reference/temporal_fields.md),
  …),
  [`temporal_with()`](https://pedrobtz.github.io/zutempo/reference/temporal_with.md),
  [`temporal_with_plain_time()`](https://pedrobtz.github.io/zutempo/reference/temporal_with.md),
  [`temporal_with_calendar()`](https://pedrobtz.github.io/zutempo/reference/temporal_with.md),
  [`temporal_to_plain_date()`](https://pedrobtz.github.io/zutempo/reference/temporal_to_plain_date.md),
  [`temporal_to_plain_time()`](https://pedrobtz.github.io/zutempo/reference/temporal_to_plain_date.md),
  [`temporal_to_plain_date_time()`](https://pedrobtz.github.io/zutempo/reference/temporal_to_plain_date.md),
  [`temporal_equals()`](https://pedrobtz.github.io/zutempo/reference/temporal_equals.md),
  the `*_compare()` statics,
  [`temporal_round()`](https://pedrobtz.github.io/zutempo/reference/temporal_round.md)
  with the nine rounding modes, and
  [`temporal_to_string()`](https://pedrobtz.github.io/zutempo/reference/temporal_to_string.md).
  The vectors subset, combine, sort, print and sit in data frames;
  `vctrs` and `pillar` methods register when those packages load.
- [`zutempo_info()`](https://pedrobtz.github.io/zutempo/reference/zutempo_info.md)
  reports the package and `zufast` versions, whether the 128-bit
  arithmetic uses the compiler’s `__int128`, and the pinned commits of
  the Temporal specification and of test262 with the tzdata release the
  fixtures come from.
- The condition classes of the design: `zutempo_error`,
  `zutempo_range_error`, `zutempo_parse_error`, `zutempo_type_error` and
  `zutempo_tz_error`, each carrying the index of the first failing
  element.
