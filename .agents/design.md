# RFC 0035: `zutempo`, TC39 Temporal in R with a native C core

- **Status:** Proposed. Merging this file adopts the design as the starting
  point for the package's own `.agents/design.md`; each decision in section
  16 stays the maintainer's until the package repository records it.
  The three additions it needs from `zufast` were merged for `zufast`
  0.1.1 on 2026-10-14 (§3.1). One of them, a 128-bit integer header, is
  shared with RFC 0009 (`zuint`).
- **Date:** 2026-10-14.
- **Packages:** `zutempo` (not yet created; crandb returns `not_found`
  and r-universe has no package of that name; `tempo` is unusable because
  CRAN has `TEMPO` 0.1.0, published 2026-10-02). `LinkingTo: zufast
  (>= 0.1.1)`, build time only; `Suggests: zuint` (RFC 0009) for exact
  epoch nanoseconds, `vctrs` and `pillar` registered lazily. Vendors
  nothing. Its own code is MIT.
- **Source:** the Temporal specification at `tc39.es/proposal-temporal`
  as of 2026-10-14 (downloaded and searched: `ISODateWithinLimits`,
  `IsValidDuration`, `nsMaxInstant`, `TimeZoneEquals`, the
  `disambiguation`, `offset`, `overflow` and rounding-mode tables, and
  the RFC 9557 parsing rules in §13.35); RFC 9557 (April 2024);
  test262's `test/built-ins/Temporal` (at least 4 605 files) and
  `test/intl402/Temporal` (at least 2 029). Temporal reached Stage 4 at
  the March 2026 plenary (Igalia, 2026-03-13). The ECMA-262 pull request
  `tc39/ecma262#3966` was still open on 2026-09-24, and ES2026 has no
  Temporal text. It ships unflagged in Firefox 139, Chrome 144 and Node
  26; Safari has it behind a flag. Shipping engines: SpiderMonkey's
  `js/src/builtin/temporal/` (`TemporalTypes.h`, `Int96.h`),
  `boa-dev/temporal` (temporal_rs v0.2.6, 2026-08-05, Apache-2.0 or MIT,
  with a Diplomat C API `temporal_capi`). `pedrobtz/zufast`'s
  `.agents/design.md` §2, §3.3, §5 and §10, and its `inst/include/` tree.
  CRAN metadata from `crandb.r-pkg.org` for `clock` 0.7.4, `tzdb` 0.5.0,
  `nanotime` 0.3.15 and `lubridate` 1.9.5, with downloads from
  `cranlogs.r-pkg.org` for the 30 days to 2026-10-12. R 4.6.1's
  `?timezones`. **Measured** in the drafting session on macOS (Apple
  clang 21, R 4.6.1, Node 22.20.0): a C probe of integer widths and a
  minimal TZif reader (§0), and `temporal-polyfill` 1.0.6 as an oracle.
  Nothing has been built as an R package.

## 0. What the drafting session measured

**Integer widths.** Temporal's bounds, evaluated with `__int128`:

| Quantity | Bound | Bits needed (signed) |
| --- | --- | --- |
| Instant, epoch nanoseconds | ±8.64 × 10²¹ (±10⁸ days) | 74 |
| Normalised time duration | 2⁵³ s × 10⁹ + 999 999 999 ns | 84 |
| Epoch day of a date | ±10⁸ | 28 (fits `int32_t`) |
| Nanoseconds in a day | 8.64 × 10¹³ | 47 (exact in a double) |
| Epoch seconds of an instant | ±8.64 × 10¹² | 44 (exact in a double) |

An `int64_t` count of nanoseconds covers only ±106 751 days, roughly
1677–2262, which is `nanotime`'s range. Every quantity that R stores fits
in a double or an integer. Only the intermediates need 128 bits (§4.3).

**Three time zone databases on one machine.**

| Copy | Version | Form |
| --- | --- | --- |
| macOS system (`/usr/share/zoneinfo`) | 2026d | TZif v2, "fat": New York's explicit transitions run to 2037-11-01 |
| R 4.6.1 (`R.home("share")/zoneinfo`) | 2026b | TZif v2, "slim": New York's last explicit transition is 2007-03-11, Lisbon's 1996-03-31 |
| `tzdb` 0.5.0 (`inst/tzdata`) | 2025a | IANA source text, compiled at run time by Howard Hinnant's library |

**Slim files need the footer.** A TZif reader that uses only the explicit
transitions gives these answers on R's own copy, for New York:

| Local time | Correct | Naive reader on R's copy |
| --- | --- | --- |
| 2026-03-08 02:30 (in the spring gap) | no candidate | one candidate, UTC−4 |
| 2026-11-01 01:30 (in the autumn fold) | two candidates | one candidate, UTC−4 |

Every DST transition after 2007 is lost. The rules live only in the POSIX
TZ string at the end of the file (`EST5EDT,M3.2.0,M11.1.0`). On the macOS
copy the same naive reader is right until 2037, which hides the bug on the
developer's machine. The footer forms seen include quoted names
(`<+1030>-10:30<+11>-11,M10.1.0,M4.1.0` for Lord Howe) and fixed zones
(`<+13>-13` for Apia).

**Links.** `Asia/Kolkata` and `Asia/Calcutta` are separate files with
identical bytes in R's copy, and separate inodes in macOS's. R's copy has
no `tzdata.zi`, so nothing in it says which name is the primary
identifier. macOS ships `tzdata.zi` with 253 `L` (link) lines.

**The oracle.** `temporal-polyfill` 1.0.6 under Node 22 (which has no
native Temporal) returned:

