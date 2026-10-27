#' Clock times: Temporal's PlainTime
#'
#' A `plain_time()` is a time of day with nanosecond precision and no date
#' or time zone, stored as a double count of nanoseconds since midnight
#' (design 4.1). The constructor is `Temporal.PlainTime` and
#' `Temporal.PlainTime.from()` in one: it reads fields, strings or another
#' zutempo value.
#'
#' @param hour The hour (0 to 23), or a string in ISO 8601 form
#'   (`"12:30"`, `"12:30:45.123456789"`, `"T12"`, or a date-time whose
#'   date is ignored; a bare time that could also read as a month-day or
#'   year-month must carry the `T` prefix), or a `plain_time()` or
#'   `plain_date_time()` to convert.
#' @param minute,second,millisecond,microsecond,nanosecond The remaining
#'   fields, 0 by default.
#' @param ... Must be empty.
#' @param overflow `"constrain"` (the default) clamps each field to its
#'   range, `"reject"` raises a `zutempo_range_error` (design 6.2).
#' @param x,y `plain_time()` values or strings, for `plain_time_compare()`.
#' @return A `plain_time()` vector; `plain_time_compare()` returns an
#'   integer vector of -1, 0 and 1.
#' @examples
#' plain_time("12:30:45.5")
#' plain_time(12, 30)
#' plain_time(25, overflow = "constrain")
#' plain_time()
#' plain_time_compare("12:30", "12:31")
#' @eval ztp_doc_members("PlainTime")
#' @export
plain_time <- function(
  hour = 0,
  minute = 0,
  second = 0,
  millisecond = 0,
  microsecond = 0,
  nanosecond = 0,
  ...,
  overflow = "constrain"
) {
  ztp_check_dots_empty(...)
  ov <- ztp_overflow_code(overflow)
  if (inherits(hour, "zutempo_plain_time")) {
    return(hour)
  }
  if (inherits(hour, "zutempo_plain_date_time")) {
    return(new_plain_time(ztp_date_time_ns(hour)))
  }
  # ToTemporalTime reads a zoned value's wall-clock time.
  if (inherits(hour, "zutempo_zoned_date_time")) {
    return(temporal_to_plain_time(hour))
  }
  if (is.character(hour)) {
    return(new_plain_time(.Call(C_ztp_r_plain_time_parse, hour)))
  }
  if (inherits(hour, "difftime")) {
    return(ztp_plain_time_from_difftime(hour))
  }
  if (!ztp_is_field_like(hour)) {
    stop_zutempo(
      sprintf(
        "cannot make a plain_time from an object of class %s",
        class(hour)[1L]
      ),
      kind = "type"
    )
  }
  fields <- ztp_time_fields(
    hour,
    minute,
    second,
    millisecond,
    microsecond,
    nanosecond
  )
  new_plain_time(do.call(
    .Call,
    c(list(C_ztp_r_plain_time_from_fields), unname(fields), list(ov))
  ))
}

ztp_time_field_names <- c(
  "hour",
  "minute",
  "second",
  "millisecond",
  "microsecond",
  "nanosecond"
)

# The nine fields of a date-time, in the order the glue takes them.
ztp_date_time_field_names <- c("year", "month", "day", ztp_time_field_names)

ztp_time_fields <- function(
  hour,
  minute,
  second,
  millisecond,
  microsecond,
  nanosecond
) {
  fields <- list(hour, minute, second, millisecond, microsecond, nanosecond)
  fields <- Map(ztp_as_field, fields, ztp_time_field_names)
  names(fields) <- ztp_time_field_names
  ztp_recycle(fields)
}

ztp_as_plain_time <- function(x) {
  if (inherits(x, "zutempo_plain_time")) x else plain_time(x)
}

#' @rdname plain_time
#' @export
plain_time_compare <- function(x, y) {
  args <- ztp_recycle(list(
    unclass(ztp_as_plain_time(x)),
    unclass(ztp_as_plain_time(y))
  ))
  as.integer(sign(args[[1L]] - args[[2L]]))
}

#' @rdname temporal_with
#' @export
temporal_with.zutempo_plain_time <- function(x, ..., overflow = "constrain") {
  fields <- ztp_partial_fields(list(...), ztp_time_field_names)
  ov <- ztp_overflow_code(overflow)
  base <- lapply(ztp_time_field_names, function(f) {
    as.double(ztp_time_field(x, f))
  })
  names(base) <- ztp_time_field_names
  for (f in names(fields)) {
    base[[f]] <- ztp_as_field(fields[[f]], f)
  }
  merged <- ztp_recycle(base)
  new_plain_time(do.call(
    .Call,
    c(list(C_ztp_r_plain_time_from_fields), unname(merged), list(ov))
  ))
}

#' @rdname temporal_equals
#' @export
temporal_equals.zutempo_plain_time <- function(x, other) {
  plain_time_compare(x, other) == 0L
}

#' @rdname temporal_round
#' @export
temporal_round.zutempo_plain_time <- function(
  x,
  smallest_unit = NULL,
  rounding_increment = 1,
  rounding_mode = "halfExpand",
  ...
) {
  ztp_check_dots_empty(...)
  if (is.null(smallest_unit)) {
    ztp_option_required("smallest_unit")
  }
  opts <- ztp_round_options(smallest_unit, rounding_increment, rounding_mode)
  new_plain_time(.Call(
    C_ztp_r_plain_time_round,
    unclass(x),
    opts[["increment"]],
    opts[["unit"]],
    opts[["mode"]]
  ))
}

#' @rdname temporal_to_string
#' @export
temporal_to_string.zutempo_plain_time <- function(
  x,
  ...,
  fractional_second_digits = "auto",
  smallest_unit = NULL,
  rounding_mode = "trunc"
) {
  ztp_check_dots_empty(...)
  p <- ztp_precision_record(
    fractional_second_digits,
    smallest_unit,
    rounding_mode
  )
  ns <- unclass(x)
  if (ztp_needs_rounding(p)) {
    ns <- .Call(
      C_ztp_r_plain_time_round,
      ns,
      p[["increment"]],
      p[["unit"]],
      p[["mode"]]
    )
  }
  .Call(C_ztp_r_plain_time_format, ns, p[["precision"]])
}
