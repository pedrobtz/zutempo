# Arithmetic on the plain types (Temporal add, subtract, since and until),
# as generics with methods per type.

#' Add a duration to, or subtract one from, a Temporal value
#'
#' Temporal's `add()` and `subtract()`. On a `plain_date()` or
#' `plain_year_month()` the time part of the duration counts in 24-hour
#' days; on a `plain_time()` only the time part applies and the result
#' wraps within the day. On a `zoned_date_time()` the date part moves
#' through the calendar in the value's zone, resolved as `"compatible"`,
#' and the time part moves the exact time, so a day across a clock change
#' is not 24 hours (design 6.5). On a `duration()` the result is a
#' balanced duration, and calendar units are an error.
#'
#' @param x A zutempo value.
#' @param other A `duration()`, or a string that `duration()` reads.
#' @param ... Must be empty.
#' @param overflow `"constrain"` (the default) clamps a day that the
#'   target month lacks, `"reject"` raises a `zutempo_range_error`
#'   (design 6.2). Not for a `plain_time()` or a `duration()`.
#' @return A value of the same class as `x`.
#' @examples
#' temporal_add(plain_date("2026-01-31"), "P1M")
#' temporal_subtract(plain_date_time("2026-03-01T00:30"), duration(hours = 1))
#' temporal_add(plain_time("23:00"), "PT2H")
#' temporal_add(duration(hours = 1), "PT30M")
#' @export
temporal_add <- function(x, other, ...) {
  UseMethod("temporal_add")
}

#' @rdname temporal_add
#' @export
temporal_subtract <- function(x, other, ...) {
  UseMethod("temporal_subtract")
}

#' Difference between two Temporal values
#'
#' Temporal's `until()` and `since()`: the duration from `x` to `other`
#' (`until`), or from `other` to `x` (`since`), balanced up to
#' `largest_unit` and rounded to `smallest_unit` (design 6.6). Defaults
#' follow the type: days for dates and date-times, hours for times, zoned
#' values and instants, years for year-months. Two `zoned_date_time()`
#' values in different zones can only be differenced in time units.
#'
#' @param x A zutempo value.
#' @param other A value of the same class, or a string its constructor
#'   reads.
#' @param ... Must be empty.
#' @param largest_unit,smallest_unit Temporal units, singular or plural;
#'   `largest_unit` may be `"auto"`.
#' @param rounding_increment A positive integer that divides the next
#'   larger unit evenly for time units.
#' @param rounding_mode One of the nine rounding modes; `"trunc"` by
#'   default.
#' @return A `duration()`.
#' @examples
#' temporal_until(plain_date("2026-01-31"), "2026-03-01")
#' temporal_until(plain_date("2026-01-31"), "2026-03-01", largest_unit = "month")
#' temporal_since(plain_time("13:30"), "12:00")
#' @export
temporal_until <- function(
  x,
  other,
  ...,
  largest_unit = NULL,
  smallest_unit = NULL,
  rounding_increment = 1,
  rounding_mode = "trunc"
) {
  UseMethod("temporal_until")
}

#' @rdname temporal_until
#' @export
temporal_since <- function(
  x,
  other,
  ...,
  largest_unit = NULL,
  smallest_unit = NULL,
  rounding_increment = 1,
  rounding_mode = "trunc"
) {
  UseMethod("temporal_since")
}

