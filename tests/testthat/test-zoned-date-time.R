# ZonedDateTime beyond the oracle: the vector's shape (design 4.2), the
# range limits, Now, and the R-side errors. The oracle cases live in
# test-oracle-zoned-date-time.R. Zone rules come from the committed slim
# fixtures.

test_that("a vector mixing three zones keeps each zone through subsetting and combination", {
  with_tzdir(tz_fixture_dir("slim"), {
    x <- zoned_date_time(c(
      "2026-03-07T12:00[America/New_York]",
      "2026-03-07T17:00[Europe/Lisbon]",
      "2026-03-07T22:30[Asia/Calcutta]"
    ))
    ids <- c("America/New_York", "Europe/Lisbon", "Asia/Calcutta")
    expect_identical(time_zone_id(x), ids)
    expect_identical(attr(x, "zones"), ids)
    expect_identical(time_zone_id(x[c(3, 1)]), ids[c(3, 1)])
    expect_identical(attr(x[3], "zones"), "Asia/Calcutta")
    expect_identical(attr(x[3], "zone"), 1L)
    expect_identical(
      time_zone_id(c(x[2], x[3], x[1], x)),
      ids[c(2, 3, 1, 1, 2, 3)]
    )
    expect_identical(time_zone_id(rep(x, 2)), rep(ids, 2))
    expect_identical(time_zone_id(rep(x, each = 2)), rep(ids, each = 2))
    expect_identical(time_zone_id(rev(x)), rev(ids))
    expect_identical(c(zoned_date_time(character()), x), x)
    expect_length(zoned_date_time(character()), 0L)
    expect_identical(
      time_zone_id(zoned_date_time(c(NA, "2026-03-07T12:00[UTC]"))),
      c(NA, "UTC")
    )
  })
})

test_that("sorting and unique() order zoned values by instant, stably", {
  with_tzdir(tz_fixture_dir("slim"), {
    x <- zoned_date_time(c(
      "2026-03-07T12:00[America/New_York]",
      "2026-03-07T17:00[Europe/Lisbon]",
      "2026-03-07T22:30[Asia/Calcutta]"
    ))
    # One instant three times: sorting is stable and keeps the zones.
    expect_identical(format(sort(x)), format(x))
    expect_identical(order(x), 1:3)
    expect_identical(
      order(c(x[3], temporal_with(x[1], minute = 1), x[2])),
      c(1L, 3L, 2L)
    )
    expect_identical(format(unique(c(x, x[2], x[1]))), format(x))
    # The same instant in two zones is one instant.
    expect_identical(temporal_to_instant(x[1]), instant("2026-03-07T17:00Z"))
    expect_identical(
      epoch_milliseconds(x),
      rep(epoch_milliseconds(instant("2026-03-07T17:00Z")), 3)
    )
  })
})

test_that("assignment and length<- recode the zone table", {
  with_tzdir(tz_fixture_dir("slim"), {
    x <- zoned_date_time(c(
      "2026-03-07T12:00[America/New_York]",
      "2026-03-07T17:00[Europe/Lisbon]",
      "2026-03-07T22:30[Asia/Calcutta]"
    ))
    ids <- c("America/New_York", "Europe/Lisbon", "Asia/Calcutta")
    y <- x
    y[2] <- x[3]
    expect_identical(time_zone_id(y), ids[c(1, 3, 3)])
    expect_identical(attr(y, "zones"), ids[c(1, 3)])
    y[[1]] <- x[[2]]
    expect_identical(time_zone_id(y), ids[c(2, 3, 3)])
    y[3] <- NA
    expect_identical(time_zone_id(y), c(ids[2:3], NA))
    expect_identical(is.na(y), c(FALSE, FALSE, TRUE))
    length(y) <- 5
    expect_identical(is.na(y), c(FALSE, FALSE, TRUE, TRUE, TRUE))
    expect_identical(format(y)[1:2], format(x)[2:3])
  })
})

