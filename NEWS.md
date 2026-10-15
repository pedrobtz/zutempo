# zutempo 0.0.0.9000

* `zutempo_info()` reports the package and `zufast` versions, whether the
  128-bit arithmetic uses the compiler's `__int128`, and the pinned commits
  of the Temporal specification and of test262 with the tzdata release the
  fixtures come from.
* The condition classes of the design: `zutempo_error`,
  `zutempo_range_error`, `zutempo_parse_error`, `zutempo_type_error` and
  `zutempo_tz_error`, each carrying the index of the first failing element.
