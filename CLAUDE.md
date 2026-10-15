# CLAUDE.md

<!-- markdownlint-disable-next-line MD013 -->
This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`zutempo` implements the Temporal date and time model of ECMA-262 in R:
`Instant`, `ZonedDateTime`, `PlainDateTime`, `PlainDate`, `PlainTime`,
`PlainYearMonth`, `PlainMonthDay`, `Duration` and `Now`, in the ISO 8601
calendar, with IANA time zones read from the same database base R uses. The
arithmetic is a transliteration of the specification's abstract operations
into C over the specification's full ranges, so a result in R matches the
result in a browser or in Node. It has no hard runtime dependency: `zufast`
is `LinkingTo` only (header-only C, needed at build time). It does not do
non-ISO calendars, locale formatting, custom time zones, `strftime`, or
arithmetic operators in 0.1.0.

The specification is [`.agents/design.md`](.agents/design.md) and the plan
is [`.agents/roadmap.md`](.agents/roadmap.md). They outrank this file:
`CLAUDE.md` orients, the design decides, the roadmap says what each stage
builds and when it is done.

## Current state

Verified 2026-10-15: stages 0 to 12. The eight types exist with every
member of the pinned specification: fields, `with*`, `compare`,
`equals`, `round`, `add`, `subtract`, `since`, `until`, `total`,
`startOfDay`, `getTimeZoneTransition`, the conversions among the types
and `toString()` with all its options; every `Now` function works;
strings are read with every RFC 9557 annotation, and
`zutempo_parse()` (`R/parse.R`) reads them in bulk with `NA` for
failures. `R/base-r.R` converts to and from base R's types (design 6.10),
with the exact double conversions in `src/ztp_instant.c`. The ledger's
`pending` list is empty. The engine has the ISO
records (`src/ztp_iso.c`), rounding (`src/ztp_round.c`), formatting
(`src/ztp_format.c`), the parser with its goals, the annotation rules,
the time zone and calendar string readers and the zufast fast path
(`src/ztp_parse.c`), durations on
128-bit time durations (`src/ztp_duration.c`), calendar arithmetic with
relative rounding with and without a zone and the zoned arithmetic
(`src/ztp_relative.c`), instants with the UTC,
fixed-offset and IANA zone kinds (`src/ztp_instant.c`) and the time zone
database: TZif reader and footer rules (`src/ztp_tz.c`), the session cache
(`src/ztp_tz_cache.c`) and the generated link table (`src/ztp_tz_links.c`);
the glue is `src/ztp_r_plain.c`, `src/ztp_r_duration.c`,
`src/ztp_r_instant.c`, `src/ztp_r_tz.c` and `src/ztp_r_zoned.c`
(`src/ztp_zoned.c` holds the candidate search, disambiguation, start of
day and the zoned string form). `R/tz.R` finds the database and reads the
files; `R/zoned-date-time.R` is the zoned type. The oracle covers the
eight types.
See the roadmap's stage table.

## Stage tracking

Progress toward the next version is tracked as GitHub sub-issues, so the
parent issue shows a progress bar such as "6 of 14".

