test_that("adding to dates follows AddDurationToDate", {
  x <- plain_date("2026-01-31")
  expect_identical(temporal_add(x, "P1M"), plain_date("2026-02-28"))
  expect_error(
    temporal_add(x, "P1M", overflow = "reject"),
    class = "zutempo_range_error"
  )
  expect_identical(temporal_add(x, "PT25H"), plain_date("2026-02-01"))
  expect_identical(temporal_add(x, "PT23H"), x)
  expect_identical(
    temporal_subtract(x, duration(months = 1)),
    plain_date("2025-12-31")
  )
  expect_identical(temporal_add(x, "P1W"), plain_date("2026-02-07"))
  expect_identical(
    temporal_add(plain_date(c("2026-01-31", NA)), "P1D"),
    plain_date(c("2026-02-01", NA))
  )
  expect_identical(
    temporal_add(x, duration(days = c(1, 2))),
    plain_date(c("2026-02-01", "2026-02-02"))
  )
  expect_error(
    temporal_add(plain_date("+275760-09-13"), "P1D"),
    class = "zutempo_range_error"
  )
  expect_error(temporal_add(x, "P1D", 5), class = "zutempo_type_error")
  expect_error(temporal_add(x, 5), class = "zutempo_type_error")
})

test_that("date differences follow DifferenceTemporalPlainDate", {
  x <- plain_date("2026-01-31")
  expect_identical(temporal_until(x, "2026-03-01"), duration("P29D"))
  expect_identical(
    temporal_until(x, "2026-03-01", largest_unit = "month"),
    duration("P1M1D")
  )
  expect_identical(
    temporal_since(x, "2026-03-01", largest_unit = "month"),
    duration("-P1M1D")
  )
  expect_identical(
    temporal_until(plain_date("2026-03-01"), x, largest_unit = "month"),
    duration("-P1M1D")
  )
  expect_identical(
    temporal_until(x, "2026-03-01", largest_unit = "weeks"),
    duration("P4W1D")
  )
  expect_identical(
    temporal_until(
      x,
      "2026-03-01",
      smallest_unit = "month",
      rounding_mode = "halfExpand"
    ),
    duration("P1M")
  )
  expect_identical(
    temporal_until(
      plain_date("2024-02-29"),
      "2025-03-01",
      largest_unit = "year"
    ),
    duration("P1Y1D")
  )
  expect_identical(temporal_until(x, x), duration("PT0S"))
  expect_error(
    temporal_until(x, "2026-02-10", largest_unit = "hour"),
    class = "zutempo_range_error"
  )
  expect_error(
    temporal_until(
      x,
      "2026-02-10",
      smallest_unit = "day",
      largest_unit = "hour"
    ),
    class = "zutempo_range_error"
  )
  expect_identical(
    temporal_until(
      plain_date("-271821-04-19"),
      "+275760-09-13",
      largest_unit = "year"
    ),
    duration("P547581Y4M25D")
  )
  expect_identical(
    temporal_until(plain_date(c("2026-01-01", NA)), "2026-01-02")$days,
    c(1, NA)
  )
})

test_that("time arithmetic wraps within the day", {
  expect_identical(
    temporal_add(plain_time("23:00"), "PT2H"),
    plain_time("01:00")
  )
  expect_identical(
    temporal_subtract(plain_time("00:30"), "PT1H"),
    plain_time("23:30")
  )
  expect_identical(
    temporal_add(plain_time("12:00"), "P1M"),
    plain_time("12:00")
  )
  expect_identical(
    temporal_add(plain_time("12:00"), "PT9007199254740991S"),
    plain_time("12:00:00") |> temporal_add(duration(seconds = 2^53 - 1))
  )
  expect_identical(
    temporal_until(plain_time("12:00"), "13:30"),
    duration("PT1H30M")
  )
  expect_identical(
    temporal_since(plain_time("12:00"), "13:30"),
    duration("-PT1H30M")
  )
  expect_identical(
    temporal_until(plain_time("12:00"), "13:30", largest_unit = "minute"),
    duration("PT90M")
  )
  expect_identical(
    temporal_until(
      plain_time("12:00"),
      "13:30",
      smallest_unit = "hour",
      rounding_mode = "halfExpand"
    ),
    duration("PT2H")
  )
  expect_error(
    temporal_until(plain_time("12:00"), "13:30", largest_unit = "day"),
    class = "zutempo_range_error"
  )
})

test_that("date-time arithmetic carries between date and time", {
  x <- plain_date_time("2026-01-31T12:00")
  expect_identical(
    temporal_add(x, "P1MT25H"),
    plain_date_time("2026-03-01T13:00")
  )
  expect_identical(
    temporal_add(plain_date_time("2026-01-31T23:00"), "PT2H"),
    plain_date_time("2026-02-01T01:00")
  )
  expect_identical(
    temporal_subtract(plain_date_time("2026-03-01T00:30"), "PT1H"),
    plain_date_time("2026-02-28T23:30")
  )
  expect_error(
    temporal_add(x, "P1M", overflow = "reject"),
    class = "zutempo_range_error"
  )
  expect_error(
    temporal_add(plain_date_time("+275760-09-13T23:00"), "PT2H"),
    class = "zutempo_range_error"
  )
  expect_identical(temporal_until(x, "2026-03-01T11:00"), duration("P28DT23H"))
  expect_identical(
    temporal_until(x, "2026-03-01T11:00", largest_unit = "month"),
    duration("P28DT23H")
  )
  expect_identical(
    temporal_until(
      plain_date_time("2026-03-01T11:00"),
      x,
      largest_unit = "month"
    ),
    duration("-P1MT23H")
  )
  expect_identical(
    temporal_until(x, "2026-03-01T11:00", largest_unit = "hour"),
    duration("PT695H")
  )
  expect_identical(
    temporal_until(
      x,
      "2026-03-01T11:00",
      smallest_unit = "month",
      rounding_mode = "halfExpand"
    ),
    duration("P1M")
  )
  expect_identical(
    temporal_since(x, "2026-03-01T11:00", largest_unit = "month"),
    duration("-P28DT23H")
  )
})

test_that("year-month arithmetic takes years and months only", {
  x <- plain_year_month("2026-01")
  expect_identical(temporal_add(x, "P13M"), plain_year_month("2027-02"))
  expect_identical(temporal_subtract(x, "P1Y"), plain_year_month("2025-01"))
  expect_error(temporal_add(x, "P1D"), class = "zutempo_range_error")
  expect_error(temporal_add(x, "PT1H"), class = "zutempo_range_error")
  expect_error(
    temporal_add(plain_year_month("+275760-09"), "P1M"),
    class = "zutempo_range_error"
  )
  expect_identical(temporal_until(x, "2027-03"), duration("P1Y2M"))
  expect_identical(
    temporal_until(x, "2027-03", largest_unit = "month"),
    duration("P14M")
  )
  expect_identical(temporal_since(x, "2027-03"), duration("-P1Y2M"))
  expect_error(
    temporal_until(x, "2027-03", largest_unit = "day"),
    class = "zutempo_range_error"
  )
  expect_identical(
    temporal_until(
      x,
      "2027-08",
      smallest_unit = "year",
      rounding_mode = "halfExpand"
    ),
    duration("P2Y")
  )
})
