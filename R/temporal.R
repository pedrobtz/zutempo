# The prototype methods of Temporal as S3 generics named `temporal_<method>`
# (design 5). Each type adds its methods in its own file.

#' Replace fields of a Temporal value
#'
#' `temporal_with()` is Temporal's `with()`: it returns a copy of `x` with
#' the named fields replaced and the rest kept, resolving the result with
#' `overflow`. `temporal_with_plain_time()` is `withPlainTime()`, and
#' `temporal_with_calendar()` is `withCalendar()`, which accepts only
#' `"iso8601"` in this version (design D7).
#'
#' @param x A zutempo value.
#' @param ... Fields to replace, named: `year`, `month`, `month_code`,
#'   `day`, `hour`, `minute`, `second`, `millisecond`, `microsecond`,
#'   `nanosecond`, as the type allows. At least one is required. Giving
#'   `month` or `month_code` discards the other from `x`; giving both
#'   requires them to agree.
#' @param overflow `"constrain"` (the default) clamps out-of-range fields,
#'   `"reject"` raises a `zutempo_range_error` for them (design 6.2).
#' @param time A `plain_time()`, a string a `plain_time()` reads, or `NULL`
#'   for midnight.
#' @param calendar A calendar identifier; only `"iso8601"` is supported.
#' @return A value of the same class as `x`.
#' @examples
#' temporal_with(plain_date("2026-01-31"), month = 2)
#' try(temporal_with(plain_date("2026-01-31"), month = 2, overflow = "reject"))
#' temporal_with_plain_time(plain_date_time("2026-01-31T12:00"), "08:30")
#' @order 1
#' @export
temporal_with <- function(x, ..., overflow = "constrain") {
  UseMethod("temporal_with")
}

#' @rdname temporal_with
#' @export
temporal_with_plain_time <- function(x, time = NULL) {
  UseMethod("temporal_with_plain_time")
}

#' @rdname temporal_with
#' @export
temporal_with_calendar <- function(x, calendar) {
  UseMethod("temporal_with_calendar")
}

#' Convert between the plain types
#'
#' Temporal's `toPlainDate()`, `toPlainTime()`, `toPlainDateTime()`,
#' `toPlainYearMonth()` and `toPlainMonthDay()`. A `plain_year_month()`
#' needs the `day` and a `plain_month_day()` the `year` to become a date;
#' both resolve it with `overflow = "constrain"`, as Temporal does.
#'
#' @param x A zutempo value.
#' @param ... Must be empty.
#' @param time For `temporal_to_plain_date_time()` on a `plain_date()`: a
#'   `plain_time()`, a string a `plain_time()` reads, or `NULL` for
#'   midnight.
#' @param day The day of the month that completes a `plain_year_month()`.
#' @param year The year that completes a `plain_month_day()`.
#' @return A `plain_date()`, `plain_time()`, `plain_date_time()`,
#'   `plain_year_month()` or `plain_month_day()`.
#' @examples
#' x <- plain_date_time("2026-01-31T12:30:45")
#' temporal_to_plain_date(x)
#' temporal_to_plain_time(x)
#' temporal_to_plain_date_time(plain_date("2026-01-31"), "08:00")
#' temporal_to_plain_year_month(plain_date("2026-01-31"))
#' temporal_to_plain_month_day(plain_date("2026-01-31"))
#' temporal_to_plain_date(plain_year_month("2026-02"), day = 31)
#' temporal_to_plain_date(plain_month_day("02-29"), year = 2025)
#' @order 1
#' @export
temporal_to_plain_date <- function(x, ...) {
  UseMethod("temporal_to_plain_date")
}

#' @rdname temporal_to_plain_date
#' @export
temporal_to_plain_time <- function(x) {
  UseMethod("temporal_to_plain_time")
}

#' @rdname temporal_to_plain_date
#' @export
temporal_to_plain_date_time <- function(x, time = NULL) {
  UseMethod("temporal_to_plain_date_time")
}

#' @rdname temporal_to_plain_date
#' @export
temporal_to_plain_year_month <- function(x) {
  UseMethod("temporal_to_plain_year_month")
}