| Expression | Result |
| --- | --- |
| `PlainDateTime 2026-03-08T02:30` → `America/New_York`, `compatible` | `2026-03-08T03:30:00-04:00[America/New_York]` |
| `PlainDate 2026-01-31` + 1 month | `2026-02-28` |
| `Instant +275760-09-13T00:00Z`, epoch ns | `8640000000000000000000` |
| `PT25H` rounded, largest unit days, relative to `2026-03-07T12:00[America/New_York]` | `P1DT2H` |
| `Asia/Calcutta` zoned value `equals` the same instant in `Asia/Kolkata` | `true`, and `timeZoneId` stays `Asia/Calcutta` |

The fourth row is the reason `Duration` needs a zone-aware `relativeTo`:
the day after 2026-03-07 noon in New York is 23 hours long.

## 1. What zutempo is

`zutempo` implements the Temporal date and time model of ECMA-262 in R:
`Instant`, `ZonedDateTime`, `PlainDateTime`, `PlainDate`, `PlainTime`,
`PlainYearMonth`, `PlainMonthDay`, `Duration` and `Now`, in the ISO 8601
calendar, with IANA time zones read from the same database that base R
uses. The arithmetic is a transliteration of the specification's abstract
operations into C, over the specification's full ranges, so that a result
in R matches the result in a browser or in Node.

Base R's `POSIXct` is a double count of seconds, so at today's epoch one
unit in the last place is about 2.4 × 10⁻⁷ s, and nanoseconds cannot be
stored. `Date` has no time of day. Neither has a duration type that knows
a day is not always 24 hours.

### 1.1 Why a C implementation

`zutempo` owns the arithmetic rather than wrapping an existing library,
because each existing route gives something up:

- **A Rust crate** (`jiff`, or temporal_rs, §3) brings
  `SystemRequirements: Cargo, rustc`, a vendored crate tarball, and CRAN's
  Rust policy on every release. `jiff` also follows Temporal only in part:
  years −9 999 to 9 999 instead of −271 821 to 275 760, duration limits of
  its own, and no `PlainYearMonth` or `PlainMonthDay`.
- **A later C surface.** A reader in the family that meets a timestamp
  (`zucbor` tag 0, `zuyaml`, a CSV date column) will want to produce a
  zoned value from C. An engine in C can offer that after v0.1.0 (§7); an
  R-level wrapper never can.

The cost is a C implementation of a large specification. Transliterating
the specification's operations (§4) keeps that cost bounded and makes
each result checkable against the reference implementations (§11).

## 2. Scope

**In v0.1.0:**

- every property and method of the eight types of §1 and of `Temporal.Now`,
  in the ISO 8601 calendar, except the members listed below and those
  JavaScript alone needs (`valueOf()`, which throws, and `toJSON()`, which
  `format()` covers);
- every Temporal option on those methods: `overflow`,
  `disambiguation`, `offset`, the nine rounding modes, `smallestUnit`,
  `largestUnit`, `roundingIncrement`, `relativeTo`, `fractionalSecondDigits`,
  `calendarName`, `timeZoneName`, `offset` display;
- IANA zones, fixed-offset zones (`+05:30`) and `UTC`, with Temporal's
  identifier rules (case-insensitive lookup, normalised output, links equal
  to their primary zone without being renamed);
- RFC 9557 parsing and formatting, including annotations and the critical
  flag;
- conversions with `Date`, `POSIXct`, `POSIXlt` and `difftime` (§6.10);

**Not in v0.1.0, and why:**

- **Non-ISO calendars** (`hebrew`, `japanese`, `islamic-*` and the rest).
  ECMA-262 requires only `iso8601`; the others come from ECMA-402 and need
  CLDR data and ICU or ICU4X. Annotations naming another calendar are
  rejected with a `zutempo_range_error`. Supporting them later would take
  an RFC of its own (D7).
- **`toLocaleString`** and locale formatting: ECMA-402.
- **Custom time zones** and POSIX TZ strings as zone identifiers. Temporal
  dropped the `TimeZone` and `Calendar` classes before Stage 4.
- **`strftime`/`strptime`**. Temporal has no such methods. Conversion to
  `POSIXct` (above) reaches base R's `format()` and `strptime()`.
- **Arithmetic and comparison operators** (`x + d`, `x - y`, `<` on
  dates). Each would be shorthand for one Temporal operation with its
  default options, and mixing with base R types needs `chooseOpsMethod()`
  from R 4.3. v0.1.0 has the functions (`temporal_add()`,
  `temporal_since()`, the `compare()` statics) and the duration
  comparisons of §6.5; operators are for a later version.
- **The C table for other packages** (§7). It serves the family's readers,
  not the specification, so v0.1.0 is Temporal alone. The engine is built
  so that the table can follow without changing it.

## 3. Position in the `zu*` family

| | zutempo |
| --- | --- |
| Role | R API; provider of a C table after v0.1.0 (§7) |
| R prefix | none for the Temporal surface (§5); `zutempo_` for package-level helpers |
| Info function | `zutempo_info()`: versions, tz database path, version and form (R1) |
| Root condition class | `zutempo_error` |
| Public C prefix | `zutempo_` for the table and header; internal `ztp_` |
| From C | `R_GetCCallable("zutempo", "zutempo_api_v1")`, after v0.1.0 |
| Hides symbols | yes (R3) |
| Vendored code | none |
| `Depends: R` | 4.1 (R2) |
| Language | en-GB (R2) |

**Relationships, as decided rather than as hoped:**

- **`zufast`**: `LinkingTo`, build time only, for its calendar
  algorithms, its RFC 3339 parser as a fast path, its digit writers, and
  the three additions of §3.1. Its design §2 lists named zones as a
  permanent non-goal, so time zones stay out of `zufast` and are
  `zutempo`'s.
