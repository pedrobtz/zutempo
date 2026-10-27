# Options shared by zutempo's functions

Temporal passes options in an object, `{ overflow: "reject" }`; zutempo
takes them as named arguments, `overflow = "reject"` (design 6.9). Each
function's help says which it takes and its default; this page says what
each one means.

## Details

An option that is not a single string, or a string the option does not
know, is a `zutempo_type_error`. A value of the right kind that fails a
range check, such as an increment that does not divide its unit, is a
`zutempo_range_error` (design 10). Either condition has a field `option`
naming the option, as does the error for a required option left out
(`smallest_unit` of
[`temporal_round()`](https://pedrobtz.github.io/zutempo/reference/temporal_round.md)).
An `NA` option is an error, not a missing result (design 6.8).

## `overflow`

What to do with a field out of its range, such as 31 February:
`"constrain"` (the default) moves it to the nearest valid value,
`"reject"` raises a `zutempo_range_error`.

## `disambiguation`

What to do with a wall-clock time that a time zone skips (a gap, when
clocks go forward) or repeats (a fold, when they go back):

- `"compatible"` (the default): the later time in a gap, the earlier in
  a fold, as most other software does;

- `"earlier"` and `"later"`: the earlier or later of the two candidates;

- `"reject"`: a `zutempo_range_error`.

## `offset`

When a string or fields give both a UTC offset and a zone, what to do if
they disagree, as when a zone's rules changed after the string was
written:

- `"reject"` (the default for
  [`zoned_date_time()`](https://pedrobtz.github.io/zutempo/reference/zoned_date_time.md)):
  a `zutempo_range_error`;

- `"use"`: the offset decides the exact time;

- `"ignore"`: the zone decides, as if no offset were given;

- `"prefer"`: the offset when it is one the zone allows at that wall
  time, otherwise the zone.

In
[`temporal_to_string()`](https://pedrobtz.github.io/zutempo/reference/temporal_to_string.md),
`offset` is instead whether to write the offset: `"auto"` or `"never"`.

## Rounding

`smallest_unit` is the unit to round to and `largest_unit` the largest
unit of a result: `"year"`, `"month"`, `"week"`, `"day"`, `"hour"`,
`"minute"`, `"second"`, `"millisecond"`, `"microsecond"` or
`"nanosecond"`, singular or plural. `rounding_increment` rounds to a
multiple of `smallest_unit`, and must divide the next larger unit for
the time units. `rounding_mode` is one of Temporal's nine modes:

|                |                                                |
|----------------|------------------------------------------------|
| Mode           | Rounds                                         |
| `"ceil"`       | towards positive infinity                      |
| `"floor"`      | towards negative infinity                      |
| `"expand"`     | away from zero                                 |
| `"trunc"`      | towards zero                                   |
| `"halfCeil"`   | to the nearest, ties towards positive infinity |
| `"halfFloor"`  | to the nearest, ties towards negative infinity |
| `"halfExpand"` | to the nearest, ties away from zero            |
| `"halfTrunc"`  | to the nearest, ties towards zero              |
| `"halfEven"`   | to the nearest, ties to the even multiple      |

## `relative_to`

Years, months and weeks have no fixed length, and neither does a day in
a zone with clock changes. Arithmetic on a
[`duration()`](https://pedrobtz.github.io/zutempo/reference/duration.md)
that has them takes `relative_to`: a
[`plain_date()`](https://pedrobtz.github.io/zutempo/reference/plain_date.md),
a
[`plain_date_time()`](https://pedrobtz.github.io/zutempo/reference/plain_date_time.md),
a
[`zoned_date_time()`](https://pedrobtz.github.io/zutempo/reference/zoned_date_time.md),
or a string that reads as one (a string with a time zone annotation is
zoned). With a zoned value, days follow the zone's clock changes; with a
plain one, a day is 24 hours.

## See also

[`temporal_round()`](https://pedrobtz.github.io/zutempo/reference/temporal_round.md),
[`temporal_until()`](https://pedrobtz.github.io/zutempo/reference/temporal_until.md),
[`temporal_add()`](https://pedrobtz.github.io/zutempo/reference/temporal_add.md),
[`zoned_date_time()`](https://pedrobtz.github.io/zutempo/reference/zoned_date_time.md)
and
[`temporal_to_string()`](https://pedrobtz.github.io/zutempo/reference/temporal_to_string.md),
which take these options.

## Examples

``` r
temporal_add(plain_date("2026-01-31"), "P1M")
#> <zutempo_plain_date[1]>
#> [1] 2026-02-28
try(temporal_add(plain_date("2026-01-31"), "P1M", overflow = "reject"))
#> Error : 2026-02-31 is not a valid date (element 1)

# 01:30 does not exist in Lisbon on 29 March 2026.
temporal_to_zoned_date_time(
  plain_date_time("2026-03-29T01:30"),
  "Europe/Lisbon",
  disambiguation = "earlier"
)
#> <zutempo_zoned_date_time[1]>
#> [1] 2026-03-29T00:30:00+00:00[Europe/Lisbon]

temporal_round(plain_time("12:30:45.5"), "second", rounding_mode = "halfEven")
#> <zutempo_plain_time[1]>
#> [1] 12:30:46
```
