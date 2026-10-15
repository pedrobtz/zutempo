# The field accessors of design 5: one S3 generic per Temporal property,
# with methods for the zutempo classes and a default that calls the
# function of the same name from another attached package (lubridate's
# year(), for example), so that masking costs nothing.

# Field codes shared with src/ztp_r_plain.c.
ztp_field_codes <- c(
  year = 1L,
  month = 2L,
  day = 3L,
  day_of_week = 4L,
  day_of_year = 5L,
  week_of_year = 6L,
  year_of_week = 7L,
  days_in_month = 8L,
  days_in_year = 9L,
  in_leap_year = 10L,
  hour = 11L,
  minute = 12L,
  second = 13L,
  millisecond = 14L,
  microsecond = 15L,
  nanosecond = 16L
)

ztp_date_field <- function(x, field) {
  .Call(C_ztp_r_plain_date_field, unclass(x), ztp_field_codes[[field]])
}

ztp_time_field <- function(x, field) {
  .Call(C_ztp_r_plain_time_field, unclass(x), ztp_field_codes[[field]])
}

ztp_date_time_field <- function(x, field) {
  .Call(C_ztp_r_plain_date_time_field, unclass(x), ztp_field_codes[[field]])
}

ztp_month_code <- function(month) {
  ifelse(is.na(month), NA_character_, sprintf("M%02d", month))
}

# NA codes give NA from integer arithmetic already; this keeps the intent
# explicit where a code is decoded.
ztp_restore_na <- function(values, x) {
  values[is.na(unclass(x))] <- NA
  values
}

# MathematicalInLeapYear, MathematicalDaysInYear and ISODaysInMonth over
# integer vectors, for a month that has no representable first day.
ztp_in_leap_year <- function(year) {
  (year %% 4L == 0L & year %% 100L != 0L) | year %% 400L == 0L
}

ztp_days_in_year <- function(year) {
  ifelse(ztp_in_leap_year(year), 366L, 365L)
}

ztp_days_in_month <- function(year, month) {
  lengths <- c(31L, 28L, 31L, 30L, 31L, 30L, 31L, 31L, 30L, 31L, 30L, 31L)
  out <- lengths[month]
  out[!is.na(month) & month == 2L & ztp_in_leap_year(year)] <- 29L
  out
}

ztp_constant_field <- function(x, value) {
  out <- rep(value, length(x))
  out[is.na(x)] <- NA
  out
}

# The function this generic masks, if an attached package or the global
# environment has one; NULL otherwise.
ztp_find_masked <- function(name) {
  for (i in seq_along(search())) {
    if (search()[[i]] == "package:zutempo") {
      next
    }
    fn <- get0(name, envir = pos.to.env(i), mode = "function", inherits = FALSE)
    if (!is.null(fn)) {
      return(fn)
    }
  }
  NULL
}

ztp_masked <- function(name, x, ...) {
  fn <- ztp_find_masked(name)
  if (is.null(fn)) {
    stop_zutempo(
      sprintf(
        "no %s() method for an object of class %s",
        name,
        paste(class(x), collapse = "/")
      ),
      kind = "type"
    )
  }
  fn(x, ...)
}