test_that("zoned values survive data frames, rbind, saveRDS and printing", {
  with_tzdir(tz_fixture_dir("slim"), {
    x <- zoned_date_time(c(
      "2026-03-07T12:00[America/New_York]",
      "2026-03-07T17:00[Europe/Lisbon]",
      "2026-03-07T22:30[Asia/Calcutta]"
    ))
    ids <- c("America/New_York", "Europe/Lisbon", "Asia/Calcutta")
    df <- data.frame(when = x, n = 1:3)
    both <- rbind(df, df)
    expect_s3_class(both$when, "zutempo_zoned_date_time")
    expect_identical(time_zone_id(both$when), rep(ids, 2))
    expect_identical(format(both$when), rep(format(x), 2))
    path <- withr::local_tempfile()
    saveRDS(x, path)
    back <- readRDS(path)
    expect_identical(back, x)
    expect_identical(time_zone_id(back), ids)
    expect_identical(as.character(x), format(x))
    expect_match(capture.output(print(x))[1], "zutempo_zoned_date_time\\[3\\]")
  })
})

test_that("vctrs sees a record of instant and zone", {
  skip_if_not_installed("vctrs")
  with_tzdir(tz_fixture_dir("slim"), {
    x <- zoned_date_time(c(
      "2026-03-07T12:00[America/New_York]",
      "2026-03-07T18:00[Europe/Lisbon]"
    ))
    expect_identical(vctrs::vec_c(x[2], x[1]), x[2:1])
    expect_identical(vctrs::vec_slice(x, 2), x[2])
    expect_identical(
      vctrs::vec_rbind(data.frame(z = x), data.frame(z = x))$z,
      c(x, x)
    )
    expect_identical(vctrs::vec_ptype_abbr(x), "zdt")
    expect_identical(vctrs::vec_size(x), 2L)
  })
})

test_that("the ends of the instant range hold in any zone", {
  with_tzdir(tz_fixture_dir("slim"), {
    top <- zoned_date_time("+275760-09-13T00:00Z[UTC]")
    expect_identical(temporal_to_instant(top), instant("+275760-09-13T00:00Z"))
    expect_identical(
      temporal_to_string(zoned_date_time("+275760-09-13T01:00[+01:00]")),
      "+275760-09-13T01:00:00+01:00[+01:00]"
    )
    expect_error(
      zoned_date_time("+275760-09-13T01:00:00.000000001[+01:00]"),
      class = "zutempo_range_error"
    )
    expect_error(
      zoned_date_time("+275760-09-13T00:00:00.000000001Z[UTC]"),
      class = "zutempo_range_error"
    )
    bottom <- zoned_date_time("-271821-04-20T00:00Z[UTC]")
    expect_identical(
      temporal_to_instant(bottom),
      instant("-271821-04-20T00:00Z")
    )
    expect_identical(hours_in_day(bottom), 24)
    # New York's local mean time, -04:56:02, puts the first instant on the
    # evening of the day before the UTC date; the candidate is the minimum
    # instant and valid (GetPossibleEpochNanoseconds).
    expect_identical(
      temporal_to_instant(zoned_date_time(
        "-271821-04-19T19:03:58[America/New_York]"
      )),
      instant("-271821-04-20T00:00Z")
    )
    expect_error(
      zoned_date_time("-271821-04-19T19:03:57[America/New_York]"),
      class = "zutempo_range_error"
    )
    # hoursInDay needs the next day's start, which the top of the range has
    # not got.
    expect_error(hours_in_day(top), class = "zutempo_range_error")
    expect_identical(temporal_start_of_day(top), top)
    expect_identical(
      temporal_start_of_day(zoned_date_time("+275760-09-13T00:00Z[+01:00]")),
      zoned_date_time("+275760-09-12T23:00Z[+01:00]")
    )
    expect_error(
      temporal_with_plain_time(top, "00:00:00.000000001"),
      class = "zutempo_range_error"
    )
    # Rounding up to the very last instant is allowed; past it is not.
    expect_identical(
      temporal_round(
        zoned_date_time("+275760-09-12T23:59:59.9Z[UTC]"),
        "second"
      ),
      top
    )
    expect_error(
      temporal_round(
        zoned_date_time("+275760-09-12T23:59:59.9Z[-01:00]"),
        "day"
      ),
      class = "zutempo_range_error"
    )
    expect_error(temporal_add(top, "PT1S"), class = "zutempo_range_error")
    expect_identical(
      temporal_to_zoned_date_time(plain_date("+275760-09-13"), "UTC"),
      top
    )
    expect_error(
      temporal_to_zoned_date_time(plain_date("+275760-09-13"), "-01:00"),
      class = "zutempo_range_error"
    )
  })
})

