# Conversions with base R's date and time types (design 6.10): methods for
# base R's generics in one direction, the constructors in the other. Each
# goes through a specification operation where one exists and loses only
# what design 6.10 says.

#' Convert Temporal values to base R dates and times
#'
#' Methods for base R's `as.Date()`, `as.POSIXct()` and `as.POSIXlt()`, and
#' `temporal_to_difftime()`, which stands in for `as.difftime()` because
#' base R's is not a generic (design 6.10). The other direction is the
#' constructors: `plain_date(<Date>)`, `instant(<POSIXct>)`,
#' `zoned_date_time(<POSIXct>)`, `plain_date_time(<POSIXct>)`,
#' `plain_time(<difftime>)` and `duration(<difftime>)`.
#'
#' What each conversion loses:
#'
#' * `plain_date()` to `Date`: nothing; both count days from 1970-01-01.
#' * `instant()` to `POSIXct`: the nanoseconds, to the nearest double second
#'   (ties to even), which keeps about 240 ns at today's dates. The other
#'   way takes the double's exact value, rounded half to even to the
#'   nanosecond, so 0.1 s is 100 ms.
#' * `zoned_date_time()` to `POSIXct`: as `instant()`, with the zone as
#'   `tzone`. Zones that are equal under Temporal's `TimeZoneEquals`, such
#'   as `Asia/Calcutta` and `Asia/Kolkata`, count as one, and the first
#'   one names the `tzone`. A vector mixing other zones gets `"UTC"`. A
#'   whole-hour offset becomes its `Etc/GMT` zone, from `+14:00`
#'   (`Etc/GMT-14`) to `-12:00` (`Etc/GMT+12`); any other offset gets
#'   `"UTC"`, since base R cannot name it. The instant is kept either way.
#' * `zoned_date_time()` to `POSIXlt`: the fields in each element's own
#'   zone, with its offset in `gmtoff`; the seconds lose precision as
#'   above. The `tzone` is chosen as for `POSIXct`, so a vector mixing
#'   zones gets `"UTC"` with fields that are not in UTC. Such a `POSIXlt`
#'   does not round-trip: base R reads the fields in its `tzone`, so
#'   `as.POSIXct()` of it can move each element by its offset. Convert with
#'   `as.POSIXct()` instead, or give `tz` to put every element in one
#'   zone.
#' * `plain_date_time()` to `POSIXct` or `POSIXlt`: needs `tz`, and resolves
#'   a wall-clock time a zone skips or repeats with `disambiguation`, as
#'   [temporal_to_zoned_date_time()] does.
#' * `instant()`, `zoned_date_time()` and `plain_date_time()` to `Date`: the
#'   date, in `tz` for an `instant()`.
#' * `plain_time()` to `difftime`: seconds since midnight, as a double.
#' * `duration()` to `difftime`: its total in seconds, as [temporal_total()]
#'   gives it, so years, months and weeks need `relative_to` and a day is
#'   24 hours without it.
#'
#' `plain_year_month()` and `plain_month_day()` have no base R counterpart;
#' [temporal_to_plain_date()] supplies the missing day or year first.
#'
#' @param x A zutempo value.
#' @param tz A time zone: for an `instant()`, the zone to show it in (the
#'   default is `"UTC"`); for a `plain_date_time()`, the zone its wall-clock
#'   time is in, which has no default (`""` is the system zone); for a
#'   `zoned_date_time()`, a zone to show it in instead of its own.
#' @param disambiguation For a `plain_date_time()`: how to resolve a time a
#'   zone skips or repeats, as in [temporal_to_zoned_date_time()].
#' @param relative_to For a `duration()` with years, months or weeks: the
#'   date or zoned date-time they count from, as in [temporal_total()].
#' @param ... Must be empty.
#' @return A `Date`, `POSIXct`, `POSIXlt` or `difftime` (in seconds), `NA`
#'   where `x` is `NA`.
#' @examples
#' as.Date(plain_date("2026-03-07"))
#' as.POSIXct(instant("2026-03-07T12:00:00.123456789Z"))
#' as.POSIXct(zoned_date_time("2026-03-07T12:00[Europe/Lisbon]"))
#' as.POSIXlt(zoned_date_time("2026-03-07T12:00[Europe/Lisbon]"))
#' as.POSIXct(plain_date_time("2026-03-29T01:30"), tz = "Europe/Lisbon")
#' temporal_to_difftime(plain_time("12:30"))
#' temporal_to_difftime(duration("P1M"), relative_to = "2026-02-01")
#'
#' # And back.
#' plain_date(as.Date("2026-03-07"))
#' instant(as.POSIXct("2026-03-07 12:00:00", tz = "UTC"))
#' duration(as.difftime(90, units = "mins"))
#' @name base-r
NULL

