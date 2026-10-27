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
  for (bad in c("+24", "+2", "+05:60", "+05:", "+05:3", "+05:30x", "?")) {
    expect_error(normalise(bad), class = "zutempo_range_error", info = bad)
  }
  expect_error(normalise("+05:30:15"), class = "zutempo_range_error")
  expect_error(normalise("+0530:15"), class = "zutempo_range_error")
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