test_that("Now follows the system zone as base R reads it", {
  skip_without_tzdb()
  id <- now_time_zone_id()
  expect_true(is.character(id) && length(id) == 1L && nzchar(id))
  before <- Sys.time()
  z <- now_zoned_date_time_iso()
  expect_identical(time_zone_id(z), id)
  expect_true(abs(epoch_milliseconds(z) / 1000 - as.numeric(before)) < 5)
  expect_s3_class(
    now_plain_date_time_iso("Asia/Tokyo"),
    "zutempo_plain_date_time"
  )
  expect_s3_class(now_plain_date_iso("Asia/Tokyo"), "zutempo_plain_date")
  expect_s3_class(now_plain_time_iso("UTC"), "zutempo_plain_time")
  today_utc <- as.Date(format(Sys.time(), tz = "UTC"))
  expect_true(
    abs(as.numeric(as.Date(format(now_plain_date_iso("UTC"))) - today_utc)) <= 1
  )
  expect_identical(time_zone_id(now_zoned_date_time_iso("+05:30")), "+05:30")
  expect_error(
    now_zoned_date_time_iso("Mars/Olympus_Mons"),
    class = "zutempo_tz_error"
  )
})

test_that("Now's zone is the one Sys.timezone() names", {
  skip_without_tzdb()
  tz <- Sys.timezone()
  skip_if(is.na(tz) || !nzchar(tz), "Sys.timezone() names no zone")
  expect_identical(tolower(now_time_zone_id()), tolower(tz))
})

test_that("the system zone falls back to UTC when base R has none", {
  withr::local_envvar(TZ = "Mars/Olympus_Mons")
  expect_identical(now_time_zone_id(), "UTC")
})

test_that("constructor arguments are checked", {
  with_tzdir(tz_fixture_dir("slim"), {
    expect_error(zoned_date_time(), class = "zutempo_type_error")
    expect_error(zoned_date_time(2026, 3, 7), class = "zutempo_type_error")
    expect_error(
      zoned_date_time("2026-03-07T12:00[UTC]", time_zone = "UTC"),
      class = "zutempo_type_error"
    )
    expect_error(
      zoned_date_time(2026, 3, 7, time_zone = 1),
      class = "zutempo_type_error"
    )
    expect_error(
      zoned_date_time(
        2026,
        3,
        7,
        time_zone = "UTC",
        disambiguation = "sometimes"
      ),
      class = "zutempo_type_error"
    )
    expect_error(
      zoned_date_time(2026, 3, 7, time_zone = "UTC", offset = "maybe"),
      class = "zutempo_type_error"
    )
    expect_error(
      zoned_date_time(2026, 3, 7, time_zone = "UTC", offset_string = 5),
      class = "zutempo_type_error"
    )
    expect_error(
      zoned_date_time(2026, 3, 7, time_zone = "UTC", offset_string = "noon"),
      class = "zutempo_range_error"
    )
    expect_error(zoned_date_time(Sys.Date()), class = "zutempo_type_error")
    expect_error(
      zoned_date_time("2026-03-07T12:00[Mars/Olympus_Mons]"),
      class = "zutempo_tz_error"
    )
    expect_error(
      zoned_date_time("2026-03-07T12:00[America/New_York]", "extra"),
      class = "zutempo_type_error"
    )
    expect_error(
      temporal_with(
        zoned_date_time("2026-03-07T12:00[UTC]"),
        time_zone = "UTC"
      ),
      class = "zutempo_type_error"
    )
    expect_error(
      temporal_with_time_zone(zoned_date_time("2026-03-07T12:00[UTC]"), 3),
      class = "zutempo_type_error"
    )
    expect_error(
      temporal_to_zoned_date_time(plain_date("2026-03-07"), c("UTC", "UTC")),
      class = "zutempo_type_error"
    )
    expect_error(
      temporal_to_plain_date_time(
        zoned_date_time("2026-03-07T12:00[UTC]"),
        "12:00"
      ),
      class = "zutempo_type_error"
    )
    expect_error(
      zoned_date_time(c(2026, 2027), 3, 7, time_zone = c("UTC", "UTC", "UTC")),
      class = "zutempo_type_error"
    )
    # NA fields and NA zones give NA elements.
    x <- zoned_date_time(c(2026, NA), 3, 7, time_zone = "UTC")
    expect_identical(is.na(x), c(FALSE, TRUE))
    x <- zoned_date_time(2026, 3, 7, time_zone = c("UTC", NA))
    expect_identical(is.na(x), c(FALSE, TRUE))
    expect_identical(time_zone_id(x), c("UTC", NA))
    # Zones recycle with the fields, one per element.
    x <- zoned_date_time(
      2026,
      3,
      7,
      12,
      time_zone = c("America/New_York", "Europe/Lisbon")
    )
    expect_identical(
      format(x),
      c(
        "2026-03-07T12:00:00-05:00[America/New_York]",
        "2026-03-07T12:00:00+00:00[Europe/Lisbon]"
      )
    )
    # A zoned value is accepted as a time zone argument.
    expect_identical(
      time_zone_id(temporal_with_time_zone(x[2], x[1])),
      "America/New_York"
    )
    expect_identical(
      time_zone_id(temporal_to_zoned_date_time_iso(
        instant("2026-03-07T17:00Z"),
        x[1]
      )),
      "America/New_York"
    )
  })
})

