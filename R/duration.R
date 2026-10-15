#' Durations: Temporal's Duration
#'
#' A `duration()` is a length of time in ten fields, years to nanoseconds,
#' each a float64-representable integer as Temporal defines them, stored as
#' a list of ten double vectors (design 4.1). All fields share one sign.
#' Years, months and weeks are calendar units: operations that need their
#' length take `relative_to`, a date, and fail without it (design 6.5).
#'
#' @param years The years, or a string in ISO 8601 form
#'   (`"P1Y2M3DT4H5M6.789S"`, a fraction only on the smallest unit
#'   present), or a `duration()` to return as is.
#' @param months,weeks,days,hours,minutes,seconds,milliseconds,microseconds,nanoseconds
#'   The remaining fields, 0 by default.
#' @param ... Must be empty.
#' @param x,y `duration()` values or strings, for `duration_compare()`.
#' @param relative_to A `plain_date()`, `plain_date_time()` or a string
#'   either reads: the date the calendar units are counted from. Required
#'   when either duration has years, months or weeks.
#' @return A `duration()` vector; `duration_compare()` returns an integer
#'   vector of -1, 0 and 1.
#' @examples
#' duration("P1Y2M3DT4H5M6.789S")
#' duration(hours = 25)
#' duration(milliseconds = 2^53 + 2)
#' duration_compare("PT1H", "PT60M")
#' duration_compare("P1M", "P30D", relative_to = "2026-02-01")
#' @export
duration <- function(
  years = 0,
  months = 0,
  weeks = 0,
  days = 0,
  hours = 0,
  minutes = 0,
  seconds = 0,
  milliseconds = 0,
  microseconds = 0,
  nanoseconds = 0,
  ...
) {
  ztp_check_dots_empty(...)
  if (inherits(years, "zutempo_duration")) {
    return(years)
  }
  if (is.character(years)) {
    return(new_duration(.Call(C_ztp_r_duration_parse, years)))
  }
  if (!ztp_is_field_like(years)) {
    stop_zutempo(
      sprintf(
        "cannot make a duration from an object of class %s",
        class(years)[1L]
      ),
      kind = "type"
    )
  }
  fields <- list(
    years,
    months,
    weeks,
    days,
    hours,
    minutes,
    seconds,
    milliseconds,
    microseconds,
    nanoseconds
  )
  fields <- Map(ztp_as_field, fields, ztp_duration_fields)
  names(fields) <- ztp_duration_fields
  new_duration(.Call(C_ztp_r_duration_create, ztp_recycle(fields)))
}

ztp_duration_fields <- c(
  "years",
  "months",
  "weeks",
  "days",
  "hours",
  "minutes",
  "seconds",
  "milliseconds",
  "microseconds",
  "nanoseconds"
)

new_duration <- function(fields = ztp_empty_duration_fields()) {
  structure(fields, class = "zutempo_duration")
}

ztp_empty_duration_fields <- function() {
  out <- rep(list(double()), 10L)
  names(out) <- ztp_duration_fields
  out
}

# ToTemporalDuration: a duration, or a string that reads as one. A bare
# number is a type error, as in Temporal.
ztp_as_duration <- function(x) {
  if (inherits(x, "zutempo_duration")) {
    return(x)
  }
  if (!is.character(x)) {
    stop_zutempo(
      sprintf(
        "expected a duration() or a string, not an object of class %s",
        class(x)[1L]
      ),
      kind = "type"
    )
  }
  duration(x)
}

# A duration list without its class, recycled to length n.
ztp_duration_data <- function(x, n) {
  data <- unclass(x)
  if (length(data[[1L]]) != n) {
    data <- lapply(data, rep_len, n)
  }
  data
}

ztp_negate_duration_data <- function(data) {
  lapply(data, function(f) {
    out <- -f
    out[!is.na(out) & out == 0] <- 0
    out
  })
}

# relative_to as recycled epoch days, or NULL.
ztp_relative_days <- function(relative_to, n) {
  if (is.null(relative_to)) {
    return(NULL)
  }
  if (inherits(relative_to, "zutempo_plain_date_time")) {
    relative_to <- temporal_to_plain_date(relative_to)
  }
  if (!inherits(relative_to, "zutempo_plain_date")) {
    if (!is.character(relative_to)) {
      stop_zutempo(
        "`relative_to` must be a plain_date(), a plain_date_time() or a string",
        kind = "type"
      )
    }
    relative_to <- ztp_relative_from_string(relative_to)
  }
  rep_len(unclass(relative_to), n)
}