#' @rdname base-r
#' @export
as.Date.zutempo_plain_date <- function(x, ...) {
  ztp_check_dots_empty(...)
  structure(as.double(unclass(x)), class = "Date")
}

#' @rdname base-r
#' @export
as.Date.zutempo_plain_date_time <- function(x, ...) {
  ztp_check_dots_empty(...)
  as.Date(temporal_to_plain_date(x))
}

#' @rdname base-r
#' @export
as.Date.zutempo_zoned_date_time <- function(x, tz = NULL, ...) {
  ztp_check_dots_empty(...)
  if (!is.null(tz)) {
    x <- temporal_with_time_zone(x, tz)
  }
  as.Date(temporal_to_plain_date(x))
}

#' @rdname base-r
#' @export
as.Date.zutempo_instant <- function(x, tz = "UTC", ...) {
  ztp_check_dots_empty(...)
  as.Date(temporal_to_plain_date(temporal_to_zoned_date_time_iso(x, tz)))
}

#' @rdname base-r
#' @export
as.POSIXct.zutempo_instant <- function(x, tz = "UTC", ...) {
  ztp_check_dots_empty(...)
  .POSIXct(.Call(C_ztp_r_instant_to_seconds, unclass(x)), tz = tz)
}

#' @rdname base-r
#' @export
as.POSIXct.zutempo_zoned_date_time <- function(x, tz = NULL, ...) {
  ztp_check_dots_empty(...)
  if (is.null(tz)) {
    tz <- ztp_posix_tzone(ztp_zdt_zones(x))
  }
  .POSIXct(.Call(C_ztp_r_instant_to_seconds, ztp_zdt_instant(x)), tz = tz)
}

#' @rdname base-r
#' @export
as.POSIXct.zutempo_plain_date_time <- function(
  x,
  tz,
  ...,
  disambiguation = "compatible"
) {
  ztp_check_dots_empty(...)
  as.POSIXct(ztp_zoned_from_plain(x, tz, disambiguation))
}

#' @rdname base-r
#' @export
as.POSIXlt.zutempo_zoned_date_time <- function(x, tz = NULL, ...) {
  ztp_check_dots_empty(...)
  if (!is.null(tz)) {
    x <- temporal_with_time_zone(x, tz)
  }
  ztp_posixlt(x)
}

#' @rdname base-r
#' @export
as.POSIXlt.zutempo_instant <- function(x, tz = "UTC", ...) {
  ztp_check_dots_empty(...)
  ztp_posixlt(temporal_to_zoned_date_time_iso(x, tz))
}

#' @rdname base-r
#' @export
as.POSIXlt.zutempo_plain_date_time <- function(
  x,
  tz,
  ...,
  disambiguation = "compatible"
) {
  ztp_check_dots_empty(...)
  ztp_posixlt(ztp_zoned_from_plain(x, tz, disambiguation))
}

#' @rdname base-r
#' @export
temporal_to_difftime <- function(x, ...) {
  UseMethod("temporal_to_difftime")
}

#' @rdname base-r
#' @export
temporal_to_difftime.zutempo_plain_time <- function(x, ...) {
  ztp_check_dots_empty(...)
  .difftime(as.double(unclass(x)) / 1e9, "secs")
}

#' @rdname base-r
#' @export
temporal_to_difftime.zutempo_duration <- function(x, ..., relative_to = NULL) {
  ztp_check_dots_empty(...)
  .difftime(temporal_total(x, "second", relative_to = relative_to), "secs")
}

#' @export
temporal_to_difftime.default <- function(x, ...) {
  stop_zutempo(
    sprintf(
      "cannot convert an object of class %s to a difftime",
      class(x)[1L]
    ),
    kind = "type"
  )
}

# --- helpers ------------------------------------------------------------------

# A POSIXct tzone for a zone table: the first zone when every zone in it
# is equal to it under TimeZoneEquals (design 4.2), "UTC" for a mix. Base
# R reads IANA names and "UTC", not offsets: a whole-hour offset becomes
# its Etc/GMT zone (the sign reversed, as tzdata writes it) where tzdata
# has one, from Etc/GMT-14 (+14:00) to Etc/GMT+12 (-12:00); any other
# offset becomes "UTC".
ztp_posix_tzone <- function(zones) {
  if (!length(zones)) {
    return("UTC")
  }
  if (length(zones) > 1L) {
    ztp_tz_ensure_all(zones)
    same <- .Call(
      C_ztp_r_zone_equals,
      rep(zones[[1L]], length(zones)),
      zones
    )
    if (!all(same)) {
      return("UTC")
    }
  }
  id <- zones[[1L]]
  if (!grepl("^[+-]", id)) {
    return(id)
  }
  east <- substr(id, 1L, 1L) == "+"
  hours <- as.integer(substr(id, 2L, 3L))
  minutes <- as.integer(substr(id, 5L, 6L))
  if (minutes != 0L || hours == 0L || hours > (if (east) 14L else 12L)) {
    return("UTC")
  }
  sprintf("Etc/GMT%s%d", if (east) "-" else "+", hours)
}

