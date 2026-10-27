# Conversions with base R (design 6.10). One test per row of the table,
# named for the row, in both directions. The rows with named zones compare
# with base R, which reads the machine's database, so zutempo reads it too
# and they skip without one (skip_without_tzdb(), helper-tz.R).

test_that("PlainDate <-> Date is exact", {
  x <- plain_date(c("2026-03-07", "1970-01-01", "-000001-12-31", NA))
  d <- as.Date(x)
  expect_s3_class(d, "Date")
  expect_identical(unclass(d), c(20519, 0, -719529, NA))
  expect_identical(plain_date(d), x)
  # A fractional Date is the day it falls in.
  expect_identical(
    plain_date(structure(c(0.5, -0.5), class = "Date")),
    plain_date(c("1970-01-01", "1969-12-31"))
  )
})

test_that("PlainDate <-> Date is exact over the whole int32_t range", {
  withr::local_seed(10)
  lo <- -100000001
  hi <- 100000000
  days <- c(
    lo,
    hi,
    0,
    round(stats::runif(2000, lo, hi)),
    round(stats::runif(500, -.Machine$integer.max, .Machine$integer.max))
  )
  inside <- days >= lo & days <= hi
  d <- structure(days[inside], class = "Date")
  x <- plain_date(d)
  expect_identical(as.double(unclass(x)), days[inside])
  expect_identical(as.Date(x), d)
  # Through fields: the same year, month and day as base R's calendar,
  # compared as numbers since base R writes years below 1000 differently
  # on different platforms.
  lt <- unclass(as.POSIXlt(d))
  expect_identical(as.double(year(x)), as.double(lt[["year"]] + 1900))
  expect_identical(as.double(month(x)), as.double(lt[["mon"]] + 1))
  expect_identical(as.double(day(x)), as.double(lt[["mday"]]))
  # Outside a PlainDate's range: a range error naming the element.
  for (day in c(lo - 1, hi + 1, -.Machine$integer.max, .Machine$integer.max)) {
    expect_error(
      plain_date(structure(c(0, day), class = "Date")),
      class = "zutempo_range_error"
    )
  }
  err <- tryCatch(
    plain_date(structure(c(0, hi + 1), class = "Date")),
    error = identity
  )
  expect_identical(err[["index"]], 2)
})

test_that("Instant <-> POSIXct goes through the nearest double second", {
  # POSIXct to Instant takes the double's exact value, rounded half to
  # even to the nanosecond.
  expect_identical(
    format(instant(.POSIXct(c(0.1, -0.1, 2.5e-9, NA), tz = "UTC"))),
    c(
      "1970-01-01T00:00:00.1Z",
      "1969-12-31T23:59:59.9Z",
      "1970-01-01T00:00:00.000000003Z",
      NA
    )
  )
  ct <- as.POSIXct(instant(c("2026-03-07T12:00:00.5Z", NA)))
  expect_s3_class(ct, "POSIXct")
  expect_identical(attr(ct, "tzone"), "UTC")
  expect_identical(unclass(ct)[[1L]], 1772884800.5)
  expect_true(is.na(ct[[2L]]))
  expect_identical(
    attr(as.POSIXct(instant("2026-03-07T12:00Z"), tz = "Asia/Tokyo"), "tzone"),
    "Asia/Tokyo"
  )
  # POSIXlt goes through POSIXct.
  lt <- as.POSIXlt("2026-03-07 12:00:00", tz = "UTC")
  expect_identical(instant(lt), instant("2026-03-07T12:00Z"))
  expect_error(instant(.POSIXct(Inf)), class = "zutempo_range_error")
  expect_error(instant(.POSIXct(9e12)), class = "zutempo_range_error")
})

test_that("Instant <-> POSIXct agree with base R for 10^4 instants, 1900 to 2100", {
  withr::local_seed(42)
  n <- 10000
  seconds <- floor(stats::runif(n, -2208988800, 4102444800))
  nanos <- floor(stats::runif(n, 0, 1e9))
  strings <- paste0(
    format(.POSIXct(seconds, tz = "UTC"), "%Y-%m-%dT%H:%M:%S", tz = "UTC"),
    sprintf(".%09.0fZ", nanos)
  )
  x <- instant(strings)
  # To POSIXct: within half the spacing of doubles at these dates, and
  # within a few ulps of base R's own arithmetic.
  ct <- unclass(as.POSIXct(x))
  base <- seconds + nanos / 1e9
  expect_lte(max(abs(ct - base)), 2.5e-7)
  # Back: whole seconds survive exactly, and the round trip of a double
  # is exact at these dates (its spacing is coarser than a nanosecond).
  expect_identical(unclass(as.POSIXct(instant(.POSIXct(ct, tz = "UTC")))), ct)
  # From base R's double: within the same half spacing of the exact time.
  back <- instant(.POSIXct(base, tz = "UTC"))
  off <- temporal_total(temporal_since(back, x), "nanosecond")
  expect_lte(max(abs(off)), 250)
})

