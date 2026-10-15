test_that("plain_date_time() stores the day and the nanoseconds exactly", {
  x <- plain_date_time("2026-01-31T12:30:45.123456789")
  z <- unclass(x)
  expect_identical(Re(z), 20484)
  expect_identical(Im(z), 45045123456789)
  expect_identical(plain_date_time(2026, 1, 31, 12, 30, 45, 123, 456, 789), x)
  expect_identical(
    plain_date_time(plain_date("2026-01-31")),
    plain_date_time("2026-01-31")
  )
  expect_identical(plain_date_time(x), x)
  expect_true(is.na(plain_date_time(NA_character_)))
  expect_identical(year(plain_date_time(NA_character_)), NA_integer_)
})

test_that("the range of a plain_date_time() extends a day beyond the dates", {
  expect_identical(
    temporal_to_string(plain_date_time("+275760-09-13T23:59:59.999999999")),
    "+275760-09-13T23:59:59.999999999"
  )
  expect_identical(
    temporal_to_string(plain_date_time("-271821-04-19T00:00:00.000000001")),
    "-271821-04-19T00:00:00.000000001"
  )
  expect_error(
    plain_date_time("-271821-04-19T00:00"),
    class = "zutempo_range_error"
  )
  expect_error(plain_date_time("+275760-09-14"), class = "zutempo_range_error")
  expect_error(
    temporal_round(plain_date_time("+275760-09-13T12:00"), "day"),
    class = "zutempo_range_error"
  )
  expect_error(
    temporal_to_plain_date_time(plain_date("-271821-04-19")),
    class = "zutempo_range_error"
  )
})

test_that("rounding carries into the date and accepts day", {
  x <- plain_date_time("2026-01-31T23:59")
  expect_identical(
    temporal_round(x, "hour"),
    plain_date_time("2026-02-01T00:00")
  )
  expect_identical(temporal_round(x, "day"), plain_date_time("2026-02-01"))
  expect_identical(
    temporal_round(plain_date_time("2026-01-31T11:59"), "day"),
    plain_date_time("2026-01-31")
  )
  expect_error(
    temporal_round(x, "day", rounding_increment = 2),
    class = "zutempo_range_error"
  )
  expect_error(temporal_round(x, "week"), class = "zutempo_range_error")
  expect_identical(
    temporal_round(
      plain_date_time("2026-01-31T12:39:59"),
      "minute",
      rounding_increment = 10,
      rounding_mode = "floor"
    ),
    plain_date_time("2026-01-31T12:30")
  )
})

test_that("conversions and with_plain_time() keep the other part", {
  x <- plain_date_time("2026-01-31T12:30:45.5")
  expect_identical(temporal_to_plain_date(x), plain_date("2026-01-31"))
  expect_identical(temporal_to_plain_time(x), plain_time("12:30:45.5"))
  expect_identical(temporal_with_plain_time(x), plain_date_time("2026-01-31"))
  expect_identical(
    temporal_with_plain_time(x, "08:00"),
    plain_date_time("2026-01-31T08:00")
  )
  expect_identical(
    temporal_with_plain_time(x, plain_time(8)),
    plain_date_time("2026-01-31T08:00")
  )
  expect_identical(
    temporal_with(x, hour = 0, month = 2),
    plain_date_time("2026-02-28T00:30:45.5")
  )
  expect_error(temporal_with(x), class = "zutempo_type_error")
  expect_error(temporal_with(x, weekday = 1), class = "zutempo_type_error")
})

test_that("date-times compare by date then time", {
  a <- plain_date_time("2026-01-31T23:59:59.999999999")
  b <- plain_date_time("2026-02-01T00:00")
  expect_identical(plain_date_time_compare(a, b), -1L)
  expect_identical(plain_date_time_compare(b, a), 1L)
  expect_identical(
    plain_date_time_compare(a, "2026-01-31T23:59:59.999999999"),
    0L
  )
  expect_identical(
    plain_date_time_compare(a, plain_date_time(NA_character_)),
    NA_integer_
  )
  expect_true(temporal_equals(a, a))
  x <- c(b, a, plain_date_time(NA_character_), a)
  expect_identical(sort(x), c(a, a, b))
  expect_identical(order(x), c(2L, 4L, 1L, 3L))
  expect_identical(xtfrm(x), c(2, 1, NA, 1))
})