- **One parent issue per target version**, titled with the bare version:
  [v0.1.0 (#2)](https://github.com/pedrobtz/zutempo/issues/2).
- **One sub-issue per roadmap stage**, titled as the roadmap titles it, for
  example `Stage 2 — PlainDate, PlainTime and PlainDateTime`, and linking to
  that section. The roadmap has fourteen stages, 0 to 13.
- **Every tracking issue carries the `stage` label**, so it can be told apart
  from bug and feature issues and left out of open-issue counts.
- **Close a stage by merging its pull request.** Put `Closes #<n>` in the
  body of the stage's pull request. Never close a stage whose exit criteria
  are not met; record a deviation in the roadmap first.
- **The roadmap stays authoritative.** The issues record which stages are
  done, not what a stage requires. Adding, removing or renaming a stage
  means editing the roadmap and the sub-issues in the same change.
- Close the parent issue when CRAN accepts the version and it is tagged.

## Versioning

The package develops at `0.0.0.9000` and targets `0.1.0` for its first CRAN
release. Set `Version: 0.1.0` and the matching `NEWS.md` heading when the
package enters `Pre-flight`. Bump to `0.1.0.9000` only after CRAN accepts it,
never before.

`zutempo` depends on `zufast` through `LinkingTo` and develops against its
default branch (`Remotes: pedrobtz/zufast`) until `zufast` 0.1.1 is on CRAN;
`zutempo` is not submitted before then (roadmap, open question 1). Nothing
depends on `zutempo` yet. The C table for other packages (design §7) comes
after 0.1.0.

## Commands

Run from the package root.

```sh
Rscript -e 'devtools::load_all()'                # compile src/ and load
Rscript -e 'devtools::document()'                # roxygen -> NAMESPACE, man/
Rscript -e 'devtools::test()'                    # full testthat suite
Rscript -e 'devtools::test(filter = "<name>")'   # one test file
Rscript -e 'devtools::test(shuffle = TRUE)'      # order independence
Rscript -e 'devtools::check()'                   # R CMD check
air format .                                     # format R sources
```

The default loop is `document()`, `test()`, `check()`. Before the first
`load_all()`, install the development `zufast`:
`Rscript -e 'pak::pak("pedrobtz/zufast")'`.

Occasional:

```sh
ZUTEMPO_CFLAGS=-DZUF_NO_INT128 Rscript -e 'devtools::clean_dll(); devtools::test()'
                                                 # the portable 128-bit build
Rscript tools/spec/members.R                     # regenerate inst/spec/members.csv
(cd tools/temporal-oracle && npm ci && npm run generate)
                                                 # regenerate tests/testthat/oracle/
(cd tools/temporal-oracle && npm run check-native)
                                                 # Node 26+: polyfill vs native
```

`devtools::clean_dll()` matters when `ZUTEMPO_CFLAGS` changes, and after
any edit to a header that changes a struct's layout: `load_all()` only
recompiles `.c` files that changed, so an object built against the old
header keeps the old sizes and the mismatch shows up as a stack smash
(SIGABRT with no message) rather than a compile error.

## Architecture

Design §4 is the reference. The layers, top down:

- `R/`: argument and option normalisation, recycling, class and attribute
  handling, `vctrs` and `pillar` methods registered lazily.
- `src/ztp_r_*.c`: the glue. R vectors in, column loops, `NA` handling,
  conditions raised with the 1-based index of the failing element.
- `src/ztp_*.c`: the engine. The specification's abstract operations over
  plain C structs, one C function per operation where practical, each
  commented with the section it implements. No `SEXP`, no R calls, no
  allocation in loops. Calendar algorithms and 128-bit intermediates come
  from `zufast`'s headers.
- `src/ztp_tz*.c`: the zone cache. TZif reader and POSIX TZ footer rules
  (`ztp_tz.c`), the session cache keyed by case-folded identifier
  (`ztp_tz_cache.c`), the link table `tools/tz/links.R` generates
  (`ztp_tz_links.c`). The engine never touches the file system: `R/tz.R`
  finds the directory in base R's order, walks it once per session for the
  identifier index, reads a zone's bytes with `readBin()` and hands them to
  `ztp_tz_cache_put()`. `ztp_zone_parse()` only knows zones already in
  the cache, so every R entry point that takes a zone goes through
  `ztp_tz_ensure()` first.
- `tests/testthat/tzdata/`: fat and slim TZif fixtures for 22 zones with
  the transitions `zdump` reports, from `tools/tz/fixtures.R` (needs `zic`
  and `zdump`). Regenerate when the tzdata pin moves.
- `src/init.c`: the only exported symbol, `R_init_zutempo`. R reaches the
  registered routines as `C_<name>` (`useDynLib(..., .fixes = "C_")`).
- A `zoned_date_time()` is the instant's complex vector with the attribute
  `zone` (an integer code per element) and `zones` (the identifiers, in
  order of first use); `new_zoned_date_time()` recodes and drops unused
  identifiers, so build vectors through it or `ztp_zoned_build()`. Every
  engine call on zoned values goes through `ztp_zdt_zones_ready()`, which
  reloads the table's zones: the C cache may have been cleared since the
  vector was made (a `zutempo_tz_reset()`, a change of database).
- `R/plumbing.R` holds every base method that keeps the class through
  `[`, `c()`, `rep()`, `unique()`, printing and data frames: base R's
  defaults drop the class attribute of a classed atomic vector. A new
  class needs each of them. `R/zzz.R` registers the `vctrs` and `pillar`
  methods lazily.
- `R/accessors.R` is generated code in spirit: one generic, one default
  and one method per class for every Temporal property. The default finds
  the function the generic masks on the search path (`lubridate::year()`).
- `R/options.R` turns option strings into the integer codes the glue
  reads; the enumerations in `src/ztp_round.h` and `src/ztp_format.h` fix
  the codes, so both sides change together.
- `src/ztp.h`: `ztp_status` and `ztp_ctx`. An engine function takes a
  context and returns a status; on failure `ztp_fail()` records the status,
  the 1-based element index and a message. `src/ztp_r.h`: `ztp_r_raise()`
  turns a failed context into a condition by evaluating `stop_zutempo()`
  in the namespace.
- `tools/fuzz/`: libFuzzer harnesses for the TZif reader, the RFC 9557
  parser and the duration parser, run by `hardening.yaml`. Their seed
  corpora under `tools/fuzz/corpus/` come from `tools/fuzz/seeds.mjs`
  (the oracle's strings and test262's); regenerate them when the oracle
  changes much.
- `tools/test262/`: `extract.mjs` translates test262's Temporal tests into
  `tests/testthat/test262/*.json.gz` (README there for the sparse
  checkout); `test-test262.R` runs them, and `differences.csv` lists
  every case that differs on purpose, with the reason. A new failure is
  a bug or a difference to justify, never a row added to get green.
- `tests/testthat/test-agreement.R`: offsets against base R, sampled
  always, exhaustive with `ZUTEMPO_EXTENDED_TESTS=true`.
- `tools/bench/`: `bench.R` and `RESULTS.md` for design 12; a miss is an
  issue labelled `performance`.
- `inst/spec/PINS`: the specification, test262 and tzdata pins (DCF).
  `inst/spec/members.csv`: every member of the pinned specification with
  its R name, written by `tools/spec/members.R`.
- `tools/temporal-oracle/`: the Node project that writes
  `tests/testthat/oracle/<Type>.json` from `temporal-polyfill`. Cases are
  data in `cases.js`; expectations come from the engine.

## Invariants that are easy to break

- **The engine never calls R.** Errors are status codes plus a message in a
  per-call buffer; the glue turns them into conditions. This is what lets
  the same engine serve C callers after 0.1.0. An `Rf_error()` or an
  allocation inside `ztp_*.c` breaks that.
- **Values are stored exactly in R's own vector types** (design §4.1). No
  bit reinterpretation, no 64-bit integers smuggled in doubles. 128-bit
  integers exist only inside C.
- **Nanoseconds are normalised to `[0, 1e9)` with the floor convention**, so
  lexicographic order on (Re, Im) of a complex value is chronological order.
- **Every `TZif` count and offset is bounds-checked against the file size**
  before use. The reader is a fuzz target.
- **A slim TZif file needs the POSIX footer.** R's own database is slim;
  macOS's is fat, which hides a footer bug on the developer's machine
  (design §0).
- **Duration fields are doubles because Temporal's are.** Field-to-normalised
  conversion is a sum of products in 128 bits, never a double computation.
- **The pinned specification moves only on purpose.** `inst/spec/PINS`
  records the `tc39/proposal-temporal` and test262 commits; changing either
  needs its own `NEWS.md` entry.
- **The suite must build and pass with `ZUF_NO_INT128`** as well as with
  `__int128`. CI runs both.
- **The pinned specification has two steps that cannot be followed
  literally** (recorded in the roadmap under stage 4): `ISODateSurpasses`
  returns false when `months` is 0, which would leave `CalendarDateUntil`'s
  day loop without an exit, and `ComputeNudgeWindow` takes the origin when
  `r1` is 0, which drops the larger units of the start duration. The
  engine does what the reference engines do; `src/ztp_relative.c` comments
  both places.
- **A list-backed class needs `names()` to return `NULL`.** The fields are
  the list's names; base R and vctrs read `names()` as element names, and
  `rbind()` and `vec_c()` break without the method. `duration()` is the
  example; `ZonedDateTime` will be the next.
- **Index lists with `[[`, never `$`.** `$` partial-matches names, so
  `fields$month` finds `month_code` when `month` is absent. This bit once
  in `temporal_with()`.
- **An invalid option value is a `zutempo_type_error`** (design 10), where
  JavaScript throws a RangeError; a value of the right kind that fails a
  range check (an increment that does not divide, a calendar other than
  ISO) is a `zutempo_range_error`. The oracle holds no invalid-option
  cases for that reason.

## Testing conventions

- **Self-sufficient.** Every test builds its own inputs inside the
  `test_that()` block. No file-scope objects.
- **Self-contained.** Global state goes through `withr::local_*()`, randomised
  input through `withr::local_seed()`. Tests write only under `tempdir()`.
- **Assert on condition classes, never message text.** Use
  `expect_error(..., class = "zutempo_<kind>_error")`. Wording belongs in
  snapshot tests.
- **Order independence.** `devtools::test(shuffle = TRUE)` is part of the
  definition of done.
- **Borrow a conformance suite before writing one.** The oracle is
  `temporal-polyfill` under Node (`tools/temporal-oracle/`, from stage 1),
  checked against Node 26's native Temporal; test262's result assertions are
  translated in stage 11. Zone cases run against committed TZif fixtures
  from a pinned tzdata release, not the machine's database.
- **Tests that need the machine's database skip when it is missing.**
- **Helpers live in `tests/testthat/helper-*.R`.** `helper-oracle.R` reads
  an oracle JSON file (`oracle_cases()`) and holds one checker per type
  (`oracle_check_plain_date()`, ...), which skips until that type's
  constructor exists. `test-oracle-<type>.R` loops the cases through it.
- **`test-members.R` is the member ledger.** When a stage exports a member,
  remove its name from `pending` there; the test fails otherwise.
- **Keep the long gctorture run inside its 120-minute budget.** Its cost
  grows with the R code the tests run, not test blocks: an oracle file runs
  all its cases in one `test_that()` and compares fields in one
  `expect_equal()`. Under `ZUTEMPO_GCTORTURE_SAMPLE=true` the oracle runs
  one case per shape (`oracle_gctorture_sample()`), since a PROTECT bug is
  in the glue a shape reaches, not in the values; that cut the run by
  about 40% (2026-10-15). Add cases freely; add expectations with care.
  A heavy loop over values in another test file samples the same way.
- **Keep the suite inside the CRAN time budget.** Not yet measured.

## Definition of done

`devtools::document()` and `devtools::check()` clean, meaning 0 errors, 0
warnings and 0 notes. The one allowed note is "New submission" before the first
release. `devtools::test(shuffle = TRUE)` green. CI green on every leg of the
quick run; the full run (`full-ci`) green once, before submission (see
Continuous integration). A user-facing change also needs
a test, roxygen documentation and a `NEWS.md` entry.

## Releasing to CRAN

- **CI is the pre-submission check.** The `pedrobtz/r-actions` R CMD check runs
  `--as-cran` on the CRAN-like runners and containers, and it replaces
  win-builder, the macOS builder and R-hub. None of them is a release step,
  and `cran-comments.md` lists the CI legs as its test environments.
- **Entering `Pre-flight`.** The roadmap's feature stages are done, the
  version is set as in Versioning, `NEWS.md` and `cran-comments.md` are
  written, and CI is green. Only submission work remains.
- **Before submitting,** run the `pkg-cran-review` skill and resolve every
  finding.
- **The pretest is automated and does not read `cran-comments.md`.** A NOTE
  that is explained but not fixed gets the upload archived. Fix the NOTE
  instead of justifying it.
- **After acceptance,** tag `v0.1.0`, publish the GitHub release, bump to
  `0.1.0.9000`, and close the version's parent issue.

## Editing rules

- roxygen comments are the source. Never edit `man/` or `NAMESPACE` by hand.
- Edit `README.Rmd`, not the generated `README.md` (from stage 12).
- Keep prose simple and short. One idea per sentence. British spelling.
- Wrap roxygen text at 80 characters and run `air format .` on R sources.
- Use `lower_snake_case`. R names follow design §5: constructors named after
  the type, `temporal_` for methods, accessors named after the property,
  `now_` for `Temporal.Now`, `zutempo_` for package helpers. Internal native
  symbols are prefixed `ztp_`; the public C prefix is `zutempo_`.
- Keep hard runtime dependencies at zero. `zufast` is `LinkingTo` only.
- Export and document public functions. Do not create roxygen topics for
  internal ones.

## Continuous integration

Workflows come from `pedrobtz/r-actions`. Call those reusable workflows instead
of writing bespoke ones, and pin a released tag rather than `main`. Pin a
workflow that holds a write token, such as `coverage.yml`, to a commit, with
the tag in a comment. The `R-CMD-check` workflow must call `r-cmd-check.yml`,
because a hand-rolled one does not count as the pre-submission check.

Every run is the quick one: each job finishes in under five minutes, on
pull requests and on pushes to `main` alike. The full run, the slow jobs
at their full length, happens once, before submission (roadmap stage 13):
put the `full-ci` label on the release pull request and run
`gh workflow run gctorture.yaml` if the long gctorture is wanted alone. A
finding of the full run is fixed then. Do not add `full-ci` to an ordinary
pull request.

This package calls:

- `R-CMD-check.yaml`: `r-cmd-check.yml@v1`, quick on pull requests, full on
  `main` or with the `full-ci` label.
- `R-CMD-check.yaml` also runs `R-CMD-check-no-int128`, the same check with
  `ZUTEMPO_CFLAGS=-DZUF_NO_INT128` in the environment, which
  `src/Makevars` adds to `PKG_CFLAGS`; `test-info.R` asserts that the flag
  reached the engine.
- `native-checks.yml`: `sanitizers.yml` (UBSan and ASan), `lto.yml`,
  `rchk.yml` (with `github-packages: pedrobtz/zufast`, since the rchk
  image ignores `Remotes:`), `analyzers.yml` and `cran-special.yml` in full
  on every run, two or three minutes each; `valgrind.yml` (about eleven
  minutes) only with `full-ci`; `gctorture.yml` at step 1000 over the
  sampled oracle, and at step 20 (about an hour) with `full-ci` or the
  `gctorture` label.
- `gctorture.yaml`: the long gctorture run alone, on demand (`gh workflow
  run gctorture.yaml`).
- `coverage.yaml`: `coverage.yml` pinned to a commit. The badge is committed
  to `gh-pages` because `main` takes no direct pushes.
- `pkgdown.yaml`: the r-lib site build, deploying to `gh-pages` with
  `force: false` so it does not overwrite the badge.
- `hardening.yaml`: `fuzz.yml` three times, one job per harness under
  `tools/fuzz/` (TZif, RFC 9557, duration), against the engine sources
  (the glue excluded). The TZif job is seeded from the slim fixtures, the
  others from `tools/fuzz/corpus/`; two minutes each on a pull request
  and a push to `main`, thirty with `full-ci` or on demand (`gh workflow
  run hardening.yaml`), with the corpus carried between runs. The harnesses
  build without R: Homebrew's `clang -fsanitize=fuzzer,address,undefined`
  over `src/ztp_*.c` minus `src/ztp_r_*.c` with `zufast`'s headers is the
  local smoke test (Apple's clang has no libFuzzer). The engine's strings
  are length-delimited, so never print one with a plain `%s`.

Small edits get a small run. The shared workflows look at the files a pull
request changes, compared with its merge base:

- **Markdown only**, such as `README.md`, `NEWS.md` or `cran-comments.md`,
  skips every check. Only coverage and the pkgdown site run.
- **`DESCRIPTION` or `README.Rmd` as well**, and nothing else, adds one R CMD
  check on Ubuntu R-release.
- **Any other file** runs everything.

So put a README or `DESCRIPTION` touch-up in its own pull request. Once a pull
request changes code, every later push to it runs in full.

## Commits and pull requests

Short, imperative, sentence-case commit subjects, optionally scoped. Keep each
commit focused and do not sweep in unrelated files. A pull request explains the
user-visible outcome and the rationale, links related issues, lists the checks
that were run and the tests that were skipped, and flags platform-sensitive
changes. Performance claims need evidence.

Never commit or push to the default branch. Work on a branch, open a pull
request, and merge it only when every check is green. A stage's pull request
closes its sub-issue.

When you find a defect, in this package or in an upstream tool, open an issue
for it rather than only working around it.
