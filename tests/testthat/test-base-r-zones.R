# The tzone a zoned_date_time() takes to POSIXct and POSIXlt (design 4.2
# and 6.10).

test_that("a whole-hour offset becomes an Etc/GMT zone only where one exists", {
  tzone <- function(s) attr(as.POSIXct(zoned_date_time(s)), "tzone")
  expect_identical(tzone("2026-01-01T00:00+14:00[+14:00]"), "Etc/GMT-14")
  expect_identical(tzone("2026-01-01T00:00+13:00[+13:00]"), "Etc/GMT-13")
  expect_identical(tzone("2026-01-01T00:00+01:00[+01:00]"), "Etc/GMT-1")
  expect_identical(tzone("2026-01-01T00:00-01:00[-01:00]"), "Etc/GMT+1")
  expect_identical(tzone("2026-01-01T00:00-12:00[-12:00]"), "Etc/GMT+12")
  # tzdata has no Etc/GMT+13 or Etc/GMT+14.
  expect_identical(tzone("2026-01-01T00:00-13:00[-13:00]"), "UTC")
  expect_identical(tzone("2026-01-01T00:00-14:00[-14:00]"), "UTC")
  expect_identical(tzone("2026-01-01T00:00+00:00[+00:00]"), "UTC")
  expect_identical(tzone("2026-01-01T00:00+05:30[+05:30]"), "UTC")
  lt <- as.POSIXlt(zoned_date_time("2026-01-01T00:00-13:00[-13:00]"))
  expect_identical(attr(lt, "tzone"), "UTC")
})

test_that("the converted instant is right whatever tzone it gets", {
  for (s in c(
    "2026-01-01T00:00-13:00[-13:00]",
    "2026-01-01T00:00+14:00[+14:00]",
    "2026-01-01T00:00-12:00[-12:00]"
  )) {
    z <- zoned_date_time(s)
    ct <- expect_silent(as.POSIXct(z))
    expect_identical(
      as.numeric(ct),
      epoch_milliseconds(z) / 1000,
      info = s
    )
  }
})

test_that("zones equal under TimeZoneEquals keep their tzone", {
  with_tzdir(tz_fixture_dir("slim"), {
    z <- zoned_date_time(c(
      "2026-01-01T00:00[Asia/Calcutta]",
      "2026-01-01T00:00[Asia/Kolkata]"
    ))
    expect_identical(attr(as.POSIXct(z), "tzone"), "Asia/Calcutta")
    expect_identical(attr(as.POSIXlt(z), "tzone"), "Asia/Calcutta")
    expect_identical(attr(as.POSIXct(rev(z)), "tzone"), "Asia/Kolkata")
    # Distinct zones still flatten to UTC, and so do UTC and +00:00, which
    # Temporal keeps apart.
    mixed <- zoned_date_time(c(
      "2026-01-01T00:00[Asia/Kolkata]",
      "2026-01-01T00:00[Asia/Tokyo]"
    ))
    expect_identical(attr(as.POSIXct(mixed), "tzone"), "UTC")
    utc <- zoned_date_time(c(
      "2026-01-01T00:00[UTC]",
      "2026-01-01T00:00+00:00[+00:00]"
    ))
    expect_identical(attr(as.POSIXct(utc), "tzone"), "UTC")
  })
})

test_that("POSIXlt of mixed zones has UTC as tzone and local fields", {
  with_tzdir(tz_fixture_dir("slim"), {
    z <- zoned_date_time(c(
      "2026-07-01T12:00[Europe/Moscow]",
      "2026-07-01T12:00[UTC]"
    ))
    lt <- as.POSIXlt(z)
    expect_identical(attr(lt, "tzone"), "UTC")
    expect_identical(unclass(lt)[["hour"]], c(12L, 12L))
    expect_identical(unclass(lt)[["gmtoff"]], c(10800L, 0L))
    # Going through POSIXct keeps the instants.
    expect_identical(
      as.numeric(as.POSIXct(z)),
      epoch_milliseconds(z) / 1000
    )
  })
})