# A relativeTo string reads as a date-time (Z and zones arrive in stage 8).
ztp_relative_from_string <- function(x) {
  temporal_to_plain_date(plain_date_time(x))
}

#' @rdname duration
#' @export
duration_compare <- function(x, y, relative_to = NULL) {
  x <- ztp_as_duration(x)
  y <- ztp_as_duration(y)
  n <- max(length(x), length(y))
  if (length(x) == 0L || length(y) == 0L) {
    n <- 0L
  }
  if (length(x) != 1L && length(x) != n || length(y) != 1L && length(y) != n) {
    stop_zutempo(
      "`x` and `y` cannot be recycled to a common length",
      kind = "type"
    )
  }
  .Call(
    C_ztp_r_duration_compare,
    ztp_duration_data(x, n),
    ztp_duration_data(y, n),
    ztp_relative_days(relative_to, n)
  )
}

# --- fields -----------------------------------------------------------------

ztp_duration_field <- function(x, field) {
  unclass(x)[[field]]
}

#' @rdname temporal_fields
#' @export
years <- function(x, ...) UseMethod("years")
#' @rdname temporal_fields
#' @export
years.default <- function(x, ...) ztp_masked("years", x, ...)
#' @rdname temporal_fields
#' @export
years.zutempo_duration <- function(x, ...) ztp_duration_field(x, "years")

#' @rdname temporal_fields
#' @export
months <- function(x, ...) UseMethod("months")
#' @rdname temporal_fields
#' @export
months.default <- function(x, ...) ztp_masked("months", x, ...)
#' @rdname temporal_fields
#' @export
months.zutempo_duration <- function(x, ...) ztp_duration_field(x, "months")

#' @rdname temporal_fields
#' @export
weeks <- function(x, ...) UseMethod("weeks")
#' @rdname temporal_fields
#' @export
weeks.default <- function(x, ...) ztp_masked("weeks", x, ...)
#' @rdname temporal_fields
#' @export
weeks.zutempo_duration <- function(x, ...) ztp_duration_field(x, "weeks")

#' @rdname temporal_fields
#' @export
days <- function(x, ...) UseMethod("days")
#' @rdname temporal_fields
#' @export
days.default <- function(x, ...) ztp_masked("days", x, ...)
#' @rdname temporal_fields
#' @export
days.zutempo_duration <- function(x, ...) ztp_duration_field(x, "days")

#' @rdname temporal_fields
#' @export
hours <- function(x, ...) UseMethod("hours")
#' @rdname temporal_fields
#' @export
hours.default <- function(x, ...) ztp_masked("hours", x, ...)
#' @rdname temporal_fields
#' @export
hours.zutempo_duration <- function(x, ...) ztp_duration_field(x, "hours")

#' @rdname temporal_fields
#' @export
minutes <- function(x, ...) UseMethod("minutes")
#' @rdname temporal_fields
#' @export
minutes.default <- function(x, ...) ztp_masked("minutes", x, ...)
#' @rdname temporal_fields
#' @export
minutes.zutempo_duration <- function(x, ...) ztp_duration_field(x, "minutes")

#' @rdname temporal_fields
#' @export
seconds <- function(x, ...) UseMethod("seconds")
#' @rdname temporal_fields
#' @export
seconds.default <- function(x, ...) ztp_masked("seconds", x, ...)
#' @rdname temporal_fields
#' @export
seconds.zutempo_duration <- function(x, ...) ztp_duration_field(x, "seconds")

#' @rdname temporal_fields
#' @export
milliseconds <- function(x, ...) UseMethod("milliseconds")
#' @rdname temporal_fields
#' @export
milliseconds.default <- function(x, ...) ztp_masked("milliseconds", x, ...)
#' @rdname temporal_fields
#' @export
milliseconds.zutempo_duration <- function(x, ...) {
  ztp_duration_field(x, "milliseconds")
}

#' @rdname temporal_fields
#' @export
microseconds <- function(x, ...) UseMethod("microseconds")
#' @rdname temporal_fields
#' @export
microseconds.default <- function(x, ...) ztp_masked("microseconds", x, ...)
#' @rdname temporal_fields
#' @export
microseconds.zutempo_duration <- function(x, ...) {
  ztp_duration_field(x, "microseconds")
}

