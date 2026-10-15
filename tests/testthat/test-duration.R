test_that("duration() reads fields and strings and keeps exact large values", {
  d <- duration(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)
  expect_identical(temporal_to_string(d), "P1Y2M3W4DT5H6M7.00800901S")
  expect_identical(years(d), 1)
  expect_identical(nanoseconds(d), 10)
  expect_identical(duration("PT1.5H"), duration(hours = 1, minutes = 30))
  expect_identical(duration("-P1DT2H"), duration(days = -1, hours = -2))
  expect_identical(duration(milliseconds = 2^53 + 2)$milliseconds, 2^53 + 2)
  expect_identical(
    temporal_to_string(duration(milliseconds = 2^53 + 2)),
    "PT9007199254740.994S"
  )
  expect_identical(duration(nanoseconds = 1e21)$nanoseconds, 1e21)
  expect_identical(
    temporal_to_string(duration(nanoseconds = 1e21)),
    "PT1000000000000S"
  )
  x <- duration("P1D")
  expect_identical(duration(x), x)
  expect_true(is.na(duration(NA_character_)))
  expect_identical(years(duration(NA_character_)), NA_real_)
  expect_identical(duration(hours = c(1, NA, 3))$hours, c(1, NA, 3))
  expect_identical(length(duration(hours = 1:3)), 3L)
})

test_that("duration() rejects invalid fields and strings", {
  expect_error(duration(years = 1, months = -1), class = "zutempo_range_error")
  expect_error(duration(hours = 1.5), class = "zutempo_range_error")
  expect_error(duration(years = 2^32), class = "zutempo_range_error")
  expect_error(duration(seconds = 2^53), class = "zutempo_range_error")
  expect_error(
    duration(seconds = 2^53 - 1, nanoseconds = 1e9),
    class = "zutempo_range_error"
  )
  expect_error(duration(TRUE), class = "zutempo_type_error")
  expect_error(duration(hours = "1"), class = "zutempo_type_error")
  expect_error(
    duration(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11),
    class = "zutempo_type_error"
  )
  for (s in c(
    "P",
    "PT",
    "P1D1W",
    "PT1.5H30M",
    "P1.5D",
    "PT0.1234567890S",
    " P1D",
    "P1D ",
    "P1Y1",
    "X1D"
  )) {
    expect_error(duration(s), class = "zutempo_parse_error", info = s)
  }
  expect_error(duration("PT9007199254740992S"), class = "zutempo_range_error")
  cond <- tryCatch(duration(c("P1D", "P1D1W")), error = identity)
  expect_identical(cond$index, 2)
})

test_that("sign, blank, negated and abs follow the specification", {
  d <- duration(c("P1D", "-PT1S", "PT0S", NA))
  expect_identical(sign(d), c(1L, -1L, 0L, NA))
  expect_identical(blank(d), c(FALSE, FALSE, TRUE, NA))
  expect_identical(temporal_negated(d), duration(c("-P1D", "PT1S", "PT0S", NA)))
  expect_identical(abs(d), duration(c("P1D", "PT1S", "PT0S", NA)))
  expect_identical(temporal_abs(d), abs(d))
  expect_error(sqrt(d), class = "zutempo_type_error")
})

test_that("temporal_with() on a duration replaces fields and checks signs", {
  d <- duration("P1Y2M3W4DT5H6M7.5S")
  expect_identical(temporal_with(d, years = 0), duration("P2M3W4DT5H6M7.5S"))
  expect_error(temporal_with(d, months = -1), class = "zutempo_range_error")
  expect_error(temporal_with(d), class = "zutempo_type_error")
  expect_error(temporal_with(d, year = 1), class = "zutempo_type_error")
})

test_that("duration add, subtract, round, total and compare without relative_to", {
  expect_identical(temporal_add(duration("PT1H"), "PT30M"), duration("PT1H30M"))
  expect_identical(temporal_add(duration("P1D"), "PT25H"), duration("P2DT1H"))
  expect_identical(
    temporal_subtract(duration("PT1H"), "PT2H"),
    duration("-PT1H")
  )
  expect_error(
    temporal_add(duration("P1M"), "P1D"),
    class = "zutempo_range_error"
  )
  expect_identical(
    temporal_round(duration("PT25H"), largest_unit = "day"),
    duration("P1DT1H")
  )
  expect_identical(temporal_round(duration("PT90M"), "hour"), duration("PT2H"))
  expect_identical(temporal_round(duration("P1DT12H"), "day"), duration("P2D"))
  expect_error(
    temporal_round(duration("P1Y"), "month"),
    class = "zutempo_range_error"
  )
  expect_error(temporal_round(duration("PT1H")), class = "zutempo_range_error")
  expect_error(
    temporal_round(duration("PT100H"), "hour", rounding_increment = 7),
    class = "zutempo_range_error"
  )
  expect_error(
    temporal_round(duration("P1D"), "day", largest_unit = "hour"),
    class = "zutempo_range_error"
  )
  expect_equal(temporal_total(duration("PT25H"), "day"), 25 / 24)
  expect_identical(temporal_total(duration("P1DT12H"), "days"), 1.5)
  expect_error(
    temporal_total(duration("P1M"), "day"),
    class = "zutempo_range_error"
  )
  expect_error(temporal_total(duration("PT1H")), class = "zutempo_type_error")
  expect_identical(duration_compare("PT1H", "PT60M"), 0L)
  expect_identical(duration_compare("P1D", "PT24H"), 0L)
  expect_identical(duration_compare("-PT1H", "PT1H"), -1L)
  expect_error(duration_compare("P1M", "P30D"), class = "zutempo_range_error")
  expect_identical(
    duration_compare(duration(c("PT1H", NA)), "PT2H"),
    c(-1L, NA)
  )
})