- **`zuint`** (RFC 0009, as revised on 2026-10-14): `Suggests` only.
  `epoch_nanoseconds()` returns a `zuint` `int128` when `zuint` is
  installed (§6.9). No R value of `zutempo` is a `zuint` vector (§4.1).
  `zuint` and `zutempo` share `zufast/wide.h`, so neither depends on the
  other for arithmetic, and `zutempo` never waits for `zuint`.
- **Readers** (`zucbor`, `zuyaml`, `zucsv`): candidate consumers of the C
  table (§7), each to be decided in its own repository. None is required
  to adopt it.

**What exists elsewhere.**

- **`clock`** 0.7.4 (MIT; 115 914 downloads in the 30 days to
  2026-10-12): naive, sys and zoned times, calendars as types
  (`year_month_day`, `iso_year_week_day`, ...), durations with a precision
  attribute. It stores an int64 tick count as two doubles holding its
  32-bit halves. Its `nonexistent` and `ambiguous` arguments cover what
  Temporal's `disambiguation` does. It keeps one zone per vector, uses
  `invalid_resolve()` rather than `overflow`, and has no RFC 9557 strings
  and no single `Duration` with calendar units and `relativeTo`. It is
  mature and fast, and not Temporal.
- **`tzdb`** 0.5.0 (MIT; 695 401 downloads): the IANA source text (2025a,
  1.4 MB installed) and Hinnant's `date`/`tz` headers, behind a C++ API.
- **`nanotime`** 0.3.15 (GPL ≥ 2): `integer64` nanoseconds, 1677–2262,
  on `RcppCCTZ`.
- **`lubridate`** 1.9.5 and base R: double seconds. Its
  `SystemRequirements` asks for system zoneinfo, falling back to R's copy
  on Windows.
- **temporal_rs**: a complete Temporal in Rust with a C API. Linking it
  from R brings back the Cargo requirement this RFC avoids (D2).
- No package on CRAN implements Temporal (search on 2026-10-14).

### 3.1 What zutempo takes from zufast

`zufast` 0.1.0 (submitted to CRAN on 2026-10-10) is header-only C99,
consumed through `LinkingTo` with no run-time dependency. Its
`zufast/datetime.h` already holds most of the calendar layer Temporal
needs:

| Need | In zufast 0.1.0 | Used for |
| --- | --- | --- |
| Days ↔ civil date | `zuf_days_from_civil()`, `zuf_civil_from_days()`, valid for every `int32_t` day (years −5 877 641 to 5 881 580) | every plain type, every date field |
| Leap years, month lengths | `zuf_is_leap_year()`, `zuf_days_in_month()` | `overflow`, `daysInMonth`, `inLeapYear` |
| Expanded-year output | `zuf_format_date()` writes `+275760-09-13` | `toString()` of out-of-range-for-RFC-3339 years |
| Common timestamps | `zuf_parse_datetime()`: four-digit years, `T`, `t` or space, 0–9 fraction digits, `Z` or `±HH[:MM]` | fast path of the parser (§9) |
| Digits | two-digit table and writers | formatting |

Three additions were made to `zufast` for 0.1.1, with `zutempo` as the
named consumer. They were tracked in `pedrobtz/zufast#34` and merged on
2026-10-14. `zufast`'s design document (§9.5 and §10) is the reference
for their exact signatures.

1. **Expanded years in parsing** (`pedrobtz/zufast#39`).
   `zuf_parse_date_opt()` and `zuf_parse_datetime_opt()` take
   `ZUF_DT_EXPANDED_YEAR`, which accepts Temporal's `±YYYYYY` and rejects
   `-000000`. Temporal's own `toString()` emits these years outside
   0–9999, so `zutempo` must read back what it writes. The formatters now
   pad such years to six digits, as Temporal does, so `+010000-01-01`
   round-trips.
2. **ISO week dates** (`pedrobtz/zufast#38`). `zuf_weekday_from_days()`,
   `zuf_iso_week_from_days()`, `zuf_iso_weeks_in_year()` and
   `zuf_days_from_iso_week()`, exact over the whole `int32_t` day range,
   for `dayOfWeek`, `weekOfYear` and `yearOfWeek`.
3. **`zufast/wide.h`, 128-bit integers** (`pedrobtz/zufast#40`).
   `zuf_i128` and `zuf_u128` are two-word structs in every build, with
   `__int128` inside the function bodies where defined and not under
   `ZUF_NO_INT128`. The header covers construction and splitting,
   comparison, checked and wrapping add, subtract and multiply, the full
   64 × 64-bit products, truncating and floor division by a 64-bit or
   128-bit divisor, exact conversion to and from `double`, and decimal
   parsing and writing. The hot path it serves is text to value: a
   timestamp string with nanoseconds becomes 74-bit epoch nanoseconds,
   and `zuint` parses and formats 128-bit integers through it.

Two things stay out of `zufast` by its own rules: time zones, a permanent
non-goal, and RFC 9557 annotations, which are not data a reader meets
without zones. The rest of the parser is `zutempo`'s.

Timing: CRAN's cadence lets `zufast` 0.1.1 follow 0.1.0 six weeks after
acceptance. `zutempo` needs more than that to reach Stage 8 (§14), so
the additions do not delay it. Until 0.1.1 is on CRAN, `zutempo` develops
against `zufast`'s default branch.

## 4. Architecture

```text
R vectors (complex / integer / double / list records), zone tables
   |
   v
R layer: argument and option normalisation, recycling, class and
         attribute handling, vctrs and pillar methods (lazy)
   |
   v
C glue (src/ztp_r_*.c): R vectors in, column loops, NA handling,
         condition raising with the element index
   |
   v
C engine (src/ztp_*.c): the specification's abstract operations over
         plain C structs; no SEXP, no allocation in loops; calendar
         algorithms and 128-bit intermediates from zufast's headers
   |                                   \
   v                                    v
Zone cache (src/ztp_tz*.c):          C table (zutempo_api_v1) for
  TZif v1–v4 reader, POSIX TZ          other packages, after v0.1.0 (§7)
  footer rules, link table,
  identifier index
   |
   v
tz database on disk (§8)
```

