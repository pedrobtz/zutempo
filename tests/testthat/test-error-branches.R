# Error branches of the engine and the glue that the R layer does not
# reach in the other tests. Each branch is tested here, or its source
# says why it cannot be reached from R.

test_that("an ill-formed time zone identifier is a range error", {
  normalise <- function(x) .Call(zutempo:::C_ztp_r_zone_normalise, x)
  expect_identical(
    normalise(c("utc", "+05", "-0530", "+05:30")),
    c(
      "UTC",
      "+05:00",
      "-05:30",
      "+05:30"
    )
  )
  # A tz error is a range error too, so each is also checked not to be
  # one: an ill-formed identifier must fail the syntax check, not the
  # cache lookup.
  bad <- c(
    "+24",
    "+2",
    "+05:60",
    "+05:",
    "+05:3",
    "+05:30x",
    "+05:30:15",
    "+0530:15",
    "?",
    "Ab$c",
    "Europe/Par is",
    "Europe//Paris",
    "Europe/-Paris"
  )
  for (x in bad) {
    e <- expect_error(normalise(x), class = "zutempo_range_error", info = x)
    expect_false(inherits(e, "zutempo_tz_error"), info = x)
  }
  # A well-formed name the cache does not hold.
  expect_error(normalise("Not/Loaded"), class = "zutempo_tz_error")
})

test_that("the duration rounding checks hold for C callers", {
  data <- unclass(duration(hours = 1))
  round <- function(largest, smallest, given) {
    .Call(
      zutempo:::C_ztp_r_duration_round,
      data,
      largest,
      smallest,
      1,
      7L,
      given,
      NULL,
      NULL,
      NULL,
      NULL
    )
  }
  expect_error(round(-2L, 9L, FALSE), class = "zutempo_range_error")
  # Nanoseconds (9) as the largest unit and hours (4) as the smallest.
  expect_error(round(9L, 4L, TRUE), class = "zutempo_range_error")
})

test_that("comparing durations past the end of the range is a range error", {
  # Days are compared by adding them to a zoned relative_to, which fails
  # within a day of the last instant.
  end <- zoned_date_time("+275760-09-12T00:00[UTC]")
  expect_error(
    duration_compare("P1D", "P2D", relative_to = end),
    class = "zutempo_range_error"
  )
  expect_identical(
    duration_compare("PT1H", "PT2H", relative_to = end),
    -1L
  )
})

test_that("a difftime too large for a duration is a range error", {
  expect_error(
    duration(as.difftime(Inf, units = "secs")),
    class = "zutempo_range_error"
  )
  expect_error(
    duration(as.difftime(1e300, units = "secs")),
    class = "zutempo_range_error"
  )
})

test_that("a time zone identifier too long for the cache is a tz error", {
  withr::defer(zutempo_tz_reset())
  path <- file.path(test_path("tzdata", "slim"), "Asia/Tokyo")
  bytes <- readBin(path, "raw", n = file.size(path))
  expect_error(
    .Call(zutempo:::C_ztp_r_tz_load, strrep("A", 60), bytes),
    class = "zutempo_tz_error"
  )
})

test_that("the second operand of until() is type-checked for C callers", {
  until <- function(f, x) .Call(f, x, "a", 3L, 9L, 1, 6L)
  expect_error(
    until(zutempo:::C_ztp_r_plain_date_until, 0L),
    class = "zutempo_type_error"
  )
  expect_error(
    until(zutempo:::C_ztp_r_plain_time_until, 0),
    class = "zutempo_type_error"
  )
  expect_error(
    until(zutempo:::C_ztp_r_plain_date_time_until, 0i),
    class = "zutempo_type_error"
  )
  expect_error(
    until(zutempo:::C_ztp_r_plain_year_month_until, 0L),
    class = "zutempo_type_error"
  )
  expect_error(
    until(zutempo:::C_ztp_r_instant_until, 0i),
    class = "zutempo_type_error"
  )
})

test_that("a year-month code near the integer limit is a type error", {
  x <- structure(-2147483647L, class = "zutempo_plain_year_month")
  expect_error(format(x), class = "zutempo_type_error")
})

test_that("option codes out of range are type errors for C callers", {
  round <- function(increment, unit, mode) {
    .Call(zutempo:::C_ztp_r_plain_time_round, 0, increment, unit, mode)
  }
  expect_identical(round(1, 9L, 6L), 0)
  expect_error(round(0, 9L, 6L), class = "zutempo_type_error")
  expect_error(round(1e10, 9L, 6L), class = "zutempo_type_error")
  expect_error(round(1.5, 9L, 6L), class = "zutempo_type_error")
  expect_error(round(NaN, 9L, 6L), class = "zutempo_type_error")
  expect_error(round(1, 10L, 6L), class = "zutempo_type_error")
  expect_error(round(1, -1L, 6L), class = "zutempo_type_error")
  expect_error(round(1, 9L, 9L), class = "zutempo_type_error")
  expect_error(round(1, 9L, NA_integer_), class = "zutempo_type_error")
  expect_error(
    .Call(zutempo:::C_ztp_r_plain_time_format, 0, 10L),
    class = "zutempo_type_error"
  )
  expect_error(
    .Call(zutempo:::C_ztp_r_plain_date_format, 0L, 4L),
    class = "zutempo_type_error"
  )
  dur <- unclass(duration(days = 1))
  expect_error(
    .Call(zutempo:::C_ztp_r_plain_date_add, 0L, dur, 2L),
    class = "zutempo_type_error"
  )
})

test_that("the zone test helpers reject seconds outside int64_t", {
  for (x in c(Inf, -Inf, 1e19)) {
    expect_error(
      .Call(zutempo:::C_ztp_r_tz_rule_utoff, "UTC0", x),
      class = "zutempo_type_error",
      info = x
    )
  }
  expect_identical(.Call(zutempo:::C_ztp_r_tz_rule_utoff, "UTC0", 0), 0L)
})

test_that("an unloaded zone in a zone table carries no element index", {
  x <- complex(real = c(0, 0), imaginary = c(0, 0))
  e <- expect_error(
    .Call(zutempo:::C_ztp_r_zoned_offset, x, 1:2, c("UTC", "Not/Loaded")),
    class = "zutempo_tz_error"
  )
  expect_null(e[["index"]])
})