test_that("ZonedDateTime <-> POSIXct keeps the zone as tzone", {
  skip_without_tzdb()
  z <- zoned_date_time(c(
    "2026-03-07T12:00[Europe/Lisbon]",
    "2026-07-07T12:00[Europe/Lisbon]"
  ))
  ct <- as.POSIXct(z)
  expect_identical(attr(ct, "tzone"), "Europe/Lisbon")
  expect_identical(format(ct, "%H:%M %Z"), c("12:00 WET", "12:00 WEST"))
  expect_identical(zoned_date_time(ct), z)
  # A mixed vector is UTC (design 4.2); offsets base R cannot name too.
  mixed <- c(z[1L], zoned_date_time("2026-03-07T12:00[Asia/Tokyo]"))
  expect_identical(attr(as.POSIXct(mixed), "tzone"), "UTC")
  expect_identical(
    attr(as.POSIXct(zoned_date_time("2026-03-07T12:00[+05:00]")), "tzone"),
    "Etc/GMT-5"
  )
  expect_identical(
    attr(as.POSIXct(zoned_date_time("2026-03-07T12:00[-03:00]")), "tzone"),
    "Etc/GMT+3"
  )
  expect_identical(
    attr(as.POSIXct(zoned_date_time("2026-03-07T12:00[+05:30]")), "tzone"),
    "UTC"
  )
  # From POSIXct: tzone, overridden by time_zone, and the system zone for
  # an empty tzone.
  ct <- as.POSIXct("2026-03-07 12:00:00", tz = "Asia/Tokyo")
  expect_identical(
    format(zoned_date_time(ct)),
    "2026-03-07T12:00:00+09:00[Asia/Tokyo]"
  )
  expect_identical(
    format(zoned_date_time(ct, time_zone = "UTC")),
    "2026-03-07T03:00:00+00:00[UTC]"
  )
  withr::local_envvar(TZ = "Europe/Lisbon")
  expect_identical(
    time_zone_id(zoned_date_time(.POSIXct(0, tz = ""))),
    "Europe/Lisbon"
  )
})

test_that("ZonedDateTime <-> POSIXlt has each element's fields and offset", {
  skip_without_tzdb()
  z <- zoned_date_time(c(
    "2026-03-07T12:34:56.5[Europe/Lisbon]",
    "2026-07-07T12:00[America/New_York]",
    NA
  ))
  lt <- as.POSIXlt(z)
  expect_s3_class(lt, "POSIXlt")
  expect_identical(unclass(lt)[["hour"]], c(12L, 12L, NA))
  expect_identical(unclass(lt)[["min"]], c(34L, 0L, NA))
  expect_identical(unclass(lt)[["sec"]], c(56.5, 0, NA))
  expect_identical(unclass(lt)[["gmtoff"]], c(0L, -14400L, NA))
  expect_identical(unclass(lt)[["isdst"]][1:2], c(0L, 1L))
  expect_identical(unclass(lt)[["zone"]][1:2], c("WET", "EDT"))
  expect_identical(unclass(lt)[["wday"]][1:2], c(6L, 2L))
  expect_identical(unclass(lt)[["yday"]][1:2], c(65L, 187L))
  # The fields agree with base R's for a single zone, and come back.
  one <- zoned_date_time("2026-11-01T01:30-05:00[America/New_York]")
  base <- as.POSIXlt(as.POSIXct(one), tz = "America/New_York")
  mine <- as.POSIXlt(one)
  for (f in c(
    "sec",
    "min",
    "hour",
    "mday",
    "mon",
    "year",
    "wday",
    "yday",
    "isdst",
    "gmtoff"
  )) {
    expect_equal(unclass(mine)[[f]], unclass(base)[[f]], info = f)
  }
  expect_identical(zoned_date_time(mine), one)
})

