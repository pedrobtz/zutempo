# Strings (design 9): the annotation grammar, its rejections, the
# formatting options of toString(), the time zone and calendar strings,
# and zutempo_parse() (design 6.8).

test_that("every string of design 9 round-trips through its type", {
  with_tzdir(tz_fixture_dir("slim"), {
    cases <- list(
      plain_date = c(
        "2026-01-31",
        "+275760-09-13",
        "-271821-04-19",
        "-000001-01-01"
      ),
      plain_time = c("12:30:00", "23:59:59.999999999", "00:00:00.5"),
      plain_date_time = c("2026-01-31T12:30:00", "-000001-12-31T23:59:59.1"),
      plain_year_month = c("2026-01", "+010000-12"),
      plain_month_day = c("02-29", "12-31"),
      instant = c("2026-01-31T12:30:00Z", "1969-12-31T23:59:59.999999999Z"),
      zoned_date_time = c(
        "2026-03-07T12:00:00-05:00[America/New_York]",
        "2026-03-07T12:00:00+05:30[+05:30]",
        "2026-03-07T12:00:00+00:00[UTC]"
      ),
      duration = c("P1Y2M3W4DT5H6M7.008009001S", "-PT1H", "PT0S")
    )
    for (type in names(cases)) {
      constructor <- get(type, envir = asNamespace("zutempo"))
      x <- cases[[type]]
      expect_identical(temporal_to_string(constructor(x)), x, info = type)
    }
    # With annotations, each type writes back its own form.
    annotated <- list(
      plain_date = c("2026-01-31[u-ca=iso8601]", "2026-01-31[u-ca=iso8601]"),
      plain_date_time = c(
        "2026-01-31T12:30:00[!u-ca=iso8601]",
        "2026-01-31T12:30:00[!u-ca=iso8601]"
      ),
      plain_year_month = c(
        "2026-01-01[u-ca=iso8601]",
        "2026-01-01[u-ca=iso8601]"
      ),
      plain_month_day = c(
        "1972-02-29[!u-ca=iso8601]",
        "1972-02-29[!u-ca=iso8601]"
      ),
      zoned_date_time = c(
        "2026-03-07T12:00:00-05:00[!America/New_York][u-ca=iso8601]",
        "2026-03-07T12:00:00-05:00[!America/New_York][u-ca=iso8601]"
      )
    )
    options <- list(
      plain_date = list(calendar_name = "always"),
      plain_date_time = list(calendar_name = "critical"),
      plain_year_month = list(calendar_name = "always"),
      plain_month_day = list(calendar_name = "critical"),
      zoned_date_time = list(
        calendar_name = "always",
        time_zone_name = "critical"
      )
    )
    for (type in names(annotated)) {
      constructor <- get(type, envir = asNamespace("zutempo"))
      x <- annotated[[type]][1L]
      out <- do.call(
        temporal_to_string,
        c(list(constructor(x)), options[[type]])
      )
      expect_identical(out, annotated[[type]][2L], info = type)
    }
  })
})

test_that("the annotation grammar is read as the specification writes it", {
  # Elective unknown annotations are ignored, in any number, after the
  # time zone annotation.
  expect_identical(
    plain_date("2026-01-31[Europe/Lisbon][a=bc][d-e=f-g][_h=I0]"),
    plain_date("2026-01-31")
  )
  # One-character keys and values are allowed (native Temporal in Node
  # 26.11 rejects them).
  expect_identical(plain_date("2026-01-31[x=1][k=V]"), plain_date("2026-01-31"))
  # A second elective calendar annotation is ignored.
  expect_identical(
    plain_date("2026-01-31[u-ca=iso8601][u-ca=gregory]"),
    plain_date("2026-01-31")
  )
  # The calendar of an instant or a time is never canonicalised.
  expect_identical(
    instant("2026-01-31T12:30Z[!u-ca=hebrew]"),
    instant("2026-01-31T12:30Z")
  )
  expect_identical(plain_time("12:30[u-ca=japanese]"), plain_time("12:30"))
  # Strings the grammar rejects and temporal-polyfill 1.0.6 accepts.
  for (s in c(
    "2026-01-31[u-ca=iso8601][Europe/Lisbon]",
    "2026-01-31[u-ca=]",
    "2026-01-31[a=b-]",
    "2026-01-31[a=b--c]",
    "2026-01-31[1a=b]",
    "2026-01-31[u-ca=a_b]",
    "2026-01-31[-a=b]"
  )) {
    expect_error(plain_date(s), class = "zutempo_parse_error", info = s)
  }
  # And the rejections every engine shares.
  for (s in c(
    "2026-01-31[!foo=bar]",
    "2026-01-31[u-ca=iso8601][!u-ca=iso8601]",
    "2026-01-31[!u-ca=iso8601][u-ca=iso8601]",
    "2026-01-31[U-CA=iso8601]",
    "2026-01-31[Europe/Lisbon][Europe/Madrid]",
    "2026-01-31[u-ca=iso8601",
    "2026-01-31[]",
    "2026-01-31T12:30Z"
  )) {
    expect_error(plain_date(s), class = "zutempo_parse_error", info = s)
  }
  expect_error(
    instant("2026-01-31T12:30Z[!foo=bar]"),
    class = "zutempo_parse_error"
  )
})

