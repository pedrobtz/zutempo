test_that("plain_year_month() reads fields, strings and dates", {
  expect_identical(unclass(plain_year_month(1970, 1)), 0L)
  expect_identical(unclass(plain_year_month("1969-12")), -1L)
  expect_identical(plain_year_month("202603"), plain_year_month(2026, 3))
  expect_identical(
    plain_year_month("2026-03-15T12:30+01:00"),
    plain_year_month(2026, 3)
  )
  expect_identical(
    plain_year_month(plain_date("2026-03-15")),
    plain_year_month(2026, 3)
  )
  expect_identical(
    plain_year_month(plain_date_time("2026-03-15T12:00")),
    plain_year_month(2026, 3)
  )
  expect_identical(
    plain_year_month(2026, month_code = "M03"),
    plain_year_month(2026, 3)
  )
  x <- plain_year_month("2026-03")
  expect_identical(plain_year_month(x), x)
  expect_true(is.na(plain_year_month(NA_character_)))
  expect_identical(year(plain_year_month(NA_character_)), NA_integer_)
  expect_identical(
    plain_year_month(2026, 1:3),
    plain_year_month(c("2026-01", "2026-02", "2026-03"))
  )
})

test_that("plain_year_month() rejects wrong input and bad strings", {
  expect_error(plain_year_month(), class = "zutempo_type_error")
  expect_error(plain_year_month(2026), class = "zutempo_type_error")
  expect_error(plain_year_month("2026-03", 3), class = "zutempo_type_error")
  expect_error(
    plain_year_month(plain_time("12:00")),
    class = "zutempo_type_error"
  )
  expect_error(plain_year_month("2026-3"), class = "zutempo_parse_error")
  expect_error(plain_year_month("2026-13"), class = "zutempo_parse_error")
  expect_error(plain_year_month("2026-02-30"), class = "zutempo_parse_error")
  expect_error(
    plain_year_month("2026-03-15T12:30Z"),
    class = "zutempo_parse_error"
  )
  expect_error(plain_year_month("-000000-01"), class = "zutempo_parse_error")
  expect_identical(
    plain_year_month("2026-03[u-ca=iso8601]"),
    plain_year_month("2026-03")
  )
  # Only the ISO 8601 calendar has the form without a day.
  expect_error(
    plain_year_month("2026-03[u-ca=gregory]"),
    class = "zutempo_parse_error"
  )
})

test_that("the range of a plain_year_month() covers every month with a date", {
  expect_identical(
    temporal_to_string(plain_year_month("+275760-09")),
    "+275760-09"
  )
  expect_identical(
    temporal_to_string(plain_year_month("-271821-04")),
    "-271821-04"
  )
  expect_error(plain_year_month("+275760-10"), class = "zutempo_range_error")
  expect_error(plain_year_month("-271821-03"), class = "zutempo_range_error")
  expect_error(plain_year_month(275760, 10), class = "zutempo_range_error")
  expect_identical(days_in_month(plain_year_month("-271821-04")), 30L)
  expect_identical(plain_year_month(2026, 13), plain_year_month(2026, 12))
  expect_error(
    plain_year_month(2026, 13, overflow = "reject"),
    class = "zutempo_range_error"
  )
  expect_error(plain_year_month(2026, 0), class = "zutempo_range_error")
})

test_that("fields of a year-month follow the ISO calendar", {
  x <- plain_year_month(c("2024-02", "2100-02", NA))
  expect_identical(year(x), c(2024L, 2100L, NA))
  expect_identical(month(x), c(2L, 2L, NA))
  expect_identical(month_code(x), c("M02", "M02", NA))
  expect_identical(days_in_month(x), c(29L, 28L, NA))
  expect_identical(days_in_year(x), c(366L, 365L, NA))
  expect_identical(in_leap_year(x), c(TRUE, FALSE, NA))
  expect_identical(months_in_year(x), c(12L, 12L, NA))
  expect_identical(calendar_id(x), c("iso8601", "iso8601", NA))
  expect_identical(era(x), c(NA_character_, NA, NA))
})

test_that("with, compare, equals and to_plain_date follow the specification", {
  x <- plain_year_month("2026-02")
  expect_identical(temporal_with(x, month = 14), plain_year_month("2026-12"))
  expect_error(
    temporal_with(x, month = 14, overflow = "reject"),
    class = "zutempo_range_error"
  )
  expect_identical(
    temporal_with(x, month_code = "M12", year = 2000),
    plain_year_month("2000-12")
  )
  expect_error(temporal_with(x, day = 5), class = "zutempo_type_error")
  expect_error(temporal_with(x), class = "zutempo_type_error")
  expect_identical(plain_year_month_compare(x, "2026-02-28"), 0L)
  expect_identical(plain_year_month_compare(c(x, NA), "2026-03"), c(-1L, NA))
  expect_true(temporal_equals(x, "2026-02-15"))
  expect_identical(
    temporal_to_plain_date(x, day = 31),
    plain_date("2026-02-28")
  )
  expect_identical(
    temporal_to_plain_date(x, day = c(1, 15)),
    plain_date(c("2026-02-01", "2026-02-15"))
  )
  expect_error(temporal_to_plain_date(x), class = "zutempo_type_error")
  expect_error(
    temporal_to_plain_date(x, day = 0),
    class = "zutempo_range_error"
  )
  expect_error(
    temporal_to_plain_date(plain_year_month("+275760-09"), day = 30),
    class = "zutempo_range_error"
  )
  expect_identical(
    temporal_to_plain_year_month(plain_date("2026-01-31")),
    plain_year_month("2026-01")
  )
})
