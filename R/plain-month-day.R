#' Days of the year: Temporal's PlainMonthDay
#'
#' A `plain_month_day()` is a month and day with no year, such as a
#' birthday, in the ISO 8601 calendar, stored as an integer
#' `month * 32 + day`. Temporal keeps the day valid in a
#' reference year, 1972, so February 29 is a `plain_month_day()`. The
#' constructor is `Temporal.PlainMonthDay` and
#' `Temporal.PlainMonthDay.from()` in one: it reads fields, strings or a
#' `plain_date()` or `plain_date_time()`.
#'
#' @param month The month (1 to 12), or a string in ISO 8601 form
#'   (`"03-14"`, `"--03-14"`, `"0314"`, or a full date or date-time whose
#'   year and time are ignored), or a `plain_month_day()`, `plain_date()`
#'   or `plain_date_time()` to convert. May be replaced by `month_code`.
#' @param day The day of the month, when `month` is a number.
#' @param ... Must be empty.
#' @param month_code The month as `"M01"` to `"M12"`, instead of `month`.
#' @param year A year in which the day must exist; without it the reference
#'   year 1972, a leap year, is used.
#' @param overflow `"constrain"` (the default) clamps `month` and `day`,
#'   `"reject"` raises a `zutempo_range_error`.
#' @return A `plain_month_day()` vector.
#' @examples
#' plain_month_day("02-29")
#' plain_month_day(2, 29, year = 2025)
#' plain_month_day(plain_date("2026-03-14"))
#' temporal_to_plain_date(plain_month_day("02-29"), year = 2025)
#' @eval ztp_doc_members("PlainMonthDay")
#' @export
plain_month_day <- function(
  month,
  day = NULL,
  ...,
  month_code = NULL,
  year = NULL,
  overflow = "constrain"
) {
  ztp_check_dots_empty(...)
  ov <- ztp_overflow_code(overflow)
  if (missing(month) && is.null(month_code)) {
    stop_zutempo("`month` or `month_code` is required", kind = "type")
  }
  if (missing(month)) {
    month <- NULL
  }
  if (inherits(month, "zutempo_plain_month_day")) {
    ztp_check_no_month_day_fields(day, month_code, year)
    return(month)
  }
  if (inherits(month, c("zutempo_plain_date", "zutempo_plain_date_time"))) {
    ztp_check_no_month_day_fields(day, month_code, year)
    return(ztp_month_day_from_fields(
      as.double(year(month)),
      as.double(month(month)),
      as.double(day(month)),
      ov
    ))
  }
  if (is.character(month)) {
    ztp_check_no_month_day_fields(day, month_code, year)
    return(new_plain_month_day(.Call(C_ztp_r_plain_month_day_parse, month)))
  }
  if (!is.null(month) && !ztp_is_field_like(month)) {
    stop_zutempo(
      sprintf(
        "cannot make a plain_month_day from an object of class %s",
        class(month)[1L]
      ),
      kind = "type"
    )
  }
  fields <- ztp_month_day_fields(year, month, day, month_code)
  ztp_month_day_from_fields(
    fields[["year"]],
    fields[["month"]],
    fields[["day"]],
    ov
  )
}

ztp_check_no_month_day_fields <- function(day, month_code, year) {
  if (!is.null(day) || !is.null(month_code) || !is.null(year)) {
    stop_zutempo(
      "`day`, `month_code` and `year` apply only when `month` is a number",
      kind = "type"
    )
  }
}

# CalendarResolveFields for ~month-day~: day, and month or month_code;
# the year is optional and defaults to the reference year 1972.
ztp_month_day_fields <- function(year, month, day, month_code) {
  if (is.null(year)) {
    year <- 1972
  }
  ztp_date_fields(year, month, day, month_code)
}

ztp_month_day_from_fields <- function(year, month, day, ov) {
  new_plain_month_day(.Call(
    C_ztp_r_plain_month_day_from_fields,
    year,
    month,
    day,
    ov
  ))
}

ztp_month_day_month <- function(x) {
  unclass(x) %/% 32L
}

ztp_month_day_day <- function(x) {
  unclass(x) %% 32L
}

#' @rdname temporal_with
#' @export
temporal_with.zutempo_plain_month_day <- function(
  x,
  ...,
  overflow = "constrain"
) {
  fields <- ztp_partial_fields(
    list(...),
    c("year", "month", "month_code", "day")
  )
  ov <- ztp_overflow_code(overflow)
  current <- list(
    year = NULL,
    month = as.double(ztp_month_day_month(x)),
    day = as.double(ztp_month_day_day(x))
  )
  year <- if (is.null(fields[["year"]])) {
    1972
  } else {
    ztp_as_field(fields[["year"]], "year")
  }
  day <- if (is.null(fields[["day"]])) {
    current[["day"]]
  } else {
    ztp_as_field(fields[["day"]], "day")
  }
  if (!is.null(fields[["month"]]) || !is.null(fields[["month_code"]])) {
    merged <- ztp_date_fields(
      year,
      ztp_as_field(fields[["month"]], "month"),
      day,
      fields[["month_code"]]
    )
  } else {
    merged <- ztp_recycle(list(
      year = year,
      month = current[["month"]],
      day = day
    ))
  }
  ztp_month_day_from_fields(
    merged[["year"]],
    merged[["month"]],
    merged[["day"]],
    ov
  )
}

#' @rdname temporal_to_plain_date
#' @export
temporal_to_plain_date.zutempo_plain_month_day <- function(x, year, ...) {
  ztp_check_dots_empty(...)
  if (missing(year) || is.null(year)) {
    stop_zutempo("`year` is required", kind = "type")
  }
  year <- ztp_as_field(year, "year")
  args <- ztp_recycle(list(
    year,
    as.double(ztp_month_day_month(x)),
    as.double(ztp_month_day_day(x))
  ))
  new_plain_date(.Call(
    C_ztp_r_plain_date_from_fields,
    args[[1L]],
    args[[2L]],
    args[[3L]],
    ztp_overflow_constrain
  ))
}

ztp_as_plain_month_day <- function(x) {
  if (inherits(x, "zutempo_plain_month_day")) x else plain_month_day(x)
}

#' @rdname temporal_equals
#' @export
temporal_equals.zutempo_plain_month_day <- function(x, other) {
  args <- ztp_recycle(list(unclass(x), unclass(ztp_as_plain_month_day(other))))
  args[[1L]] == args[[2L]]
}

#' @rdname temporal_to_string
#' @export
temporal_to_string.zutempo_plain_month_day <- function(
  x,
  ...,
  calendar_name = "auto"
) {
  ztp_check_dots_empty(...)
  show <- ztp_show_calendar_code(calendar_name)
  .Call(C_ztp_r_plain_month_day_format, unclass(x), show)
}