test_that("fields of zoned values are the local date-time's", {
  with_tzdir(tz_fixture_dir("slim"), {
    x <- zoned_date_time("2026-03-07T23:30:15.123456789[America/New_York]")
    expect_identical(year(x), 2026L)
    expect_identical(month(x), 3L)
    expect_identical(month_code(x), "M03")
    expect_identical(day(x), 7L)
    expect_identical(day_of_week(x), 6L)
    expect_identical(day_of_year(x), 66L)
    expect_identical(week_of_year(x), 10L)
    expect_identical(year_of_week(x), 2026L)
    expect_identical(days_in_week(x), 7L)
    expect_identical(days_in_month(x), 31L)
    expect_identical(days_in_year(x), 365L)
    expect_identical(months_in_year(x), 12L)
    expect_false(in_leap_year(x))
    expect_identical(hour(x), 23L)
    expect_identical(minute(x), 30L)
    expect_identical(second(x), 15L)
    expect_identical(millisecond(x), 123L)
    expect_identical(microsecond(x), 456L)
    expect_identical(nanosecond(x), 789L)
    expect_identical(calendar_id(x), "iso8601")
    expect_true(is.na(era(x)))
    expect_true(is.na(era_year(x)))
    expect_identical(offset(x), "-05:00")
    expect_identical(offset_nanoseconds(x), -18000e9)
    expect_identical(time_zone_id(x), "America/New_York")
    expect_identical(hours_in_day(x), 24)
    expect_identical(
      epoch_nanoseconds(x),
      epoch_nanoseconds(temporal_to_instant(x))
    )
    na <- zoned_date_time(NA_character_)
    expect_true(is.na(year(na)))
    expect_true(is.na(offset(na)))
    expect_true(is.na(hours_in_day(na)))
    expect_true(is.na(time_zone_id(na)))
    # The accessors fall through to a masked function for other classes:
    # offset() masks stats::offset(), which just returns its argument.
    expect_identical(offset(1), stats::offset(1))
    expect_error(hours_in_day(1), class = "zutempo_type_error")
    expect_error(time_zone_id(1), class = "zutempo_type_error")
    expect_error(offset_nanoseconds(1), class = "zutempo_type_error")
  })
})

test_that("equality and comparison recycle and propagate NA", {
  with_tzdir(tz_fixture_dir("slim"), {
    x <- zoned_date_time(c(
      "2026-03-07T12:00[America/New_York]",
      "2026-03-07T17:00[Europe/Lisbon]",
      NA
    ))
    expect_identical(
      temporal_equals(x, "2026-03-07T12:00[America/New_York]"),
      c(TRUE, FALSE, NA)
    )
    expect_identical(
      zoned_date_time_compare(x, "2026-03-07T17:00[UTC]"),
      c(0L, 0L, NA)
    )
    expect_identical(zoned_date_time_compare(x[1], x[2]), 0L)
    expect_identical(temporal_equals(x[1], x[2]), FALSE)
    expect_identical(
      temporal_equals(x[1], temporal_with_time_zone(x[2], "america/new_york")),
      TRUE
    )
    expect_identical(order(x, na.last = TRUE), c(1L, 2L, 3L))
  })
})