test_that("a calendar other than ISO 8601 is a range error (design D7)", {
  with_tzdir(tz_fixture_dir("slim"), {
    for (f in list(plain_date, plain_date_time, zoned_date_time)) {
      expect_error(
        f("2026-01-31T12:00[UTC][u-ca=hebrew]"),
        class = "zutempo_range_error"
      )
    }
  })
  expect_error(
    plain_year_month("2026-01-15[u-ca=gregory]"),
    class = "zutempo_range_error"
  )
  expect_error(
    plain_month_day("2026-01-15[u-ca=gregory]"),
    class = "zutempo_range_error"
  )
  # Only ISO 8601 has the forms without a day or a year, which the grammar
  # itself rejects.
  expect_error(
    plain_year_month("2026-01[u-ca=gregory]"),
    class = "zutempo_parse_error"
  )
  expect_error(
    plain_month_day("01-15[u-ca=gregory]"),
    class = "zutempo_parse_error"
  )
  # The calendar identifier matches ASCII case-insensitively.
  expect_identical(
    plain_date("2026-01-31[u-ca=IsO8601]"),
    plain_date("2026-01-31")
  )
})

test_that("a parse error carries the position of the first bad byte", {
  err <- tryCatch(
    plain_date(c("2026-01-31", "2026-13-01")),
    error = identity
  )
  expect_s3_class(err, "zutempo_parse_error")
  expect_identical(err[["index"]], 2)
  expect_identical(err[["position"]], 6)
  # A duration's number without a designator fails where the number starts.
  err <- tryCatch(duration("P1Y1Q"), error = identity)
  expect_identical(err[["position"]], 4)
  err <- tryCatch(plain_date("2026-01-31[!foo=bar]"), error = identity)
  expect_identical(err[["position"]], 11)
  # A range error has no position.
  err <- tryCatch(plain_date("2026-01-31[u-ca=hebrew]"), error = identity)
  expect_null(err[["position"]])
})

test_that("time zone arguments read ISO strings (ParseTemporalTimeZoneString)", {
  with_tzdir(tz_fixture_dir("slim"), {
    x <- instant("2026-01-31T12:30Z")
    expect_identical(
      temporal_to_string(x, time_zone = "2026-01-01T00:00[Asia/Tokyo]"),
      "2026-01-31T21:30:00+09:00"
    )
    expect_identical(
      temporal_to_string(x, time_zone = "2026-01-01T00:00-03:30"),
      "2026-01-31T09:00:00-03:30"
    )
    expect_identical(
      temporal_to_string(x, time_zone = "2026-01-01T00:00Z"),
      "2026-01-31T12:30:00+00:00"
    )
    z <- temporal_with_time_zone(
      zoned_date_time("2026-03-07T12:00[America/New_York]"),
      "2026-01-01T00:00[Europe/Lisbon]"
    )
    expect_identical(time_zone_id(z), "Europe/Lisbon")
    # An offset finer than minutes, a string without a zone, a critical
    # flag outside brackets.
    expect_error(
      temporal_to_string(x, time_zone = "2026-01-01T00:00+01:00:30"),
      class = "zutempo_range_error"
    )
    # A seconds part is an error even when it is zero
    # (ParseTimeZoneIdentifier reads no sub-minute precision).
    expect_error(
      temporal_to_string(x, time_zone = "2026-01-01T00:00+01:00:00.000"),
      class = "zutempo_range_error"
    )
    expect_error(
      temporal_to_string(x, time_zone = "2026-01-01"),
      class = "zutempo_range_error"
    )
    expect_error(
      temporal_to_string(x, time_zone = "!Europe/Lisbon"),
      class = "zutempo_parse_error"
    )
  })
})