# GetDifferenceSettings: resolves the units and rounding of a difference
# and negates the rounding mode for `since`.
ztp_difference_settings <- function(
  largest_unit,
  smallest_unit,
  rounding_increment,
  rounding_mode,
  group,
  disallowed,
  fallback_smallest,
  default_largest,
  since
) {
  largest <- if (is.null(largest_unit) || identical(largest_unit, "auto")) {
    NULL
  } else {
    ztp_unit_code(largest_unit, group, name = "largest_unit")
  }
  if (!is.null(largest) && ztp_units[largest + 1L] %in% disallowed) {
    stop_zutempo(
      sprintf("`largest_unit` cannot be \"%s\" here", ztp_units[largest + 1L]),
      kind = "range",
      option = "largest_unit"
    )
  }
  smallest <- if (is.null(smallest_unit)) {
    match(fallback_smallest, ztp_units) - 1L
  } else {
    ztp_unit_code(smallest_unit, group)
  }
  if (ztp_units[smallest + 1L] %in% disallowed) {
    stop_zutempo(
      sprintf(
        "`smallest_unit` cannot be \"%s\" here",
        ztp_units[smallest + 1L]
      ),
      kind = "range",
      option = "smallest_unit"
    )
  }
  default <- min(match(default_largest, ztp_units) - 1L, smallest)
  if (is.null(largest)) {
    largest <- default
  }
  if (largest > smallest) {
    stop_zutempo(
      "`largest_unit` must not be smaller than `smallest_unit`",
      kind = "range",
      option = "largest_unit"
    )
  }
  maximum <- ztp_unit_maximum[ztp_units[smallest + 1L]]
  increment <- if (is.na(maximum)) {
    ztp_increment_value(rounding_increment)
  } else {
    ztp_increment(rounding_increment, maximum[[1L]], inclusive = FALSE)
  }
  mode <- ztp_rounding_mode_code(rounding_mode)
  if (since) {
    mode <- ztp_negate_rounding_mode(mode)
  }
  list(
    largest = largest,
    smallest = smallest,
    increment = increment,
    mode = mode
  )
}

# NegateRoundingMode on the engine codes.
ztp_negate_rounding_mode <- function(code) {
  name <- ztp_rounding_modes[code + 1L]
  flipped <- switch(
    name,
    ceil = "floor",
    floor = "ceil",
    halfCeil = "halfFloor",
    halfFloor = "halfCeil",
    name
  )
  match(flipped, ztp_rounding_modes) - 1L
}

# The shared body of until() and since(): `since` negates the result.
ztp_difference <- function(x, other, convert, compute, settings, since) {
  other <- convert(other)
  n <- ztp_common_length(x, other)
  a <- rep_len(unclass(x), n)
  b <- rep_len(unclass(other), n)
  out <- compute(a, b, settings)
  if (since) {
    out <- ztp_negate_duration_data(out)
  }
  new_duration(out)
}

ztp_add_impl <- function(x, other, compute, negate) {
  other <- ztp_as_duration(other)
  n <- ztp_common_length(x, other)
  data <- ztp_duration_data(other, n)
  if (negate) {
    data <- ztp_negate_duration_data(data)
  }
  compute(rep_len(unclass(x), n), data)
}

# --- PlainDate ----------------------------------------------------------------

#' @rdname temporal_add
#' @export
temporal_add.zutempo_plain_date <- function(
  x,
  other,
  ...,
  overflow = "constrain"
) {
  ztp_check_dots_empty(...)
  ov <- ztp_overflow_code(overflow)
  new_plain_date(ztp_add_impl(
    x,
    other,
    function(days, dur) {
      .Call(C_ztp_r_plain_date_add, days, dur, ov)
    },
    negate = FALSE
  ))
}

#' @rdname temporal_add
#' @export
temporal_subtract.zutempo_plain_date <- function(
  x,
  other,
  ...,
  overflow = "constrain"
) {
  ztp_check_dots_empty(...)
  ov <- ztp_overflow_code(overflow)
  new_plain_date(ztp_add_impl(
    x,
    other,
    function(days, dur) {
      .Call(C_ztp_r_plain_date_add, days, dur, ov)
    },
    negate = TRUE
  ))
}

ztp_plain_date_difference <- function(
  x,
  other,
  largest_unit,
  smallest_unit,
  rounding_increment,
  rounding_mode,
  since
) {
  settings <- ztp_difference_settings(
    largest_unit,
    smallest_unit,
    rounding_increment,
    rounding_mode,
    group = "date",
    disallowed = character(),
    fallback_smallest = "day",
    default_largest = "day",
    since = since
  )
  ztp_difference(
    x,
    other,
    ztp_as_plain_date,
    function(a, b, s) {
      .Call(
        C_ztp_r_plain_date_until,
        a,
        b,
        s[["largest"]],
        s[["smallest"]],
        s[["increment"]],
        s[["mode"]]
      )
    },
    settings,
    since = since
  )
}

#' @rdname temporal_until
#' @export
temporal_until.zutempo_plain_date <- function(
  x,
  other,
  ...,
  largest_unit = NULL,
  smallest_unit = NULL,
  rounding_increment = 1,
  rounding_mode = "trunc"
) {
  ztp_check_dots_empty(...)
  ztp_plain_date_difference(
    x,
    other,
    largest_unit,
    smallest_unit,
    rounding_increment,
    rounding_mode,
    since = FALSE
  )
}

