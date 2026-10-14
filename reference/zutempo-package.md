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

## See also

Useful links:

- <https://pedrobtz.github.io/zutempo/>

- <https://github.com/pedrobtz/zutempo>

- Report bugs at <https://github.com/pedrobtz/zutempo/issues>

## Author

**Maintainer**: Pedro Baltazar <pedrobtz@gmail.com> \[copyright holder\]

Authors:

- Pedro Baltazar <pedrobtz@gmail.com> \[copyright holder\]