- The engine is written against the specification's operation names
  (`AddDurationToDate`, `DifferenceZonedDateTime`, `RoundRelativeDuration`,
  `GetPossibleEpochNanoseconds`, ...), one C function per operation where
  practical, each with a comment naming the section it implements. This is
  how SpiderMonkey's `builtin/temporal/` is organised, and it makes a
  specification change a diff against named functions.
- **A pinned specification.** `zutempo` implements the specification at a
  recorded commit of `tc39/proposal-temporal` (or of `tc39/ecma262` once
  Temporal is merged there) and runs test262 at a recorded commit.
  `zutempo_info()` reports both. Moving either is a deliberate change with
  its own NEWS entry, since Temporal still receives normative fixes after
  Stage 4.
- The engine never calls R. Errors are status codes plus a message in a
  per-call buffer; the glue turns them into conditions. This is what lets
  §7 offer the same engine to C callers.
- C99 with `static inline` helpers. No C++ and no Rust.

### 4.1 Values in R

Every value is stored exactly in R's own vector types. 128-bit integers
appear only inside C (§4.3).

| Class | Temporal type | Storage | Range check |
| --- | --- | --- | --- |
| `zutempo_instant` | `Instant` | complex: Re = epoch seconds (integral double), Im = nanoseconds 0–999 999 999 | ±8.64 × 10¹² s |
| `zutempo_zoned_date_time` | `ZonedDateTime` | record of two fields: `instant` (as `Instant`) and `zone` (integer code into the attribute `zones`, a character vector of identifiers) | as `Instant` |
| `zutempo_plain_date_time` | `PlainDateTime` | complex: Re = epoch day (integral double), Im = nanoseconds of day | `ISODateTimeWithinLimits` |
| `zutempo_plain_date` | `PlainDate` | integer: epoch day | `ISODateWithinLimits` |
| `zutempo_plain_time` | `PlainTime` | double: nanoseconds of day | 0 to 8.64 × 10¹³ − 1 |
| `zutempo_plain_year_month` | `PlainYearMonth` | integer: months since 1970-01; reference day 1 | as `PlainDate` |
| `zutempo_plain_month_day` | `PlainMonthDay` | integer: `month × 32 + day`; reference year 1972 | valid in 1972 |
| `zutempo_duration` | `Duration` | list of ten doubles, years to nanoseconds | `IsValidDuration` |

Why these shapes:

- **One atomic vector per value type wherever possible.** The exceptions
  are `Duration`, whose ten fields Temporal keeps apart, and
  `ZonedDateTime`, whose zone is per value (§4.2). `[`, `length()`,
  `rep()`, `rev()`, data-frame columns and `saveRDS()` then work through
  R's own code, and a class-stripping function such as `unclass()` or
  `ifelse()` still yields readable numbers rather than reinterpreted bits.
  A complex vector carries two exact doubles per element; R's
  `NA_complex_` is the missing value.
- **Ordering.** Nanoseconds are normalised to `[0, 10⁹)` with the floor
  convention, so lexicographic order on (Re, Im) is chronological order.
  `xtfrm()` and `sort()` methods compare in C.
- **Duration fields are doubles because Temporal's are.** The
  specification defines each field as a "float64-representable integer",
  which is exactly an R double holding an integral value; JavaScript
  stores them as Numbers. Duration results therefore agree with JavaScript
  by construction, field for field. Temporal's 84-bit arithmetic happens
  on the normalised form, in C.
- **Day numbers, not records.** A plain date is one integer, not a
  `vctrs::new_rcrd()` record of year, month and day. That is a third of
  the memory of a three-field record and makes date differences a
  subtraction. Field accessors decode in C.

### 4.2 Zones on zoned values

Every `ZonedDateTime` carries its own zone, as in Temporal, not one zone
per vector as in `POSIXct` and `clock`. A vector holds an integer code per
element into a table of the identifiers it uses, stored once as the
attribute `zones`. Each value keeps the identifier it was given, so
`Asia/Calcutta` and `Asia/Kolkata` are separate table entries that are
equal under `TimeZoneEquals` (§6.7).

- `c()`, `[`, `rep()` and assignment merge or subset the tables and
  recode, so mixed zones combine freely. They are methods on the class,
  with `vctrs` record methods registered when `vctrs` is loaded.
- The engine works per distinct zone, not per element: a call groups the
  elements by code, opens each zone once, and handles the common
  single-zone vector with no grouping at all.
- `as.POSIXct()` of a vector whose zones are all equal under
  `TimeZoneEquals` keeps that zone as `tzone`. With mixed zones the
  instants are kept and `tzone` is `"UTC"`, since `POSIXct` has one zone
  per vector.

### 4.3 Exact arithmetic in C

| Operation | Representation in C |
| --- | --- |
| Instant and zoned arithmetic | epoch nanoseconds as `zuf_i128` |
| Time durations (`TimeDuration` in the specification) | nanoseconds as `zuf_i128`, \|t\| < 2⁵³ × 10⁹ |
| Differences of time durations | `zuf_i128`, checked add (85 bits worst case) |
| Rounding to an increment | `zuf_i128` floor/trunc divmod by `increment × unit` |
| Date arithmetic | `int32_t` epoch days, `zufast`'s civil algorithms |
| Time of day | `int64_t` nanoseconds |