#' @rdname temporal_fields
#' @export
nanoseconds <- function(x, ...) UseMethod("nanoseconds")
#' @rdname temporal_fields
#' @export
nanoseconds.default <- function(x, ...) ztp_masked("nanoseconds", x, ...)
#' @rdname temporal_fields
#' @export
nanoseconds.zutempo_duration <- function(x, ...) {
  ztp_duration_field(x, "nanoseconds")
}

#' @rdname temporal_fields
#' @export
blank <- function(x, ...) UseMethod("blank")
#' @rdname temporal_fields
#' @export
blank.default <- function(x, ...) ztp_masked("blank", x, ...)
#' @rdname temporal_fields
#' @export
blank.zutempo_duration <- function(x, ...) ztp_duration_sign(x) == 0L

# DurationSign over the fields: the first non-zero field decides.
ztp_duration_sign <- function(x) {
  data <- unclass(x)
  out <- rep(0L, length(data[[1L]]))
  undecided <- rep(TRUE, length(out))
  for (f in rev(ztp_duration_fields)) {
    out[!is.na(data[[f]]) & data[[f]] != 0] <- sign(data[[f]][
      !is.na(data[[f]]) & data[[f]] != 0
    ])
  }
  out[is.na(data[[1L]])] <- NA_integer_
  as.integer(out)
}

#' @rdname temporal_fields
#' @export
Math.zutempo_duration <- function(x, ...) {
  switch(
    .Generic,
    sign = ztp_duration_sign(x),
    abs = temporal_abs(x),
    stop_zutempo(
      sprintf("%s() is not defined for a duration", .Generic),
      kind = "type"
    )
  )
}

# --- methods ----------------------------------------------------------------

#' @rdname temporal_with
#' @export
temporal_with.zutempo_duration <- function(x, ..., overflow = "constrain") {
  fields <- ztp_partial_fields(list(...), ztp_duration_fields)
  ztp_overflow_code(overflow)
  data <- unclass(x)
  for (f in names(fields)) {
    data[[f]] <- ztp_as_field(fields[[f]], f)
  }
  new_duration(.Call(C_ztp_r_duration_create, ztp_recycle(data)))
}

#' Negate or take the magnitude of a duration
#'
#' Temporal's `negated()` and `abs()`. `abs(x)` and `sign(x)` also work on
#' a `duration()` through R's `Math` group generic.
#'
#' @param x A `duration()`.
#' @return A `duration()`.
#' @examples
#' temporal_negated(duration("P1DT2H"))
#' temporal_abs(duration("-P1DT2H"))
#' sign(duration("-P1DT2H"))
#' @export
temporal_negated <- function(x) {
  UseMethod("temporal_negated")
}

#' @rdname temporal_negated
#' @export
temporal_negated.zutempo_duration <- function(x) {
  new_duration(ztp_negate_duration_data(unclass(x)))
}

#' @rdname temporal_negated
#' @export
temporal_abs <- function(x) {
  UseMethod("temporal_abs")
}

#' @rdname temporal_negated
#' @export
temporal_abs.zutempo_duration <- function(x) {
  new_duration(lapply(unclass(x), abs))
}

#' @rdname temporal_add
#' @export
temporal_add.zutempo_duration <- function(x, other, ...) {
  ztp_check_dots_empty(...)
  other <- ztp_as_duration(other)
  n <- ztp_common_length(x, other)
  new_duration(.Call(
    C_ztp_r_duration_add,
    ztp_duration_data(x, n),
    ztp_duration_data(other, n)
  ))
}

#' @rdname temporal_add
#' @export
temporal_subtract.zutempo_duration <- function(x, other, ...) {
  ztp_check_dots_empty(...)
  other <- ztp_as_duration(other)
  n <- ztp_common_length(x, other)
  new_duration(.Call(
    C_ztp_r_duration_add,
    ztp_duration_data(x, n),
    ztp_negate_duration_data(ztp_duration_data(other, n))
  ))
}