#' Fields of a Temporal value
#'
#' One accessor per Temporal property, named after it in snake case
#' (design 5). Each is an S3 generic with methods for the zutempo classes
#' and a default that calls the function of the same name from another
#' attached package, so that `lubridate::year()` and the others keep
#' working on their own objects after zutempo is attached.
#'
#' @param x A zutempo value.
#' @param ... Passed on by the default method to the function it masks.
#' @return An integer vector, or a character vector for `calendar_id()`,
#'   `era()` and `month_code()`, or a logical vector for `in_leap_year()`,
#'   with `NA` where `x` is `NA`.
#' @section Fields:
#' * `calendar_id()`: `calendarId`, the calendar identifier, always "iso8601".
#' * `era()`: `era`, the era, `NA` in the ISO 8601 calendar.
#' * `era_year()`: `eraYear`, the year within the era, `NA` in the ISO 8601 calendar.
#' * `year()`: `year`, the year.
#' * `month()`: `month`, the month, 1 to 12.
#' * `month_code()`: `monthCode`, the month code, `"M01"` to `"M12"`.
#' * `day()`: `day`, the day of the month.
#' * `day_of_week()`: `dayOfWeek`, the day of the week, 1 (Monday) to 7 (Sunday).
#' * `day_of_year()`: `dayOfYear`, the day of the year, from 1.
#' * `week_of_year()`: `weekOfYear`, the ISO week number, 1 to 53.
#' * `year_of_week()`: `yearOfWeek`, the year the ISO week belongs to.
#' * `days_in_week()`: `daysInWeek`, always 7.
#' * `days_in_month()`: `daysInMonth`, 28 to 31.
#' * `days_in_year()`: `daysInYear`, 365 or 366.
#' * `months_in_year()`: `monthsInYear`, always 12.
#' * `in_leap_year()`: `inLeapYear`, whether the year is a leap year.
#' * `hour()`: `hour`, 0 to 23.
#' * `minute()`: `minute`, 0 to 59.
#' * `second()`: `second`, 0 to 59.
#' * `millisecond()`: `millisecond`, 0 to 999.
#' * `microsecond()`: `microsecond`, 0 to 999.
#' * `nanosecond()`: `nanosecond`, 0 to 999.
#' @examples
#' x <- plain_date("2026-01-31")
#' year(x)
#' day_of_week(x)
#' month_code(x)
#' hour(plain_time("12:30:45.5"))
#' @name temporal_fields
NULL

#' @rdname temporal_fields
#' @export
calendar_id <- function(x, ...) UseMethod("calendar_id")
#' @rdname temporal_fields
#' @export
calendar_id.default <- function(x, ...) ztp_masked("calendar_id", x, ...)
#' @rdname temporal_fields
#' @export
calendar_id.zutempo_plain_date <- function(x, ...) {
  ztp_constant_field(x, "iso8601")
}
#' @rdname temporal_fields
#' @export
calendar_id.zutempo_plain_date_time <- function(x, ...) {
  ztp_constant_field(x, "iso8601")
}

#' @rdname temporal_fields
#' @export
era <- function(x, ...) UseMethod("era")
#' @rdname temporal_fields
#' @export
era.default <- function(x, ...) ztp_masked("era", x, ...)
#' @rdname temporal_fields
#' @export
era.zutempo_plain_date <- function(x, ...) ztp_constant_field(x, NA_character_)
#' @rdname temporal_fields
#' @export
era.zutempo_plain_date_time <- function(x, ...) {
  ztp_constant_field(x, NA_character_)
}

#' @rdname temporal_fields
#' @export
era_year <- function(x, ...) UseMethod("era_year")
#' @rdname temporal_fields
#' @export
era_year.default <- function(x, ...) ztp_masked("era_year", x, ...)
#' @rdname temporal_fields
#' @export
era_year.zutempo_plain_date <- function(x, ...) {
  ztp_constant_field(x, NA_integer_)
}
#' @rdname temporal_fields
#' @export
era_year.zutempo_plain_date_time <- function(x, ...) {
  ztp_constant_field(x, NA_integer_)
}

#' @rdname temporal_fields
#' @export
year <- function(x, ...) UseMethod("year")
#' @rdname temporal_fields
#' @export
year.default <- function(x, ...) ztp_masked("year", x, ...)
#' @rdname temporal_fields
#' @export
year.zutempo_plain_date <- function(x, ...) ztp_date_field(x, "year")
#' @rdname temporal_fields
#' @export
year.zutempo_plain_date_time <- function(x, ...) ztp_date_time_field(x, "year")

#' @rdname temporal_fields
#' @export
month <- function(x, ...) UseMethod("month")
#' @rdname temporal_fields
#' @export
month.default <- function(x, ...) ztp_masked("month", x, ...)
#' @rdname temporal_fields
#' @export
month.zutempo_plain_date <- function(x, ...) ztp_date_field(x, "month")
#' @rdname temporal_fields
#' @export
month.zutempo_plain_date_time <- function(x, ...) {
  ztp_date_time_field(x, "month")
}

