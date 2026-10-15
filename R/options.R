# Option normalisation (design 6.9: option bags become named arguments;
# design 10: an invalid option value is a zutempo_type_error). Each helper
# returns the integer code the C glue understands.

ztp_match_option <- function(value, choices, name) {
  if (!is.character(value) || length(value) != 1L || is.na(value)) {
    stop_zutempo(
      sprintf("`%s` must be a single string", name),
      kind = "type"
    )
  }
  i <- match(value, choices)
  if (is.na(i)) {
    stop_zutempo(
      sprintf(
        "`%s` must be one of %s, not \"%s\"",
        name,
        paste0("\"", choices, "\"", collapse = ", "),
        value
      ),
      kind = "type"
    )
  }
  i
}

# GetTemporalOverflowOption: 0 constrain, 1 reject.
ztp_overflow_code <- function(overflow) {
  ztp_match_option(overflow, c("constrain", "reject"), "overflow") - 1L
}

# GetRoundingModeOption: Table 28, in the engine's order.
ztp_rounding_modes <- c(
  "ceil",
  "floor",
  "expand",
  "trunc",
  "halfCeil",
  "halfFloor",
  "halfExpand",
  "halfTrunc",
  "halfEven"
)

ztp_rounding_mode_code <- function(rounding_mode) {
  ztp_match_option(rounding_mode, ztp_rounding_modes, "rounding_mode") - 1L
}

# The units table (Temporal 13.17), singular and plural, in the engine's
# order: year 0 to nanosecond 9.
ztp_units <- c(
  "year",
  "month",
  "week",
  "day",
  "hour",
  "minute",
  "second",
  "millisecond",
  "microsecond",
  "nanosecond"
)
ztp_unit_category <- c(rep("date", 4L), rep("time", 6L))

# GetTemporalUnitValuedOption and ValidateTemporalUnitValue. `group` is
# the unit group the member accepts; `extra` names units accepted on top.
ztp_unit_code <- function(
  unit,
  group,
  extra = character(),
  name = "smallest_unit"
) {
  if (!is.character(unit) || length(unit) != 1L || is.na(unit)) {
    stop_zutempo(sprintf("`%s` must be a single string", name), kind = "type")
  }
  i <- match(unit, ztp_units)
  if (is.na(i)) {
    i <- match(unit, paste0(ztp_units, "s"))
  }
  if (is.na(i)) {
    stop_zutempo(
      sprintf("`%s` must be a Temporal unit, not \"%s\"", name, unit),
      kind = "type"
    )
  }
  allowed <- ztp_unit_category[i] == group ||
    group == "datetime" ||
    ztp_units[i] %in% extra
  if (!allowed) {
    stop_zutempo(
      sprintf("`%s` cannot be \"%s\" here", name, unit),
      kind = "range"
    )
  }
  i - 1L
}

# GetRoundingIncrementOption followed by ValidateTemporalRoundingIncrement.
# `maximum` is the dividend the increment must divide; when `inclusive`
# is FALSE the increment must also be smaller than it.
ztp_increment <- function(rounding_increment, maximum, inclusive) {
  if (
    !is.numeric(rounding_increment) ||
      length(rounding_increment) != 1L ||
      is.na(rounding_increment)
  ) {
    stop_zutempo("`rounding_increment` must be a single number", kind = "type")
  }
  increment <- trunc(rounding_increment)
  if (!is.finite(increment) || increment < 1 || increment > 1e9) {
    stop_zutempo(
      "`rounding_increment` must be between 1 and 1000000000",
      kind = "range"
    )
  }
  limit <- if (inclusive) maximum else maximum - 1
  if (increment > limit || maximum %% increment != 0) {
    stop_zutempo(
      sprintf(
        "`rounding_increment` %s does not divide %s evenly",
        format(increment, scientific = FALSE),
        format(maximum, scientific = FALSE)
      ),
      kind = "range"
    )
  }
  as.double(increment)
}

# GetRoundingIncrementOption alone, for a date unit, which has no maximum:
# a positive integer up to 10^9.
ztp_increment_unchecked <- function(rounding_increment) {
  if (
    !is.numeric(rounding_increment) ||
      length(rounding_increment) != 1L ||
      is.na(rounding_increment)
  ) {
    stop_zutempo("`rounding_increment` must be a single number", kind = "type")
  }
  increment <- trunc(rounding_increment)
  if (!is.finite(increment) || increment < 1 || increment > 1e9) {
    stop_zutempo(
      "`rounding_increment` must be between 1 and 1000000000",
      kind = "range"
    )
  }
  as.double(increment)
}

# "Maximum duration rounding increment" of the units table.
ztp_unit_maximum <- c(
  hour = 24,
  minute = 60,
  second = 60,
  millisecond = 1000,
  microsecond = 1000,
  nanosecond = 1000
)

# The rounding options of round(): smallest_unit is required.
ztp_round_options <- function(
  smallest_unit,
  rounding_increment,
  rounding_mode,
  allow_day = FALSE
) {
  unit <- ztp_unit_code(
    smallest_unit,
    "time",
    extra = if (allow_day) "day" else character()
  )
  mode <- ztp_rounding_mode_code(rounding_mode)
  if (ztp_units[unit + 1L] == "day") {
    increment <- ztp_increment(rounding_increment, 1, inclusive = TRUE)
  } else {
    increment <- ztp_increment(
      rounding_increment,
      ztp_unit_maximum[[ztp_units[unit + 1L]]],
      inclusive = FALSE
    )
  }
  list(unit = unit, increment = increment, mode = mode)
}