#' @rdname temporal_to_plain_date
#' @export
temporal_to_plain_month_day <- function(x) {
  UseMethod("temporal_to_plain_month_day")
}

#' Compare Temporal values
#'
#' `temporal_equals()` is Temporal's `equals()`. The `*_compare()`
#' functions are the `compare()` statics: they return -1, 0 or 1 as the
#' first value comes before, at or after the second. All recycle their
#' arguments and propagate `NA`.
#'
#' @param x,other Values of one zutempo class, or strings that its
#'   constructor reads.
#' @return A logical vector for `temporal_equals()`, an integer vector for
#'   the comparisons.
#' @examples
#' temporal_equals(plain_date("2026-01-31"), "2026-01-31")
#' plain_date_compare(plain_date("2026-01-31"), plain_date("2026-02-01"))
#' plain_time_compare("12:30", "12:30")
#' @order 1
#' @export
temporal_equals <- function(x, other) {
  UseMethod("temporal_equals")
}

#' Round a Temporal value
#'
#' Temporal's `round()`, to an increment of `smallest_unit` with one of the
#' nine rounding modes (design 6.4). `plain_time()` rounds within the day;
#' `plain_date_time()` carries into the date and also accepts `"day"`.
#'
#' @param x A zutempo value.
#' @param smallest_unit The unit to round to: `"hour"`, `"minute"`,
#'   `"second"`, `"millisecond"`, `"microsecond"` or `"nanosecond"`, or
#'   their plurals; `"day"` for a `plain_date_time()`; any unit for a
#'   `duration()`, which may instead give only `largest_unit`.
#' @param ... Must be empty, except for a `duration()`'s `largest_unit`
#'   and `relative_to`.
#' @param largest_unit For a `duration()`: the unit to balance up to,
#'   `"auto"` or `NULL` for the duration's own largest unit.
#' @param relative_to For a `duration()`: a `plain_date()`,
#'   `plain_date_time()` or a string either reads, required to round years,
#'   months or weeks (design 6.5).
#' @param rounding_increment A positive integer that divides the next
#'   larger unit evenly: 24 hours, 60 minutes or seconds, 1000 of the
#'   sub-second units, and 1 for `"day"`.
#' @param rounding_mode One of `"ceil"`, `"floor"`, `"expand"`, `"trunc"`,
#'   `"halfCeil"`, `"halfFloor"`, `"halfExpand"` (the default),
#'   `"halfTrunc"` or `"halfEven"`.
#' @return A value of the same class as `x`.
#' @examples
#' temporal_round(plain_time("12:34:56"), "minute")
#' temporal_round(plain_time("12:34:56"), "hour", rounding_mode = "floor")
#' temporal_round(plain_date_time("2026-01-31T23:59"), "hour")
#' temporal_round(duration(hours = 25), largest_unit = "day")
#' temporal_round(duration(hours = 25), largest_unit = "day", relative_to = "2026-03-07")
#' @order 1
#' @export
temporal_round <- function(
  x,
  smallest_unit = NULL,
  rounding_increment = 1,
  rounding_mode = "halfExpand",
  ...
) {
  UseMethod("temporal_round")
}

#' Format a Temporal value as an ISO 8601 string
#'
#' Temporal's `toString()` with its default options; `format()` and
#' `as.character()` give the same strings. Years outside 0 to 9999 are
#' written with a sign and six digits, and a time's fraction keeps only its
#' significant digits.
#'
#' @param x A zutempo value.
#' @param ... Must be empty, except for an `instant()`'s `time_zone`.
#' @param time_zone For an `instant()`: `"UTC"` or a fixed offset such as
#'   `"+05:30"` to show the time in; `NULL` (the default) writes the time
#'   in UTC with `Z`. Named zones arrive with the time zone database.
#' @return A character vector, `NA` where `x` is `NA`.
#' @examples
#' temporal_to_string(plain_date(c(2026, 275760), c(1, 9), c(31, 13)))
#' temporal_to_string(instant("2026-01-31T12:30Z"), time_zone = "+05:30")
#' temporal_to_string(plain_time(12, 30, 45, 500))
#' @order 1
#' @export
temporal_to_string <- function(x, ...) {
  UseMethod("temporal_to_string")
}