#' @rdname temporal_fields
#' @export
month_code <- function(x, ...) UseMethod("month_code")
#' @rdname temporal_fields
#' @export
month_code.default <- function(x, ...) ztp_masked("month_code", x, ...)
#' @rdname temporal_fields
#' @export
month_code.zutempo_plain_date <- function(x, ...) {
  ztp_month_code(ztp_date_field(x, "month"))
}
#' @rdname temporal_fields
#' @export
month_code.zutempo_plain_date_time <- function(x, ...) {
  ztp_month_code(ztp_date_time_field(x, "month"))
}

#' @rdname temporal_fields
#' @export
day <- function(x, ...) UseMethod("day")
#' @rdname temporal_fields
#' @export
day.default <- function(x, ...) ztp_masked("day", x, ...)
#' @rdname temporal_fields
#' @export
day.zutempo_plain_date <- function(x, ...) ztp_date_field(x, "day")
#' @rdname temporal_fields
#' @export
day.zutempo_plain_date_time <- function(x, ...) ztp_date_time_field(x, "day")

#' @rdname temporal_fields
#' @export
day_of_week <- function(x, ...) UseMethod("day_of_week")
#' @rdname temporal_fields
#' @export
day_of_week.default <- function(x, ...) ztp_masked("day_of_week", x, ...)
#' @rdname temporal_fields
#' @export
day_of_week.zutempo_plain_date <- function(x, ...) {
  ztp_date_field(x, "day_of_week")
}
#' @rdname temporal_fields
#' @export
day_of_week.zutempo_plain_date_time <- function(x, ...) {
  ztp_date_time_field(x, "day_of_week")
}

#' @rdname temporal_fields
#' @export
day_of_year <- function(x, ...) UseMethod("day_of_year")
#' @rdname temporal_fields
#' @export
day_of_year.default <- function(x, ...) ztp_masked("day_of_year", x, ...)
#' @rdname temporal_fields
#' @export
day_of_year.zutempo_plain_date <- function(x, ...) {
  ztp_date_field(x, "day_of_year")
}
#' @rdname temporal_fields
#' @export
day_of_year.zutempo_plain_date_time <- function(x, ...) {
  ztp_date_time_field(x, "day_of_year")
}

#' @rdname temporal_fields
#' @export
week_of_year <- function(x, ...) UseMethod("week_of_year")
#' @rdname temporal_fields
#' @export
week_of_year.default <- function(x, ...) ztp_masked("week_of_year", x, ...)
#' @rdname temporal_fields
#' @export
week_of_year.zutempo_plain_date <- function(x, ...) {
  ztp_date_field(x, "week_of_year")
}
#' @rdname temporal_fields
#' @export
week_of_year.zutempo_plain_date_time <- function(x, ...) {
  ztp_date_time_field(x, "week_of_year")
}

#' @rdname temporal_fields
#' @export
year_of_week <- function(x, ...) UseMethod("year_of_week")
#' @rdname temporal_fields
#' @export
year_of_week.default <- function(x, ...) ztp_masked("year_of_week", x, ...)
#' @rdname temporal_fields
#' @export
year_of_week.zutempo_plain_date <- function(x, ...) {
  ztp_date_field(x, "year_of_week")
}
#' @rdname temporal_fields
#' @export
year_of_week.zutempo_plain_date_time <- function(x, ...) {
  ztp_date_time_field(x, "year_of_week")
}

#' @rdname temporal_fields
#' @export
days_in_week <- function(x, ...) UseMethod("days_in_week")
#' @rdname temporal_fields
#' @export
days_in_week.default <- function(x, ...) ztp_masked("days_in_week", x, ...)
#' @rdname temporal_fields
#' @export
days_in_week.zutempo_plain_date <- function(x, ...) ztp_constant_field(x, 7L)
#' @rdname temporal_fields
#' @export
days_in_week.zutempo_plain_date_time <- function(x, ...) {
  ztp_constant_field(x, 7L)
}

