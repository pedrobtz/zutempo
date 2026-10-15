test_that("plain_date() reads fields, strings and other plain types", {
  expect_identical(unclass(plain_date(1970, 1, 1)), 0L)
  expect_identical(unclass(plain_date("1970-01-02")), 1L)
  expect_identical(unclass(plain_date("1969-12-31")), -1L)
  expect_identical(
    plain_date(plain_date_time("2026-01-31T12:30")),
    plain_date("2026-01-31")
  )
  x <- plain_date("2026-01-31")
  expect_identical(plain_date(x), x)
  expect_s3_class(x, "zutempo_plain_date")
})

test_that("plain_date() recycles fields and propagates NA", {
  x <- plain_date(2026, 1:3, 1)
  expect_length(x, 3L)
  expect_identical(month(x), 1:3)
  expect_identical(
    plain_date(c(2026, NA), 1, 1),
    plain_date(c("2026-01-01", NA))
  )
  expect_true(is.na(plain_date(NA_character_)))
  expect_identical(year(plain_date(NA_character_)), NA_integer_)
  expect_error(plain_date(2026, 1:2, 1:3), class = "zutempo_type_error")
})

test_that("plain_date() rejects wrong kinds of input with a type error", {
  expect_error(plain_date(), class = "zutempo_type_error")
  expect_error(plain_date(TRUE), class = "zutempo_type_error")
  expect_error(plain_date(2026), class = "zutempo_type_error")
  expect_error(plain_date(2026, 1), class = "zutempo_type_error")
  expect_error(plain_date("2026-01-31", 1), class = "zutempo_type_error")
  expect_error(plain_date(2026, 1, 1, 5), class = "zutempo_type_error")
  expect_error(plain_date(2026, "1", 1), class = "zutempo_type_error")
  expect_error(
    plain_date(2026, 1, 1, overflow = "bogus"),
    class = "zutempo_type_error"
  )
  expect_error(
    plain_date(2026, 1, 1, overflow = NA),
    class = "zutempo_type_error"
  )
})

test_that("the range of a plain_date() is Temporal's (design 6.1)", {
  expect_identical(
    temporal_to_string(plain_date("+275760-09-13")),
    "+275760-09-13"
  )
  expect_identical(
    temporal_to_string(plain_date("-271821-04-19")),
    "-271821-04-19"
  )
  expect_error(plain_date("+275760-09-14"), class = "zutempo_range_error")
  expect_error(plain_date("-271821-04-18"), class = "zutempo_range_error")
  expect_error(plain_date(275760, 9, 14), class = "zutempo_range_error")
  expect_error(plain_date(1e300, 1, 1), class = "zutempo_range_error")
  expect_error(plain_date(Inf, 1, 1), class = "zutempo_range_error")
  expect_error(plain_date(NaN, 1, 1), class = "zutempo_range_error")
})

test_that("-000000 is a parse error and the error names the element", {
  cond <- tryCatch(
    plain_date(c("2026-01-31", "-000000-01-01")),
    error = identity
  )
  expect_s3_class(cond, "zutempo_parse_error")
  expect_s3_class(cond, "zutempo_range_error")
  expect_identical(cond$index, 2)
  expect_match(conditionMessage(cond), "element 2")
  expect_match(conditionMessage(cond), "byte")
})

test_that("annotations are read, and a calendar other than ISO 8601 rejected", {
  expect_identical(
    plain_date("2026-01-31[u-ca=iso8601]"),
    plain_date("2026-01-31")
  )
  expect_error(
    plain_date("2026-01-31[u-ca=hebrew]"),
    class = "zutempo_range_error"
  )
  # The time zone annotation is read and ignored by a plain type.
  expect_identical(
    plain_date("2026-01-31[America/New_York]"),
    plain_date("2026-01-31")
  )
})

test_that("month codes are validated and reconciled with month", {
  expect_identical(
    plain_date(2026, month_code = "M02", day = 1),
    plain_date(2026, 2, 1)
  )
  expect_identical(
    plain_date(2026, 2, 1, month_code = "M02"),
    plain_date(2026, 2, 1)
  )
  expect_error(
    plain_date(2026, 3, 1, month_code = "M02"),
    class = "zutempo_range_error"
  )
  expect_error(
    plain_date(2026, month_code = "M13", day = 1),
    class = "zutempo_range_error"
  )
  expect_error(
    plain_date(2026, month_code = "M02L", day = 1),
    class = "zutempo_range_error"
  )
  expect_error(
    plain_date(2026, month_code = "02", day = 1),
    class = "zutempo_range_error"
  )
  expect_error(
    plain_date(2026, month_code = 2, day = 1),
    class = "zutempo_type_error"
  )
})

test_that("temporal_with() replaces fields with the ISO merge rules", {
  x <- plain_date("2026-01-31")
  expect_identical(
    temporal_with(x, year = 2024, month = 2, day = 29),
    plain_date("2024-02-29")
  )
  expect_identical(temporal_with(x, month = 2), plain_date("2026-02-28"))
  expect_identical(
    temporal_with(x, month_code = "M02"),
    plain_date("2026-02-28")
  )
  expect_error(
    temporal_with(x, month = 2, overflow = "reject"),
    class = "zutempo_range_error"
  )
  expect_error(
    temporal_with(x, month = 2, month_code = "M03"),
    class = "zutempo_range_error"
  )
  expect_error(temporal_with(x), class = "zutempo_type_error")
  expect_error(temporal_with(x, 5), class = "zutempo_type_error")
  expect_error(temporal_with(x, hour = 5), class = "zutempo_type_error")
  expect_error(temporal_with(x, day = 1, day = 2), class = "zutempo_type_error")
  expect_identical(
    temporal_with(plain_date(c("2026-01-31", NA)), day = 1)[2],
    plain_date(NA_character_)
  )
})

test_that("temporal_with_calendar() accepts only the ISO calendar", {
  x <- plain_date("2026-01-31")
  expect_identical(temporal_with_calendar(x, "iso8601"), x)
  expect_identical(temporal_with_calendar(x, "ISO8601"), x)
  expect_error(
    temporal_with_calendar(x, "hebrew"),
    class = "zutempo_range_error"
  )
  expect_error(temporal_with_calendar(x, 1), class = "zutempo_type_error")
  expect_identical(calendar_id(x), "iso8601")
  expect_identical(era(x), NA_character_)
  expect_identical(era_year(x), NA_integer_)
})

test_that("comparisons recycle and accept strings", {
  x <- plain_date(c("2026-01-31", "2026-02-01", NA))
  expect_identical(plain_date_compare(x, "2026-02-01"), c(-1L, 0L, NA))
  expect_identical(temporal_equals(x, "2026-02-01"), c(FALSE, TRUE, NA))
  expect_identical(plain_date_compare(x[1], x[2:3]), c(-1L, NA))
})

test_that("the fields of a date follow the ISO calendar", {
  x <- plain_date("2024-02-29")
  expect_identical(day_of_year(x), 60L)
  expect_identical(day_of_week(x), 4L)
  expect_identical(days_in_month(x), 29L)
  expect_identical(days_in_year(x), 366L)
  expect_true(in_leap_year(x))
  expect_identical(days_in_week(x), 7L)
  expect_identical(months_in_year(x), 12L)
  expect_identical(month_code(x), "M02")
  expect_identical(week_of_year(plain_date("2024-12-31")), 1L)
  expect_identical(year_of_week(plain_date("2024-12-31")), 2025L)
  expect_identical(in_leap_year(plain_date(NA_character_)), NA)
})
