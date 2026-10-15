#' Exact times in a time zone: Temporal's ZonedDateTime
#'
#' A `zoned_date_time()` is an exact time together with the time zone it is
#' read in, so that it has both an `instant()` and a wall-clock date and
#' time. Every element carries its own zone (design 4.2): the vector is an
#' `instant()` with an integer zone code per element into the `zones`
#' attribute, the identifiers in the database's case. The constructor is
#' `Temporal.ZonedDateTime` and `Temporal.ZonedDateTime.from()` in one.
#'
#' A local time that does not exist (a clock gap) or exists twice (a fold)
#' is resolved by `disambiguation` (design 6.3): `"compatible"` (the
#' default) moves a gap forward by its length and takes the earlier of a
#' fold, `"earlier"` and `"later"` take that side, `"reject"` raises a
#' `zutempo_range_error`. When the fields or the string carry a UTC offset
#' as well as a zone, `offset` says what to do when the two disagree:
#' `"reject"` (the default for the constructor) raises, `"use"` trusts the
#' offset, `"ignore"` trusts the zone, `"prefer"` (the default for
#' `temporal_with()`) trusts the offset when it is one of the zone's
#' candidates and the zone otherwise.
#'
#' @param year The year, or a string in RFC 9557 form with the zone in
#'   brackets (`"2026-03-07T12:00[America/New_York]"`,
#'   `"2026-03-07T12:00-05:00[America/New_York]"`,
#'   `"2026-03-07T17:00Z[Europe/Lisbon]"` for the instant shown in that
#'   zone, `"2026-03-07[+05:30]"` for the start of that day), or a
#'   `zoned_date_time()` to return as is.
#' @param month,day The month (1 to 12) and day of the month, when `year`
#'   is a number. `month` may be replaced by `month_code`.
#' @param hour,minute,second,millisecond,microsecond,nanosecond The time
#'   fields, 0 by default.
#' @param ... Must be empty.
#' @param time_zone The time zone of each value, when `year` is a number:
#'   an IANA identifier such as `"Europe/Lisbon"`, `"UTC"`, or a fixed
#'   offset such as `"+05:30"`; recycled with the fields. Identifiers match
#'   regardless of case and are stored in the database's case.
#' @param month_code The month as `"M01"` to `"M12"`, instead of `month`.
#' @param offset_string The UTC offset the fields are given in, such as
#'   `"-05:00"`, when the fields carry one (Temporal's `offset` field);
#'   `offset` decides what happens when it disagrees with the zone.
#' @param disambiguation How to resolve a local time in a clock gap or
#'   fold: `"compatible"`, `"earlier"`, `"later"` or `"reject"`.
#' @param offset What to do with a UTC offset that disagrees with the zone:
#'   `"reject"`, `"use"`, `"ignore"` or `"prefer"`.
#' @param overflow `"constrain"` (the default) clamps each field to its
#'   range, `"reject"` raises a `zutempo_range_error` (design 6.2).
#' @param x,y `zoned_date_time()` values or strings, for
#'   `zoned_date_time_compare()`, which orders by the instant alone.
#' @return A `zoned_date_time()` vector; `zoned_date_time_compare()`
#'   returns an integer vector of -1, 0 and 1.
#' @examples
#' zoned_date_time("2026-03-07T12:00[America/New_York]")
#' zoned_date_time(2026, 3, 8, 2, 30, time_zone = "America/New_York")
#' zoned_date_time(2026, 11, 1, 1, 30, time_zone = "America/New_York",
#'   disambiguation = "later")
#' zoned_date_time("2026-07-01T12:00+05:30[Asia/Kolkata]")
#' zoned_date_time_compare(
#'   "2026-03-07T12:00[America/New_York]",
#'   "2026-03-07T18:00[Europe/Lisbon]"
#' )
#' @export
zoned_date_time <- function(
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
  time_zone = NULL,
  month_code = NULL,
  offset_string = NULL,
  disambiguation = "compatible",
  offset = "reject",
  overflow = "constrain"
) {
  ztp_check_dots_empty(...)
  dis <- ztp_disambiguation_code(disambiguation)
  off <- ztp_offset_option_code(offset)
  ov <- ztp_overflow_code(overflow)
  if (missing(year)) {
    stop_zutempo("`year` is required", kind = "type")
  }
  if (inherits(year, "zutempo_zoned_date_time")) {
    ztp_check_no_fields(month, day, month_code)
    return(year)
  }
  if (is.character(year)) {
    ztp_check_no_fields(month, day, month_code)
    if (!is.null(time_zone)) {
      stop_zutempo(
        "`time_zone` must be NULL when reading strings; the string carries the zone",
        kind = "type"
      )
    }
    return(ztp_zoned_from_strings(year, dis, off))
  }
  if (!ztp_is_field_like(year)) {
    stop_zutempo(
      sprintf(
        "cannot make a zoned_date_time from an object of class %s",
        class(year)[1L]
      ),
      kind = "type"
    )
  }
  if (is.null(time_zone)) {
    stop_zutempo("`time_zone` is required", kind = "type")
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
  fields <- ztp_recycle(c(
    date,
    time,
    list(time_zone = ztp_zone_ids(time_zone))
  ))
  local <- do.call(
    .Call,
    c(list(C_ztp_r_plain_date_time_from_fields), unname(fields[1:9]), list(ov))
  )
  ztp_zoned_resolve(
    local,
    fields[["time_zone"]],
    offset_string,
    dis,
    off,
    behaviour_default = 2L
  )
}

# --- construction helpers -----------------------------------------------------

new_zoned_date_time <- function(
  z = complex(),
  codes = integer(),
  zones = character()
) {
  z[is.na(z)] <- NA_complex_
  codes[is.na(z)] <- NA_integer_
  # Drop identifiers no element uses and recode in order of first use, so
  # that equal vectors are identical() whatever their history.
  used <- unique(codes[!is.na(codes)])
  zones <- zones[used]
  codes <- match(codes, used)
  structure(
    z,
    zone = codes,
    zones = zones,
    class = "zutempo_zoned_date_time"
  )
}

# The instant, the codes, the table and the identifier of each element.
ztp_zdt_instant <- function(x) {
  z <- unclass(x)
  attributes(z) <- NULL
  z
}
ztp_zdt_codes <- function(x) attr(x, "zone", exact = TRUE)
ztp_zdt_zones <- function(x) attr(x, "zones", exact = TRUE)
ztp_zdt_ids <- function(x) ztp_zdt_zones(x)[ztp_zdt_codes(x)]

# Check and normalise time zone identifiers: strings, resolved through
# the database (design 8), NA kept.
ztp_zone_ids <- function(time_zone, name = "time_zone") {
  if (inherits(time_zone, "zutempo_zoned_date_time")) {
    return(ztp_zdt_ids(time_zone))
  }
  if (!is.character(time_zone)) {
    stop_zutempo(
      sprintf("`%s` must be a character vector of time zone identifiers", name),
      kind = "type"
    )
  }
  ztp_tz_ensure_all(time_zone)
}

# Build a vector from instants and the identifier of each element.
ztp_zoned_build <- function(z, ids) {
  zones <- unique(ids[!is.na(ids)])
  new_zoned_date_time(z, match(ids, zones), zones)
}

# ToTemporalZonedDateTime for strings.
ztp_zoned_from_strings <- function(x, dis, off) {
  parts <- .Call(C_ztp_r_zoned_parse, x)
  ids <- ztp_tz_ensure_all(parts$tz)
  zones <- unique(ids[!is.na(ids)])
  codes <- match(ids, zones)
  z <- .Call(
    C_ztp_r_zoned_interpret,
    parts$day,
    parts$ns,
    codes,
    zones,
    parts$behaviour,
    parts$offset_ns,
    dis,
    off,
    parts$match_minutes
  )
  new_zoned_date_time(z, codes, zones)
}

# InterpretISODateTimeOffset over a PlainDateTime vector (complex of day
# and nanoseconds of day) with a zone identifier per element and an
# optional offset string per element. `behaviour_default` is the
# behaviour without an offset: 2 wall, 3 start of day.
ztp_zoned_resolve <- function(
  local,
  ids,
  offset_string,
  dis,
  off,
  behaviour_default = 2L
) {
  n <- length(local)
  zones <- unique(ids[!is.na(ids)])
  codes <- match(ids, zones)
  if (is.null(offset_string)) {
    offset_ns <- rep(NA_real_, n)
    behaviour <- rep(behaviour_default, n)
  } else {
    if (!is.character(offset_string)) {
      stop_zutempo("`offset_string` must be a character vector", kind = "type")
    }
    offset_string <- ztp_recycle(list(offset_string, local))[[1L]]
    offset_ns <- .Call(C_ztp_r_parse_offset_string, offset_string)
    behaviour <- ifelse(is.na(offset_ns), behaviour_default, 0L)
  }
  z <- .Call(
    C_ztp_r_zoned_interpret,
    Re(local),
    Im(local),
    codes,
    zones,
    as.integer(behaviour),
    offset_ns,
    dis,
    off,
    rep(FALSE, n)
  )
  new_zoned_date_time(z, codes, zones)
}

# GetTemporalDisambiguationOption and GetTemporalOffsetOption, as the codes
# of src/ztp_zoned.h.
ztp_disambiguation_code <- function(disambiguation) {
  ztp_match_option(
    disambiguation,
    c("compatible", "earlier", "later", "reject"),
    "disambiguation"
  ) -
    1L
}

ztp_offset_option_code <- function(offset) {
  ztp_match_option(offset, c("prefer", "use", "ignore", "reject"), "offset") -
    1L
}

ztp_as_zoned_date_time <- function(x) {
  if (inherits(x, "zutempo_zoned_date_time")) x else zoned_date_time(x)
}

# A single time zone identifier argument, resolved.
ztp_single_zone <- function(time_zone, name = "time_zone") {
  if (
    inherits(time_zone, "zutempo_zoned_date_time") && length(time_zone) == 1L
  ) {
    return(ztp_zdt_ids(time_zone))
  }
  if (!is.character(time_zone) || length(time_zone) != 1L || is.na(time_zone)) {
    stop_zutempo(sprintf("`%s` must be a single string", name), kind = "type")
  }
  ztp_tz_ensure(time_zone)
}

# --- statics and equality -----------------------------------------------------

#' @rdname zoned_date_time
#' @export
zoned_date_time_compare <- function(x, y) {
  instant_compare(
    temporal_to_instant(ztp_as_zoned_date_time(x)),
    temporal_to_instant(ztp_as_zoned_date_time(y))
  )
}

#' @rdname temporal_equals
#' @export
temporal_equals.zutempo_zoned_date_time <- function(x, other) {
  other <- ztp_as_zoned_date_time(other)
  args <- ztp_recycle(list(ztp_zdt_instant(x), ztp_zdt_instant(other)))
  same_instant <- instant_compare(
    new_instant(args[[1L]]),
    new_instant(args[[2L]])
  ) ==
    0L
  ztp_zdt_zones_ready(x)
  ztp_zdt_zones_ready(other)
  ids <- ztp_recycle(list(ztp_zdt_ids(x), ztp_zdt_ids(other)))
  same_zone <- .Call(C_ztp_r_zone_equals, ids[[1L]], ids[[2L]])
  same_instant & same_zone
}

# --- fields ---------------------------------------------------------------------

#' @rdname temporal_to_plain_date
#' @export
temporal_to_plain_date_time.zutempo_zoned_date_time <- function(
  x,
  time = NULL
) {
  if (!is.null(time)) {
    stop_zutempo("`time` is not used for a zoned_date_time", kind = "type")
  }
  new_plain_date_time(.Call(
    C_ztp_r_zoned_local,
    ztp_zdt_instant(x),
    ztp_zdt_codes(x),
    ztp_zdt_zones_ready(x)
  ))
}

#' @rdname temporal_to_plain_date
#' @export
temporal_to_plain_date.zutempo_zoned_date_time <- function(x, ...) {
  ztp_check_dots_empty(...)
  temporal_to_plain_date(temporal_to_plain_date_time(x))
}

#' @rdname temporal_to_plain_date
#' @export
temporal_to_plain_time.zutempo_zoned_date_time <- function(x) {
  temporal_to_plain_time(temporal_to_plain_date_time(x))
}

#' Convert to and from zoned values
#'
#' Temporal's `toInstant()`, `toZonedDateTimeISO()` and `toZonedDateTime()`.
#' An `instant()` becomes a `zoned_date_time()` in any zone; a
#' `plain_date_time()` is resolved in the zone with `disambiguation`
#' (design 6.3); a `plain_date()` gives the start of that day in the zone,
#' or the given `plain_time` on that day.
#'
#' @param x A zutempo value.
#' @param time_zone A time zone identifier (`"Europe/Lisbon"`, `"UTC"`,
#'   `"+05:30"`), or a `zoned_date_time()` of length one to take the zone
#'   from.
#' @param ... Must be empty.
#' @param plain_time For a `plain_date()`: a `plain_time()`, a string a
#'   `plain_time()` reads, or `NULL` for the start of the day.
#' @param disambiguation For a `plain_date_time()`: how to resolve a local
#'   time in a clock gap or fold, as for [zoned_date_time()].
#' @return An `instant()` or a `zoned_date_time()`.
#' @examples
#' x <- zoned_date_time("2026-03-07T12:00[America/New_York]")
#' temporal_to_instant(x)
#' temporal_to_zoned_date_time_iso(instant("2026-03-07T17:00Z"), "Europe/Lisbon")
#' temporal_to_zoned_date_time(plain_date("2026-03-08"), "America/New_York")
#' temporal_to_zoned_date_time(
#'   plain_date_time("2026-03-08T02:30"),
#'   "America/New_York",
#'   disambiguation = "earlier"
#' )
#' @order 1
#' @export
temporal_to_instant <- function(x) {
  UseMethod("temporal_to_instant")
}

#' @rdname temporal_to_instant
#' @export
temporal_to_instant.zutempo_zoned_date_time <- function(x) {
  new_instant(ztp_zdt_instant(x))
}

#' @rdname temporal_to_instant
#' @export
temporal_to_zoned_date_time_iso <- function(x, time_zone) {
  UseMethod("temporal_to_zoned_date_time_iso")
}

#' @rdname temporal_to_instant
#' @export
temporal_to_zoned_date_time_iso.zutempo_instant <- function(x, time_zone) {
  id <- ztp_single_zone(time_zone)
  z <- unclass(x)
  ztp_zoned_build(z, rep(id, length(z)))
}

#' @rdname temporal_to_instant
#' @export
temporal_to_zoned_date_time <- function(x, time_zone, ...) {
  UseMethod("temporal_to_zoned_date_time")
}

#' @rdname temporal_to_instant
#' @export
temporal_to_zoned_date_time.zutempo_plain_date <- function(
  x,
  time_zone,
  ...,
  plain_time = NULL
) {
  ztp_check_dots_empty(...)
  id <- ztp_single_zone(time_zone)
  if (is.null(plain_time)) {
    local <- unclass(temporal_to_plain_date_time(x))
    return(ztp_zoned_resolve(
      local,
      rep(id, length(local)),
      NULL,
      0L,
      3L,
      behaviour_default = 3L
    ))
  }
  local <- unclass(temporal_to_plain_date_time(x, plain_time))
  ztp_zoned_resolve(
    local,
    rep(id, length(local)),
    NULL,
    0L,
    3L,
    behaviour_default = 2L
  )
}

#' @rdname temporal_to_instant
#' @export
temporal_to_zoned_date_time.zutempo_plain_date_time <- function(
  x,
  time_zone,
  ...,
  disambiguation = "compatible"
) {
  ztp_check_dots_empty(...)
  id <- ztp_single_zone(time_zone)
  dis <- ztp_disambiguation_code(disambiguation)
  local <- unclass(x)
  ztp_zoned_resolve(
    local,
    rep(id, length(local)),
    NULL,
    dis,
    3L,
    behaviour_default = 2L
  )
}

#' @rdname temporal_fields
#' @export
epoch_milliseconds.zutempo_zoned_date_time <- function(x, ...) {
  epoch_milliseconds(temporal_to_instant(x))
}

#' @rdname temporal_fields
#' @export
epoch_nanoseconds.zutempo_zoned_date_time <- function(x, ...) {
  epoch_nanoseconds(temporal_to_instant(x))
}

#' @rdname temporal_fields
#' @export
offset_nanoseconds <- function(x, ...) UseMethod("offset_nanoseconds")
#' @rdname temporal_fields
#' @export
offset_nanoseconds.default <- function(x, ...) {
  ztp_masked("offset_nanoseconds", x, ...)
}
#' @rdname temporal_fields
#' @export
offset_nanoseconds.zutempo_zoned_date_time <- function(x, ...) {
  .Call(
    C_ztp_r_zoned_offset,
    ztp_zdt_instant(x),
    ztp_zdt_codes(x),
    ztp_zdt_zones_ready(x)
  )
}

#' @rdname temporal_fields
#' @export
offset <- function(x, ...) UseMethod("offset")
#' @rdname temporal_fields
#' @export
offset.default <- function(x, ...) ztp_masked("offset", x, ...)
#' @rdname temporal_fields
#' @export
offset.zutempo_zoned_date_time <- function(x, ...) {
  .Call(C_ztp_r_format_offset_exact, offset_nanoseconds(x))
}

#' @rdname temporal_fields
#' @export
time_zone_id <- function(x, ...) UseMethod("time_zone_id")
#' @rdname temporal_fields
#' @export
time_zone_id.default <- function(x, ...) ztp_masked("time_zone_id", x, ...)
#' @rdname temporal_fields
#' @export
time_zone_id.zutempo_zoned_date_time <- function(x, ...) ztp_zdt_ids(x)

#' @rdname temporal_fields
#' @export
hours_in_day <- function(x, ...) UseMethod("hours_in_day")
#' @rdname temporal_fields
#' @export
hours_in_day.default <- function(x, ...) ztp_masked("hours_in_day", x, ...)
#' @rdname temporal_fields
#' @export
hours_in_day.zutempo_zoned_date_time <- function(x, ...) {
  .Call(
    C_ztp_r_zoned_hours_in_day,
    ztp_zdt_instant(x),
    ztp_zdt_codes(x),
    ztp_zdt_zones_ready(x)
  )
}

# --- with ----------------------------------------------------------------------

#' @rdname temporal_with
#' @export
temporal_with.zutempo_zoned_date_time <- function(
  x,
  ...,
  disambiguation = "compatible",
  offset = "prefer",
  overflow = "constrain"
) {
  fields <- ztp_partial_fields(
    list(...),
    c(
      "year",
      "month",
      "month_code",
      "day",
      ztp_time_field_names,
      "offset_string"
    )
  )
  dis <- ztp_disambiguation_code(disambiguation)
  off <- ztp_offset_option_code(offset)
  ov <- ztp_overflow_code(overflow)
  local <- temporal_to_plain_date_time(x)
  base <- list(
    year = as.double(ztp_date_time_field(local, "year")),
    month = as.double(ztp_date_time_field(local, "month")),
    day = as.double(ztp_date_time_field(local, "day"))
  )
  date <- ztp_merge_date_fields(
    base,
    fields[intersect(names(fields), c("year", "month", "month_code", "day"))]
  )
  time <- lapply(ztp_time_field_names, function(f) {
    as.double(ztp_date_time_field(local, f))
  })
  names(time) <- ztp_time_field_names
  for (f in intersect(names(fields), ztp_time_field_names)) {
    time[[f]] <- ztp_as_field(fields[[f]], f)
  }
  offset_string <- if (is.null(fields[["offset_string"]])) {
    offset(x)
  } else {
    fields[["offset_string"]]
  }
  ztp_zdt_zones_ready(x)
  merged <- ztp_recycle(c(
    date,
    time,
    list(ids = ztp_zdt_ids(x), offset_string = offset_string)
  ))
  regulated <- do.call(
    .Call,
    c(list(C_ztp_r_plain_date_time_from_fields), unname(merged[1:9]), list(ov))
  )
  ztp_zoned_resolve(
    regulated,
    merged[["ids"]],
    merged[["offset_string"]],
    dis,
    off
  )
}

#' @rdname temporal_with
#' @export
temporal_with_plain_time.zutempo_zoned_date_time <- function(x, time = NULL) {
  if (is.null(time)) {
    return(temporal_start_of_day(x))
  }
  local <- temporal_with_plain_time(temporal_to_plain_date_time(x), time)
  ztp_zdt_zones_ready(x)
  ids <- ztp_recycle(list(ztp_zdt_ids(x), unclass(local)))[[1L]]
  ztp_zoned_resolve(unclass(local), ids, NULL, 0L, 3L)
}

#' @rdname temporal_with
#' @export
temporal_with_time_zone <- function(x, time_zone) {
  UseMethod("temporal_with_time_zone")
}

#' @rdname temporal_with
#' @export
temporal_with_time_zone.zutempo_zoned_date_time <- function(x, time_zone) {
  ids <- ztp_zone_ids(time_zone)
  args <- ztp_recycle(list(ztp_zdt_instant(x), ids))
  ztp_zoned_build(args[[1L]], args[[2L]])
}

#' @rdname temporal_with
#' @export
temporal_with_calendar.zutempo_zoned_date_time <- function(x, calendar) {
  ztp_check_calendar(calendar)
  x
}

#' The start of a day in a time zone
#'
#' Temporal's `startOfDay()`: the first instant of the calendar day of each
#' value in its own zone, which is not always midnight (a day may start at
#' 01:00 when a clock gap removes midnight, as in Asuncion or Havana).
#'
#' @param x A `zoned_date_time()`.
#' @return A `zoned_date_time()`.
#' @examples
#' temporal_start_of_day(zoned_date_time("2026-03-07T12:00[America/New_York]"))
#' @export
temporal_start_of_day <- function(x) {
  UseMethod("temporal_start_of_day")
}

#' @rdname temporal_start_of_day
#' @export
temporal_start_of_day.zutempo_zoned_date_time <- function(x) {
  z <- .Call(
    C_ztp_r_zoned_start_of_day,
    ztp_zdt_instant(x),
    ztp_zdt_codes(x),
    ztp_zdt_zones_ready(x)
  )
  new_zoned_date_time(z, ztp_zdt_codes(x), ztp_zdt_zones(x))
}

#' @rdname temporal_to_string
#' @export
temporal_to_string.zutempo_zoned_date_time <- function(x, ...) {
  ztp_check_dots_empty(...)
  .Call(
    C_ztp_r_zoned_format,
    ztp_zdt_instant(x),
    ztp_zdt_codes(x),
    ztp_zdt_zones_ready(x),
    -1L,
    TRUE,
    0L
  )
}

# --- Now ------------------------------------------------------------------------

#' The current time in a time zone
#'
#' Temporal's `Temporal.Now` functions: the system time zone as base R
#' reads it (`Sys.timezone()`, falling back to `"UTC"`), and the current
#' time as a `zoned_date_time()`, `plain_date_time()`, `plain_date()` or
#' `plain_time()` in that zone or in `time_zone`.
#'
#' @param time_zone A time zone identifier, or `NULL` for the system zone.
#' @return `now_time_zone_id()` returns a string; the others the value named.
#' @examples
#' now_time_zone_id()
#' now_zoned_date_time_iso()
#' now_plain_date_time_iso("Asia/Tokyo")
#' now_plain_date_iso("Pacific/Auckland")
#' now_plain_time_iso("UTC")
#' @export
now_time_zone_id <- function() {
  # TZ first, as the C library base R formats with does; Sys.timezone()
  # caches its first answer for the session and ignores a later TZ.
  id <- Sys.getenv("TZ")
  if (!nzchar(id)) {
    id <- tryCatch(
      Sys.timezone(),
      error = function(e) NA_character_,
      warning = function(w) NA_character_
    )
  }
  if (is.na(id) || !nzchar(id)) {
    return("UTC")
  }
  tryCatch(ztp_tz_ensure(id), error = function(e) "UTC")
}

ztp_now_zone <- function(time_zone) {
  if (is.null(time_zone)) now_time_zone_id() else ztp_single_zone(time_zone)
}

#' @rdname now_time_zone_id
#' @export
now_zoned_date_time_iso <- function(time_zone = NULL) {
  id <- ztp_now_zone(time_zone)
  ztp_zoned_build(unclass(now_instant()), id)
}

#' @rdname now_time_zone_id
#' @export
now_plain_date_time_iso <- function(time_zone = NULL) {
  temporal_to_plain_date_time(now_zoned_date_time_iso(time_zone))
}

#' @rdname now_time_zone_id
#' @export
now_plain_date_iso <- function(time_zone = NULL) {
  temporal_to_plain_date(now_zoned_date_time_iso(time_zone))
}

#' @rdname now_time_zone_id
#' @export
now_plain_time_iso <- function(time_zone = NULL) {
  temporal_to_plain_time(now_zoned_date_time_iso(time_zone))
}

# --- plumbing -------------------------------------------------------------------

#' @export
`[.zutempo_zoned_date_time` <- function(x, i, ...) {
  codes <- ztp_zdt_codes(x)
  new_zoned_date_time(ztp_zdt_instant(x)[i], codes[i], ztp_zdt_zones(x))
}
#' @export
`[[.zutempo_zoned_date_time` <- function(x, i, ...) {
  codes <- ztp_zdt_codes(x)
  new_zoned_date_time(ztp_zdt_instant(x)[[i]], codes[[i]], ztp_zdt_zones(x))
}

ztp_zdt_assign <- function(x, i, value) {
  if (is.null(value)) {
    stop_zutempo("cannot assign NULL", kind = "type")
  }
  if (is.logical(value) && all(is.na(value))) {
    value <- new_zoned_date_time(
      rep(NA_complex_, length(value)),
      rep(NA_integer_, length(value))
    )
  } else {
    ztp_check_same_class(x, value, "the replacement value")
  }
  z <- ztp_zdt_instant(x)
  ids <- ztp_zdt_ids(x)
  z[i] <- ztp_zdt_instant(value)
  ids[i] <- ztp_zdt_ids(value)
  ztp_zoned_build(z, ids)
}

#' @export
`[<-.zutempo_zoned_date_time` <- function(x, i, value) {
  ztp_zdt_assign(x, i, value)
}
#' @export
`[[<-.zutempo_zoned_date_time` <- function(x, i, value) {
  ztp_zdt_assign(x, i, value)
}

#' @export
c.zutempo_zoned_date_time <- function(...) {
  dots <- list(...)
  dots <- dots[!vapply(dots, is.null, logical(1L))]
  x <- dots[[1L]]
  parts <- lapply(dots, function(d) {
    if (is.logical(d) && all(is.na(d))) {
      return(list(
        z = rep(NA_complex_, length(d)),
        ids = rep(NA_character_, length(d))
      ))
    }
    ztp_check_same_class(x, d, "every argument of c()")
    list(z = ztp_zdt_instant(d), ids = ztp_zdt_ids(d))
  })
  ztp_zoned_build(
    do.call(c, lapply(parts, `[[`, "z")),
    do.call(c, lapply(parts, `[[`, "ids"))
  )
}

#' @export
rep.zutempo_zoned_date_time <- function(x, ...) {
  idx <- rep(seq_along(x), ...)
  x[idx]
}

#' @export
unique.zutempo_zoned_date_time <- function(x, ...) {
  key <- paste(format(ztp_zdt_instant(x), digits = 17), ztp_zdt_ids(x))
  x[!duplicated(key)]
}

#' @export
`length<-.zutempo_zoned_date_time` <- function(x, value) {
  n <- length(x)
  if (value <= n) {
    return(x[seq_len(value)])
  }
  c(x, rep(NA, value - n))
}

#' @export
as.data.frame.zutempo_zoned_date_time <- function(x, ...) {
  as.data.frame.vector(x, ...)
}

#' @export
xtfrm.zutempo_zoned_date_time <- function(x) {
  ztp_order_key_complex(ztp_zdt_instant(x))
}

#' @export
format.zutempo_zoned_date_time <- function(x, ...) temporal_to_string(x)
#' @export
as.character.zutempo_zoned_date_time <- function(x, ...) temporal_to_string(x)
#' @export
print.zutempo_zoned_date_time <- function(x, ...) ztp_print(x, ...)
#' @export
is.na.zutempo_zoned_date_time <- function(x) is.na(ztp_zdt_instant(x))

# --- arithmetic (stage 8) --------------------------------------------------------

# Recycle a zoned vector and a duration to a common length; returns the
# instants, the codes and the loaded zone table, plus the duration data.
ztp_zoned_with_duration <- function(x, other, negate) {
  other <- ztp_as_duration(other)
  n <- ztp_common_length(x, other)
  data <- ztp_duration_data(other, n)
  if (negate) {
    data <- ztp_negate_duration_data(data)
  }
  idx <- rep_len(seq_along(x), n)
  list(
    z = ztp_zdt_instant(x)[idx],
    codes = ztp_zdt_codes(x)[idx],
    zones = ztp_zdt_zones_ready(x),
    data = data
  )
}

#' @rdname temporal_add
#' @export
temporal_add.zutempo_zoned_date_time <- function(x, other, ..., overflow = "constrain") {
  ztp_check_dots_empty(...)
  ov <- ztp_overflow_code(overflow)
  a <- ztp_zoned_with_duration(x, other, negate = FALSE)
  new_zoned_date_time(.Call(C_ztp_r_zoned_add, a$z, a$codes, a$zones, a$data, ov), a$codes, a$zones)
}

#' @rdname temporal_add
#' @export
temporal_subtract.zutempo_zoned_date_time <- function(x, other, ..., overflow = "constrain") {
  ztp_check_dots_empty(...)
  ov <- ztp_overflow_code(overflow)
  a <- ztp_zoned_with_duration(x, other, negate = TRUE)
  new_zoned_date_time(.Call(C_ztp_r_zoned_add, a$z, a$codes, a$zones, a$data, ov), a$codes, a$zones)
}

ztp_zoned_difference <- function(
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
    default_largest = "hour",
    since = since
  )
  other <- ztp_as_zoned_date_time(other)
  n <- ztp_common_length(x, other)
  ix <- rep_len(seq_along(x), n)
  io <- rep_len(seq_along(other), n)
  out <- .Call(
    C_ztp_r_zoned_until,
    ztp_zdt_instant(x)[ix],
    ztp_zdt_codes(x)[ix],
    ztp_zdt_zones_ready(x),
    ztp_zdt_instant(other)[io],
    ztp_zdt_codes(other)[io],
    ztp_zdt_zones_ready(other),
    settings$largest,
    settings$smallest,
    settings$increment,
    settings$mode
  )
  if (since) {
    out <- ztp_negate_duration_data(out)
  }
  new_duration(out)
}

