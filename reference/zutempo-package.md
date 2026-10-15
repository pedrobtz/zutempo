# zutempo: Dates, Times and Durations Following the 'TC39' Temporal Specification

An implementation of the Temporal date and time model of 'ECMA-262' in
'R', with a native 'C' core: 'Instant', 'ZonedDateTime',
'PlainDateTime', 'PlainDate', 'PlainTime', 'PlainYearMonth',
'PlainMonthDay', 'Duration' and 'Now', in the ISO 8601 calendar, with
'IANA' time zones read from the same database that base 'R' uses. Values
are stored exactly in 'R' vectors, arithmetic is done over the
specification's full ranges with exact 128-bit intermediates, and
strings follow RFC 9557 with annotations. Every result is meant to match
the result of the same operation in a browser or in 'Node'.

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
  `x < y`): use the functions, such as
  [`temporal_add()`](https://pedrobtz.github.io/zutempo/reference/temporal_add.md)
  and
  [`plain_date_compare()`](https://pedrobtz.github.io/zutempo/reference/plain_date.md).
  Durations do compare with `==` and `<`.

## See also

Useful links:

- <https://pedrobtz.github.io/zutempo/>

- <https://github.com/pedrobtz/zutempo>

- Report bugs at <https://github.com/pedrobtz/zutempo/issues>

## Author

**Maintainer**: Pedro Baltazar <pedrobtz@gmail.com> \[copyright holder\]

Authors:

- Pedro Baltazar <pedrobtz@gmail.com> \[copyright holder\]