test_that("relative_to drives calendar units (design 6.5)", {
  expect_identical(
    temporal_round(
      duration("PT25H"),
      largest_unit = "day",
      relative_to = "2026-03-07"
    ),
    duration("P1DT1H")
  )
  expect_identical(
    temporal_round(
      duration("P45D"),
      largest_unit = "month",
      relative_to = plain_date("2026-01-31")
    ),
    duration("P1M17D")
  )
  expect_identical(
    temporal_round(
      duration("P1M16D"),
      "month",
      relative_to = plain_date_time("2026-01-01T12:00")
    ),
    duration("P2M")
  )
  expect_identical(
    temporal_total(duration("P1M"), "day", relative_to = "2026-02-01"),
    28
  )
  expect_identical(
    duration_compare("P1M", "P30D", relative_to = "2026-02-01"),
    -1L
  )
  expect_identical(
    duration_compare("P1M", "P30D", relative_to = "2026-01-01"),
    1L
  )
  expect_error(
    temporal_total(duration("P1M"), "day", relative_to = 5),
    class = "zutempo_type_error"
  )
  expect_identical(
    temporal_total(duration(c("P1M", NA)), "day", relative_to = "2026-02-01"),
    c(28, NA)
  )
})

test_that("comparison operators on durations follow design 6.5", {
  a <- duration(c("PT1H", "PT60M", "PT2H"))
  expect_identical(a == "PT60M", c(FALSE, TRUE, FALSE))
  expect_identical(a != duration("PT1H"), c(FALSE, TRUE, TRUE))
  expect_identical(a < "PT90M", c(TRUE, TRUE, FALSE))
  expect_identical(
    sort(duration(c("PT2H", "PT1H", "P1D"))),
    duration(c("PT1H", "PT2H", "P1D"))
  )
  expect_error(sort(duration(c("P1M", "P30D"))), class = "zutempo_range_error")
  expect_error(duration("P1M") < "P30D", class = "zutempo_range_error")
  expect_error(
    duration("PT1H") + duration("PT1H"),
    class = "zutempo_type_error"
  )
})

test_that("durations behave as vectors", {
  d <- duration(c("P1D", "PT2H", NA))
  expect_identical(length(d), 3L)
  expect_identical(d[2], duration("PT2H"))
  expect_identical(d[[2]], duration("PT2H"))
  expect_identical(c(d[1], d[2]), d[1:2])
  expect_identical(c(d[1], NA), d[c(1, 3)])
  expect_identical(rep(d[1], 2), duration(c("P1D", "P1D")))
  expect_identical(rev(d), d[3:1])
  expect_identical(unique(c(d, d)), d)
  expect_identical(is.na(d), c(FALSE, FALSE, TRUE))
  y <- d
  y[3] <- duration("PT1S")
  expect_identical(y[3], duration("PT1S"))
  y[1] <- NA
  expect_true(is.na(y[1]))
  expect_error(y[1] <- 5, class = "zutempo_type_error")
  expect_error(c(d, plain_date("2026-01-01")), class = "zutempo_type_error")
  length(y) <- 4
  expect_true(is.na(y[4]))
  expect_identical(format(d), c("P1D", "PT2H", NA))
  expect_identical(as.character(d), format(d))
  out <- capture.output(print(d))
  expect_match(out[1], "<zutempo_duration\\[3\\]>")
  df <- data.frame(d = d)
  expect_identical(df$d, d)
  expect_identical(rbind(df, df)$d, c(d, d))
  path <- withr::local_tempfile(fileext = ".rds")
  saveRDS(df, path)
  expect_identical(readRDS(path), df)
})

test_that("vctrs and pillar handle durations", {
  skip_if_not_installed("vctrs")
  d <- duration(c("P1D", "PT2H", NA))
  expect_identical(vctrs::vec_slice(d, 2:3), d[2:3])
  expect_identical(vctrs::vec_c(d[1], d[2]), d[1:2])
  expect_identical(
    vctrs::vec_rbind(data.frame(x = d), data.frame(x = d))$x,
    c(d, d)
  )
  expect_identical(vctrs::vec_ptype_abbr(d), "duration")
  skip_if_not_installed("pillar")
  expect_s3_class(pillar::pillar_shaft(d), "pillar_shaft")
})

test_that("a relative_to string is a date, valid down to the first PlainDate", {
  # Its midnight is before the first PlainDateTime, which does not matter
  # (test262 Duration/prototype/round/relativeto-date-limits.js).
  expect_identical(
    format(temporal_round(
      duration(0),
      largest_unit = "year",
      relative_to = "-271821-04-19"
    )),
    "PT0S"
  )
  expect_identical(
    temporal_total(duration(0), "year", relative_to = "-271821-04-19"),
    0
  )
})

test_that("fields from a 128-bit total are the nearest double, ties to even", {
  # 8692288669465520373761 microseconds is not a double; adding its two
  # 64-bit halves as doubles rounded twice and missed by one ulp (test262
  # Duration/prototype/round/precision-exact-in-balance-time-duration.js).
  d <- duration(seconds = 8692288669465520, microseconds = 373761)
  r <- temporal_round(d, largest_unit = "microseconds")
  expect_identical(format(r), "PT8692288669465520.898048S")
  # Compared as the double's exact digits: R's parser does not always round
  # a long decimal literal to the nearest double.
  expect_identical(sprintf("%.0f", microseconds(r)), "8692288669465520898048")
})
