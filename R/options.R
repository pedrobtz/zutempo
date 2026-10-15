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
# (design D7). Anything else is a range error, as CanonicalizeCalendar
# throws for an unknown calendar.
ztp_check_calendar <- function(calendar) {
  if (!is.character(calendar) || length(calendar) != 1L || is.na(calendar)) {
    stop_zutempo("`calendar` must be a single string", kind = "type")
  }
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