#' @rdname temporal_fields
#' @export
days_in_month <- function(x, ...) UseMethod("days_in_month")
#' @rdname temporal_fields
#' @export
days_in_month.default <- function(x, ...) ztp_masked("days_in_month", x, ...)
#' @rdname temporal_fields
#' @export
days_in_month.zutempo_plain_date <- function(x, ...) {
  ztp_date_field(x, "days_in_month")
}
#' @rdname temporal_fields
#' @export
days_in_month.zutempo_plain_date_time <- function(x, ...) {
  ztp_date_time_field(x, "days_in_month")
}

#' @rdname temporal_fields
#' @export
days_in_year <- function(x, ...) UseMethod("days_in_year")
#' @rdname temporal_fields
#' @export
days_in_year.default <- function(x, ...) ztp_masked("days_in_year", x, ...)
#' @rdname temporal_fields
#' @export
days_in_year.zutempo_plain_date <- function(x, ...) {
  ztp_date_field(x, "days_in_year")
}
#' @rdname temporal_fields
#' @export
days_in_year.zutempo_plain_date_time <- function(x, ...) {
  ztp_date_time_field(x, "days_in_year")
}

#' @rdname temporal_fields
#' @export
months_in_year <- function(x, ...) UseMethod("months_in_year")
#' @rdname temporal_fields
#' @export
months_in_year.default <- function(x, ...) ztp_masked("months_in_year", x, ...)
#' @rdname temporal_fields
#' @export
months_in_year.zutempo_plain_date <- function(x, ...) ztp_constant_field(x, 12L)
#' @rdname temporal_fields
#' @export
months_in_year.zutempo_plain_date_time <- function(x, ...) {
  ztp_constant_field(x, 12L)
}

#' @rdname temporal_fields
#' @export
in_leap_year <- function(x, ...) UseMethod("in_leap_year")
#' @rdname temporal_fields
#' @export
in_leap_year.default <- function(x, ...) ztp_masked("in_leap_year", x, ...)
#' @rdname temporal_fields
#' @export
in_leap_year.zutempo_plain_date <- function(x, ...) {
  ztp_date_field(x, "in_leap_year")
}
#' @rdname temporal_fields
#' @export
in_leap_year.zutempo_plain_date_time <- function(x, ...) {
  ztp_date_time_field(x, "in_leap_year")
}

#' @rdname temporal_fields
#' @export
hour <- function(x, ...) UseMethod("hour")
#' @rdname temporal_fields
#' @export
hour.default <- function(x, ...) ztp_masked("hour", x, ...)
#' @rdname temporal_fields
#' @export
hour.zutempo_plain_time <- function(x, ...) ztp_time_field(x, "hour")
#' @rdname temporal_fields
#' @export
hour.zutempo_plain_date_time <- function(x, ...) ztp_date_time_field(x, "hour")

#' @rdname temporal_fields
#' @export
minute <- function(x, ...) UseMethod("minute")
#' @rdname temporal_fields
#' @export
minute.default <- function(x, ...) ztp_masked("minute", x, ...)
#' @rdname temporal_fields
#' @export
minute.zutempo_plain_time <- function(x, ...) ztp_time_field(x, "minute")
#' @rdname temporal_fields
#' @export
minute.zutempo_plain_date_time <- function(x, ...) {
  ztp_date_time_field(x, "minute")
}

#' @rdname temporal_fields
#' @export
second <- function(x, ...) UseMethod("second")
#' @rdname temporal_fields
#' @export
second.default <- function(x, ...) ztp_masked("second", x, ...)
#' @rdname temporal_fields
#' @export
second.zutempo_plain_time <- function(x, ...) ztp_time_field(x, "second")
#' @rdname temporal_fields
#' @export
second.zutempo_plain_date_time <- function(x, ...) {
  ztp_date_time_field(x, "second")
}

