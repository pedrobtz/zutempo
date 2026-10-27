# NA propagation through the C glue (design 6.8): every vectorised entry
# point gives NA for an NA element, in the first argument and in the
# second, and a value for the others. The oracle and test262 hold no NA, so
# these are the only tests of the glue's NA branches.

test_that("every glue entry point propagates NA in the first argument", {
  na_pair <- list(
    instant = instant(c("2026-01-01T00:00Z", NA)),
    zoned = zoned_date_time(c("2026-01-01T12:00[UTC]", NA)),
    date = plain_date(c("2026-01-31", NA)),
    time = plain_time(c("12:30", NA)),
    date_time = plain_date_time(c("2026-01-31T12:30", NA)),
    year_month = plain_year_month(c("2026-01", NA)),
    duration = duration(c("PT1H", NA))
  )
  calls <- list(
    "instant_from_epoch_milliseconds" = function(x) {
      instant_from_epoch_milliseconds(c(0, NA))
    },
    "instant_from_epoch_nanoseconds" = function(x) {
      instant_from_epoch_nanoseconds(c("0", NA))
    },
    "epoch_nanoseconds" = function(x) epoch_nanoseconds(x$instant),
    "Instant add" = function(x) temporal_add(x$instant, "PT1H"),
    "Instant until" = function(x) {
      temporal_until(x$instant, instant("2026-01-02T00:00Z"))
    },
    "Instant round" = function(x) temporal_round(x$instant, "hour"),
    "ZonedDateTime start of day" = function(x) temporal_start_of_day(x$zoned),
    "PlainDate to PlainDateTime" = function(x) {
      temporal_to_plain_date_time(x$date, plain_time("12:00"))
    },
    "PlainDateTime round" = function(x) temporal_round(x$date_time, "hour"),
    "PlainTime add" = function(x) temporal_add(x$time, "PT1H"),
    "PlainTime until" = function(x) temporal_until(x$time, plain_time("13:00")),
    "PlainDateTime add" = function(x) temporal_add(x$date_time, "P1D"),
    "PlainDateTime until" = function(x) {
      temporal_until(x$date_time, plain_date_time("2026-02-01T00:00"))
    },
    "PlainYearMonth add" = function(x) temporal_add(x$year_month, "P1M"),
    "PlainYearMonth until" = function(x) {
      temporal_until(x$year_month, plain_year_month("2027-01"))
    },
    "Duration add" = function(x) temporal_add(x$duration, "PT1H"),
    "Duration compare" = function(x) duration_compare(x$duration, "PT2H")
  )
  got <- vapply(
    calls,
    function(f) paste(is.na(f(na_pair)), collapse = " "),
    ""
  )
  expect_identical(
    got,
    rep("FALSE TRUE", length(calls)) |> stats::setNames(names(calls))
  )
})

test_that("every glue entry point propagates NA in the second argument", {
  calls <- list(
    "Instant add" = function() {
      temporal_add(instant("2026-01-01T00:00Z"), duration(c("PT1H", NA)))
    },
    "Instant until" = function() {
      temporal_until(
        instant("2026-01-01T00:00Z"),
        instant(c("2026-01-02T00:00Z", NA))
      )
    },
    "PlainDate to PlainDateTime" = function() {
      temporal_to_plain_date_time(
        plain_date("2026-01-31"),
        plain_time(c("12:00", NA))
      )
    },
    "PlainTime add" = function() {
      temporal_add(plain_time("12:30"), duration(c("PT1H", NA)))
    },
    "PlainTime until" = function() {
      temporal_until(plain_time("12:30"), plain_time(c("13:00", NA)))
    },
    "PlainDateTime add" = function() {
      temporal_add(plain_date_time("2026-01-31T12:30"), duration(c("P1D", NA)))
    },
    "PlainDateTime until" = function() {
      temporal_until(
        plain_date_time("2026-01-31T12:30"),
        plain_date_time(c("2026-02-01T00:00", NA))
      )
    },
    "PlainYearMonth add" = function() {
      temporal_add(plain_year_month("2026-01"), duration(c("P1M", NA)))
    },
    "PlainYearMonth until" = function() {
      temporal_until(
        plain_year_month("2026-01"),
        plain_year_month(c("2027-01", NA))
      )
    },
    "Duration add" = function() {
      temporal_add(duration("PT1H"), duration(c("PT1H", NA)))
    },
    "Duration compare" = function() {
      duration_compare("PT1H", duration(c("PT2H", NA)))
    }
  )
  got <- vapply(calls, function(f) paste(is.na(f()), collapse = " "), "")
  expect_identical(
    got,
    rep("FALSE TRUE", length(calls)) |> stats::setNames(names(calls))
  )
})
