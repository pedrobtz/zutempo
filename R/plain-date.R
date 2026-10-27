#' Calendar dates: Temporal's PlainDate
#'
#' A `plain_date()` is a calendar date in the ISO 8601 calendar with no
#' time of day and no time zone, stored as an integer count of days since
#' 1970-01-01. The constructor is `Temporal.PlainDate` and
#' `Temporal.PlainDate.from()` in one: it reads fields, strings or another
#' zutempo value.
#'
#' Dates run from -271821-04-19 to +275760-09-13. A result outside that
#' range is a `zutempo_range_error`, never `NA`.
#'
#' @param year The year, or a string in ISO 8601 form (`"2026-01-31"`, a
#'   date-time whose time is ignored, or a year with a sign and six digits
#'   such as `"+275760-09-13"`), or a `plain_date()`, `plain_date_time()`,
#'   `zoned_date_time()`, `Date`, `POSIXct` or `POSIXlt` value to convert. A
#'   zoned or `POSIXt` value gives its date in its own zone.
#' @param month,day The month (1 to 12) and day of the month, when `year`
#'   is a number. `month` may be replaced by `month_code`.
#' @param ... Must be empty.
#' @param month_code The month as `"M01"` to `"M12"`, instead of `month`.
#' @param overflow `"constrain"` (the default) clamps `month` and `day` to
#'   their valid ranges, `"reject"` raises a `zutempo_range_error` for
#'   them.
#' @param x,y `plain_date()` values or strings, for `plain_date_compare()`.
#' @return A `plain_date()` vector; `plain_date_compare()` returns an
#'   integer vector of -1, 0 and 1.
#' @examples
#' plain_date("2026-01-31")
#' plain_date(2026, 2, 31)
#' plain_date(2026, month_code = "M02", day = 29, overflow = "constrain")
#' plain_date(c("2026-01-31", NA, "+275760-09-13"))
#' plain_date_compare(plain_date("2026-01-31"), "2026-02-01")
#' @eval ztp_doc_members("PlainDate")
#' @export
plain_date <- function(
  year,
  month = NULL,
  day = NULL,
  ...,
  month_code = NULL,
  overflow = "constrain"
) {
  ztp_check_dots_empty(...)
  ov <- ztp_overflow_code(overflow)
  if (missing(year)) {
    stop_zutempo("`year` is required", kind = "type")
  }
  if (inherits(year, "zutempo_plain_date")) {
    ztp_check_no_fields(month, day, month_code)
    return(year)
  }
  if (inherits(year, "zutempo_plain_date_time")) {
    ztp_check_no_fields(month, day, month_code)
    return(new_plain_date(ztp_date_time_days(year)))
  }
  # ToTemporalDate reads a zoned value's date in its zone.
  if (inherits(year, "zutempo_zoned_date_time")) {
    ztp_check_no_fields(month, day, month_code)
    return(temporal_to_plain_date(year))
  }
  if (is.character(year)) {
    ztp_check_no_fields(month, day, month_code)
    return(new_plain_date(.Call(C_ztp_r_plain_date_parse, year)))
  }
  if (inherits(year, "Date")) {
    ztp_check_no_fields(month, day, month_code)
    return(ztp_plain_date_from_date(year))
  }
  if (inherits(year, "POSIXt")) {
    ztp_check_no_fields(month, day, month_code)
    return(temporal_to_plain_date(zoned_date_time(year)))
  }
  if (!ztp_is_field_like(year)) {
    stop_zutempo(
      sprintf(
        "cannot make a plain_date from an object of class %s",
        class(year)[1L]
      ),
      kind = "type"
    )
  }
  fields <- ztp_date_fields(year, month, day, month_code)
  new_plain_date(.Call(
    C_ztp_r_plain_date_from_fields,
    fields[["year"]],
    fields[["month"]],
    fields[["day"]],
    ov
  ))
}

ztp_check_no_fields <- function(month, day, month_code) {
  if (!is.null(month) || !is.null(day) || !is.null(month_code)) {
    stop_zutempo(
      "`month`, `day` and `month_code` apply only when `year` is a number",
      kind = "type"
    )
  }
}

# PrepareCalendarFields and CalendarResolveFields for the ISO calendar:
# year and day are required, month or month_code is required, and both
# month and month_code must agree when given. Returns recycled doubles.
ztp_date_fields <- function(year, month, day, month_code) {
  year <- ztp_as_field(year, "year")
  month <- ztp_as_field(month, "month")
  day <- ztp_as_field(day, "day")
  if (is.null(day)) {
    stop_zutempo("`day` is required", kind = "type")
  }
  if (is.null(month) && is.null(month_code)) {
    stop_zutempo("one of `month` and `month_code` is required", kind = "type")
  }
  if (!is.null(month_code)) {
    from_code <- ztp_month_from_code(month_code)
    if (!is.null(month)) {
      both <- ztp_recycle(list(month, from_code))
      disagree <- which(
        !is.na(both[[1L]]) & !is.na(both[[2L]]) & both[[1L]] != both[[2L]]
      )
      if (length(disagree)) {
        stop_zutempo(
          "`month` and `month_code` disagree",
          kind = "range",
          index = disagree[1L]
        )
      }
      month <- ifelse(is.na(both[[1L]]), both[[2L]], both[[1L]])
    } else {
      month <- from_code
    }
  }
  ztp_recycle(list(year = year, month = month, day = day))
}

