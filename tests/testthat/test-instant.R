test_that("instant() stores whole seconds and nanoseconds with the floor convention", {
  x <- instant("1969-12-31T23:59:59.5Z")
  expect_identical(Re(unclass(x)), -1)
  expect_identical(Im(unclass(x)), 5e8)
  expect_identical(
    instant("2026-01-31T12:30+05:30"),
    instant("2026-01-31T07:00Z")
  )
  expect_identical(
    instant("2026-01-31T12:30+05:30:15.5"),
    instant("2026-01-31T06:59:44.5Z")
  )
  expect_identical(instant(x), x)
  expect_true(is.na(instant(NA_character_)))
  expect_identical(epoch_milliseconds(instant(NA_character_)), NA_real_)
  expect_error(instant(5), class = "zutempo_type_error")
  for (s in c(
    "2026-01-31T12:30",
    "2026-01-31",
    "2026-01-31T12:30Z[u-ca=iso8601]",
    ""
  )) {
    expect_error(instant(s), class = "zutempo_parse_error", info = s)
  }
  # A time zone annotation is read and ignored (ParseTemporalInstantString).
  expect_identical(
    instant("2026-01-31T12:30Z[UTC]"),
    instant("2026-01-31T12:30Z")
  )
})

test_that("the range of an instant is ten to the eighth days either side of the epoch", {
  expect_identical(
    epoch_nanoseconds(instant("+275760-09-13T00:00Z")),
    "8640000000000000000000"
  )
  expect_identical(
    epoch_nanoseconds(instant("-271821-04-20T00:00Z")),
    "-8640000000000000000000"
  )
  expect_error(
    instant("+275760-09-13T00:00:00.000000001Z"),
    class = "zutempo_range_error"
  )
  expect_error(
    instant("-271821-04-19T23:59:59.999999999Z"),
    class = "zutempo_range_error"
  )
  expect_error(
    instant_from_epoch_nanoseconds("8640000000000000000001"),
    class = "zutempo_range_error"
  )
  expect_identical(
    instant_from_epoch_nanoseconds("8640000000000000000000"),
    instant("+275760-09-13T00:00Z")
  )
  expect_identical(
    instant_from_epoch_milliseconds(8.64e15),
    instant("+275760-09-13T00:00Z")
  )
  expect_error(
    instant_from_epoch_milliseconds(8.64e15 + 1),
    class = "zutempo_range_error"
  )
  expect_error(
    instant_from_epoch_milliseconds(1.5),
    class = "zutempo_range_error"
  )
  expect_error(
    instant_from_epoch_nanoseconds("1e9"),
    class = "zutempo_range_error"
  )
  expect_error(
    instant_from_epoch_nanoseconds(0.5),
    class = "zutempo_range_error"
  )
  expect_identical(
    instant_from_epoch_nanoseconds(c(-1, NA)),
    instant(c("1969-12-31T23:59:59.999999999Z", NA))
  )
})

test_that("epoch fields floor towards the past", {
  x <- instant(c("1969-12-31T23:59:59.999999999Z", "1970-01-01T00:00:00.5Z"))
  expect_identical(epoch_milliseconds(x), c(-1, 500))
  expect_identical(epoch_nanoseconds(x), c("-1", "500000000"))
  expect_identical(epoch_milliseconds(instant("+275760-09-13T00:00Z")), 8.64e15)
})

test_that("instants round as if positive and with daily maxima", {
  y <- instant("1969-12-31T23:59:59.5Z")
  expect_identical(temporal_round(y, "second"), instant("1970-01-01T00:00Z"))
  # As if positive (design 6.4): trunc goes toward the past before 1970 and
  # a tie goes toward the future. test262's rounding-direction test; the
  # polyfill 1.0.6 differs here, so these are not oracle cases.
  expect_identical(
    temporal_round(y, "second", rounding_mode = "trunc"),
    instant("1969-12-31T23:59:59Z")
  )
  expect_identical(
    temporal_round(y, "second", rounding_mode = "halfTrunc"),
    instant("1969-12-31T23:59:59Z")
  )
  expect_identical(
    temporal_round(y, "second", rounding_mode = "floor"),
    instant("1969-12-31T23:59:59Z")
  )
  expect_identical(
    temporal_round(y, "second", rounding_mode = "ceil"),
    instant("1970-01-01T00:00Z")
  )
  expect_identical(
    temporal_round(y, "hour", rounding_increment = 24),
    instant("1970-01-01T00:00Z")
  )
  expect_error(
    temporal_round(y, "hour", rounding_increment = 25),
    class = "zutempo_range_error"
  )
  expect_error(temporal_round(y, "day"), class = "zutempo_range_error")
  expect_error(temporal_round(y), class = "zutempo_type_error")
  expect_identical(
    temporal_round(instant("+275760-09-12T23:59:59.9Z"), "second"),
    instant("+275760-09-13T00:00Z")
  )
})