#' @rdname temporal_until
#' @export
temporal_since.zutempo_plain_date <- function(
  x,
  other,
  ...,
  largest_unit = NULL,
  smallest_unit = NULL,
  rounding_increment = 1,
  rounding_mode = "trunc"
) {
  ztp_check_dots_empty(...)
  ztp_plain_date_difference(
    x,
    other,
    largest_unit,
    smallest_unit,
    rounding_increment,
    rounding_mode,
    since = TRUE
  )
}

# --- PlainTime ----------------------------------------------------------------

#' @rdname temporal_add
#' @export
temporal_add.zutempo_plain_time <- function(x, other, ...) {
  ztp_check_dots_empty(...)
  new_plain_time(ztp_add_impl(
    x,
    other,
    function(ns, dur) {
      .Call(C_ztp_r_plain_time_add, ns, dur)
    },
    negate = FALSE
  ))
}

#' @rdname temporal_add
#' @export
temporal_subtract.zutempo_plain_time <- function(x, other, ...) {
  ztp_check_dots_empty(...)
  new_plain_time(ztp_add_impl(
    x,
    other,
    function(ns, dur) {
      .Call(C_ztp_r_plain_time_add, ns, dur)
    },
    negate = TRUE
  ))
}

ztp_plain_time_difference <- function(
  x,
  other,
  largest_unit,
  smallest_unit,
  rounding_increment,
  rounding_mode,
  since
) {
  settings <- ztp_difference_settings(
    largest_unit,
    smallest_unit,
    rounding_increment,
    rounding_mode,
    group = "time",
    disallowed = character(),
    fallback_smallest = "nanosecond",
    default_largest = "hour",
    since = since
  )
  ztp_difference(
    x,
    other,
    ztp_as_plain_time,
    function(a, b, s) {
      .Call(
        C_ztp_r_plain_time_until,
        a,
        b,
        s[["largest"]],
        s[["smallest"]],
        s[["increment"]],
        s[["mode"]]
      )
    },
    settings,
    since = since
  )
}

#' @rdname temporal_until
#' @export
temporal_until.zutempo_plain_time <- function(
  x,
  other,
  ...,
  largest_unit = NULL,
  smallest_unit = NULL,
  rounding_increment = 1,
  rounding_mode = "trunc"
) {
  ztp_check_dots_empty(...)
  ztp_plain_time_difference(
    x,
    other,
    largest_unit,
    smallest_unit,
    rounding_increment,
    rounding_mode,
    since = FALSE
  )
}

#' @rdname temporal_until
#' @export
temporal_since.zutempo_plain_time <- function(
  x,
  other,
  ...,
  largest_unit = NULL,
  smallest_unit = NULL,
  rounding_increment = 1,
  rounding_mode = "trunc"
) {
  ztp_check_dots_empty(...)
  ztp_plain_time_difference(
    x,
    other,
    largest_unit,
    smallest_unit,
    rounding_increment,
    rounding_mode,
    since = TRUE
  )
}

# --- PlainDateTime ------------------------------------------------------------

#' @rdname temporal_add
#' @export
temporal_add.zutempo_plain_date_time <- function(
  x,
  other,
  ...,
  overflow = "constrain"
) {
  ztp_check_dots_empty(...)
  ov <- ztp_overflow_code(overflow)
  new_plain_date_time(ztp_add_impl(
    x,
    other,
    function(z, dur) {
      .Call(C_ztp_r_plain_date_time_add, z, dur, ov)
    },
    negate = FALSE
  ))
}

#' @rdname temporal_add
#' @export
temporal_subtract.zutempo_plain_date_time <- function(
  x,
  other,
  ...,
  overflow = "constrain"
) {
  ztp_check_dots_empty(...)
  ov <- ztp_overflow_code(overflow)
  new_plain_date_time(ztp_add_impl(
    x,
    other,
    function(z, dur) {
      .Call(C_ztp_r_plain_date_time_add, z, dur, ov)
    },
    negate = TRUE
  ))
}

