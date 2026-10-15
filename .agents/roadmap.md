# zutempo: roadmap

Status: draft 2026-10-15. Implements [design.md](design.md).
Target: v0.1.0, the first CRAN release.
Tracking: [v0.1.0 (#2)](https://github.com/pedrobtz/zutempo/issues/2), with one
sub-issue per stage;
[CRAN-submission (#17)](https://github.com/pedrobtz/zutempo/issues/17).

The stages follow §14 of the design, split where one of its rows would not
fit a single review: design stage 0 becomes stages 0 and 1, design stage 1
becomes stages 2 and 3, design stage 5 becomes stages 7 and 8, and design
stage 9 becomes stages 12 and 13. Each stage ends in a package that passes
`R CMD check` on every r-actions leg and merges as one pull request.

Starting point (2026-10-15): a `usethis` skeleton. `R-CMD-check` and
`coverage` already call `pedrobtz/r-actions`, `.Rbuildignore` already
excludes `.agents`, and `pkgdown` deploys. `DESCRIPTION` is template text,
`src/` holds an empty translation unit, and there is no `CLAUDE.md`.

## Stages

| Stage | Title | Issue | Pull request | Done |
| --- | --- | --- | --- | --- |
| 0 | [Package identity](#stage-0--package-identity) | [#3](https://github.com/pedrobtz/zutempo/issues/3) | [#19](https://github.com/pedrobtz/zutempo/pull/19) | 2026-10-15 |
| 1 | [Engine scaffold, pinned specification and oracle](#stage-1--engine-scaffold-pinned-specification-and-oracle) | [#4](https://github.com/pedrobtz/zutempo/issues/4) | [#20](https://github.com/pedrobtz/zutempo/pull/20) | 2026-10-15 |
| 2 | [PlainDate, PlainTime and PlainDateTime](#stage-2--plaindate-plaintime-and-plaindatetime) | [#5](https://github.com/pedrobtz/zutempo/issues/5) | [#21](https://github.com/pedrobtz/zutempo/pull/21) | 2026-10-15 |
| 3 | [PlainYearMonth and PlainMonthDay](#stage-3--plainyearmonth-and-plainmonthday) | [#6](https://github.com/pedrobtz/zutempo/issues/6) | [#22](https://github.com/pedrobtz/zutempo/pull/22) | 2026-10-15 |
| 4 | [Duration and plain arithmetic](#stage-4--duration-and-plain-arithmetic) | [#7](https://github.com/pedrobtz/zutempo/issues/7) | [#23](https://github.com/pedrobtz/zutempo/pull/23) | 2026-10-15 |
| 5 | [Instant and fixed-offset zones](#stage-5--instant-and-fixed-offset-zones) | [#8](https://github.com/pedrobtz/zutempo/issues/8) | [#24](https://github.com/pedrobtz/zutempo/pull/24) | 2026-10-15 |
| 6 | [Time zone database](#stage-6--time-zone-database) | [#9](https://github.com/pedrobtz/zutempo/issues/9) | | |
| 7 | [ZonedDateTime](#stage-7--zoneddatetime) | [#10](https://github.com/pedrobtz/zutempo/issues/10) | | |
| 8 | [Zone-aware arithmetic and transitions](#stage-8--zone-aware-arithmetic-and-transitions) | [#11](https://github.com/pedrobtz/zutempo/issues/11) | | |
| 9 | [RFC 9557 annotations and formatting options](#stage-9--rfc-9557-annotations-and-formatting-options) | [#12](https://github.com/pedrobtz/zutempo/issues/12) | | |
| 10 | [Base R conversions and epoch nanoseconds](#stage-10--base-r-conversions-and-epoch-nanoseconds) | [#13](https://github.com/pedrobtz/zutempo/issues/13) | | |
| 11 | [Conformance, agreement and benchmarks](#stage-11--conformance-agreement-and-benchmarks) | [#14](https://github.com/pedrobtz/zutempo/issues/14) | | |
| 12 | [Documentation](#stage-12--documentation) | [#15](https://github.com/pedrobtz/zutempo/issues/15) | | |
| 13 | [v0.1.0 readiness](#stage-13--v010-readiness) | [#16](https://github.com/pedrobtz/zutempo/issues/16) | | |

Stage 6 depends on nothing after stage 1 and can run in parallel with
stages 2 to 5. Every other stage depends on the one before it.

## Stage 0 — Package identity

**Issue.** [#3](https://github.com/pedrobtz/zutempo/issues/3), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zutempo/issues/2).

**Goal.** The repository describes the package it will become, and every
check the portfolio expects runs on each pull request.

**Work.**
- `DESCRIPTION`: Title with "Temporal" in it (D11), a one-paragraph
  Description, `Authors@R` with Pedro Baltazar as `aut`, `cre` and `cph`,
  `Depends: R (>= 4.1)`, `Language: en-GB` (R2), `Version: 0.0.0.9000`,
  `LinkingTo: zufast (>= 0.1.1)` with `Remotes: pedrobtz/zufast` until
  0.1.1 is on CRAN (§13), `Suggests: testthat, withr, vctrs, pillar`.
  `LICENSE` and `LICENSE.md` already exist and stay as they are.
- `src/Makevars` with `PKG_CFLAGS = $(C_VISIBILITY)` (R3), `src/init.c`
  with `R_init_zutempo` and `R_useDynamicSymbols(dll, FALSE)`; the empty
  `src/zutempo.c` goes.
- `CLAUDE.md` from `templates/package-CLAUDE.md` in `pedrobtz/packages`,
  naming `.agents/design.md` as the specification, linking this roadmap
  and the `v0.1.0` issue, and listing the workflows below.
- `.github/workflows/native-checks.yml` from `examples/native-checks.yml`
  in `pedrobtz/r-actions` (sanitizers with ASan, valgrind, LTO, gctorture,
  rchk, analyzers, cran-special), with the same quick/full profile
  expression as `R-CMD-check.yaml`.
- `coverage.yaml` pinned to a commit of `r-actions` with the tag in a
  comment, since it holds a write token.
- `NEWS.md` keeps its development heading; `README.md` is left for
  stage 12.

Already done, not repeated here: `.Rbuildignore` with `^\.agents$`,
`R-CMD-check.yaml` calling `r-cmd-check.yml@v1` with the quick/full profile,
`pkgdown.yaml`, `_pkgdown.yml`, MIT licence files.

**Exit criteria.**
- `R CMD check` passes on all r-actions legs with 0 errors, 0 warnings and
  0 notes, with `zufast` installed from its default branch through
  `Remotes:`.
- The `native-checks` workflow runs green on the pull request.
- `CLAUDE.md` exists and links `.agents/design.md`, this roadmap and the
  `v0.1.0` issue.
- `DESCRIPTION` contains no template text.

**Deviations (2026-10-15).**
- `LinkingTo: zufast (>= 0.1.0.9000)`, not `(>= 0.1.1)`: `zufast`'s default
  branch, which `Remotes: pedrobtz/zufast` installs, is at 0.1.0.9000, and
  0.1.1 does not exist yet, so the `>= 0.1.1` constraint cannot resolve. The
  constraint moves to `>= 0.1.1` in stage 13, with `Remotes:` removed (open
  question 1).
- `NEWS.md`'s heading is `# zutempo 0.0.0.9000`, not `(development
  version)`: R 4.6.1's `R CMD check` drops a section whose title has no
  version and reports "No news entries found" as a NOTE. The heading still
  tracks the development version and becomes `# zutempo 0.1.0` in stage 13.
- The coverage badge is committed to `gh-pages` (`badge-branch`), not
  `main`: the `main` ruleset rejects direct pushes, so the badge job failed
  on every merge. The pkgdown deploy gets `force: false` so it rebases on
  the badge commit, and the badge link in `README.md` points at `gh-pages`.
  Both are the r-actions README's prescribed setup for this case.
- `rchk.yml` gets `github-packages: pedrobtz/zufast` and
  `fail-on-findings: true`: the rchk image ignores `Remotes:`, so without it
  the package cannot be installed there and nothing is analysed.
- The `sanitizers` job of `native-checks.yml` is deferred to stage 1. Its
  instrumentation verifier requires a `__ubsan*` symbol in the shared
  object, and `init.c`, the only C in stage 0, contains nothing UBSan
  instruments, so both UBSan legs fail before `R CMD check` runs although
  the flags reach the compiler ([pedrobtz/r-actions#68](https://github.com/pedrobtz/r-actions/issues/68)). Stage 1
  adds the first C with arithmetic and restores the job; the other six
  native jobs run from stage 0.

**Design.** §3 (identity table), §13, §14 row 0.

## Stage 1 — Engine scaffold, pinned specification and oracle

**Issue.** [#4](https://github.com/pedrobtz/zutempo/issues/4), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zutempo/issues/2).

**Goal.** The layering of §4 exists end to end for one trivial call, the
specification and test262 are pinned to recorded commits, the member list
that stage 13 is checked against is extracted, the oracle generator
produces cases, and CI runs the suite with and without `__int128`.

**Work.**
- `src/ztp.h`: status codes, the per-call message buffer and the
  `ztp_result` convention of §4 (the engine never calls R). `src/ztp_r.h`
  and `src/ztp_r_common.c`: the glue that turns a status into a condition
  carrying the 1-based element index (§10).
- `R/conditions.R`: the class hierarchy of §10 (`zutempo_error`,
  `zutempo_range_error`, `zutempo_parse_error`, `zutempo_type_error`,
  `zutempo_tz_error`) and one internal `stop_zutempo()` helper.
- `inst/spec/PINS`: the `tc39/proposal-temporal` commit, the `tc39/test262`
  commit and the tzdata version the package is built against.
  `zutempo_info()` returns them (its time zone fields arrive in stage 6).
- `tools/spec/members.*`: a script that extracts every property, method,
  static and `Now` function of the eight types from the pinned
  specification into `inst/spec/members.csv`, with the R name §5's rule
  gives each one and a column saying whether it is in scope (§2).
- `tests/testthat/test-members.R`: every in-scope member has an exported
  function of that name. Members not yet built sit in a `pending` vector
  in the test; each later stage removes its members, and stage 13 requires
  the vector to be empty.
- `tools/temporal-oracle/`: a Node project pinned to `temporal-polyfill`
  1.0.6 with `package-lock.json`, a `generate.js` that writes
  `tests/testthat/oracle/<type>.json`, and `tests/testthat/helper-oracle.R`
  that runs every case in a file. A second script runs the same cases on
  Node 26's native Temporal and diffs. First cases: a handful for
  `PlainDate`, so the loop is proven before stage 2 fills it.
- A compile-time use of `zufast/wide.h` and `zufast/datetime.h` through
  `LinkingTo`, reached by one internal `.Call` that a test exercises.
- CI: a second `r-cmd-check.yml` call (or an `env` input the Makevars
  honours) that defines `ZUF_NO_INT128`, on the quick and full profiles.
- CI: restore the `sanitizers` job (with `asan: true`) in
  `native-checks.yml`, deferred from stage 0 because its verifier needs
  instrumentable C ([pedrobtz/r-actions#68](https://github.com/pedrobtz/r-actions/issues/68)).
- `.Rbuildignore` entries for `tools/`, `inst/spec/PINS` stays in the
  tarball.

**Exit criteria.**
- CI is green on every leg, including the `ZUF_NO_INT128` leg and the
  `sanitizers` job.
- `zutempo_info()` returns the three pins from `inst/spec/PINS`.
- `inst/spec/members.csv` exists and `test-members.R` passes with every
  in-scope member listed as pending.
- Running the oracle generator twice produces identical JSON; the helper
  runs the `PlainDate` cases (they may be skipped until stage 2 with a
  reason naming this roadmap).
- `expect_error(..., class = "zutempo_<kind>_error")` passes for each
  class in §10, raised through the C glue with an element index.

**Deviations (2026-10-15).**
- `Suggests: jsonlite`, for `helper-oracle.R` to read the oracle JSON. A
  test-only dependency; the package's runtime dependencies stay at zero.
- The oracle holds no case whose expected value the design documents as
  different from an engine (§2, §6.9), such as a non-ISO calendar
  annotation: the polyfill rejects it as zutempo does, native engines
  accept it, and the native diff would carry that difference forever. Such
  behaviour is tested in the package instead.
- The `ZUF_NO_INT128` leg is a second `r-cmd-check.yml` job with
  `ZUTEMPO_CFLAGS=-DZUF_NO_INT128` in its `env`, which `src/Makevars`
  appends to `PKG_CFLAGS`; `test-info.R` asserts that `zutempo_info()`
  reports the portable build whenever the variable is set, so a leg that
  silently lost the flag fails.
- The tzdata pin is 2026d, the release of the macOS database the design's
  §0 measurements were made against; the oracle header records the tzdata
  of the Node binary that generated it (2025b for Node 22.20).

**Design.** §4, §10, §11 (oracle), §14 row 0, §15 criterion 3.

## Stage 2 — PlainDate, PlainTime and PlainDateTime

**Issue.** [#5](https://github.com/pedrobtz/zutempo/issues/5), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zutempo/issues/2).

**Goal.** The three calendar-and-clock types exist as R vectors with every
member that needs neither a `Duration` nor an annotation, and the vector
plumbing every later type reuses is in place.

**Work.**
- Storage per §4.1: `zutempo_plain_date` (integer epoch day),
  `zutempo_plain_time` (double nanoseconds of day),
  `zutempo_plain_date_time` (complex: epoch day, nanoseconds of day).
  Range checks `ISODateWithinLimits` and `ISODateTimeWithinLimits` (§6.1).
- Constructors `plain_date()`, `plain_time()`, `plain_date_time()` from
  fields with `overflow` (§6.2), from each other, and from strings: the
  ISO 8601 core of §9 without annotations. `zuf_parse_datetime()` is the
  fast path; the package's own parser covers expanded years, comma
  fractions, the date-only and time-only forms, leap second `:60` → `:59`,
  more than nine fraction digits as a `zutempo_parse_error`, and `Z` or
  an offset where the type forbids or ignores it. A string containing `[`
  is a `zutempo_parse_error` until stage 9.
- Field accessors as S3 generics with a default that calls the masked
  function (§5): `year()`, `month()`, `month_code()`, `day()`,
  `day_of_week()`, `day_of_year()`, `week_of_year()`, `year_of_week()`,
  `days_in_week()`, `days_in_month()`, `days_in_year()`,
  `months_in_year()`, `in_leap_year()`, `era()`, `era_year()`,
  `calendar_id()`, `hour()` to `nanosecond()`; ISO week fields through
  `zufast`'s week functions.
- `temporal_with()`, `temporal_with_plain_time()`,
  `temporal_with_calendar()` (only `iso8601`), `temporal_to_plain_date()`,
  `temporal_to_plain_time()`, `temporal_to_plain_date_time()`,
  `temporal_equals()`, `plain_date_compare()`, `plain_time_compare()`,
  `plain_date_time_compare()`, `temporal_round()` for `PlainTime` and
  `PlainDateTime` with the nine rounding modes and `rounding_increment`
  (§6.4; the engine's rounding helpers are shared with stage 4),
  `temporal_to_string()` with the default options (other options in
  stage 9), `temporal_to_json()` is not provided (§2).
- Vector plumbing shared by every class: `[`, `[[`, `[<-`, `c()`,
  `rep()`, `rev()`, `unique()`, `is.na()`, `format()`, `print()`,
  `as.character()`, `xtfrm()` (chronological order from the (Re, Im)
  convention, §4.1), data-frame columns, and `vctrs` (`vec_ptype2()`,
  `vec_cast()`, `vec_proxy()`) and `pillar` (`pillar_shaft()`) methods
  registered lazily from `.onLoad()`.
- `NA` propagation per §6.8; every condition names the first failing
  element.
- Oracle cases for the three types, generated by stage 1's tool;
  `test-members.R` loses these members from `pending`.

**Exit criteria.**
- CI green on every leg, both builds; `devtools::test(shuffle = TRUE)`
  green; `gctorture(TRUE)` clean on the new C.
- Every oracle case for the three types passes.
- `pending` in `test-members.R` no longer lists any member of the three
  types except `add`, `subtract`, `since`, `until` and the formatting
  options.
- A data frame with a column of each class prints under `pillar` and
  survives `vctrs::vec_slice()`, `rbind()` and `saveRDS()` round trips.
- Parsing `"+275760-09-13"` and `"-271821-04-19"` succeeds and
  `"-000000-01-01"` is a `zutempo_parse_error`.

**Deviations (2026-10-15).**
- Constructor signatures: the first argument doubles as the value to
  convert, so `plain_date(2026, 1, 31)`, `plain_date("2026-01-31")` and
  `plain_date(<plain_date_time>)` all work; it is named `year` (`hour` for
  `plain_time()`) so that `plain_date(year = 2026, month = 1, day = 1)`
  reads like Temporal's field bag. `month_code` is a named argument after
  `...`.
- `temporal_to_plain_date()` and `temporal_to_plain_time()` have methods
  only for the types Temporal gives them to (`PlainDateTime`); the
  constructors convert the rest (`plain_date(<plain_date_time>)`).
- `temporal_to_zoned_date_time()`, `temporal_to_plain_year_month()` and
  `temporal_to_plain_month_day()` stay pending: their target types arrive
  in stages 3 and 7.
- `Duration`-free arithmetic on dates exists only through `temporal_with()`;
  `add`, `subtract`, `since` and `until` stay pending for stage 4 as
  planned.
- The engine's string formatter already takes the precision and calendar
  options of stage 9, since `toString()` is defined through them; the R
  side exposes the defaults only.

**Design.** §4.1, §5, §6.1, §6.2, §6.4, §6.8, §9 (core grammar), §14 row 1.

## Stage 3 — PlainYearMonth and PlainMonthDay

**Issue.** [#6](https://github.com/pedrobtz/zutempo/issues/6), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zutempo/issues/2).

**Goal.** The two partial-date types exist with every member that needs no
`Duration`.

**Work.**
- Storage per §4.1: `zutempo_plain_year_month` (integer months since
  1970-01, reference day 1) and `zutempo_plain_month_day` (integer
  `month × 32 + day`, reference year 1972).
- Constructors from fields with `overflow`, from strings (`2026-03`,
  `03-14`, `--03-14`, and the full date forms the specification accepts
  for each), and from the other plain types.
- Fields, `temporal_with()`, `temporal_equals()`,
  `plain_year_month_compare()`, `temporal_to_plain_date()` supplying the
  missing day or year (§6.10 last row), `temporal_to_string()` with the
  default options, and the vector plumbing of stage 2 applied to both
  classes.
- Oracle cases; `pending` updated.

**Exit criteria.**
- CI green on every leg, both builds; shuffle green; gctorture clean.
- Every oracle case for the two types passes.
- `pending` no longer lists any member of the two types except `add`,
  `subtract`, `since`, `until` and the formatting options.

**Deviations (2026-10-15).**
- `temporal_to_plain_date()` takes the missing field as a named argument
  (`day =` for a `plain_year_month()`, `year =` for a `plain_month_day()`)
  rather than Temporal's one-property object; the generic gained `...` for
  it.
- `plain_month_day()` takes the optional `year` that constrains the day as
  a named argument after `...`, and `plain_year_month()` ignores no `day`:
  an R call has no extra properties to ignore, so a `day` to
  `plain_year_month()` is an unused-argument error.
- `temporal_to_plain_year_month()` and `temporal_to_plain_month_day()`
  (members of `PlainDate`) land here with their target types, one stage
  later than stage 2's table row implied.

**Design.** §4.1, §5, §6.10, §14 row 1.

## Stage 4 — Duration and plain arithmetic

**Issue.** [#7](https://github.com/pedrobtz/zutempo/issues/7), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zutempo/issues/2).

**Goal.** `Duration` exists in full for everything that does not need a
zone, and the five plain types gain `add`, `subtract`, `since` and
`until`.

**Work.**
- Storage per §4.1: a list of ten doubles, `IsValidDuration`, the
  normalised time duration as `zuf_i128` with the 2⁵³ s bound, and the
  field-to-normalised sum of products in 128 bits, never in doubles
  (§4.3).
- `duration()` from fields, from strings (`P1Y2M3DT4H5M6.789S`, a fraction
  only on the smallest unit present, §9) and from `difftime` later
  (stage 10); `sign()`, `blank()`, `abs()`, `negated()`,
  `temporal_with()`, `temporal_to_string()` with the default options.
- `temporal_add()` and `temporal_subtract()` on `Duration`, erroring on
  calendar units; `temporal_round()` and `temporal_total()` with
  `relative_to` a `PlainDate` or `PlainDateTime` (24-hour days),
  `largest_unit`, `smallest_unit`, `rounding_increment` and the nine
  modes; `duration_compare()` with a plain `relative_to`. Without
  `relative_to`, any operation that needs it, weeks included, is a
  `zutempo_range_error` (§6.5).
- `==`, `<` and `sort()` on durations per §6.5: `==` compares fields,
  `<` and `sort()` compare total nanoseconds and error on calendar units.
- `temporal_add()`, `temporal_subtract()`, `temporal_since()` and
  `temporal_until()` on `PlainDate`, `PlainTime`, `PlainDateTime` and
  `PlainYearMonth` with `overflow`, `largest_unit`, `smallest_unit`,
  `rounding_increment` and `rounding_mode`, following
  `AddDurationToDate`, `DifferencePlainDate*` and §6.6's default units.
- Oracle cases, including `2026-01-31` plus one month giving
  `2026-02-28` and the plain-relative rounding of `PT25H`.

**Exit criteria.**
- CI green on every leg, both builds; shuffle green; gctorture clean.
- Every oracle case for `Duration` and for plain arithmetic passes.
- `pending` no longer lists any member of `Duration` or of the five plain
  types except the formatting options, nor `Duration`'s zoned
  `relative_to` behaviour (stage 8).
- A `Duration` built from milliseconds beyond 2⁵³ that are exactly
  representable keeps its value through normalisation in both builds.

**Deviations (2026-10-15).**
- Two steps of the pinned specification are not followed literally, since
  taken as written they do not compute what the reference engines (and
  test262) expect: `ISODateSurpasses` step "If months = 0, return false"
  leaves `CalendarDateUntil`'s day loop without an exit when no months are
  added, and `ComputeNudgeWindow` step "If r1 = 0, let startEpochNs be
  originEpochNs" ignores the larger units of the start duration (`P1Y`
  rounded to months would start a year early). The engine skips the first
  and adds the start duration in the second; the same text is on
  `tc39/proposal-temporal` main on 2026-10-15. Worth an upstream issue.
- `sign` is a base R generic, so `sign(x)` on a `duration()` dispatches
  through the `Math` group method rather than through an export named
  `sign`; `abs(x)` works the same way, next to `temporal_abs()`.
  `test-members.R` accepts group methods for such names.
- `relative_to` accepts a `plain_date()`, a `plain_date_time()` or a
  string; a string with a time zone annotation or `Z` arrives in stage 8
  with `ZonedDateTime`.
- Duration fields given to `duration()` must be integral, as
  `ToIntegerIfIntegral` requires; a bare number passed as a duration to
  `temporal_add()` and friends is a type error, as in Temporal.
- `temporal_round()`'s generic gained `...` so the `duration()` method can
  take `largest_unit` and `relative_to`; the plain types reject extra
  arguments.
- The oracle test files run every case of a type inside one `test_that()`
  block and compare a value's fields in one expectation. The full-profile
  `gctorture` job (step 20, 120-minute timeout) took 9 minutes at stage 1,
  48 at stage 2 and over an hour at stage 3, growing with the number of
  expectations; measured locally at step 200, the PlainDate oracle file
  went from 188 s to 63 s with the same cases and assertions. Case ids
  travel in `info` so a failure still names its case.

**Design.** §4.1, §4.3, §6.2, §6.4, §6.5, §6.6, §9 (durations), §14 row 2.

## Stage 5 — Instant and fixed-offset zones

**Issue.** [#8](https://github.com/pedrobtz/zutempo/issues/8), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zutempo/issues/2).

**Goal.** `Instant` exists over Temporal's full range, the engine has a
zone object with the `UTC` and fixed-offset kinds, and `now_instant()`
works.

**Work.**
- Storage per §4.1: complex of epoch seconds and nanoseconds, normalised
  with the floor convention; range ±8.64 × 10²¹ ns (§6.1) checked in
  `zuf_i128`.
- `instant()` from strings with `Z` or an offset (fast path through
  `zuf_parse_datetime()`), `instant_from_epoch_milliseconds()`,
  `instant_from_epoch_nanoseconds()` accepting a double, a decimal string
  and, from stage 10, a `zuint::int128`; `epoch_milliseconds()` as an
  exact double and `epoch_nanoseconds()` as a decimal string (stage 10
  adds `zuint`).
- `instant_compare()`, `temporal_equals()`, `temporal_add()` and
  `temporal_subtract()` with time units, `temporal_since()` and
  `temporal_until()`, `temporal_round()` rounding "as if positive" (§6.4),
  `temporal_to_string()` with `time_zone` restricted to `UTC` and
  fixed offsets until stage 7.
- The engine's zone object (`ztp_zone`) with the `fixed` kind: offset
  lookup, local-to-instant with exactly one candidate, and `TimeZoneEquals`
  for `+00:00` versus `UTC` (§6.7). The IANA kind arrives in stage 6.
- `now_instant()`; the other `Now` functions need a named zone and arrive
  in stage 7 (a deviation from §14 row 3, recorded here).
- Oracle cases, including `+275760-09-13T00:00Z` giving
  `8640000000000000000000` and rounding before 1970 with `trunc`.

**Exit criteria.**
- CI green on every leg, both builds; shuffle green; gctorture clean.
- Every oracle case for `Instant` passes, in both builds.
- `pending` no longer lists any member of `Instant` except
  `toZonedDateTimeISO` and the formatting options.
- `now_instant()` is within one second of `Sys.time()` in a test.

**Deviations (2026-10-15).**
- `temporal_to_string()`'s generic gained `...` so the `instant()` method
  can take `time_zone`; the other methods reject extra arguments. Stage 9
  adds the remaining string options on the same generic.
- A named zone given to `temporal_to_string()` is a `zutempo_tz_error`
  naming stage 6, not a parse error: the identifier is well formed and
  the database is what is missing.
- `now_instant()` reads `Sys.time()`, so its precision is the platform's
  double seconds (about a microsecond today); the engine has no clock of
  its own.
- `instant_from_epoch_nanoseconds()` takes doubles that are exact
  integers as well as decimal strings; `zuint` arrives in stage 10.
- `temporal-polyfill` 1.0.6 rounds a negative epoch value away from zero
  with `trunc`, `halfExpand` and `halfTrunc`, where `RoundTemporalInstant`
  rounds "as if positive" (design §6.4; test262's
  `Instant/prototype/round/rounding-direction.js`). The package follows
  the specification; those three cases left the oracle and live in
  `test-instant.R`. The native run of the oracle on Node 26 (stage 11)
  should show the same difference against the polyfill; worth reporting
  to `fullcalendar/temporal-polyfill`.

**Design.** §4.1, §4.3, §6.1, §6.4, §6.6, §6.7, §14 row 3.

## Stage 6 — Time zone database

**Issue.** [#9](https://github.com/pedrobtz/zutempo/issues/9), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zutempo/issues/2).

**Goal.** Named IANA zones resolve from the same database base R uses, on
slim and fat files alike, with Temporal's identifier rules.

**Work.**
- Lookup order of §8.1: option `zutempo.tzdir`, `TZDIR` with R's special
  values, then the per-platform defaults. A missing database leaves `UTC`
  and offset zones working and makes a named zone a `zutempo_tz_error`
  naming the directories tried.
- TZif reader (`src/ztp_tz*.c`): versions 1 to 4, the 64-bit block when
  present, every count and offset bounds-checked against the file size
  (§8.2).
- The POSIX TZ footer in full: `M`, `J` and zero-based day rules, quoted
  and unquoted names, signed offsets, v3 hours −167 to 167; per-year rule
  evaluation cached.
- Offset at an instant by binary search then footer; the candidate search
  of `GetPossibleEpochNanoseconds`; `GetNamedTimeZoneNextTransition` and
  `...PreviousTransition` bounded by the instant range.
- Identifier index: one directory walk per session excluding
  `posixrules`, `*.tab`, `+VERSION`, `right/` and `posix/`;
  case-insensitive match, database-case output (§6.7, §8.3).
- Link table generated by `tools/tz/links.R` from IANA's `backward` file
  into C, with its tzdata version; `TimeZoneEquals` through it; the
  database wins for existence and the table for identity.
- Session cache keyed by case-folded identifier, invalidated when
  `zutempo.tzdir` or `TZDIR` changes; `zutempo_tz_reset()` (§8.4).
- `zutempo_info()` gains the directory, the version (from `+VERSION`, R's
  `VERSION`, or `tzdata.zi`), fat or slim, and the link table version.
- Committed fixtures (§11): about twenty TZif files, fat and slim, from
  the pinned tzdata release, under `tests/testthat/tzdata/`, fetched by
  `tools/tz/fetch-fixtures.sh`; about 100 KB compressed.
- Tests: offsets for every fixture zone at every transition against values
  recorded from the oracle for that tzdata version; the slim-file
  regression of §0 as a test (New York, 2026-03-08 02:30 gives no
  candidate, 2026-11-01 01:30 gives two) on the slim fixture and, when
  present, on `R.home("share")/zoneinfo`; tests skip when no database is
  found, checked by pointing `zutempo.tzdir` at an empty directory.
- `.github/workflows/hardening.yaml` calling `fuzz.yml` with a TZif
  harness under `tools/fuzz/`, seeded from the fixtures.

**Exit criteria.**
- CI green on every leg, both builds, including the `hardening` fuzz job.
- The slim-file regression test passes on the committed slim fixture.
- `zutempo_info()` reports the directory, version and form on macOS,
  Windows and Ubuntu runners (asserted non-empty in a test).
- Every fixture zone's offsets match the recorded values, fat and slim.
- The suite passes with `zutempo.tzdir` set to an empty directory.

**Design.** §0, §6.7, §8, §11 (fixtures, fuzzing), §13, §14 row 4,
§15 criterion 5.

## Stage 7 — ZonedDateTime

**Issue.** [#10](https://github.com/pedrobtz/zutempo/issues/10), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zutempo/issues/2).

**Goal.** `ZonedDateTime` exists with a zone per value, resolves local
times with Temporal's `disambiguation` and `offset` rules, and the
remaining `Now` functions work.

**Work.**
- Storage per §4.2: a record of `instant` and an integer `zone` code into
  the `zones` attribute; `c()`, `[`, `[<-`, `rep()` and the `vctrs`
  record methods merge and recode tables; the engine groups elements by
  zone and skips grouping for a single-zone vector.
- `zoned_date_time()` from fields with `time_zone`, `disambiguation`,
  `offset` and `overflow`; from strings with a bracketed zone
  (`[America/New_York]`, `[+05:30]`, `[UTC]`, and `Z[zone]` meaning the
  instant displayed in that zone). Other annotations wait for stage 9.
- `GetPossibleEpochNanoseconds` over the stage 6 zone object; the
  `disambiguation` table of §6.3; `offset` as `use`, `ignore`, `prefer`
  and `reject` with the per-caller defaults.
- Fields: the calendar and clock fields of stage 2, `offset()`,
  `offset_nanoseconds()`, `time_zone_id()`, `epoch_*`, `hours_in_day()`;
  `temporal_start_of_day()`, `temporal_with()`,
  `temporal_with_plain_time()`, `temporal_with_time_zone()`,
  `temporal_with_calendar()`, `temporal_to_instant()`,
  `temporal_to_plain_date()`, `temporal_to_plain_time()`,
  `temporal_to_plain_date_time()`, `temporal_equals()` through
  `TimeZoneEquals`, `zoned_date_time_compare()`, `temporal_to_string()`
  with the default options.
- `temporal_to_zoned_date_time_iso()` on `Instant`, `PlainDate` and
  `PlainDateTime`; `temporal_to_string()` on `Instant` with any zone.
- `now_time_zone_id()`, `now_zoned_date_time_iso()`,
  `now_plain_date_time_iso()`, `now_plain_date_iso()`,
  `now_plain_time_iso()`, with the system zone as base R reads it.
- Oracle cases, including New York `2026-03-08T02:30` with `compatible`
  giving `03:30:00-04:00`, and `Asia/Calcutta` equal to `Asia/Kolkata`
  while keeping its identifier.

**Exit criteria.**
- CI green on every leg, both builds; shuffle green; gctorture clean.
- Every oracle case for `ZonedDateTime` construction, fields and `Now`
  passes on the committed fixtures.
- `pending` no longer lists any member of `ZonedDateTime` or `Now` except
  `add`, `subtract`, `since`, `until`, `round`, `getTimeZoneTransition`
  and the formatting options.
- A vector mixing three zones survives `c()`, `[`, `rep()`, `rbind()`
  and `saveRDS()` with the right identifier on every element.

**Design.** §4.2, §5, §6.3, §6.7, §14 row 5.

## Stage 8 — Zone-aware arithmetic and transitions

**Issue.** [#11](https://github.com/pedrobtz/zutempo/issues/11), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zutempo/issues/2).

**Goal.** Every arithmetic member that depends on a zone follows the
specification, and `Duration` rounds relative to zoned values.

**Work.**
- `AddZonedDateTime` and `DifferenceZonedDateTime`: `temporal_add()`,
  `temporal_subtract()`, `temporal_since()` and `temporal_until()` on
  `ZonedDateTime`, with date units through the local calendar and
  `compatible` resolution, and time units on epoch nanoseconds.
- `temporal_round()` on `ZonedDateTime`, with `day` as `hours_in_day`.
- `temporal_round()`, `temporal_total()` and `duration_compare()` with a
  `ZonedDateTime` `relative_to`, through `RoundRelativeDuration`'s zone
  path (§6.5).
- `temporal_get_time_zone_transition(direction)` bounded by the instant
  range (§8.2).
- Oracle cases, including `PT25H` rounded with `largest_unit = "day"`
  relative to `2026-03-07T12:00[America/New_York]` giving `P1DT2H`, and
  the §5 example `temporal_add(x, duration(hours = 25))`.

**Exit criteria.**
- CI green on every leg, both builds; shuffle green; gctorture clean.
- Every oracle case for zoned arithmetic, zoned rounding and transitions
  passes on the committed fixtures.
- `pending` no longer lists any arithmetic member of any type; only the
  formatting options remain.

**Design.** §0 (oracle table), §6.5, §6.6, §8.2, §14 row 5.

## Stage 9 — RFC 9557 annotations and formatting options

**Issue.** [#12](https://github.com/pedrobtz/zutempo/issues/12), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zutempo/issues/2).

**Goal.** Every string Temporal reads is read, every string option it
offers is offered, and the parsers are fuzzed.

**Work.**
- The full annotation grammar of §9 in every string constructor: any
  number of key-value annotations, `u-ca` (only `iso8601` accepted, any
  other calendar a `zutempo_range_error`, D7), the `!` critical flag with
  its rejection rules, elective unknown annotations ignored, and the
  per-type rules for `Z`, offsets and bracketed zones.
- Formatting options on `temporal_to_string()` and `format()` for every
  type: `fractional_second_digits`, `smallest_unit`, `rounding_mode`,
  `calendar_name`, `time_zone_name` and `offset`, with offsets printed as
  `±HH:MM` rounded to minutes.
- `zutempo_parse(x, na_on_error = TRUE)` as the bulk-reading escape of
  §6.8; `zutempo_parse_error` carries the position of the first bad byte
  (§10).
- Fuzz harnesses for the RFC 9557 parser and the duration parser added to
  `hardening.yaml`, seeded from test262 strings and the oracle cases.
- Oracle cases for annotations and every formatting option; `pending`
  emptied of the formatting options.

**Exit criteria.**
- CI green on every leg, both builds, including all three fuzz targets.
- Every string in §9 round-trips through parse and `toString()` for the
  type that owns it, and every rejection in §9 raises the named class.
- Every oracle case for strings and formatting passes.
- `pending` in `test-members.R` is empty.

**Design.** §2 (calendars), §6.8, §9, §10, §11 (fuzzing), §14 row 6.

## Stage 10 — Base R conversions and epoch nanoseconds

**Issue.** [#13](https://github.com/pedrobtz/zutempo/issues/13), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zutempo/issues/2).

**Goal.** Every row of the §6.10 table is a tested method, and
`epoch_nanoseconds()` returns an exact integer where a package for it
exists.

**Work.**
- `as.Date()`, `as.POSIXct()`, `as.POSIXlt()` and `as.difftime()` methods
  for every class in the table, with `tz`, `disambiguation` and
  `relative_to` where a row needs them, each losing only what the row
  says; mixed-zone vectors give `tzone = "UTC"` (§4.2); `POSIXlt` carries
  each element's `gmtoff`.
- The reverse direction in the constructors: `plain_date(<Date>)`,
  `instant(<POSIXct>)`, `zoned_date_time(<POSIXct>)` with `tzone` rules,
  `plain_date_time(<POSIXlt>)` through `POSIXct`, `duration(<difftime>)`
  balanced as `Duration.from()` leaves it; doubles rounded to nanoseconds
  half to even.
- `epoch_nanoseconds()` returning `zuint::int128` when `zuint` is
  installed, and `instant_from_epoch_nanoseconds()` accepting one, with
  `Suggests: zuint`, if `zuint` is on CRAN by then; otherwise the decimal
  string of stage 5 stays and the `zuint` hook moves under "After 0.1.0"
  (open question 2).
- Tests against base R for a grid of instants and zones, and an exactness
  test for `Date` and `PlainDate` across the whole `int32_t` range.

**Exit criteria.**
- CI green on every leg, both builds; shuffle green.
- Each row of the §6.10 table has a test in both directions, named for
  the row.
- `as.POSIXct(instant(x))` and `instant(as.POSIXct(x))` agree with base R
  to the documented precision for 10⁴ random instants between 1900 and
  2100.
- `R CMD check` raises no note about `zuint` on any leg, whichever way
  open question 2 is decided.

**Design.** §4.2, §6.9, §6.10, §14 row 7, D10.

## Stage 11 — Conformance, agreement and benchmarks

**Issue.** [#14](https://github.com/pedrobtz/zutempo/issues/14), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zutempo/issues/2).

**Goal.** The package is checked against test262, against base R's zone
offsets, and against the performance targets, and the results are
recorded.

**Work.**
- `tools/test262/`: an extractor that reads `test/built-ins/Temporal` at
  the pinned commit, turns result assertions (values and thrown error
  classes) into `tests/testthat/test262/*.json`, and writes a skip list
  with a reason per skipped file; `tools/test262/REPORT.md` records the
  share translated (reported, not targeted). A runner test maps
  `RangeError` and `TypeError` to the §10 classes.
- Base R agreement: for every zone in the database and every hour from
  1900 to 2100, `zutempo`'s offset equals `as.POSIXlt()`'s, except on a
  committed list of documented differences. Runs only when
  `ZUTEMPO_EXTENDED_TESTS` is set, which CI passes through
  `r-cmd-check.yml`'s `env` input on one Ubuntu leg; skipped on CRAN.
- `tools/bench/`: a `bench` script for the five operations of §12 at 10⁶
  elements and the operations `clock` shares, with results and the
  machine recorded in `tools/bench/RESULTS.md`. Not run on CRAN.
- Each §12 miss recorded as an issue labelled `performance`, not as a
  stage blocker (§12: targets, not constraints).

**Exit criteria.**
- CI green on every leg, both builds, including the agreement leg.
- Every translated test262 assertion passes, or its case is listed under
  §6.9's differences with a reason.
- `REPORT.md` states the translated share and the skip reasons; the
  agreement test's difference list is committed and each entry cites R's
  documented behaviour.
- `RESULTS.md` holds a measurement for every row of §12 and for every
  shared `clock` operation.

**Design.** §11, §12, §14 row 8, §15 criteria 2 and 4.

## Stage 12 — Documentation

**Issue.** [#15](https://github.com/pedrobtz/zutempo/issues/15), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zutempo/issues/2).

**Goal.** A user who knows Temporal finds every function, and a user who
knows base R finds the way in.

**Work.**
- `README.Rmd` (and the generated `README.md`): installation, the §5
  examples, the §5 naming table from Temporal to R, the conversions of
  §6.10 in brief, and what 0.1.0 leaves out (§2).
- Roxygen for every export with an `@examples` block that runs on CRAN;
  one topic per Temporal type listing its members, one per `Now`, one for
  conversions, one for options (`overflow`, `disambiguation`, `offset`,
  rounding) shared through `@inheritParams`.
- `_pkgdown.yml` reference index grouped by type, `Now`, conversions,
  options and package helpers; `pkgdown::check_pkgdown()` clean.
- A vignette, `vignette("zutempo")`, walking one zoned value through
  construction, arithmetic, rounding and conversion (open question 3).
- `inst/WORDLIST` for `spelling`; `NEWS.md` lists what 0.1.0 contains.

**Exit criteria.**
- CI green, including the `pkgdown` deployment on the merge.
- `pkgdown::check_pkgdown()` and `spelling::spell_check_package()` clean.
- Every export has an `@examples` block, checked by a test over
  `tools::Rd_db("zutempo")`.
- `README.md` renders from `README.Rmd` with no error and its examples
  produce the outputs shown in §5.

**Design.** §2, §5, §6.10, §14 row 9.

## Stage 13 — v0.1.0 readiness

**Issue.** [#16](https://github.com/pedrobtz/zutempo/issues/16), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zutempo/issues/2).

**Goal.** Only the submission itself is left.

**Work.**
- `Version: 0.1.0` and the matching `NEWS.md` heading.
- `Remotes:` removed; `LinkingTo: zufast (>= 0.1.1)` resolved from CRAN
  (open question 1).
- `cran-comments.md` listing the r-actions CI legs (runners and
  containers, both builds) as the test environments; no win-builder,
  macOS builder or R-hub.
- The `pkg-cran-review` skill run, every finding resolved.
- `urlchecker::url_check()` and `spelling::spell_check_package()` clean.
- The §15 acceptance criteria re-verified on the release commit and
  recorded in the pull request.
- Test suite timed on the Ubuntu leg and within CRAN's budget.

**Exit criteria.**
- A full-profile r-actions run (`R-CMD-check`, `native-checks`,
  `hardening`, `coverage`) is green on the release commit, with `zufast`
  0.1.1 installed from CRAN and no `Remotes:` field.
- `R CMD check --as-cran` shows 0 errors, 0 warnings and only the "New
  submission" note, natively and with `ZUF_NO_INT128`.
- `test-members.R` has an empty `pending` vector (§15 criterion 3).
- `cran-comments.md`, `NEWS.md` and `DESCRIPTION` agree on 0.1.0.
- The `pkg-cran-review` report has no open finding.

**Design.** §13, §14 row 9, §15.

## After 0.1.0

- **The C table `zutempo_api_v1`** (§7): `inst/include/zutempo.h`, the
  registered callable, and the fixture consumer package in `tests/`. The
  engine of stages 1 to 9 is shaped so that adding it changes no engine
  code; it waits for a reader (`zucbor`, `zuyaml`, `zucsv`) to ask.
- **Arithmetic and comparison operators** on dates and zoned values (§2):
  shorthand for one Temporal operation each, and `chooseOpsMethod()` from
  R 4.3 for mixing with base types; deferred because `Depends: R (>= 4.1)`
  and because the functions exist.
- **`zuint` integration** of `epoch_nanoseconds()` (§6.9, D10), if
  `zuint` is not on CRAN when stage 10 runs (open question 2).
- **Non-ISO calendars** (D7), `toLocaleString` and custom time zones
  (§2): ECMA-402 territory, each needing an RFC of its own.
- **A plain R-devel runner leg** as insurance against a stale container
  image, if the containers ever lag (r-actions README).

## Open questions

1. **When does `zufast` 0.1.1 reach CRAN?** Stage 13 cannot close before
   it does: `LinkingTo: zufast (>= 0.1.1)` must resolve from CRAN and
   `Remotes:` must go (§13). On 2026-10-15 `zufast` 0.1.0, submitted
   2026-10-10, is not yet on CRAN, and 0.1.1 can follow no sooner than six
   weeks after acceptance. Stages 0 to 12 build against the default branch
   meanwhile.
2. **Does `zuint` exist in time for stage 10?** The design makes
   `epoch_nanoseconds()` return `zuint::int128` when `zuint` is installed
   (§6.9, D10), but no `pedrobtz/zuint` repository exists on 2026-10-15 and
   CRAN rejects a `Suggests` entry it cannot install. Proposed: stage 10
   ships the decimal string alone and the `zuint` hook moves to "After
   0.1.0" unless `zuint` is on CRAN when stage 10 starts. Maintainer's
   call; it changes stage 10's work and exit criteria.
3. **Is a vignette part of 0.1.0?** The design does not mention one.
   Stage 12 includes a single short vignette; drop it from the stage if
   not wanted.
