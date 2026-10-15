#' Calendar dates with clock times: Temporal's PlainDateTime
#'
#' A `plain_date_time()` is a calendar date in the ISO 8601 calendar with a
#' time of day to the nanosecond and no time zone, stored as a complex
#' vector whose real part is the epoch day and whose imaginary part is the
#' nanoseconds of day (design 4.1). The constructor is
#' `Temporal.PlainDateTime` and `Temporal.PlainDateTime.from()` in one: it
#' reads fields, strings or another zutempo value.
#'
#' Values may lie up to a day beyond the range of a `plain_date()`, from
#' just after -271821-04-19T00:00 to the end of +275760-09-13. A result
#' outside that range is a `zutempo_range_error`, never `NA`.
#'
#' @param year The year, or a string in ISO 8601 form
#'   (`"2026-01-31T12:30:45.5"`, a date alone for midnight, an offset is
#'   ignored and `Z` is rejected), or a `plain_date()` (for midnight) or
#'   `plain_date_time()` to convert.
#' @param month,day The month (1 to 12) and day of the month, when `year`
#'   is a number. `month` may be replaced by `month_code`.
#' @param hour,minute,second,millisecond,microsecond,nanosecond The time
#'   fields, 0 by default.
#' @param ... Must be empty.
#' @param month_code The month as `"M01"` to `"M12"`, instead of `month`.
#' @param overflow `"constrain"` (the default) clamps each field to its
#'   range, `"reject"` raises a `zutempo_range_error` (design 6.2).
#' @param x,y `plain_date_time()` values or strings, for
#'   `plain_date_time_compare()`.
#' @return A `plain_date_time()` vector; `plain_date_time_compare()`
#'   returns an integer vector of -1, 0 and 1.
#' @examples
#' plain_date_time("2026-01-31T12:30:45.5")
#' plain_date_time(2026, 1, 31, 12, 30)
#' plain_date_time(plain_date("2026-01-31"))
#' plain_date_time_compare("2026-01-31T12:30", "2026-01-31T12:31")
#' @export
plain_date_time <- function(
  year,
  month = NULL,
  day = NULL,
  hour = 0,
  minute = 0,
  second = 0,
  millisecond = 0,
  microsecond = 0,
  nanosecond = 0,
  ...,
  month_code = NULL,
  overflow = "constrain"
) {
  ztp_check_dots_empty(...)
  ov <- ztp_overflow_code(overflow)
  if (missing(year)) {
    stop_zutempo("`year` is required", kind = "type")
  }
  if (inherits(year, "zutempo_plain_date_time")) {
    ztp_check_no_fields(month, day, month_code)
    return(year)
  }
  if (inherits(year, "zutempo_plain_date")) {
    ztp_check_no_fields(month, day, month_code)
    return(temporal_to_plain_date_time(year))
  }
  if (is.character(year)) {
    ztp_check_no_fields(month, day, month_code)
    return(new_plain_date_time(.Call(C_ztp_r_plain_date_time_parse, year)))
  }
  if (!ztp_is_field_like(year)) {
    stop_zutempo(
      sprintf(
        "cannot make a plain_date_time from an object of class %s",
        class(year)[1L]
      ),
      kind = "type"
    )
  }
  date <- ztp_date_fields(year, month, day, month_code)
  time <- ztp_time_fields(
    hour,
    minute,
    second,
    millisecond,
    microsecond,
    nanosecond
  )
  fields <- ztp_recycle(c(date, time))
  new_plain_date_time(do.call(
    .Call,
    c(list(C_ztp_r_plain_date_time_from_fields), unname(fields), list(ov))
  ))
}

ztp_as_plain_date_time <- function(x) {
  if (inherits(x, "zutempo_plain_date_time")) x else plain_date_time(x)
}

#' @rdname plain_date_time
#' @export
plain_date_time_compare <- function(x, y) {
  args <- ztp_recycle(list(
    unclass(ztp_as_plain_date_time(x)),
    unclass(ztp_as_plain_date_time(y))
  ))
  a <- args[[1L]]
  b <- args[[2L]]
  out <- as.integer(sign(Re(a) - Re(b)))
  tie <- !is.na(out) & out == 0L
  out[tie] <- as.integer(sign(Im(a)[tie] - Im(b)[tie]))
  out
}

#' @rdname temporal_with
#' @export
temporal_with.zutempo_plain_date_time <- function(
  x,
  ...,
  overflow = "constrain"
) {
  fields <- ztp_partial_fields(
    list(...),
    c("year", "month", "month_code", "day", ztp_time_field_names)
  )
  ov <- ztp_overflow_code(overflow)
  base <- list(
    year = as.double(ztp_date_time_field(x, "year")),
    month = as.double(ztp_date_time_field(x, "month")),
    day = as.double(ztp_date_time_field(x, "day"))
  )
  date <- ztp_merge_date_fields(
    base,
    fields[intersect(names(fields), c("year", "month", "month_code", "day"))]
  )
  time <- lapply(ztp_time_field_names, function(f) {
    as.double(ztp_date_time_field(x, f))
  })
  names(time) <- ztp_time_field_names
  for (f in intersect(names(fields), ztp_time_field_names)) {
    time[[f]] <- ztp_as_field(fields[[f]], f)
  }
  merged <- ztp_recycle(c(date, time))
  new_plain_date_time(do.call(
    .Call,
    c(list(C_ztp_r_plain_date_time_from_fields), unname(merged), list(ov))
  ))
}

#' @rdname temporal_with
#' @export
temporal_with_plain_time.zutempo_plain_date_time <- function(x, time = NULL) {
  ns <- ztp_time_or_midnight(time)
  args <- ztp_recycle(list(ztp_date_time_days(x), ns))
  new_plain_date_time(.Call(
    C_ztp_r_plain_date_time_combine,
    args[[1L]],
    args[[2L]]
  ))
}

#' @rdname temporal_with
#' @export
temporal_with_calendar.zutempo_plain_date_time <- function(x, calendar) {
  ztp_check_calendar(calendar)
  x
}

#' @rdname temporal_to_plain_date
#' @export
temporal_to_plain_date.zutempo_plain_date_time <- function(x, ...) {
  ztp_check_dots_empty(...)
  new_plain_date(ztp_date_time_days(x))
}

#' @rdname temporal_to_plain_date
#' @export
temporal_to_plain_time.zutempo_plain_date_time <- function(x) {
  new_plain_time(ztp_date_time_ns(x))
}

#' @rdname temporal_equals
#' @export
temporal_equals.zutempo_plain_date_time <- function(x, other) {
  plain_date_time_compare(x, other) == 0L
}

#' @rdname temporal_round
#' @export
temporal_round.zutempo_plain_date_time <- function(
  x,
  smallest_unit = NULL,
  rounding_increment = 1,
  rounding_mode = "halfExpand",
  ...
) {
  ztp_check_dots_empty(...)
  if (is.null(smallest_unit)) {
    stop_zutempo("`smallest_unit` is required", kind = "type")
  }
  opts <- ztp_round_options(
    smallest_unit,
    rounding_increment,
    rounding_mode,
    allow_day = TRUE
  )
  new_plain_date_time(.Call(
    C_ztp_r_plain_date_time_round,
    unclass(x),
    opts$increment,
    opts$unit,
    opts$mode
  ))
}

#' @rdname temporal_to_string
#' @export
temporal_to_string.zutempo_plain_date_time <- function(x, ...) {
  ztp_check_dots_empty(...)
  .Call(C_ztp_r_plain_date_time_format, unclass(x), -1L, 0L)
}
