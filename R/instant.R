#' Exact times: Temporal's Instant
#'
#' An `instant()` is an exact point on the time line with nanosecond
#' precision and no calendar or time zone, stored as a complex vector whose
#' real part is the whole seconds since 1970-01-01T00:00Z and whose
#' imaginary part is the nanoseconds within that second (design 4.1). The
#' range is 10^8 days either side of the epoch. The constructor is
#' `Temporal.Instant` and `Temporal.Instant.from()` in one.
#'
#' @param x A string in ISO 8601 form with `Z` or a UTC offset
#'   (`"2026-01-31T12:30:45.123456789Z"`, `"2026-01-31T12:30+05:30"`), or an
#'   `instant()` to return as is. For `instant_from_epoch_milliseconds()`,
#'   integral milliseconds since the epoch; for
#'   `instant_from_epoch_nanoseconds()`, integral nanoseconds as numbers
#'   exact in a double or as decimal strings.
#' @param y An `instant()` or a string, for `instant_compare()`.
#' @return An `instant()` vector; `instant_compare()` returns an integer
#'   vector of -1, 0 and 1.
#' @examples
#' instant("2026-01-31T12:30:45.123456789Z")
#' instant("2026-01-31T12:30+05:30")
#' instant_from_epoch_milliseconds(0)
#' instant_from_epoch_nanoseconds("8640000000000000000000")
#' epoch_nanoseconds(instant("+275760-09-13T00:00Z"))
#' instant_compare("1969-12-31T23:59:59Z", "1970-01-01T00:00Z")
#' @export
instant <- function(x) {
  if (inherits(x, "zutempo_instant")) {
    return(x)
  }
  if (!is.character(x)) {
    stop_zutempo(
      sprintf(
        "cannot make an instant from an object of class %s",
        class(x)[1L]
      ),
      kind = "type"
    )
  }
  new_instant(.Call(C_ztp_r_instant_parse, x))
}

new_instant <- function(z = complex()) {
  z[is.na(z)] <- NA_complex_
  structure(z, class = "zutempo_instant")
}

#' @rdname instant
#' @export
instant_from_epoch_milliseconds <- function(x) {
  x <- ztp_as_field(x, "x")
  new_instant(.Call(C_ztp_r_instant_from_epoch_ms, x))
}

#' @rdname instant
#' @export
instant_from_epoch_nanoseconds <- function(x) {
  if (!is.character(x)) {
    x <- ztp_as_field(x, "x")
  }
  new_instant(.Call(C_ztp_r_instant_from_epoch_ns, x))
}

ztp_as_instant <- function(x) {
  if (inherits(x, "zutempo_instant")) x else instant(x)
}

#' @rdname instant
#' @export
instant_compare <- function(x, y) {
  args <- ztp_recycle(list(
    unclass(ztp_as_instant(x)),
    unclass(ztp_as_instant(y))
  ))
  a <- args[[1L]]
  b <- args[[2L]]
  out <- as.integer(sign(Re(a) - Re(b)))
  tie <- !is.na(out) & out == 0L
  out[tie] <- as.integer(sign(Im(a)[tie] - Im(b)[tie]))
  out
}

#' @rdname temporal_fields
#' @export
epoch_milliseconds <- function(x, ...) UseMethod("epoch_milliseconds")
#' @rdname temporal_fields
#' @export
epoch_milliseconds.default <- function(x, ...) {
  ztp_masked("epoch_milliseconds", x, ...)
}
#' @rdname temporal_fields
#' @export
epoch_milliseconds.zutempo_instant <- function(x, ...) {
  .Call(C_ztp_r_instant_epoch_ms, unclass(x))
}

#' @rdname temporal_fields
#' @export
epoch_nanoseconds <- function(x, ...) UseMethod("epoch_nanoseconds")
#' @rdname temporal_fields
#' @export
epoch_nanoseconds.default <- function(x, ...) {
  ztp_masked("epoch_nanoseconds", x, ...)
}
#' @rdname temporal_fields
#' @export
epoch_nanoseconds.zutempo_instant <- function(x, ...) {
  .Call(C_ztp_r_instant_epoch_ns_string, unclass(x))
}

#' @rdname temporal_equals
#' @export
temporal_equals.zutempo_instant <- function(x, other) {
  instant_compare(x, other) == 0L
}

#' @rdname temporal_add
#' @export
temporal_add.zutempo_instant <- function(x, other, ...) {
  ztp_check_dots_empty(...)
  new_instant(ztp_add_impl(
    x,
    other,
    function(z, dur) {
      .Call(C_ztp_r_instant_add, z, dur)
    },
    negate = FALSE
  ))
}

#' @rdname temporal_add
#' @export
temporal_subtract.zutempo_instant <- function(x, other, ...) {
  ztp_check_dots_empty(...)
  new_instant(ztp_add_impl(
    x,
    other,
    function(z, dur) {
      .Call(C_ztp_r_instant_add, z, dur)
    },
    negate = TRUE
  ))
}