# A plain date-time placed in `tz` (design 6.10: no default; "" is the
# system zone).
ztp_zoned_from_plain <- function(x, tz, disambiguation) {
  if (missing(tz)) {
    stop_zutempo(
      "`tz` is required: the time zone the wall-clock time is in",
      kind = "type"
    )
  }
  if (identical(tz, "")) {
    tz <- now_time_zone_id()
  }
  temporal_to_zoned_date_time(x, tz, disambiguation = disambiguation)
}

# POSIXlt from zoned values: the fields in each element's zone, its offset
# in gmtoff, and its zone abbreviation and DST flag as base R reports them
# for that instant.
ztp_posixlt <- function(x) {
  n <- length(x)
  ct <- .Call(C_ztp_r_instant_to_seconds, ztp_zdt_instant(x))
  ids <- time_zone_id(x)
  frac <- (millisecond(x) * 1e6 + microsecond(x) * 1e3 + nanosecond(x)) / 1e9
  isdst <- rep(-1L, n)
  abbrev <- rep(NA_character_, n)
  for (id in unique(ids[!is.na(ids)])) {
    at <- which(ids == id)
    tz <- ztp_posix_tzone(id)
    if (identical(tz, id)) {
      lt <- unclass(as.POSIXlt(.POSIXct(ct[at], tz = tz), tz = tz))
      isdst[at] <- lt[["isdst"]]
      abbrev[at] <- lt[["zone"]]
    } else {
      isdst[at] <- 0L
      abbrev[at] <- id
    }
  }
  wday <- day_of_week(x) %% 7L
  lt <- list(
    sec = second(x) + frac,
    min = as.integer(minute(x)),
    hour = as.integer(hour(x)),
    mday = as.integer(day(x)),
    mon = as.integer(month(x)) - 1L,
    year = as.integer(year(x)) - 1900L,
    wday = as.integer(wday),
    yday = as.integer(day_of_year(x)) - 1L,
    isdst = as.integer(isdst),
    zone = abbrev,
    gmtoff = as.integer(round(offset_nanoseconds(x) / 1e9))
  )
  tzone <- ztp_posix_tzone(ztp_zdt_zones(x))
  structure(lt, class = c("POSIXlt", "POSIXt"), tzone = tzone)
}

# Date to PlainDate: exact, a fractional Date to the day it falls in.
ztp_plain_date_from_date <- function(x) {
  days <- floor(as.double(unclass(x)))
  bad <- which(!is.na(days) & (days < -100000001 | days > 100000000))
  if (length(bad)) {
    stop_zutempo(
      "the date is outside the range of a PlainDate",
      kind = "range",
      index = bad[1L]
    )
  }
  new_plain_date(as.integer(days))
}

# POSIXct (or POSIXlt, through POSIXct) to ZonedDateTime: the instant, in
# `time_zone`, else the tzone attribute, else the system zone.
ztp_zoned_from_posix <- function(x, time_zone = NULL) {
  x <- as.POSIXct(x)
  if (is.null(time_zone)) {
    time_zone <- attr(x, "tzone", exact = TRUE)[1L]
  }
  if (is.null(time_zone) || is.na(time_zone) || !nzchar(time_zone)) {
    time_zone <- now_time_zone_id()
  }
  temporal_to_zoned_date_time_iso(instant(x), time_zone)
}

# A difftime's exact seconds and nanoseconds (design 6.10).
ztp_difftime_parts <- function(x) {
  .Call(C_ztp_r_seconds_split, as.double(x, units = "secs"))
}

# A difftime as a time of day: seconds since midnight, below 24 hours.
ztp_plain_time_from_difftime <- function(x) {
  parts <- ztp_difftime_parts(x)
  ns <- parts[["seconds"]] * 1e9 + parts[["nanoseconds"]]
  bad <- which(!is.na(ns) & (ns < 0 | ns >= 86400e9))
  if (length(bad)) {
    stop_zutempo(
      "a time of day is from 0 to 24 hours after midnight",
      kind = "range",
      index = bad[1L]
    )
  }
  new_plain_time(ns)
}