ztp_date_time_days <- function(x) {
  z <- unclass(x)
  out <- as.integer(Re(z))
  out[is.na(z)] <- NA_integer_
  out
}

ztp_date_time_ns <- function(x) {
  z <- unclass(x)
  out <- Im(z)
  out[is.na(z)] <- NA_real_
  out
}

# The ztp_as_<type>() helpers take a value of the class as is and pass
# anything else to the constructor, as compare() and equals() do.
ztp_as_plain_date <- function(x) {
  if (inherits(x, "zutempo_plain_date")) x else plain_date(x)
}

#' @rdname plain_date
#' @export
plain_date_compare <- function(x, y) {
  args <- ztp_recycle(list(
    unclass(ztp_as_plain_date(x)),
    unclass(ztp_as_plain_date(y))
  ))
  as.integer(sign(args[[1L]] - args[[2L]]))
}

#' @rdname temporal_with
#' @export
temporal_with.zutempo_plain_date <- function(x, ..., overflow = "constrain") {
  fields <- ztp_partial_fields(
    list(...),
    c("year", "month", "month_code", "day")
  )
  ov <- ztp_overflow_code(overflow)
  current <- list(
    year = as.double(ztp_date_field(x, "year")),
    month = as.double(ztp_date_field(x, "month")),
    day = as.double(ztp_date_field(x, "day"))
  )
  merged <- ztp_merge_date_fields(current, fields)
  new_plain_date(.Call(
    C_ztp_r_plain_date_from_fields,
    merged[["year"]],
    merged[["month"]],
    merged[["day"]],
    ov
  ))
}

# CalendarMergeFields then CalendarResolveFields for the ISO calendar.
ztp_merge_date_fields <- function(current, fields) {
  year <- if (!is.null(fields[["year"]])) {
    ztp_as_field(fields[["year"]], "year")
  } else {
    current[["year"]]
  }
  day <- if (!is.null(fields[["day"]])) {
    ztp_as_field(fields[["day"]], "day")
  } else {
    current[["day"]]
  }
  if (is.null(fields[["month"]]) && is.null(fields[["month_code"]])) {
    return(ztp_recycle(list(
      year = year,
      month = current[["month"]],
      day = day
    )))
  }
  ztp_date_fields(
    year,
    ztp_as_field(fields[["month"]], "month"),
    day,
    fields[["month_code"]]
  )
}

#' @rdname temporal_with
#' @export
temporal_with_calendar.zutempo_plain_date <- function(x, calendar) {
  ztp_check_calendar(calendar)
  x
}

#' @rdname temporal_to_plain_date
#' @export
temporal_to_plain_date_time.zutempo_plain_date <- function(x, time = NULL) {
  ns <- ztp_time_or_midnight(time)
  args <- ztp_recycle(list(unclass(x), ns))
  new_plain_date_time(.Call(
    C_ztp_r_plain_date_time_combine,
    args[[1L]],
    args[[2L]]
  ))
}

# ToTimeRecordOrMidnight: NULL is midnight; anything else goes through
# plain_time().
ztp_time_or_midnight <- function(time) {
  if (is.null(time)) {
    return(0)
  }
  unclass(plain_time(time))
}

#' @rdname temporal_to_plain_date
#' @export
temporal_to_plain_year_month.zutempo_plain_date <- function(x) {
  ztp_year_month_from_fields(
    as.double(year(x)),
    as.double(month(x)),
    ztp_overflow_constrain
  )
}

#' @rdname temporal_to_plain_date
#' @export
temporal_to_plain_month_day.zutempo_plain_date <- function(x) {
  ztp_month_day_from_fields(
    as.double(year(x)),
    as.double(month(x)),
    as.double(day(x)),
    ztp_overflow_constrain
  )
}

#' @rdname temporal_equals
#' @export
temporal_equals.zutempo_plain_date <- function(x, other) {
  plain_date_compare(x, other) == 0L
}

#' @rdname temporal_to_string
#' @export
temporal_to_string.zutempo_plain_date <- function(
  x,
  ...,
  calendar_name = "auto"
) {
  ztp_check_dots_empty(...)
  show <- ztp_show_calendar_code(calendar_name)
  .Call(C_ztp_r_plain_date_format, unclass(x), show)
}