test_that("PlainDateTime -> POSIXct and POSIXlt need tz and disambiguate", {
  skip_without_tzdb()
  x <- plain_date_time("2026-03-29T01:30")
  expect_error(as.POSIXct(x), class = "zutempo_type_error")
  expect_error(as.POSIXlt(x), class = "zutempo_type_error")
  # 01:30 does not exist in Lisbon that night.
  expect_identical(
    format(as.POSIXct(x, tz = "Europe/Lisbon"), "%H:%M %Z"),
    "02:30 WEST"
  )
  expect_identical(
    format(
      as.POSIXct(x, tz = "Europe/Lisbon", disambiguation = "earlier"),
      "%H:%M %Z"
    ),
    "00:30 WET"
  )
  expect_error(
    as.POSIXct(x, tz = "Europe/Lisbon", disambiguation = "reject"),
    class = "zutempo_range_error"
  )
  expect_identical(unclass(as.POSIXlt(x, tz = "Europe/Lisbon"))[["hour"]], 2L)
  # And back from POSIXct or POSIXlt, the wall clock in tzone.
  lt <- as.POSIXlt("2026-03-07 12:00:00", tz = "Asia/Tokyo")
  expect_identical(plain_date_time(lt), plain_date_time("2026-03-07T12:00"))
  expect_identical(
    plain_date_time(as.POSIXct(lt)),
    plain_date_time("2026-03-07T12:00")
  )
})

test_that("ZonedDateTime, Instant and PlainDateTime -> Date take the local date", {
  skip_without_tzdb()
  z <- zoned_date_time("2026-03-07T23:30[America/New_York]")
  expect_identical(as.Date(z), as.Date("2026-03-07"))
  expect_identical(as.Date(z, tz = "UTC"), as.Date("2026-03-08"))
  i <- instant("2026-03-07T23:30Z")
  expect_identical(as.Date(i), as.Date("2026-03-07"))
  expect_identical(as.Date(i, tz = "Asia/Tokyo"), as.Date("2026-03-08"))
  expect_identical(
    as.Date(plain_date_time("2026-03-07T23:30")),
    as.Date("2026-03-07")
  )
  # And back: a Date or a POSIXct is a PlainDate or PlainDateTime.
  expect_identical(
    plain_date(as.POSIXct("2026-03-07 23:30", tz = "America/New_York")),
    plain_date("2026-03-07")
  )
  expect_identical(
    plain_date_time(as.Date("2026-03-07")),
    plain_date_time("2026-03-07T00:00")
  )
})

test_that("PlainTime <-> difftime is seconds since midnight", {
  d <- temporal_to_difftime(plain_time(c("12:30:00.5", "00:00", NA)))
  expect_s3_class(d, "difftime")
  expect_identical(units(d), "secs")
  expect_identical(as.double(d), c(45000.5, 0, NA))
  expect_identical(
    plain_time(as.difftime(c(750.0125, NA), units = "mins")),
    plain_time(c("12:30:00.75", NA))
  )
  expect_error(
    plain_time(as.difftime(c(1, 24), units = "hours")),
    class = "zutempo_range_error"
  )
  expect_error(
    plain_time(as.difftime(-1, units = "secs")),
    class = "zutempo_range_error"
  )
})

test_that("Duration <-> difftime is the total in seconds", {
  d <- temporal_to_difftime(duration(c("PT1H30M", "-PT0.5S", "P1D", NA)))
  expect_identical(units(d), "secs")
  expect_identical(as.double(d), c(5400, -0.5, 86400, NA))
  # Calendar units need relative_to.
  expect_error(
    temporal_to_difftime(duration("P1M")),
    class = "zutempo_range_error"
  )
  expect_identical(
    as.double(temporal_to_difftime(
      duration("P1M"),
      relative_to = "2026-02-01"
    )),
    28 * 86400
  )
  # From difftime: seconds and nanoseconds of one sign, as Duration.from()
  # leaves them.
  x <- duration(as.difftime(c(90, -1.5, 0.1, NA), units = "mins"))
  expect_identical(format(x), c("PT5400S", "-PT90S", "PT6S", NA))
  y <- duration(as.difftime(-1.25, units = "secs"))
  expect_identical(seconds(y), -1)
  expect_identical(nanoseconds(y), -250000000)
  expect_error(
    temporal_to_difftime(plain_date("2026-03-07")),
    class = "zutempo_type_error"
  )
})

test_that("PlainYearMonth and PlainMonthDay have no base R conversion", {
  # No method: base R's as.Date.default() raises its own error.
  expect_error(as.Date(plain_year_month("2026-03")), class = "simpleError")
  expect_error(as.Date(plain_month_day("03-07")), class = "simpleError")
  expect_identical(
    as.Date(temporal_to_plain_date(plain_year_month("2026-03"), day = 7)),
    as.Date("2026-03-07")
  )
  expect_identical(
    as.Date(temporal_to_plain_date(plain_month_day("03-07"), year = 2026)),
    as.Date("2026-03-07")
  )
})