test_that("the zone cache may be cleared under a vector and it still formats", {
  with_tzdir(tz_fixture_dir("slim"), {
    x <- zoned_date_time("2026-03-07T12:00[America/New_York]")
    zutempo_tz_reset()
    expect_identical(format(x), "2026-03-07T12:00:00-05:00[America/New_York]")
    zutempo_tz_reset()
    expect_identical(hour(x), 12L)
    zutempo_tz_reset()
    expect_identical(
      format(temporal_with(x, hour = 1)),
      "2026-03-07T01:00:00-05:00[America/New_York]"
    )
    # ... but a zone that is not in the current database cannot be read.
    withr::with_options(list(zutempo.tzdir = withr::local_tempdir()), {
      expect_error(format(x), class = "zutempo_tz_error")
      expect_identical(
        format(zoned_date_time("2026-03-07T12:00[+05:30]")),
        "2026-03-07T12:00:00+05:30[+05:30]"
      )
    })
  })
})

test_that("strings with a zone annotation are read by the other types and ignored", {
  with_tzdir(tz_fixture_dir("slim"), {
    expect_identical(
      plain_date("2026-03-07[America/New_York]"),
      plain_date("2026-03-07")
    )
    expect_identical(
      plain_date_time("2026-03-07T12:00[Europe/Lisbon]"),
      plain_date_time("2026-03-07T12:00")
    )
    expect_identical(plain_time("12:00[+05:30]"), plain_time("12:00"))
    expect_identical(
      plain_year_month("2026-03[UTC]"),
      plain_year_month("2026-03")
    )
    expect_identical(plain_month_day("03-07[!UTC]"), plain_month_day("03-07"))
    expect_identical(
      instant("2026-03-07T12:00Z[America/New_York]"),
      instant("2026-03-07T12:00Z")
    )
    expect_identical(
      instant("2026-03-07T12:00+01:00[Mars/Olympus_Mons]"),
      instant("2026-03-07T11:00Z")
    )
    expect_error(plain_date("2026-03-07[]"), class = "zutempo_parse_error")
    expect_error(
      plain_date("2026-03-07[America/New_York"),
      class = "zutempo_parse_error"
    )
    expect_identical(
      plain_date("2026-03-07[America/New_York][u-ca=iso8601]"),
      plain_date("2026-03-07")
    )
    expect_error(
      plain_date("2026-03-07[u-ca=iso8601][America/New_York]"),
      class = "zutempo_parse_error"
    )
    expect_error(
      plain_date("2026-03-07[+05:30:00]"),
      class = "zutempo_parse_error"
    )
    expect_error(
      plain_date("2026-03-07[1America]"),
      class = "zutempo_parse_error"
    )
    expect_error(
      zoned_date_time("2026-03-07T12:00[America/New_York]x"),
      class = "zutempo_parse_error"
    )
    expect_error(
      zoned_date_time(paste0("2026-03-07T12:00[", strrep("A", 60), "]")),
      class = "zutempo_parse_error"
    )
  })
})

test_that("zoned add and subtract recycle, propagate NA and keep each element's zone", {
  with_tzdir(tz_fixture_dir("slim"), {
    x <- zoned_date_time(c(
      "2026-03-07T12:00[America/New_York]",
      "2026-03-28T12:00[Europe/Lisbon]",
      NA
    ))
    added <- temporal_add(x, "P1D")
    expect_identical(
      format(added),
      c(
        "2026-03-08T12:00:00-04:00[America/New_York]",
        "2026-03-29T12:00:00+01:00[Europe/Lisbon]",
        NA
      )
    )
    expect_identical(time_zone_id(added), time_zone_id(x))
    expect_identical(temporal_subtract(added, "P1D"), x)
    expect_identical(
      format(temporal_add(x[1], c("PT1H", "PT2H"))),
      c(
        "2026-03-07T13:00:00-05:00[America/New_York]",
        "2026-03-07T14:00:00-05:00[America/New_York]"
      )
    )
    expect_error(
      temporal_add(x[1:2], duration(hours = 1:3)),
      class = "zutempo_type_error"
    )
    expect_error(temporal_add(x, "P1D", "extra"), class = "zutempo_type_error")
    # The §5 example.
    expect_identical(
      format(temporal_add(
        zoned_date_time("2026-03-07T12:00[America/New_York]"),
        duration(hours = 25)
      )),
      "2026-03-08T14:00:00-04:00[America/New_York]"
    )
  })
})