ztp_common_length <- function(x, y) {
  lx <- length(x)
  ly <- length(y)
  if (lx == 0L || ly == 0L) {
    return(0L)
  }
  if (lx != 1L && ly != 1L && lx != ly) {
    stop_zutempo(
      sprintf(
        "arguments cannot be recycled to a common length (lengths %d, %d)",
        lx,
        ly
      ),
      kind = "type"
    )
  }
  max(lx, ly)
}

#' @rdname temporal_round
#' @export
temporal_round.zutempo_duration <- function(
  x,
  smallest_unit = NULL,
  rounding_increment = 1,
  rounding_mode = "halfExpand",
  ...,
  largest_unit = NULL,
  relative_to = NULL
) {
  ztp_check_dots_empty(...)
  smallest_given <- !is.null(smallest_unit)
  largest_given <- !is.null(largest_unit)
  if (!smallest_given && !largest_given) {
    stop_zutempo(
      "one of `smallest_unit` and `largest_unit` is required",
      kind = "range"
    )
  }
  smallest <- if (smallest_given) {
    ztp_unit_code(smallest_unit, "datetime")
  } else {
    9L
  }
  largest <- if (!largest_given) {
    -1L
  } else if (identical(largest_unit, "auto")) {
    -1L
  } else {
    ztp_unit_code(largest_unit, "datetime", name = "largest_unit")
  }
  mode <- ztp_rounding_mode_code(rounding_mode)
  maximum <- ztp_unit_maximum[ztp_units[smallest + 1L]]
  increment <- if (is.na(maximum)) {
    ztp_increment_unchecked(rounding_increment)
  } else {
    ztp_increment(rounding_increment, maximum[[1L]], inclusive = FALSE)
  }
  if (largest >= 0L && largest > smallest) {
    stop_zutempo(
      "`largest_unit` must not be smaller than `smallest_unit`",
      kind = "range"
    )
  }
  n <- length(x)
  new_duration(.Call(
    C_ztp_r_duration_round,
    unclass(x),
    largest,
    smallest,
    increment,
    mode,
    smallest_given,
    ztp_relative_days(relative_to, n)
  ))
}

#' Total a duration in one unit
#'
#' Temporal's `total()`: the whole duration as a possibly fractional count
#' of `unit`. Years, months and weeks need `relative_to`; without it a day
#' counts 24 hours (design 6.5).
#'
#' @param x A `duration()`.
#' @param unit A Temporal unit, singular or plural.
#' @param relative_to A `plain_date()`, `plain_date_time()` or a string
#'   either reads.
#' @return A double vector.
#' @examples
#' temporal_total(duration(hours = 25), "day")
#' temporal_total(duration(months = 1), "day", relative_to = "2026-02-01")
#' @export
temporal_total <- function(x, unit, relative_to = NULL) {
  UseMethod("temporal_total")
}

#' @rdname temporal_total
#' @export
temporal_total.zutempo_duration <- function(x, unit, relative_to = NULL) {
  if (missing(unit)) {
    stop_zutempo("`unit` is required", kind = "type")
  }
  code <- ztp_unit_code(unit, "datetime", name = "unit")
  n <- length(x)
  .Call(
    C_ztp_r_duration_total,
    unclass(x),
    code,
    ztp_relative_days(relative_to, n)
  )
}

#' @rdname temporal_to_string
#' @export
temporal_to_string.zutempo_duration <- function(x) {
  .Call(C_ztp_r_duration_format, unclass(x), -1L)
}

# --- plumbing for the record class ---------------------------------------

ztp_duration_subset <- function(x, i) {
  new_duration(lapply(unclass(x), `[`, i))
}