test_that("calendar arguments read ISO strings (ParseTemporalCalendarString)", {
  x <- plain_date("2026-01-31")
  for (cal in c(
    "iso8601",
    "ISO8601",
    "2026-01-01",
    "2026-01-01[u-ca=iso8601]"
  )) {
    expect_identical(temporal_with_calendar(x, cal), x, info = cal)
  }
  for (cal in c("hebrew", "2026-01-01[u-ca=gregory]", "-x", "")) {
    expect_error(
      temporal_with_calendar(x, cal),
      class = "zutempo_range_error",
      info = cal
    )
  }
})

test_that("the formatting options round, then write", {
  # Each precision record of ToSecondsStringPrecisionRecord.
  t <- plain_time("12:30:45.987654321")
  digits <- vapply(
    0:9,
    function(d) temporal_to_string(t, fractional_second_digits = d),
    character(1)
  )
  expect_identical(
    digits,
    paste0(
      "12:30:45",
      c("", paste0(".", substring("987654321", 1, 1:9)))
    )
  )
  expect_identical(
    temporal_to_string(t, fractional_second_digits = 2.9),
    "12:30:45.98"
  )
  units <- c("minute", "second", "millisecond", "microsecond", "nanosecond")
  expect_identical(
    vapply(
      units,
      function(u) temporal_to_string(t, smallest_unit = u),
      character(1),
      USE.NAMES = FALSE
    ),
    c(
      "12:30",
      "12:30:45",
      "12:30:45.987",
      "12:30:45.987654",
      "12:30:45.987654321"
    )
  )
  # NA stays NA, and format() takes the same options.
  expect_identical(
    format(
      plain_time(c("12:30:45.5", NA)),
      smallest_unit = "second",
      rounding_mode = "halfExpand"
    ),
    c("12:30:46", NA)
  )
  # A duration rounds its time part; with a date largest unit, whole days
  # of time join the days (TemporalDurationFromInternal).
  expect_identical(
    temporal_to_string(
      duration("P1M2DT23H59M59.6S"),
      smallest_unit = "second",
      rounding_mode = "halfExpand"
    ),
    "P1M3DT0S"
  )
})

test_that("invalid formatting options raise the class design 10 names", {
  t <- plain_time("12:30")
  expect_error(
    temporal_to_string(t, fractional_second_digits = "two"),
    class = "zutempo_type_error"
  )
  expect_error(
    temporal_to_string(t, fractional_second_digits = c(1, 2)),
    class = "zutempo_type_error"
  )
  expect_error(
    temporal_to_string(t, fractional_second_digits = -1),
    class = "zutempo_range_error"
  )
  expect_error(
    temporal_to_string(t, fractional_second_digits = Inf),
    class = "zutempo_range_error"
  )
  expect_error(
    temporal_to_string(t, smallest_unit = "fortnight"),
    class = "zutempo_type_error"
  )
  expect_error(
    temporal_to_string(t, smallest_unit = "day"),
    class = "zutempo_range_error"
  )
  expect_error(
    temporal_to_string(duration("PT1M"), smallest_unit = "minute"),
    class = "zutempo_range_error"
  )
  expect_error(
    temporal_to_string(t, rounding_mode = "up"),
    class = "zutempo_type_error"
  )
  expect_error(
    temporal_to_string(plain_date("2026-01-31"), calendar_name = "sometimes"),
    class = "zutempo_type_error"
  )
  expect_error(
    temporal_to_string(t, calendar_name = "always"),
    class = "zutempo_type_error"
  )
  with_tzdir(tz_fixture_dir("slim"), {
    z <- zoned_date_time("2026-03-07T12:00[America/New_York]")
    expect_error(
      temporal_to_string(z, time_zone_name = "always"),
      class = "zutempo_type_error"
    )
    expect_error(
      temporal_to_string(z, offset = "always"),
      class = "zutempo_type_error"
    )
  })
})