test_that("durations round, total and compare relative to a zoned value", {
  with_tzdir(tz_fixture_dir("slim"), {
    x <- zoned_date_time(c(
      "2026-03-07T12:00[America/New_York]",
      "2026-03-28T12:00[Europe/Lisbon]",
      NA
    ))
    expect_identical(
      format(temporal_round(
        duration(hours = 25),
        largest_unit = "day",
        relative_to = x[1]
      )),
      "P1DT2H"
    )
    expect_identical(
      temporal_total(duration(hours = 25), "day", relative_to = x[1]),
      26 / 24
    )
    expect_identical(duration_compare("P1D", "PT24H", relative_to = x[1]), -1L)
    expect_identical(
      duration_compare(
        "P1D",
        "PT24H",
        relative_to = "2026-06-07T12:00[America/New_York]"
      ),
      0L
    )
    # A zoned relative_to recycles and propagates NA. Lisbon's clocks also
    # change on the night after x[2], so both days are 23 hours; the
    # fraction of a day is measured on the following, 24-hour day.
    expect_identical(
      format(temporal_round(
        duration(hours = 25),
        largest_unit = "day",
        relative_to = x
      )),
      c("P1DT2H", "P1DT2H", NA)
    )
    expect_identical(
      temporal_total(duration(hours = 25), "day", relative_to = x),
      c(26 / 24, 26 / 24, NA)
    )
    expect_identical(
      format(temporal_round(
        duration(hours = 25),
        largest_unit = "day",
        relative_to = "2026-06-07T12:00[America/New_York]"
      )),
      "P1DT1H"
    )
    expect_error(
      temporal_round(
        duration(hours = 25),
        largest_unit = "day",
        relative_to = c("2026-03-07T12:00[UTC]", "2026-03-07")
      ),
      class = "zutempo_type_error"
    )
    expect_error(
      temporal_round(
        duration(hours = 25),
        largest_unit = "day",
        relative_to = 1
      ),
      class = "zutempo_type_error"
    )
  })
})

test_that("zoned until and since work across elements and check the zones", {
  with_tzdir(tz_fixture_dir("slim"), {
    x <- zoned_date_time(c(
      "2026-03-07T12:00[America/New_York]",
      "2026-03-28T12:00[Europe/Lisbon]",
      NA
    ))
    y <- temporal_add(x, "P1DT2H")
    d <- temporal_until(x, y, largest_unit = "day")
    expect_identical(format(d), c("P1DT2H", "P1DT2H", NA))
    expect_identical(
      format(temporal_since(y, x, largest_unit = "day")),
      c("P1DT2H", "P1DT2H", NA)
    )
    expect_identical(format(temporal_until(x, y)), c("PT25H", "PT25H", NA))
    expect_identical(format(temporal_until(x[1], y)), c("PT25H", "PT524H", NA))
    expect_error(
      temporal_until(x[1], y[2], largest_unit = "day"),
      class = "zutempo_range_error"
    )
    # The zones are checked before equal instants return a zero duration.
    expect_error(
      temporal_until(
        zoned_date_time("2026-03-07T12:00[America/New_York]"),
        zoned_date_time("2026-03-07T17:00[Europe/Lisbon]"),
        largest_unit = "day"
      ),
      class = "zutempo_range_error"
    )
    expect_error(
      temporal_until(x[1], y[1], largest_unit = "day", smallest_unit = "month"),
      class = "zutempo_range_error"
    )
    expect_error(
      temporal_until(x[1], y[1], "extra"),
      class = "zutempo_type_error"
    )
  })
})

