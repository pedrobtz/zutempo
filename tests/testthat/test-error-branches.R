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