test_that("instants format in UTC or in a fixed-offset zone", {
  y <- instant("1969-12-31T23:59:59.5Z")
  expect_identical(temporal_to_string(y), "1969-12-31T23:59:59.5Z")
  expect_identical(
    temporal_to_string(y, time_zone = "+05:30"),
    "1970-01-01T05:29:59.5+05:30"
  )
  expect_identical(
    temporal_to_string(y, time_zone = "+0530"),
    "1970-01-01T05:29:59.5+05:30"
  )
  expect_identical(
    temporal_to_string(y, time_zone = "+05"),
    "1970-01-01T04:59:59.5+05:00"
  )
  expect_identical(
    temporal_to_string(y, time_zone = "utc"),
    "1969-12-31T23:59:59.5+00:00"
  )
  expect_identical(
    temporal_to_string(y, time_zone = "-00:00"),
    "1969-12-31T23:59:59.5+00:00"
  )
  expect_error(
    temporal_to_string(y, time_zone = "+05:30:15"),
    class = "zutempo_range_error"
  )
  expect_error(
    temporal_to_string(y, time_zone = "bogus/"),
    class = "zutempo_range_error"
  )
  expect_error(
    temporal_to_string(y, time_zone = "Mars/Olympus_Mons"),
    class = "zutempo_tz_error"
  )
  expect_error(
    temporal_to_string(y, time_zone = 5),
    class = "zutempo_type_error"
  )
  expect_identical(
    format(instant(c("1970-01-01T00:00Z", NA))),
    c("1970-01-01T00:00:00Z", NA)
  )
})

test_that("instant arithmetic takes time units only", {
  y <- instant("1969-12-31T23:59:59.5Z")
  expect_identical(temporal_add(y, "PT1H"), instant("1970-01-01T00:59:59.5Z"))
  expect_identical(
    temporal_subtract(y, duration(milliseconds = 500)),
    instant("1969-12-31T23:59:59Z")
  )
  expect_error(temporal_add(y, "P1D"), class = "zutempo_range_error")
  expect_error(
    temporal_add(instant("+275760-09-13T00:00Z"), "PT1S"),
    class = "zutempo_range_error"
  )
  expect_identical(
    temporal_until(y, "1970-01-02T00:00:00Z"),
    duration(seconds = 86400, milliseconds = 500)
  )
  expect_identical(
    temporal_until(y, "1970-01-02T00:00:00Z", largest_unit = "hour"),
    duration(hours = 24, milliseconds = 500)
  )
  expect_identical(
    temporal_since(y, "1970-01-02T00:00:00Z", largest_unit = "hour"),
    duration(hours = -24, milliseconds = -500)
  )
  expect_error(
    temporal_until(y, "1970-01-02T00:00:00Z", largest_unit = "day"),
    class = "zutempo_range_error"
  )
  expect_identical(
    temporal_until(
      instant("-271821-04-20T00:00Z"),
      "+275760-09-13T00:00Z",
      largest_unit = "hour"
    ),
    duration(hours = 4800000000)
  )
})

test_that("instants compare, sort and behave as vectors", {
  x <- instant(c(
    "1970-01-01T00:00Z",
    "1969-12-31T23:59:59.5Z",
    NA,
    "+275760-09-13T00:00Z"
  ))
  expect_identical(instant_compare(x[2], "1970-01-01T00:00Z"), -1L)
  expect_identical(instant_compare(x, x[1]), c(0L, -1L, NA, 1L))
  expect_true(temporal_equals(x[2], "1969-12-31T18:59:59.5-05:00"))
  expect_identical(sort(x), x[c(2, 1, 4)])
  expect_identical(order(x), c(2L, 1L, 4L, 3L))
  expect_identical(c(x[1], NA), x[c(1, 3)])
  expect_identical(rev(rev(x)), x)
  expect_identical(unique(c(x, x)), x)
  df <- data.frame(i = x)
  expect_identical(df$i, x)
  expect_identical(rbind(df, df)$i, c(x, x))
  skip_if_not_installed("vctrs")
  expect_identical(vctrs::vec_slice(x, 2:3), x[2:3])
  expect_identical(vctrs::vec_ptype_abbr(x), "instant")
})

test_that("now_instant() is within a second of Sys.time()", {
  before <- as.numeric(Sys.time())
  now <- now_instant()
  after <- as.numeric(Sys.time())
  secs <- Re(unclass(now)) + Im(unclass(now)) / 1e9
  expect_true(secs >= before - 1 && secs <= after + 1)
  expect_s3_class(now, "zutempo_instant")
  expect_length(now, 1L)
})
