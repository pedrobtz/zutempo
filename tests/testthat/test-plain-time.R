test_that("plain_time() reads fields and strings", {
  expect_identical(unclass(plain_time()), 0)
  expect_identical(unclass(plain_time(0, 0, 0, 0, 0, 1)), 1)
  expect_identical(unclass(plain_time(23, 59, 59, 999, 999, 999)), 86400e9 - 1)
  expect_identical(plain_time("12:30:45.5"), plain_time(12, 30, 45, 500))
  expect_identical(plain_time("T12"), plain_time(12))
  expect_identical(plain_time("2026-01-31T12:30+05:30"), plain_time(12, 30))
  expect_identical(
    plain_time(plain_date_time("2026-01-31T12:30")),
    plain_time(12, 30)
  )
  expect_error(
    plain_time(plain_date("2026-01-31")),
    class = "zutempo_type_error"
  )
  expect_true(is.na(plain_time(NA_character_)))
  expect_true(is.na(plain_time(NA, 1)))
})

test_that("plain_time() applies overflow to every field", {
  expect_identical(
    plain_time(24, 60, 60, 1000, 1000, 1000),
    plain_time(23, 59, 59, 999, 999, 999)
  )
  expect_identical(plain_time(-1, -1), plain_time(0))
  expect_error(
    plain_time(24, overflow = "reject"),
    class = "zutempo_range_error"
  )
  cond <- tryCatch(
    plain_time(c(1, 2, 25), overflow = "reject"),
    error = identity
  )
  expect_identical(cond$index, 3)
})

test_that("ambiguous bare times are rejected and 'T' disambiguates", {
  expect_error(plain_time("1230"), class = "zutempo_parse_error")
  expect_error(plain_time("12-14"), class = "zutempo_parse_error")
  expect_error(plain_time("2026-03"), class = "zutempo_parse_error")
  expect_error(plain_time("2026-01-31"), class = "zutempo_parse_error")
  expect_identical(plain_time("T1230"), plain_time(12, 30))
  expect_identical(plain_time("123045"), plain_time(12, 30, 45))
  expect_error(plain_time("12:30Z"), class = "zutempo_parse_error")
  expect_error(plain_time("24:00"), class = "zutempo_parse_error")
  expect_identical(plain_time("12:30:60"), plain_time(12, 30, 59))
  expect_error(plain_time("12:30:45.1234567890"), class = "zutempo_parse_error")
  expect_error(plain_time(""), class = "zutempo_parse_error")
})

test_that("temporal_round() validates its options", {
  x <- plain_time("12:30")
  expect_error(temporal_round(x), class = "zutempo_type_error")
  expect_error(temporal_round(x, "fortnight"), class = "zutempo_type_error")
  expect_error(temporal_round(x, "day"), class = "zutempo_range_error")
  expect_error(
    temporal_round(x, "hour", rounding_increment = 24),
    class = "zutempo_range_error"
  )
  expect_error(
    temporal_round(x, "hour", rounding_increment = 7),
    class = "zutempo_range_error"
  )
  expect_error(
    temporal_round(x, "hour", rounding_increment = 0),
    class = "zutempo_range_error"
  )
  expect_error(
    temporal_round(x, "hour", rounding_increment = "2"),
    class = "zutempo_type_error"
  )
  expect_error(
    temporal_round(x, "hour", rounding_mode = "nearest"),
    class = "zutempo_type_error"
  )
  expect_identical(
    temporal_round(x, "hours", rounding_increment = 2),
    plain_time(12)
  )
  expect_identical(
    temporal_round(
      plain_time(c(NA, 12.5 * 3600e9 / 3600e9 * 0 + 12), 30),
      "hour"
    )[1],
    plain_time(NA_real_)
  )
})

test_that("the nine rounding modes agree with the specification's table", {
  tie <- plain_time("12:30")
  odd <- plain_time("13:30")
  below <- plain_time("13:29")
  r <- function(x, mode) hour(temporal_round(x, "hour", rounding_mode = mode))
  expect_identical(r(tie, "ceil"), 13L)
  expect_identical(r(tie, "floor"), 12L)
  expect_identical(r(tie, "expand"), 13L)
  expect_identical(r(tie, "trunc"), 12L)
  expect_identical(r(tie, "halfCeil"), 13L)
  expect_identical(r(tie, "halfFloor"), 12L)
  expect_identical(r(tie, "halfExpand"), 13L)
  expect_identical(r(tie, "halfTrunc"), 12L)
  expect_identical(r(tie, "halfEven"), 12L)
  expect_identical(r(odd, "halfEven"), 14L)
  expect_identical(r(below, "halfCeil"), 13L)
  expect_identical(r(below, "ceil"), 14L)
})

test_that("time strings keep significant fraction digits only", {
  expect_identical(temporal_to_string(plain_time(12, 30)), "12:30:00")
  expect_identical(
    temporal_to_string(plain_time(12, 30, 45, 500)),
    "12:30:45.5"
  )
  expect_identical(
    temporal_to_string(plain_time(0, 0, 0, 0, 0, 1)),
    "00:00:00.000000001"
  )
  expect_identical(format(plain_time(c(NA, 7))), c(NA, "07:00:00"))
})