`zuf_i128` (§3.1) is a two-word struct, computed with `__int128` on every
64-bit CRAN platform (GCC and clang, Rtools included) and without it under
`ZUF_NO_INT128`.
`zutempo` builds and runs its whole test suite both ways in CI (§11).
Because the header is `static inline`, `zufast` is needed when `zutempo`
is built and never when it runs.

The specification allows millisecond, microsecond and nanosecond fields to
hold integers beyond 2⁵³ that are still exactly representable as doubles;
it notes that this "can be implemented by using 128-bit integers". The
conversion from fields to the normalised form is therefore a sum of
products in `zuf_i128`, never a double computation.

## 5. Public R API

Names follow Temporal's, in snake case, by one rule per kind of member:

| Temporal | R | Examples |
| --- | --- | --- |
| type and its `from()` | constructor named after the type | `plain_date()`, `instant()`, `zoned_date_time()`, `duration()` |
| static method other than `from()` | type name, then method name | `duration_compare()`, `instant_compare()` |
| prototype method | `temporal_` and the method name | `temporal_add()`, `temporal_round()`, `temporal_since()`, `temporal_get_time_zone_transition()` |
| property | accessor named after it | `year()`, `epoch_nanoseconds()`, `hours_in_day()` |
| `Temporal.Now` function | `now_` and the function name | `now_instant()`, `now_zoned_date_time_iso()` |

`zutempo_info()` and `zutempo_tz_reset()` (§8) are the package-level
helpers. A test checks the exported names against the member list of
§15.

```r
x <- zoned_date_time("2026-03-07T12:00[America/New_York]")
temporal_add(x, duration(hours = 25))
#> 2026-03-08T14:00:00-04:00[America/New_York]
temporal_round(duration(hours = 25), largest_unit = "day", relative_to = x)
#> P1DT2H
plain_date("2026-01-31") |> temporal_add(duration(months = 1))
#> 2026-02-28
epoch_nanoseconds(instant("+275760-09-13T00:00Z"))   # zuint::int128 if installed
#> 8640000000000000000000
```

Consequences:

- The accessors `year()`, `month()`, `day()`, `hour()` and friends
  mask `lubridate`'s. They are S3 generics with methods
  for `zutempo` classes and a default that calls the function they mask,
  so `lubridate` objects keep working.
- Classes are `zutempo_*`, so saved objects never dispatch to another
  package's methods.

## 6. Semantics

Each subsection names the specification operations it follows. Where this
RFC says nothing, the specification decides.

### 6.1 Ranges

`Instant` and `ZonedDateTime`: ±10⁸ days around the epoch, inclusive.
Dates: years −271 821 to 275 760, from April of the first year to
September of the last. `PlainDateTime` may be up to one day outside the
instant range. A result outside its range is a `zutempo_range_error`, never
`NA` and never a clamp. `Now` clamps, as the specification says.

### 6.2 Overflow

`overflow = "constrain"` (default) clamps fields to their valid range,
such as 2026-01-31 plus one month giving 2026-02-28. `"reject"` raises a
`zutempo_range_error`.

### 6.3 Local time to instant

`GetPossibleEpochNanoseconds` finds zero, one or two candidates from the
offsets in force one day either side of the local time.
`disambiguation`:

| Value | Gap (zero candidates) | Fold (two candidates) |
| --- | --- | --- |
| `compatible` (default) | later: shift forward by the gap | earlier |
| `earlier` | shift backward by the gap | earlier |
| `later` | shift forward by the gap | later |
| `reject` | error | error |

`offset` (for strings and `with()` that carry an offset): `use`,
`ignore`, `prefer` (default for `with()`), `reject` (default for
`from()`).

### 6.4 Rounding

The nine modes of the specification's Table 28: `ceil`, `floor`,
`expand`, `trunc`, `halfCeil`, `halfFloor`, `halfExpand`, `halfTrunc`,
`halfEven`. `roundingIncrement` must divide the next larger unit for units
below a day. `Instant` rounding rounds the epoch nanoseconds "as if
positive", so `trunc` goes down before 1970. This and `halfEven` ties
are the specification's definitions, with no adaptation layer.

### 6.5 Durations

Balancing, `round()`, `total()` and `compare()` follow
`RoundRelativeDuration`, `BalanceTimeDuration` and their callers.
Calendar units (years, months, weeks) need `relativeTo`; with a
`PlainDate` a day is 24 hours, and with a `ZonedDateTime` days follow the
zone (§0, `P1DT2H`). Without `relativeTo`, any operation that needs it is
an error, including weeks.

`<`, `==` and `sort()` on durations: Temporal has no operators, since
`valueOf()` throws. In R, `==` compares fields (`PT1H != PT60M`), and
`<` and `sort()` error unless every element is free of calendar units, in
which case they compare total nanoseconds. `duration_compare()` takes
`relative_to`.

### 6.6 Since and until

`x$since(y)` is `-(x$until(y))` with the negated rounding mode, as
`DifferenceTemporal*` defines it. Default largest units follow the
specification per type (`hour` for zoned values and instants' `second`,
...).

### 6.7 Time zone identity

Identifiers match ASCII-case-insensitively and are emitted in the
database's case. Two identifiers are equal under `TimeZoneEquals` when
they resolve to the same primary identifier, but a value keeps the
identifier it was given (§0, `Asia/Calcutta`). `+00:00` and `UTC` are
different zones that happen to have the same offset, as in Temporal.

### 6.8 Missing values

`NA` propagates through every operation. An `NA` in an option argument is
an error, not a missing result. Constructors from strings return `NA` only
for `NA_character_`; an unparsable string is an error, with
`zutempo_parse(x, na_on_error = TRUE)` as the bulk-reading escape.

