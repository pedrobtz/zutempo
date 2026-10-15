# Fields of a Temporal value

One accessor per Temporal property, named after it in snake case (design
5). Each is an S3 generic with methods for the zutempo classes and a
default that calls the function of the same name from another attached
package, so that `lubridate::year()` and the others keep working on
their own objects after zutempo is attached.

## Usage

``` r
calendar_id(x, ...)

# Default S3 method
calendar_id(x, ...)

# S3 method for class 'zutempo_plain_date'
calendar_id(x, ...)

# S3 method for class 'zutempo_plain_date_time'
calendar_id(x, ...)

era(x, ...)

# Default S3 method
era(x, ...)

# S3 method for class 'zutempo_plain_date'
era(x, ...)

# S3 method for class 'zutempo_plain_date_time'
era(x, ...)

era_year(x, ...)

# Default S3 method
era_year(x, ...)

# S3 method for class 'zutempo_plain_date'
era_year(x, ...)

# S3 method for class 'zutempo_plain_date_time'
era_year(x, ...)

year(x, ...)

# Default S3 method
year(x, ...)

# S3 method for class 'zutempo_plain_date'
year(x, ...)

# S3 method for class 'zutempo_plain_date_time'
year(x, ...)

month(x, ...)

# Default S3 method
month(x, ...)

# S3 method for class 'zutempo_plain_date'
month(x, ...)

# S3 method for class 'zutempo_plain_date_time'
month(x, ...)

month_code(x, ...)

# Default S3 method
month_code(x, ...)

# S3 method for class 'zutempo_plain_date'
month_code(x, ...)

# S3 method for class 'zutempo_plain_date_time'
month_code(x, ...)

day(x, ...)

# Default S3 method
day(x, ...)

# S3 method for class 'zutempo_plain_date'
day(x, ...)

# S3 method for class 'zutempo_plain_date_time'
day(x, ...)

day_of_week(x, ...)

# Default S3 method
day_of_week(x, ...)

# S3 method for class 'zutempo_plain_date'
day_of_week(x, ...)

# S3 method for class 'zutempo_plain_date_time'
day_of_week(x, ...)

day_of_year(x, ...)

# Default S3 method
day_of_year(x, ...)

# S3 method for class 'zutempo_plain_date'
day_of_year(x, ...)

# S3 method for class 'zutempo_plain_date_time'
day_of_year(x, ...)

week_of_year(x, ...)

# Default S3 method
week_of_year(x, ...)

# S3 method for class 'zutempo_plain_date'
week_of_year(x, ...)

# S3 method for class 'zutempo_plain_date_time'
week_of_year(x, ...)

year_of_week(x, ...)

# Default S3 method
year_of_week(x, ...)

# S3 method for class 'zutempo_plain_date'
year_of_week(x, ...)

# S3 method for class 'zutempo_plain_date_time'
year_of_week(x, ...)

days_in_week(x, ...)

# Default S3 method
days_in_week(x, ...)

# S3 method for class 'zutempo_plain_date'
days_in_week(x, ...)

# S3 method for class 'zutempo_plain_date_time'
days_in_week(x, ...)

days_in_month(x, ...)

# Default S3 method
days_in_month(x, ...)

# S3 method for class 'zutempo_plain_date'
days_in_month(x, ...)

# S3 method for class 'zutempo_plain_date_time'
days_in_month(x, ...)

days_in_year(x, ...)

# Default S3 method
days_in_year(x, ...)

# S3 method for class 'zutempo_plain_date'
days_in_year(x, ...)

# S3 method for class 'zutempo_plain_date_time'
days_in_year(x, ...)

months_in_year(x, ...)

# Default S3 method
months_in_year(x, ...)

# S3 method for class 'zutempo_plain_date'
months_in_year(x, ...)

# S3 method for class 'zutempo_plain_date_time'
months_in_year(x, ...)

in_leap_year(x, ...)

# Default S3 method
in_leap_year(x, ...)

# S3 method for class 'zutempo_plain_date'
in_leap_year(x, ...)

# S3 method for class 'zutempo_plain_date_time'
in_leap_year(x, ...)

hour(x, ...)

# Default S3 method
hour(x, ...)

# S3 method for class 'zutempo_plain_time'
hour(x, ...)

# S3 method for class 'zutempo_plain_date_time'
hour(x, ...)

minute(x, ...)

# Default S3 method
minute(x, ...)

# S3 method for class 'zutempo_plain_time'
minute(x, ...)

# S3 method for class 'zutempo_plain_date_time'
minute(x, ...)

second(x, ...)

# Default S3 method
second(x, ...)

# S3 method for class 'zutempo_plain_time'
second(x, ...)

# S3 method for class 'zutempo_plain_date_time'
second(x, ...)

millisecond(x, ...)

# Default S3 method
millisecond(x, ...)

# S3 method for class 'zutempo_plain_time'
millisecond(x, ...)

# S3 method for class 'zutempo_plain_date_time'
millisecond(x, ...)

microsecond(x, ...)

# Default S3 method
microsecond(x, ...)

# S3 method for class 'zutempo_plain_time'
microsecond(x, ...)

# S3 method for class 'zutempo_plain_date_time'
microsecond(x, ...)

nanosecond(x, ...)

# Default S3 method
nanosecond(x, ...)

# S3 method for class 'zutempo_plain_time'
nanosecond(x, ...)

# S3 method for class 'zutempo_plain_date_time'
nanosecond(x, ...)
```

## Arguments

- x:

  A zutempo value.

- ...:

  Passed on by the default method to the function it masks.

## Value

An integer vector, or a character vector for `calendar_id()`, `era()`
and `month_code()`, or a logical vector for `in_leap_year()`, with `NA`
where `x` is `NA`.

## Fields

- `calendar_id()`: `calendarId`, the calendar identifier, always
  "iso8601".

- `era()`: `era`, the era, `NA` in the ISO 8601 calendar.

- `era_year()`: `eraYear`, the year within the era, `NA` in the ISO 8601
  calendar.

- `year()`: `year`, the year.

- `month()`: `month`, the month, 1 to 12.

- `month_code()`: `monthCode`, the month code, `"M01"` to `"M12"`.

- `day()`: `day`, the day of the month.

- `day_of_week()`: `dayOfWeek`, the day of the week, 1 (Monday) to 7
  (Sunday).

- `day_of_year()`: `dayOfYear`, the day of the year, from 1.

- `week_of_year()`: `weekOfYear`, the ISO week number, 1 to 53.

- `year_of_week()`: `yearOfWeek`, the year the ISO week belongs to.

- `days_in_week()`: `daysInWeek`, always 7.

- `days_in_month()`: `daysInMonth`, 28 to 31.

- `days_in_year()`: `daysInYear`, 365 or 366.

- `months_in_year()`: `monthsInYear`, always 12.

- `in_leap_year()`: `inLeapYear`, whether the year is a leap year.

- `hour()`: `hour`, 0 to 23.

- `minute()`: `minute`, 0 to 59.

- `second()`: `second`, 0 to 59.

- `millisecond()`: `millisecond`, 0 to 999.

- `microsecond()`: `microsecond`, 0 to 999.

- `nanosecond()`: `nanosecond`, 0 to 999.

## Examples

``` r
x <- plain_date("2026-01-31")
year(x)
#> [1] 2026
day_of_week(x)
#> [1] 6
month_code(x)
#> [1] "M01"
hour(plain_time("12:30:45.5"))
#> [1] 12
```