ztp_instant_difference <- function(
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
    default_largest = "second",
    since = since
  )
  ztp_difference(
    x,
    other,
    ztp_as_instant,
    function(a, b, s) {
      .Call(
        C_ztp_r_instant_until,
        a,
        b,
        s$largest,
        s$smallest,
        s$increment,
        s$mode
      )
    },
    settings,
    since
  )
}

#' @rdname temporal_until
#' @export
temporal_until.zutempo_instant <- function(
  x,
  other,
  ...,
  largest_unit = NULL,
  smallest_unit = NULL,
  rounding_increment = 1,
  rounding_mode = "trunc"
) {
  ztp_check_dots_empty(...)
  ztp_instant_difference(
    x,
    other,
    largest_unit,
    smallest_unit,
    rounding_increment,
    rounding_mode,
    FALSE
  )
}

#' @rdname temporal_until
#' @export
temporal_since.zutempo_instant <- function(
  x,
  other,
  ...,
  largest_unit = NULL,
  smallest_unit = NULL,
  rounding_increment = 1,
  rounding_mode = "trunc"
) {
  ztp_check_dots_empty(...)
  ztp_instant_difference(
    x,
    other,
    largest_unit,
    smallest_unit,
    rounding_increment,
    rounding_mode,
    TRUE
  )
}

# The maximum rounding increment of an Instant is a whole day of the unit,
# inclusive (Temporal.Instant.prototype.round).
ztp_instant_unit_maximum <- c(
  hour = 24,
  minute = 1440,
  second = 86400,
  millisecond = 86400e3,
  microsecond = 86400e6,
  nanosecond = 86400e9
)

#' @rdname temporal_round
#' @export
temporal_round.zutempo_instant <- function(
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
  unit <- ztp_unit_code(smallest_unit, "time")
  mode <- ztp_rounding_mode_code(rounding_mode)
  increment <- ztp_increment(
    rounding_increment,
    ztp_instant_unit_maximum[[ztp_units[unit + 1L]]],
    inclusive = TRUE
  )
  new_instant(.Call(C_ztp_r_instant_round, unclass(x), increment, unit, mode))
}

#' @rdname temporal_to_string
#' @export
temporal_to_string.zutempo_instant <- function(x, ..., time_zone = NULL) {
  ztp_check_dots_empty(...)
  if (!is.null(time_zone)) {
    if (
      !is.character(time_zone) || length(time_zone) != 1L || is.na(time_zone)
    ) {
      stop_zutempo("`time_zone` must be a single string", kind = "type")
    }
  }
  if (!is.null(time_zone)) {
    time_zone <- ztp_tz_ensure(time_zone)
  }
  .Call(C_ztp_r_instant_format, unclass(x), time_zone, -1L)
}

#' The current time
#'
#' Temporal's `Temporal.Now.instant()`: the system clock as an `instant()`,
#' at the precision the platform's clock offers.
#'
#' @return An `instant()` of length one.
#' @examples
#' now_instant()
#' @export
now_instant <- function() {
  seconds <- as.numeric(Sys.time())
  whole <- floor(seconds)
  ns <- round((seconds - whole) * 1e9)
  if (ns >= 1e9) {
    whole <- whole + 1
    ns <- ns - 1e9
  }
  new_instant(complex(real = whole, imaginary = ns))
}

# --- plumbing ---------------------------------------------------------------

#' @export
`[.zutempo_instant` <- function(x, i, ...) ztp_subset(x, i)
#' @export
`[[.zutempo_instant` <- function(x, i, ...) ztp_subset2(x, i)
#' @export
`[<-.zutempo_instant` <- function(x, i, value) ztp_assign(x, i, value)
#' @export
`[[<-.zutempo_instant` <- function(x, i, value) ztp_assign(x, i, value)
#' @export
c.zutempo_instant <- function(...) ztp_combine(..1, list(...))
#' @export
rep.zutempo_instant <- function(x, ...) ztp_restore(rep(unclass(x), ...), x)
#' @export
unique.zutempo_instant <- function(x, ...) {
  ztp_restore(unique(unclass(x), ...), x)
}
#' @export
`length<-.zutempo_instant` <- function(x, value) {
  ztp_restore(`length<-`(unclass(x), value), x)
}
#' @export
as.data.frame.zutempo_instant <- function(x, ...) as.data.frame.vector(x, ...)
#' @export
xtfrm.zutempo_instant <- function(x) ztp_order_key_complex(x)
#' @export
format.zutempo_instant <- function(x, ...) temporal_to_string(x)
#' @export
as.character.zutempo_instant <- function(x, ...) temporal_to_string(x)
#' @export
print.zutempo_instant <- function(x, ...) ztp_print(x, ...)
