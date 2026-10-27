test_that("each condition class is raised through the C glue with an index", {
  expect_error(ztp_probe_fail("range", 3), class = "zutempo_range_error")
  expect_error(ztp_probe_fail("parse", 3), class = "zutempo_parse_error")
  expect_error(ztp_probe_fail("type", 3), class = "zutempo_type_error")
  expect_error(ztp_probe_fail("tz", 3), class = "zutempo_tz_error")

  cond <- tryCatch(ztp_probe_fail("range", 3), error = identity)
  expect_s3_class(cond, "zutempo_error")
  expect_identical(cond[["index"]], 3)
  # The "(element 3)" in the message is in test-messages.R.
})

test_that("parse and tz errors are range errors; type errors are not", {
  expect_error(ztp_probe_fail("parse"), class = "zutempo_range_error")
  expect_error(ztp_probe_fail("tz"), class = "zutempo_range_error")
  expect_error(ztp_probe_fail("range"), class = "zutempo_error")
  expect_error(ztp_probe_fail("type"), class = "zutempo_error")
  cond <- tryCatch(ztp_probe_fail("type"), error = identity)
  expect_false(inherits(cond, "zutempo_range_error"))
})

test_that("an index of zero means no element", {
  cond <- tryCatch(ztp_probe_fail("range", 0), error = identity)
  expect_null(cond[["index"]])
  expect_no_match(conditionMessage(cond), "element")
})

test_that("an unknown kind from the engine is a type error", {
  expect_error(ztp_probe_fail("nonsense"), class = "zutempo_type_error")
})

test_that("stop_zutempo() rejects an unknown kind", {
  # A programming error inside the package, not a zutempo condition: base
  # R's own error class.
  expect_error(stop_zutempo("x", kind = "nonsense"), class = "simpleError")
})

test_that("an option error names the option", {
  option_of <- function(expr) {
    tryCatch(expr, zutempo_error = function(e) e[["option"]])
  }
  x <- plain_time("12:34:56")
  expect_identical(
    option_of(temporal_round(x, "minute", rounding_mode = "up")),
    "rounding_mode"
  )
  expect_identical(option_of(temporal_round(x, "fortnight")), "smallest_unit")
  expect_identical(option_of(temporal_round(x, "year")), "smallest_unit")
  expect_identical(option_of(temporal_round(x)), "smallest_unit")
  expect_identical(
    option_of(temporal_round(x, "minute", rounding_increment = 7)),
    "rounding_increment"
  )
  expect_identical(
    option_of(temporal_to_string(x, fractional_second_digits = 10)),
    "fractional_second_digits"
  )
  expect_identical(
    option_of(temporal_until(
      x,
      x,
      largest_unit = "second",
      smallest_unit = "hour"
    )),
    "largest_unit"
  )
  expect_identical(
    option_of(plain_date(2026, 2, 31, overflow = "nope")),
    "overflow"
  )
  expect_identical(option_of(temporal_total(duration(hours = 1))), "unit")
  # Errors about values, not options, have none.
  expect_null(option_of(plain_date("2026-02-31")))
})