ztp_plain_date_time_difference <- function(
  x,
  other,
  largest_unit,
  smallest_unit,
  rounding_increment,
  rounding_mode,
  since
) {
  settings <- ztp_difference_settings(
    largest_unit,
    smallest_unit,
    rounding_increment,
    rounding_mode,
    group = "datetime",
    disallowed = character(),
    fallback_smallest = "nanosecond",
    default_largest = "day",
    since = since
  )
  ztp_difference(
    x,
    other,
    ztp_as_plain_date_time,
    function(a, b, s) {
      .Call(
        C_ztp_r_plain_date_time_until,
        a,
        b,
        s[["largest"]],
        s[["smallest"]],
        s[["increment"]],
        s[["mode"]]
      )
    },
    settings,
    since = since
  )
}

#' @rdname temporal_until
#' @export
temporal_until.zutempo_plain_date_time <- function(
  x,
  other,
  ...,
  largest_unit = NULL,
  smallest_unit = NULL,
  rounding_increment = 1,
  rounding_mode = "trunc"
) {
  ztp_check_dots_empty(...)
  ztp_plain_date_time_difference(
    x,
    other,
    largest_unit,
    smallest_unit,
    rounding_increment,
    rounding_mode,
    since = FALSE
  )
}

#' @rdname temporal_until
#' @export
temporal_since.zutempo_plain_date_time <- function(
  x,
  other,
  ...,
  largest_unit = NULL,
  smallest_unit = NULL,
  rounding_increment = 1,
  rounding_mode = "trunc"
) {
  ztp_check_dots_empty(...)
  ztp_plain_date_time_difference(
    x,
    other,
    largest_unit,
    smallest_unit,
    rounding_increment,
    rounding_mode,
    since = TRUE
  )
}

# --- PlainYearMonth -----------------------------------------------------------

#' @rdname temporal_add
#' @export
temporal_add.zutempo_plain_year_month <- function(
  x,
  other,
  ...,
  overflow = "constrain"
) {
  ztp_check_dots_empty(...)
  ov <- ztp_overflow_code(overflow)
  new_plain_year_month(ztp_add_impl(
    x,
    other,
    function(ym, dur) {
      .Call(C_ztp_r_plain_year_month_add, ym, dur, ov)
    },
    negate = FALSE
  ))
}

#' @rdname temporal_add
#' @export
temporal_subtract.zutempo_plain_year_month <- function(
  x,
  other,
  ...,
  overflow = "constrain"
) {
  ztp_check_dots_empty(...)
  ov <- ztp_overflow_code(overflow)
  new_plain_year_month(ztp_add_impl(
    x,
    other,
    function(ym, dur) {
      .Call(C_ztp_r_plain_year_month_add, ym, dur, ov)
    },
    negate = TRUE
  ))
}

ztp_plain_year_month_difference <- function(
  x,
  other,
  largest_unit,
  smallest_unit,
  rounding_increment,
  rounding_mode,
  since
) {
  settings <- ztp_difference_settings(
    largest_unit,
    smallest_unit,
    rounding_increment,
    rounding_mode,
    group = "date",
    disallowed = c("week", "day"),
    fallback_smallest = "month",
    default_largest = "year",
    since = since
  )
  ztp_difference(
    x,
    other,
    ztp_as_plain_year_month,
    function(a, b, s) {
      .Call(
        C_ztp_r_plain_year_month_until,
        a,
        b,
        s[["largest"]],
        s[["smallest"]],
        s[["increment"]],
        s[["mode"]]
      )
    },
    settings,
    since = since
  )
}

#' @rdname temporal_until
#' @export
temporal_until.zutempo_plain_year_month <- function(
  x,
  other,
  ...,
  largest_unit = NULL,
  smallest_unit = NULL,
  rounding_increment = 1,
  rounding_mode = "trunc"
) {
  ztp_check_dots_empty(...)
  ztp_plain_year_month_difference(
    x,
    other,
    largest_unit,
    smallest_unit,
    rounding_increment,
    rounding_mode,
    since = FALSE
  )
}

#' @rdname temporal_until
#' @export
temporal_since.zutempo_plain_year_month <- function(
  x,
  other,
  ...,
  largest_unit = NULL,
  smallest_unit = NULL,
  rounding_increment = 1,
  rounding_mode = "trunc"
) {
  ztp_check_dots_empty(...)
  ztp_plain_year_month_difference(
    x,
    other,
    largest_unit,
    smallest_unit,
    rounding_increment,
    rounding_mode,
    since = TRUE
  )
}