### 6.9 Differences from the specification

These are the only differences from the specification. The first four are
forced by R:

- **`epochNanoseconds`** is a BigInt in JavaScript. `epoch_nanoseconds()`
  returns a `zuint::int128` when `zuint` is installed and a decimal string
  otherwise; `epoch_milliseconds()` is a double and exact, since
  8.64 × 10¹⁵ < 2⁵³.
- **Option bags** become named arguments. JavaScript's property-read
  order and type coercion (a large share of test262) have no R
  counterpart.
- **Methods** are functions: `x.add(d)` is `temporal_add(x, d)`.
- **Vectorisation**: arguments recycle by R's rules; options are scalar.

The last two are choices this RFC makes:

- **Missing values** (§6.8): `NA` has no JavaScript counterpart.
- **Duration operators** (§6.5): `==`, `<` and `sort()` exist in R, where
  Temporal's `valueOf()` throws.

### 6.10 Conversions with base R

Base R has four date and time types. Each conversion goes through a
specification operation where one exists, and states what it loses.

| From | To | How, and what is lost |
| --- | --- | --- |
| `PlainDate` | `Date` | exact: both count days from 1970-01-01 |
| `Instant` | `POSIXct`, `tzone = "UTC"` | epoch nanoseconds to the nearest double second, so precision below about 240 ns at today's dates is lost |
| `ZonedDateTime` | `POSIXct` | as `Instant`, with the zone as `tzone`; mixed zones give `"UTC"` (§4.2) |
| `ZonedDateTime` | `POSIXlt` | fields in each value's zone, with each element's offset in `gmtoff`; seconds lose precision as above |
| `PlainDateTime` | `POSIXct`, `POSIXlt` | needs `tz`, which has no default, and takes `disambiguation` (§6.3): through `ZonedDateTime` |
| `ZonedDateTime`, `Instant` | `Date` | the date in the value's zone, or in `tz` for an `Instant`: through `PlainDate` |
| `PlainTime` | `difftime` | seconds since midnight; base R has no time-of-day type |
| `Duration` | `difftime` | `Duration.prototype.total` in seconds: years, months and weeks need `relative_to`, and a day counts 24 hours without it; the total is rounded to a double |
| `PlainYearMonth`, `PlainMonthDay` | none | `Date` only through `temporal_to_plain_date()`, which supplies the missing day or year, as in Temporal |

In the other direction:

- `Date` to `PlainDate` is exact.
- `POSIXct` to `Instant` takes the double's exact value, not the decimal
  that was typed: 0.1 s is 100 000 000.000 000 005 551 ns, which rounds
  to 100 000 000 ns. Nanoseconds are rounded half to even.
- `POSIXct` to `ZonedDateTime` takes the zone from `tzone`; an empty
  `tzone` is the system zone, as base R reads it.
- `POSIXlt` goes through `POSIXct`. `difftime` becomes a `Duration` of
  seconds and nanoseconds, balanced as `Duration.from()` leaves it.

The R interface is S3 methods on base R's own generics, `as.Date()`,
`as.POSIXct()`, `as.POSIXlt()` and `as.difftime()`, with `tz`,
`disambiguation` and `relative_to` arguments where a conversion needs
them. The reverse direction is the constructors: `plain_date(<Date>)`,
`instant(<POSIXct>)`, `zoned_date_time(<POSIXct>)` and
`duration(<difftime>)`. These methods sit outside §5's naming rule,
since they are R's generics, not Temporal members.

## 7. The C table, after v0.1.0

Not in v0.1.0 (§2). This section records the shape the engine is built to
allow, so that adding the table later changes no engine code.

```c
#include <zutempo.h>          /* inst/include, LinkingTo: zutempo */

const zutempo_api_v1 *api = zutempo_api();   /* R_GetCCallable */
zutempo_zone *z;
api->zone_open("Europe/Madrid", &z);         /* cached, reference-counted */
api->parse(str, len, &fields);               /* RFC 9557 into a struct */
api->local_to_instant(z, &local, ZUTEMPO_DISAMBIG_COMPATIBLE, &instant);
api->offset_at(z, &instant, &offset_ns);
api->format_zoned(buf, cap, &instant, z, &opts);
api->zone_close(z);
```

The table has a version and a size field, grows only at the end, and
never changes a member's meaning. Plain structs, no `SEXP`, no allocation
visible to the caller. It covers what a reader needs to turn a timestamp
string into a value or a value into a string: parsing, zone lookup,
local-to-instant resolution, offsets and formatting. Whether it also
exposes duration arithmetic and rounding is decided when it lands. The
starting position is no, until a reader asks.

When it lands, a fixture package in `tests/` (built in CI, not in the
tarball) consumes it the way `zucbor`'s tag 0 decoder would.

## 8. Time zone data

### 8.1 Where it is read from

`zutempo` reads compiled TZif files and follows base R's lookup, so that
`zutempo` and `POSIXct` agree on the same machine:

1. option `zutempo.tzdir`, then environment variable `TZDIR`, with R's
   special values `"internal"` and `"macOS"`;
2. on Windows, `R.home("share")/zoneinfo`;
3. on macOS, `R.home("share")/zoneinfo`, then
   `/var/db/timezone/zoneinfo`, as R does (amended 2026-10-15: R's
   `?timezones` says R takes whichever is newer, but R 4.6 reads its own
   copy even when the system's is newer, and agreeing with `POSIXct` is
   the point of this list);
4. elsewhere, `/usr/share/zoneinfo`, then `R.home("share")/zoneinfo`.