test_that("format() ignores base R's formatting arguments", {
  with_tzdir(tz_fixture_dir("slim"), {
    df <- data.frame(
      d = plain_date("2026-01-31"),
      z = zoned_date_time("2026-03-07T12:00[America/New_York]"),
      p = duration("PT1.5S")
    )
    out <- capture.output(print(df))
    expect_match(out[2L], "2026-01-31", fixed = TRUE)
    expect_match(out[2L], "[America/New_York]", fixed = TRUE)
    expect_identical(
      format(plain_date("2026-01-31"), justify = "left", width = 20),
      "2026-01-31"
    )
  })
})

test_that("zutempo_parse() returns NA for each string it cannot read", {
  x <- c("2026-03-07", "2026-13-01", NA, "+275761-01-01", "2026-03-07[!a=b]")
  d <- zutempo_parse(x, "plain_date")
  expect_s3_class(d, "zutempo_plain_date")
  expect_identical(
    format(d),
    c("2026-03-07", NA, NA, NA, NA)
  )
  errors <- zutempo_parse_errors(d)
  expect_identical(errors[["index"]], c(2, 4, 5))
  expect_identical(errors[["position"]], c(6, NA, 11))
  expect_identical(
    errors[["class"]],
    c("zutempo_parse_error", "zutempo_range_error", "zutempo_parse_error")
  )
  expect_false(any(grepl("(element", errors[["message"]], fixed = TRUE)))
  # Every string read: an empty table.
  ok <- zutempo_parse(c("12:30", NA), "plain_time")
  expect_identical(nrow(zutempo_parse_errors(ok)), 0L)
  # na_on_error = FALSE is the constructor.
  expect_error(
    zutempo_parse(x, "plain_date", na_on_error = FALSE),
    class = "zutempo_parse_error"
  )
  expect_error(zutempo_parse(x, "date"), class = "zutempo_type_error")
  expect_error(zutempo_parse(1, "plain_date"), class = "zutempo_type_error")
  expect_error(
    zutempo_parse(x, "plain_date", na_on_error = NA),
    class = "zutempo_type_error"
  )
})

test_that("zutempo_parse() reads every type, and passes options on", {
  with_tzdir(tz_fixture_dir("slim"), {
    z <- zutempo_parse(
      c(
        "2026-03-07T12:00[America/New_York]",
        "2026-03-07T12:00[Mars/Olympus_Mons]",
        "2026-03-07T12:00+01:00[America/New_York]",
        "2026-03-07T12:00"
      ),
      "zoned_date_time"
    )
    expect_identical(
      format(z),
      c("2026-03-07T12:00:00-05:00[America/New_York]", NA, NA, NA)
    )
    expect_identical(
      zutempo_parse_errors(z)[["class"]],
      c("zutempo_tz_error", "zutempo_range_error", "zutempo_parse_error")
    )
    # The offset option reaches the constructor.
    z <- zutempo_parse(
      "2026-03-07T12:00+01:00[America/New_York]",
      "zoned_date_time",
      offset = "ignore"
    )
    expect_identical(format(z), "2026-03-07T12:00:00-05:00[America/New_York]")
    p <- zutempo_parse(c("P1D", "P1Q", "PT1.5H30M"), "duration")
    expect_identical(format(p), c("P1D", NA, NA))
    expect_identical(zutempo_parse_errors(p)[["position"]], c(2, 7))
    expect_identical(
      format(zutempo_parse(c("2026-01", "2026-13"), "plain_year_month")),
      c("2026-01", NA)
    )
    expect_identical(
      format(zutempo_parse(c("02-29", "02-30"), "plain_month_day")),
      c("02-29", NA)
    )
    expect_identical(
      format(zutempo_parse(c("2026-01-31T12:30Z", "x"), "instant")),
      c("2026-01-31T12:30:00Z", NA)
    )
    expect_identical(
      format(zutempo_parse(c("2026-01-31T12:30", "x"), "plain_date_time")),
      c("2026-01-31T12:30:00", NA)
    )
  })
})

test_that("relative_to strings are zoned by their time zone annotation", {
  with_tzdir(tz_fixture_dir("slim"), {
    d <- duration(hours = 25)
    expect_identical(
      format(temporal_round(
        d,
        largest_unit = "day",
        relative_to = "2026-03-07[u-ca=iso8601]"
      )),
      "P1DT1H"
    )
    expect_identical(
      format(temporal_round(
        d,
        largest_unit = "day",
        relative_to = "2026-03-07T12:00[America/New_York][u-ca=iso8601]"
      )),
      "P1DT2H"
    )
  })
})