#' @rdname temporal_until
#' @export
temporal_until.zutempo_zoned_date_time <- function(
  x,
  other,
  ...,
  largest_unit = NULL,
  smallest_unit = NULL,
  rounding_increment = 1,
  rounding_mode = "trunc"
) {
  ztp_check_dots_empty(...)
  ztp_zoned_difference(x, other, largest_unit, smallest_unit, rounding_increment, rounding_mode, FALSE)
}

#' @rdname temporal_until
#' @export
temporal_since.zutempo_zoned_date_time <- function(
  x,
  other,
  ...,
  largest_unit = NULL,
  smallest_unit = NULL,
  rounding_increment = 1,
  rounding_mode = "trunc"
) {
  ztp_check_dots_empty(...)
  ztp_zoned_difference(x, other, largest_unit, smallest_unit, rounding_increment, rounding_mode, TRUE)
}

#' @rdname temporal_round
#' @export
temporal_round.zutempo_zoned_date_time <- function(
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
  opts <- ztp_round_options(smallest_unit, rounding_increment, rounding_mode, allow_day = TRUE)
  z <- .Call(
    C_ztp_r_zoned_round,
    ztp_zdt_instant(x),
    ztp_zdt_codes(x),
    ztp_zdt_zones_ready(x),
    opts$increment,
    opts$unit,
    opts$mode
  )
  new_zoned_date_time(z, ztp_zdt_codes(x), ztp_zdt_zones(x))
}