`zutempo_info()` reports the directory, the version (from `+VERSION`,
R's `VERSION` file, or the `# version` line of `tzdata.zi`) and whether
the files are fat or slim. When no database is found, `UTC` and offset
zones still work and a named zone is a `zutempo_tz_error` naming the
directories tried.

**No bundled copy in v0.1.0.** Every CRAN platform has one of the sources
above: R itself ships one on Windows and macOS. A bundled copy goes
stale: `tzdb` 0.5.0 still carries 2025a while this machine's system has
2026d. No last-resort copy is bundled either (D6): R ships one on the
platforms that lack a system copy.

### 8.2 Reading it

- TZif versions 1 to 4, the 64-bit block only when present.
- The **POSIX TZ footer** in full: `M`, `J` and zero-based day rules,
  quoted and unquoted names, signed offsets, and v3's extended hours
  (−167 to 167) for rules such as "24:00". This is mandatory, not an
  optimisation: R's own copy is slim (§0).
- Transitions are searched by binary search over the explicit list, then
  by the footer rule for times after the last transition, computed per
  year and cached.
- `GetNamedTimeZoneNextTransition` and `...PreviousTransition` (Temporal's
  `getTimeZoneTransition`) walk the same structure, bounded by the instant
  range.
- Files are parsed defensively: every count and offset is
  bounds-checked against the file size before use, and the reader is a
  fuzz target (§11).

### 8.3 Identifiers and links

TZif files say nothing about links (§0). `zutempo` ships a generated
table of IANA's `backward` file, about 250 link → target pairs, with the
tzdata version it came from, and uses it for `TimeZoneEquals`. Available
identifiers are found by walking the database directory once per session,
excluding non-zone files (`posixrules`, `*.tab`, `+VERSION`, `right/`,
`posix/`), and are matched case-insensitively from that index. That makes
lookup behave the same on case-sensitive Linux file systems and
case-insensitive macOS ones.

When the link table and the database disagree (a link added in a newer
tzdata), the database wins for existence and the table for identity, and
`zutempo_info()` reports both versions.

### 8.4 Caching

Parsed zones are cached for the session, keyed by the case-folded
identifier, and invalidated when `zutempo.tzdir` or `TZDIR` changes.
`zutempo_tz_reset()` clears the cache explicitly.

## 9. Strings

Parsing follows the specification's grammar, which is RFC 9557 on top of
ISO 8601 with Temporal's restrictions:

- expanded years (`+275760`, `-271821`; `-000000` rejected);
- a time zone annotation `[Europe/Madrid]` or `[+05:30]`, and any number
  of key-value annotations; `u-ca` is the only key understood;
- `!` marks a critical annotation. An unknown critical annotation, or a
  second `u-ca` where either is critical, is a `zutempo_range_error`;
  unknown elective annotations are ignored;
- a leap second `:60` is read as `:59`;
- `Z` with a bracketed zone means "instant, displayed in this zone";
- duration strings, `P1Y2M3DT4H5M6.789S`, with a fraction only on the
  smallest unit present.

A string with no `[` that `zuf_parse_datetime()` accepts takes that fast
path (§3.1); the result is then checked against Temporal's extra rules:
a leap second becomes `:59`, and more than nine fraction digits is a
`zutempo_parse_error`, where `zufast` validates and discards them.
Everything else goes through `zutempo`'s own parser: expanded years, comma
fractions, annotations, and the date-only, time-only, year-month and
month-day forms.

Formatting: `fractionalSecondDigits` (`auto` or 0–9), `smallestUnit`,
`roundingMode`, `calendarName` (`auto`, `always`, `never`, `critical`),
`timeZoneName` (`auto`, `never`, `critical`) and `offset` (`auto`,
`never`). Offsets print as `±HH:MM` and round to minutes, as Temporal
does.

## 10. Errors

| Class | Raised for |
| --- | --- |
| `zutempo_error` | root of all classes below |
| `zutempo_range_error` | values or results out of range; invalid fields with `overflow = "reject"`; unsupported calendars; `disambiguation = "reject"` |
| `zutempo_parse_error` | unparsable strings, with the position of the first bad byte; a subclass of `zutempo_range_error` |
| `zutempo_type_error` | wrong argument classes and invalid option values |
| `zutempo_tz_error` | unknown zones; missing or unreadable database; a subclass of `zutempo_range_error` |

Every condition from a vectorised call carries the 1-based index of the
first failing element. The classes mirror JavaScript's `RangeError` and
`TypeError`, where an unparsable string and an unknown zone are both
`RangeError`s, so that test262 expectations map one to one.

## 11. Testing

- **An oracle from the reference implementations.** A generator under
  `tools/temporal-oracle/` runs cases through `temporal-polyfill` under
  Node (§0) and writes the expected values as JSON. That becomes the
  acceptance suite of §15. A second run against Node ≥ 26's native
  Temporal (V8 with temporal_rs) checks the polyfill.
  Cases that depend on zone rules record the tzdata version they were
  generated with and run against a small committed set of TZif files from
  that version (§11 last bullet), not against the machine's database.
- **test262, translated.** The result assertions of
  `test/built-ins/Temporal` (values, thrown error classes) are extracted by
  a script under `tools/` into JSON, skipping files that test only
  JavaScript mechanics (property order, coercion, prototype shape,
  `BigInt` handling). Each skipped file is listed with its reason. The
  share of files translated is reported, not targeted.
- **Agreement with base R.** For every zone in the database and every
  hour from 1900 to 2100, `zutempo`'s offset equals base R's
  `as.POSIXlt()` offset, except where R's documented behaviour differs
  (R picks one candidate in a gap). Run in CI, not on CRAN. This checks
  interoperability, not correctness: where R and the specification
  disagree, `zutempo` follows the specification and the case is listed.
- **Fallback build.** The whole suite runs again with `ZUF_NO_INT128`.
- **Sanitisers and fuzzing.** `native-checks.yaml` (UBSan, ASan,
  valgrind, rchk). Fuzz targets for the RFC 9557 parser, the duration
  parser and the TZif reader (`hardening.yaml`), with corpora seeded from
  the database and from test262 strings.
- **Committed zone fixtures.** About twenty TZif files from one pinned
  tzdata release, chosen for awkward histories: `America/New_York`,
  `Europe/Lisbon`, `Australia/Lord_Howe` (30-minute DST),
  `Pacific/Apia` (skipped 2011-12-30), `Pacific/Kiritimati` (+14),
  `America/St_Johns`, `Africa/Casablanca` (Ramadan rules), `Asia/Kolkata`
  and its link, `Europe/Dublin` (negative DST), `Antarctica/Troll`
  (+2 hours of DST). Both fat and slim builds of each.

## 12. Performance targets

Targets for the first stage to measure, not measurements:

| Operation, 10⁶ elements | Target |
| --- | --- |
| Parse RFC 3339 strings with offset into `Instant` | < 0.3 s |
| Parse RFC 9557 strings with a bracketed zone into `ZonedDateTime` | < 0.5 s |
| `Instant` to `ZonedDateTime` field access, one zone | < 0.1 s |
| `PlainDateTime` to `ZonedDateTime`, `compatible`, one zone | < 0.2 s |
| Format `ZonedDateTime` to strings | < 0.4 s |

And no slower than `clock` on the operations both offer, measured with
`bench` in a non-CRAN benchmark script.

These are targets, not constraints. No speed-up justifies a result that
differs from the specification: a faster path that cannot match it
exactly is not taken.

## 13. Build, portability and CRAN

- C99, `PKG_CFLAGS = $(C_VISIBILITY)`, nothing exported but
  `R_init_zutempo` (R3), and the registered table once §7 lands.
- `LinkingTo: zufast (>= 0.1.1)`. CI installs `zufast` from its default
  branch until 0.1.1 is on CRAN; `zutempo` is not submitted before then.
- Reads the system's or R's tz database; writes nothing. CRAN policy
  restricts writing, not reading, and base R reads the same files.
- Expected source size well under 1 MB: no vendored library, about 250
  lines of generated link table, and test fixtures of about 100 KB
  compressed.
- Tests that need the machine's database skip when it is missing, so a
  minimal container without tzdata still passes `R CMD check`.

## 14. Roadmap

| Stage | Title | Size |
| --- | --- | --- |
| 0 | Identity; CI from `r-actions`; pinned specification and member list (§4); oracle generator (§11) | M |
| 1 | `PlainDate`, `PlainTime`, `PlainDateTime`, `PlainYearMonth`, `PlainMonthDay`: storage, constructors, fields, `with`, compare, ISO strings | L |
| 2 | `Duration`: storage, validation, balancing without `relativeTo`, `add`/`subtract`/`since`/`until` on plain types, rounding modes | L |
| 3 | `Instant`, `UTC` and offset zones; `Now` | M |
| 4 | TZif reader, POSIX footer, identifier index, link table, cache, `zutempo_info()` | L |
| 5 | `ZonedDateTime`: disambiguation, offset option, zone-aware arithmetic, `relativeTo`, `startOfDay`, `hoursInDay`, transitions | L |
| 6 | RFC 9557 annotations end to end; formatting options | M |
| 7 | Base R conversions (§6.10); `epoch_nanoseconds()` with `zuint` | S |
| 8 | test262 translation, base R agreement, fuzzing, benchmarks | M |
| 9 | Documentation, release 0.1.0 | M |

## 15. Acceptance criteria for v0.1.0

1. `R CMD check --as-cran` clean on every CI leg, natively and with
   `ZUF_NO_INT128`, against `zufast` 0.1.1 from CRAN.
2. Every oracle case (§11) matches, with no documented differences
   outside §6.9.
3. Every member in scope (§2) has an R function under the names of §5,
   checked by a test against a member list extracted from the pinned
   specification (§4).
4. The base R agreement test passes for every zone, 1900–2100.
5. The slim-file regression of §0 is a test: New York, 2026, R's copy,
   zero and two candidates.

## 16. Decisions

| # | Question | Decision |
| --- | --- | --- |
| D1 | Implementation | C, transliterating the specification's operations |
| D2 | Not chosen | temporal_rs through `temporal_capi` (Cargo again); `jiff` (Cargo, and partial Temporal ranges and types, §1.1) |
| D3 | Shared C primitives | `zufast` (>= 0.1.1) through `LinkingTo`: calendar algorithms, RFC 3339 fast path, and the new `wide.h` (§3.1) |
| D4 | R storage | exact doubles, integers and complex pairs (§4.1); no `zuint` vectors |
| D5 | Zones on zoned values | one per value, as in Temporal: a code per element into a zone table (§4.2) |
| D6 | tz database | base R's lookup order, read at run time; no bundled copy |
| D7 | Calendars | ISO 8601 only |
| D8 | R names | Temporal's, in snake case (§5) |
| D9 | Licence | MIT |
| D10 | `zuint` | `Suggests` only, for `epoch_nanoseconds()` |
| D11 | Name | `zutempo`: short and unused, with "Temporal" in the Title field; `tempo` is unusable because CRAN has `TEMPO` |

## 17. Open questions

None. §16 records an answer to every question this RFC raised: the zone
data (D6), calendars (D7) and the name (D11). The C table's scope is left
to the table's own design (§7).

## 18. What this RFC does not decide

- Whether `zucbor`, `zuyaml` or `zucsv` adopt the C table.
- When `zufast`'s design §2 and §3.3 are amended to name `zutempo` as the
  owner of time zones.

Review prepared with assistance from generative AI.