test_that("zoned round rounds in each element's zone", {
  with_tzdir(tz_fixture_dir("slim"), {
    y <- zoned_date_time(c(
      "2026-03-08T14:00[America/New_York]",
      "2026-03-29T14:00[Europe/Lisbon]",
      NA
    ))
    expect_identical(
      format(temporal_round(y, "day")),
      c(
        "2026-03-09T00:00:00-04:00[America/New_York]",
        "2026-03-30T00:00:00+01:00[Europe/Lisbon]",
        NA
      )
    )
    expect_error(temporal_round(y), class = "zutempo_type_error")
    expect_error(temporal_round(y, "year"), class = "zutempo_range_error")
    expect_error(
      temporal_round(y, "day", rounding_increment = 2),
      class = "zutempo_range_error"
    )
  })
})

test_that("time zone transitions are found in each element's zone", {
  with_tzdir(tz_fixture_dir("slim"), {
    x <- zoned_date_time(c(
      "2026-03-07T12:00[America/New_York]",
      "2026-03-28T12:00[Europe/Lisbon]",
      NA
    ))
    nxt <- temporal_get_time_zone_transition(x, "next")
    expect_identical(
      format(nxt),
      c(
        "2026-03-08T03:00:00-04:00[America/New_York]",
        "2026-03-29T02:00:00+01:00[Europe/Lisbon]",
        NA
      )
    )
    expect_identical(time_zone_id(nxt), time_zone_id(x))
    expect_true(is.na(temporal_get_time_zone_transition(
      zoned_date_time("2026-01-01T00:00[+05:30]"),
      "next"
    )))
    expect_true(is.na(temporal_get_time_zone_transition(
      zoned_date_time("2026-01-01T00:00[Asia/Kolkata]"),
      "next"
    )))
    expect_true(is.na(temporal_get_time_zone_transition(
      zoned_date_time("+275760-09-13T00:00Z[America/New_York]"),
      "next"
    )))
    expect_true(is.na(temporal_get_time_zone_transition(
      zoned_date_time("-271821-04-20T00:00Z[America/New_York]"),
      "previous"
    )))
    expect_error(
      temporal_get_time_zone_transition(x),
      class = "zutempo_type_error"
    )
    expect_error(
      temporal_get_time_zone_transition(x, "sideways"),
      class = "zutempo_type_error"
    )
  })
})

test_that("the fat fixture agrees with the slim one on transitions past 2037", {
  far <- "2050-01-01T00:00[America/New_York]"
  slim_next <- with_tzdir(
    tz_fixture_dir("slim"),
    format(temporal_get_time_zone_transition(zoned_date_time(far), "next"))
  )
  fat_next <- with_tzdir(
    tz_fixture_dir("fat"),
    format(temporal_get_time_zone_transition(zoned_date_time(far), "next"))
  )
  expect_identical(fat_next, slim_next)
  expect_identical(slim_next, "2050-03-13T03:00:00-04:00[America/New_York]")
})

test_that("a gap at local midnight resolves to the day before with earlier", {
  with_tzdir(tz_fixture_dir("slim"), {
    # Sao Paulo's clocks went from 00:00 to 01:00 on 2018-11-04.
    expect_identical(
      format(zoned_date_time(
        2018,
        11,
        4,
        0,
        30,
        time_zone = "America/Sao_Paulo",
        disambiguation = "earlier"
      )),
      "2018-11-03T23:30:00-03:00[America/Sao_Paulo]"
    )
    expect_identical(
      format(zoned_date_time(
        2018,
        11,
        4,
        0,
        30,
        time_zone = "America/Sao_Paulo"
      )),
      "2018-11-04T01:30:00-02:00[America/Sao_Paulo]"
    )
    expect_identical(
      format(temporal_start_of_day(
        zoned_date_time("2018-11-04T12:00[America/Sao_Paulo]")
      )),
      "2018-11-04T01:00:00-02:00[America/Sao_Paulo]"
    )
  })
})

test_that("the constructors read a zoned value as ToTemporal* does", {
  with_tzdir(tz_fixture_dir("slim"), {
    z <- zoned_date_time("2026-03-07T12:30:45.5[America/New_York]")
    expect_identical(plain_date(z), plain_date("2026-03-07"))
    expect_identical(plain_time(z), plain_time("12:30:45.5"))
    expect_identical(
      plain_date_time(z),
      plain_date_time("2026-03-07T12:30:45.5")
    )
    expect_identical(instant(z), instant("2026-03-07T17:30:45.5Z"))
  })
})