# Calendar identifiers: only "iso8601", matched ASCII case-insensitively
# (design D7). An ISO string names its calendar annotation, or "iso8601"
# (ParseTemporalCalendarString). Anything else is a range error, as
# CanonicalizeCalendar throws for an unknown calendar.
ztp_check_calendar <- function(calendar) {
  if (!is.character(calendar) || length(calendar) != 1L || is.na(calendar)) {
    stop_zutempo("`calendar` must be a single string", kind = "type")
  }
  calendar <- .Call(C_ztp_r_calendar_string, calendar)
  if (tolower(calendar) != "iso8601") {
    stop_zutempo(
      sprintf(
        "calendar \"%s\" is not supported; only \"iso8601\" is",
        calendar
      ),
      kind = "range"
    )
  }
  "iso8601"
}

# ParseMonthCode for the ISO calendar: "M01" to "M12", never a leap month.
ztp_month_from_code <- function(month_code) {
  if (!is.character(month_code)) {
    stop_zutempo("`month_code` must be a character vector", kind = "type")
  }
  ok <- is.na(month_code) | grepl("^M(0[1-9]|1[0-2])$", month_code)
  if (!all(ok)) {
    bad <- which(!ok)[1L]
    stop_zutempo(
      sprintf(
        "\"%s\" is not a month code of the ISO 8601 calendar",
        month_code[bad]
      ),
      kind = "range",
      index = bad
    )
  }
  as.double(substr(month_code, 2L, 3L))
}

# GetTemporalFractionalSecondDigitsOption: "auto" (-1) or a number floored
# to 0 to 9. Another string is an invalid value (a type error, design 10);
# a number out of range or not finite is a range error.
ztp_fractional_digits <- function(fractional_second_digits) {
  x <- fractional_second_digits
  if (is.character(x) && length(x) == 1L && !is.na(x)) {
    if (identical(x, "auto")) {
      return(-1L)
    }
    stop_zutempo(
      sprintf(
        "`fractional_second_digits` must be \"auto\" or 0 to 9, not \"%s\"",
        x
      ),
      kind = "type"
    )
  }
  if (!is.numeric(x) || length(x) != 1L || is.na(x)) {
    stop_zutempo(
      "`fractional_second_digits` must be \"auto\" or a single number",
      kind = "type"
    )
  }
  digits <- floor(x)
  if (!is.finite(digits) || digits < 0 || digits > 9) {
    stop_zutempo(
      "`fractional_second_digits` must be between 0 and 9",
      kind = "range"
    )
  }
  as.integer(digits)
}

# ToSecondsStringPrecisionRecord after the options of toString(): the
# precision the formatter writes (-1 auto, -2 minute, else digits) and the
# unit, increment and rounding mode the value is rounded with first. A
# smallest unit wins over the digits; "hour" is never allowed, "minute"
# only when `minute` is TRUE (not for a duration).
ztp_precision_record <- function(
  fractional_second_digits = "auto",
  smallest_unit = NULL,
  rounding_mode = "trunc",
  minute = TRUE
) {
  digits <- ztp_fractional_digits(fractional_second_digits)
  mode <- ztp_rounding_mode_code(rounding_mode)
  if (!is.null(smallest_unit)) {
    unit <- ztp_unit_code(smallest_unit, "time")
    name <- ztp_units[unit + 1L]
    if (name == "hour" || (!minute && name == "minute")) {
      stop_zutempo(
        sprintf("`smallest_unit` cannot be \"%s\" here", smallest_unit),
        kind = "range"
      )
    }
    precision <- c(
      minute = -2L,
      second = 0L,
      millisecond = 3L,
      microsecond = 6L,
      nanosecond = 9L
    )[[name]]
    return(list(precision = precision, unit = unit, increment = 1, mode = mode))
  }
  if (digits < 0L) {
    return(list(precision = -1L, unit = 9L, increment = 1, mode = mode))
  }
  if (digits == 0L) {
    return(list(precision = 0L, unit = 6L, increment = 1, mode = mode))
  }
  list(
    precision = digits,
    unit = 6L + (digits + 2L) %/% 3L,
    increment = 10^((3L - digits %% 3L) %% 3L),
    mode = mode
  )
}

# GetTemporalShowCalendarNameOption, GetTemporalShowTimeZoneNameOption and
# GetTemporalShowOffsetOption, as the codes of src/ztp_format.h and
# src/ztp_zoned.h.
ztp_show_calendar_code <- function(calendar_name) {
  choices <- c("auto", "always", "never", "critical")
  ztp_match_option(calendar_name, choices, "calendar_name") - 1L
}

ztp_show_time_zone_code <- function(time_zone_name) {
  choices <- c("auto", "never", "critical")
  ztp_match_option(time_zone_name, choices, "time_zone_name") - 1L
}

ztp_show_offset <- function(offset) {
  ztp_match_option(offset, c("auto", "never"), "offset") == 1L
}

# format() hands Temporal's formatting options to temporal_to_string() and
# drops the arguments base R's formatting machinery adds (justify, width
# and the like), so that print() and data frames keep working.
ztp_format <- function(x, ...) {
  dots <- list(...)
  method <- getS3method("temporal_to_string", class(x)[1L])
  keep <- setdiff(names(formals(method)), c("x", "..."))
  dots <- dots[!is.null(names(dots)) & names(dots) %in% keep]
  do.call(temporal_to_string, c(list(x), dots))
}
