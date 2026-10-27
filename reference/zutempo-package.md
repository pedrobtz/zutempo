# zutempo: Dates, Times and Durations Following 'JavaScript' Temporal

An implementation of the Temporal date and time model of 'ECMAScript',
the language standard 'ECMA-262' behind 'JavaScript', in 'R', with a
native 'C' core: 'Instant', 'ZonedDateTime', 'PlainDateTime',
'PlainDate', 'PlainTime', 'PlainYearMonth', 'PlainMonthDay', 'Duration'
and 'Now', in the ISO 8601 calendar, with the time zones of the Internet
Assigned Numbers Authority (IANA) read from the same database that base
'R' uses. Values are stored exactly in 'R' vectors, arithmetic is done
over the specification's full ranges with exact 128-bit intermediates,
and strings follow the Internet Extended Date/Time Format of RFC 9557,
with annotations. Every result is meant to match the result of the same
operation in a browser or in 'Node.js'.

## Scope

zutempo implements every member of the eight Temporal types and
`Temporal.Now` in the pinned specification
([`zutempo_info()`](https://pedrobtz.github.io/zutempo/reference/zutempo_info.md)),
in the ISO 8601 calendar. It does not include:

- calendars other than ISO 8601 (Hebrew, Japanese and the others come
  from ECMA-402, with CLDR data);

- locale formatting (`toLocaleString()`): convert to `POSIXct` and use
  base R's [`format()`](https://rdrr.io/r/base/format.html);

- custom time zones, or POSIX TZ strings as zone identifiers;

- arithmetic and comparison operators on dates and times (`x + d`,
  `x < y`, `x == y`): they raise a `zutempo_type_error`. Use the
  functions, such as
  [`temporal_add()`](https://pedrobtz.github.io/zutempo/reference/temporal_add.md),
  [`temporal_equals()`](https://pedrobtz.github.io/zutempo/reference/temporal_equals.md)
  and
  [`plain_date_compare()`](https://pedrobtz.github.io/zutempo/reference/plain_date.md).
  Durations do compare with `==` and `<`.

[`sort()`](https://rdrr.io/r/base/sort.html),
[`order()`](https://rdrr.io/r/base/order.html),
[`min()`](https://rdrr.io/r/base/Extremes.html),
[`max()`](https://rdrr.io/r/base/Extremes.html) and
[`range()`](https://rdrr.io/r/base/range.html) use each type's
`compare()` order; a zoned value sorts by its instant. A
[`plain_month_day()`](https://pedrobtz.github.io/zutempo/reference/plain_month_day.md)
has no `compare()` in Temporal: it sorts by month and day, but has no
[`min()`](https://rdrr.io/r/base/Extremes.html),
[`max()`](https://rdrr.io/r/base/Extremes.html) or
[`range()`](https://rdrr.io/r/base/range.html).
[`rank()`](https://rdrr.io/r/base/rank.html) compares with operators, so
use `rank(xtfrm(x))`.

## See also

Useful links:

- <https://pedrobtz.github.io/zutempo/>

- <https://github.com/pedrobtz/zutempo>

- Report bugs at <https://github.com/pedrobtz/zutempo/issues>

## Author

**Maintainer**: Pedro Baltazar <pedrobtz@gmail.com> \[copyright holder\]

Authors:

- Pedro Baltazar <pedrobtz@gmail.com> \[copyright holder\]

Other contributors:

- Ecma International (Test262 tests translated into
  tests/testthat/test262/, see inst/COPYRIGHTS) \[copyright holder\]