#' Time zone transitions
#'
#' Temporal's `getTimeZoneTransition()`: the next or previous instant at
#' which each value's zone changes its UTC offset, as a `zoned_date_time()`
#' in that zone, or `NA` when there is none within the representable range
#' or the zone is a fixed offset.
#'
#' @param x A `zoned_date_time()`.
#' @param direction `"next"` or `"previous"`.
#' @return A `zoned_date_time()`.
#' @examples
#' x <- zoned_date_time("2026-01-15T12:00[America/New_York]")
#' temporal_get_time_zone_transition(x, "next")
#' temporal_get_time_zone_transition(x, "previous")
#' @export
temporal_get_time_zone_transition <- function(x, direction) {
  UseMethod("temporal_get_time_zone_transition")
}

#' @rdname temporal_get_time_zone_transition
#' @export
temporal_get_time_zone_transition.zutempo_zoned_date_time <- function(x, direction) {
  if (missing(direction)) {
    stop_zutempo("`direction` is required", kind = "type")
  }
  dir <- ztp_match_option(direction, c("next", "previous"), "direction")
  z <- .Call(
    C_ztp_r_zoned_transition,
    ztp_zdt_instant(x),
    ztp_zdt_codes(x),
    ztp_zdt_zones_ready(x),
    if (dir == 1L) 1L else -1L
  )
  new_zoned_date_time(z, ztp_zdt_codes(x), ztp_zdt_zones(x))
}
