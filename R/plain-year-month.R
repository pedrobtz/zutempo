#' Months: Temporal's PlainYearMonth
#'
#' A `plain_year_month()` is a month of a year in the ISO 8601 calendar,
#' stored as an integer count of months since January 1970 (design 4.1).
#' The constructor is `Temporal.PlainYearMonth` and
#' `Temporal.PlainYearMonth.from()` in one: it reads fields, strings or a
#' `plain_date()` or `plain_date_time()`.
#'
#' Months run from -271821-04 to +275760-09, every month that holds a
#' representable `plain_date()`.
#'
#' @param year The year, or a string in ISO 8601 form (`"2026-03"`,
#'   `"202603"`, or a full date or date-time whose day and time are
#'   ignored), or a `plain_year_month()`, `plain_date()` or
#'   `plain_date_time()` to convert.
#' @param month The month (1 to 12), when `year` is a number. May be
#'   replaced by `month_code`.
#' @param ... Must be empty.
#' @param month_code The month as `"M01"` to `"M12"`, instead of `month`.
#' @param overflow `"constrain"` (the default) clamps `month` to 1 to 12,
#'   `"reject"` raises a `zutempo_range_error` (design 6.2).
#' @param x,y `plain_year_month()` values or strings, for
#'   `plain_year_month_compare()`.
#' @return A `plain_year_month()` vector; `plain_year_month_compare()`
#'   returns an integer vector of -1, 0 and 1.
#' @examples
#' plain_year_month("2026-03")
#' plain_year_month(2026, 3)
#' plain_year_month(plain_date("2026-03-15"))
#' temporal_to_plain_date(plain_year_month("2026-02"), day = 31)
#' plain_year_month_compare("2026-02", "2026-03")
#' @export
plain_year_month <- function(
  year,
  month = NULL,
  ...,
  month_code = NULL,
  overflow = "constrain"
) {
  ztp_check_dots_empty(...)
  ov <- ztp_overflow_code(overflow)
  if (missing(year)) {
    stop_zutempo("`year` is required", kind = "type")
  }
  if (inherits(year, "zutempo_plain_year_month")) {
    ztp_check_no_fields(month, NULL, month_code)
    return(year)
  }
  if (inherits(year, c("zutempo_plain_date", "zutempo_plain_date_time"))) {
    ztp_check_no_fields(month, NULL, month_code)
    return(ztp_year_month_from_fields(
      as.double(year(year)),
      as.double(month(year)),
      ov
    ))
  }
  if (is.character(year)) {
    ztp_check_no_fields(month, NULL, month_code)
    return(new_plain_year_month(.Call(C_ztp_r_plain_year_month_parse, year)))
  }
  if (!ztp_is_field_like(year)) {
    stop_zutempo(
      sprintf(
        "cannot make a plain_year_month from an object of class %s",
        class(year)[1L]
      ),
      kind = "type"
    )
  }
  fields <- ztp_year_month_fields(year, month, month_code)
  ztp_year_month_from_fields(fields$year, fields$month, ov)
}

ztp_year_month_from_fields <- function(year, month, ov) {
  new_plain_year_month(.Call(
    C_ztp_r_plain_year_month_from_fields,
    year,
    month,
    ov
  ))
}

# CalendarResolveFields for ~year-month~: year and month or month_code.
ztp_year_month_fields <- function(year, month, month_code) {
  fields <- ztp_date_fields(year, month, 1, month_code)
  fields["day"] <- NULL
  fields
}

ztp_as_plain_year_month <- function(x) {
  if (inherits(x, "zutempo_plain_year_month")) x else plain_year_month(x)
}

#' @rdname plain_year_month
#' @export
plain_year_month_compare <- function(x, y) {
  args <- ztp_recycle(list(
    unclass(ztp_as_plain_year_month(x)),
    unclass(ztp_as_plain_year_month(y))
  ))
  as.integer(sign(args[[1L]] - args[[2L]]))
}

#' @rdname temporal_with
#' @export
temporal_with.zutempo_plain_year_month <- function(
  x,
  ...,
  overflow = "constrain"
) {
  fields <- ztp_partial_fields(list(...), c("year", "month", "month_code"))
  ov <- ztp_overflow_code(overflow)
  base <- list(
    year = as.double(year(x)),
    month = as.double(month(x)),
    day = 1
  )
  merged <- ztp_merge_date_fields(base, fields)
  ztp_year_month_from_fields(merged$year, merged$month, ov)
}

#' @rdname temporal_to_plain_date
#' @export
temporal_to_plain_date.zutempo_plain_year_month <- function(x, day, ...) {
  ztp_check_dots_empty(...)
  if (missing(day) || is.null(day)) {
    stop_zutempo("`day` is required", kind = "type")
  }
  day <- ztp_as_field(day, "day")
  args <- ztp_recycle(list(as.double(year(x)), as.double(month(x)), day))
  new_plain_date(.Call(
    C_ztp_r_plain_date_from_fields,
    args[[1L]],
    args[[2L]],
    args[[3L]],
    0L
  ))
}

#' @rdname temporal_equals
#' @export
temporal_equals.zutempo_plain_year_month <- function(x, other) {
  plain_year_month_compare(x, other) == 0L
}

#' @rdname temporal_to_string
#' @export
temporal_to_string.zutempo_plain_year_month <- function(x, ...) {
  ztp_check_dots_empty(...)
  .Call(C_ztp_r_plain_year_month_format, unclass(x), 0L)
}