#' @export
length.zutempo_duration <- function(x) length(unclass(x)[[1L]])
# The list's names are the fields, not element names: base R and vctrs
# read names() as the latter.
#' @export
names.zutempo_duration <- function(x) NULL
#' @export
`names<-.zutempo_duration` <- function(x, value) {
  if (!is.null(value)) {
    stop_zutempo("durations cannot have element names", kind = "type")
  }
  x
}
#' @export
`[.zutempo_duration` <- function(x, i, ...) ztp_duration_subset(x, i)
#' @export
`[[.zutempo_duration` <- function(x, i, ...) ztp_duration_subset(x, i)
#' @export
`[<-.zutempo_duration` <- function(x, i, value) {
  if (is.logical(value) && all(is.na(value))) {
    value <- new_duration(lapply(ztp_empty_duration_fields(), function(f) {
      rep(NA_real_, length(value))
    }))
  }
  ztp_check_same_class(x, value, "the replacement value")
  data <- unclass(x)
  v <- unclass(value)
  for (f in ztp_duration_fields) {
    data[[f]][i] <- v[[f]]
  }
  new_duration(data)
}
#' @export
`[[<-.zutempo_duration` <- function(x, i, value) `[<-`(x, i, value)
#' @export
c.zutempo_duration <- function(...) {
  dots <- list(...)
  dots <- dots[!vapply(dots, is.null, logical(1L))]
  dots <- lapply(dots, function(d) {
    if (is.logical(d) && all(is.na(d))) {
      return(new_duration(lapply(ztp_empty_duration_fields(), function(f) {
        rep(NA_real_, length(d))
      })))
    }
    ztp_check_same_class(..1, d, "every argument of c()")
    d
  })
  data <- lapply(ztp_duration_fields, function(f) {
    do.call(c, lapply(dots, function(d) unclass(d)[[f]]))
  })
  names(data) <- ztp_duration_fields
  new_duration(data)
}
#' @export
rep.zutempo_duration <- function(x, ...) {
  new_duration(lapply(unclass(x), rep, ...))
}
#' @export
unique.zutempo_duration <- function(x, ...) x[!duplicated(x)]
#' @export
duplicated.zutempo_duration <- function(x, ...) {
  duplicated(temporal_to_string(x), ...)
}
#' @export
is.na.zutempo_duration <- function(x) is.na(unclass(x)[[1L]])
#' @export
anyNA.zutempo_duration <- function(x, recursive = FALSE) anyNA(unclass(x)[[1L]])
#' @export
`length<-.zutempo_duration` <- function(x, value) {
  new_duration(lapply(unclass(x), `length<-`, value))
}
# as.data.frame.vector() drops the names of a list, which are the fields
# here, so the one-column frame is built directly.
#' @export
as.data.frame.zutempo_duration <- function(
  x,
  row.names = NULL,
  optional = FALSE,
  ...,
  nm = deparse1(substitute(x))
) {
  force(nm)
  value <- list(x)
  if (!optional) {
    names(value) <- nm
  }
  structure(value, row.names = .set_row_names(length(x)), class = "data.frame")
}
#' @export
format.zutempo_duration <- function(x, ...) temporal_to_string(x)
#' @export
as.character.zutempo_duration <- function(x, ...) temporal_to_string(x)
#' @export
print.zutempo_duration <- function(x, ...) ztp_print(x, ...)
#' @export
as.list.zutempo_duration <- function(x, ...) {
  lapply(seq_along(x), function(i) x[i])
}

# Durations free of calendar units order by their total nanoseconds; others
# cannot be ordered (design 6.5).
ztp_duration_order_key <- function(x) {
  data <- unclass(x)
  calendar <- !is.na(data$years) &
    (data$years != 0 | data$months != 0 | data$weeks != 0)
  if (any(calendar)) {
    stop_zutempo(
      "durations with years, months or weeks cannot be ordered without `relative_to`; use duration_compare()",
      kind = "range",
      index = which(calendar)[1L]
    )
  }
  .Call(C_ztp_r_duration_total, data, 9L, NULL)
}

#' @export
xtfrm.zutempo_duration <- function(x) ztp_duration_order_key(x)

#' @export
Ops.zutempo_duration <- function(e1, e2) {
  if (.Generic %in% c("==", "!=")) {
    a <- ztp_as_duration(e1)
    b <- ztp_as_duration(e2)
    n <- ztp_common_length(a, b)
    da <- ztp_duration_data(a, n)
    db <- ztp_duration_data(b, n)
    same <- rep(TRUE, n)
    for (f in ztp_duration_fields) {
      same <- same & da[[f]] == db[[f]]
    }
    return(if (.Generic == "==") same else !same)
  }
  if (.Generic %in% c("<", ">", "<=", ">=")) {
    a <- ztp_as_duration(e1)
    b <- ztp_as_duration(e2)
    return(get(.Generic)(ztp_duration_order_key(a), ztp_duration_order_key(b)))
  }
  stop_zutempo(
    sprintf(
      "`%s` is not defined for durations; use temporal_add() and friends",
      .Generic
    ),
    kind = "type"
  )
}
