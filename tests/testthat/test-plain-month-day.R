test_that("plain_month_day() reads fields, strings and dates", {
  expect_identical(unclass(plain_month_day(3, 14)), 3L * 32L + 14L)
  for (s in c(
    "03-14",
    "0314",
    "--03-14",
    "--0314",
    "2026-03-14",
    "20260314",
    "2026-03-14T12:30+01:00"
  )) {
    expect_identical(plain_month_day(s), plain_month_day(3, 14), info = s)
  }
  expect_identical(plain_month_day("02-29"), plain_month_day(2, 29))
  expect_identical(
    plain_month_day(month_code = "M02", day = 29),
    plain_month_day(2, 29)
  )
  expect_identical(
    plain_month_day(plain_date("2024-02-29")),
    plain_month_day(2, 29)
  )
  expect_identical(
    plain_month_day(plain_date_time("2026-03-14T12:00")),
    plain_month_day(3, 14)
  )
  x <- plain_month_day("03-14")
  expect_identical(plain_month_day(x), x)
  expect_true(is.na(plain_month_day(NA_character_)))
  expect_identical(day(plain_month_day(NA_character_)), NA_integer_)
})

test_that("plain_month_day() rejects wrong input and bad strings", {
  expect_error(plain_month_day(), class = "zutempo_type_error")
  expect_error(plain_month_day(3), class = "zutempo_type_error")
  expect_error(plain_month_day("03-14", 1), class = "zutempo_type_error")
  expect_error(
    plain_month_day(plain_time("12:00")),
    class = "zutempo_type_error"
  )
  for (s in c(
    "02-30",
    "13-01",
    "03-00",
    "-03-14",
    "03-14T12:30",
    "2026-02-29",
    "2026-03-14T12:30Z",
    "3-14"
  )) {
    expect_error(plain_month_day(s), class = "zutempo_parse_error", info = s)
  }
})

test_that("a year constrains or rejects the day", {
  expect_identical(plain_month_day(2, 29, year = 2025), plain_month_day(2, 28))
  expect_error(
    plain_month_day(2, 29, year = 2025, overflow = "reject"),
    class = "zutempo_range_error"
  )
  expect_identical(plain_month_day(2, 30), plain_month_day(2, 29))
  expect_error(
    plain_month_day(2, 30, overflow = "reject"),
    class = "zutempo_range_error"
  )
  expect_error(
    plain_month_day(13, 1, overflow = "reject"),
    class = "zutempo_range_error"
  )
  expect_identical(plain_month_day(13, 1), plain_month_day(12, 1))
})

test_that("fields, with, equals and to_plain_date follow the specification", {
  x <- plain_month_day(c("02-29", NA))
  expect_identical(month_code(x), c("M02", NA))
  expect_identical(day(x), c(29L, NA))
  expect_identical(calendar_id(x), c("iso8601", NA))
  expect_error(month(x), class = "zutempo_type_error")
  expect_identical(temporal_with(x[1], day = 31), plain_month_day(2, 29))
  expect_identical(temporal_with(x[1], year = 2025), plain_month_day(2, 28))
  expect_error(
    temporal_with(x[1], year = 2025, overflow = "reject"),
    class = "zutempo_range_error"
  )
  expect_identical(temporal_with(x[1], month = 3), plain_month_day(3, 29))
  expect_identical(
    temporal_with(x[1], month_code = "M03"),
    plain_month_day(3, 29)
  )
  expect_error(temporal_with(x[1]), class = "zutempo_type_error")
  expect_error(temporal_with(x[1], hour = 1), class = "zutempo_type_error")
  expect_identical(temporal_equals(x, "2024-02-29"), c(TRUE, NA))
  expect_false(temporal_equals(x[1], "02-28"))
  expect_identical(
    temporal_to_plain_date(x[1], year = 2024),
    plain_date("2024-02-29")
  )
  expect_identical(
    temporal_to_plain_date(x[1], year = 2025),
    plain_date("2025-02-28")
  )
  expect_error(temporal_to_plain_date(x[1]), class = "zutempo_type_error")
  expect_error(
    temporal_to_plain_date(plain_month_day("09-14"), year = 275760),
    class = "zutempo_range_error"
  )
  expect_identical(temporal_to_plain_month_day(plain_date("2024-02-29")), x[1])
  expect_identical(temporal_to_string(x), c("02-29", NA))
})