#' @rdname temporal_fields
#' @export
millisecond <- function(x, ...) UseMethod("millisecond")
#' @rdname temporal_fields
#' @export
millisecond.default <- function(x, ...) ztp_masked("millisecond", x, ...)
#' @rdname temporal_fields
#' @export
millisecond.zutempo_plain_time <- function(x, ...) {
  ztp_time_field(x, "millisecond")
}
#' @rdname temporal_fields
#' @export
millisecond.zutempo_plain_date_time <- function(x, ...) {
  ztp_date_time_field(x, "millisecond")
}

#' @rdname temporal_fields
#' @export
microsecond <- function(x, ...) UseMethod("microsecond")
#' @rdname temporal_fields
#' @export
microsecond.default <- function(x, ...) ztp_masked("microsecond", x, ...)
#' @rdname temporal_fields
#' @export
microsecond.zutempo_plain_time <- function(x, ...) {
  ztp_time_field(x, "microsecond")
}
#' @rdname temporal_fields
#' @export
microsecond.zutempo_plain_date_time <- function(x, ...) {
  ztp_date_time_field(x, "microsecond")
}

#' @rdname temporal_fields
#' @export
nanosecond <- function(x, ...) UseMethod("nanosecond")
#' @rdname temporal_fields
#' @export
nanosecond.default <- function(x, ...) ztp_masked("nanosecond", x, ...)
#' @rdname temporal_fields
#' @export
nanosecond.zutempo_plain_time <- function(x, ...) {
  ztp_time_field(x, "nanosecond")
}
#' @rdname temporal_fields
#' @export
nanosecond.zutempo_plain_date_time <- function(x, ...) {
  ztp_date_time_field(x, "nanosecond")
}

# --- PlainYearMonth and PlainMonthDay -----------------------------------------

#' @rdname temporal_fields
#' @export
calendar_id.zutempo_plain_year_month <- function(x, ...) {
  ztp_constant_field(x, "iso8601")
}
#' @rdname temporal_fields
#' @export
era.zutempo_plain_year_month <- function(x, ...) {
  ztp_constant_field(x, NA_character_)
}
#' @rdname temporal_fields
#' @export
era_year.zutempo_plain_year_month <- function(x, ...) {
  ztp_constant_field(x, NA_integer_)
}
#' @rdname temporal_fields
#' @export
year.zutempo_plain_year_month <- function(x, ...) {
  ztp_restore_na(as.integer(1970L + unclass(x) %/% 12L), x)
}
#' @rdname temporal_fields
#' @export
month.zutempo_plain_year_month <- function(x, ...) {
  ztp_restore_na(as.integer(unclass(x) %% 12L + 1L), x)
}
#' @rdname temporal_fields
#' @export
month_code.zutempo_plain_year_month <- function(x, ...) ztp_month_code(month(x))
#' @rdname temporal_fields
#' @export
days_in_year.zutempo_plain_year_month <- function(x, ...) {
  ztp_days_in_year(year(x))
}
#' @rdname temporal_fields
#' @export
days_in_month.zutempo_plain_year_month <- function(x, ...) {
  ztp_days_in_month(year(x), month(x))
}
#' @rdname temporal_fields
#' @export
months_in_year.zutempo_plain_year_month <- function(x, ...) {
  ztp_constant_field(x, 12L)
}
#' @rdname temporal_fields
#' @export
in_leap_year.zutempo_plain_year_month <- function(x, ...) {
  ztp_in_leap_year(year(x))
}
#' @rdname temporal_fields
#' @export
calendar_id.zutempo_plain_month_day <- function(x, ...) {
  ztp_constant_field(x, "iso8601")
}
#' @rdname temporal_fields
#' @export
month_code.zutempo_plain_month_day <- function(x, ...) {
  ztp_month_code(ztp_month_day_month(x))
}
#' @rdname temporal_fields
#' @export
day.zutempo_plain_month_day <- function(x, ...) {
  ztp_restore_na(as.integer(ztp_month_day_day(x)), x)
}
