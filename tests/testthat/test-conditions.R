test_that("each condition class is raised through the C glue with an index", {
  expect_error(ztp_probe_fail("range", 3), class = "zutempo_range_error")
  expect_error(ztp_probe_fail("parse", 3), class = "zutempo_parse_error")
  expect_error(ztp_probe_fail("type", 3), class = "zutempo_type_error")
  expect_error(ztp_probe_fail("tz", 3), class = "zutempo_tz_error")

  cond <- tryCatch(ztp_probe_fail("range", 3), error = identity)
  expect_s3_class(cond, "zutempo_error")
  expect_identical(cond$index, 3)
  expect_match(conditionMessage(cond), "element 3")
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
  expect_null(cond$index)
  expect_no_match(conditionMessage(cond), "element")
})

test_that("an unknown kind from the engine is a type error", {
  expect_error(ztp_probe_fail("nonsense"), class = "zutempo_type_error")
})

test_that("stop_zutempo() rejects an unknown kind", {
  expect_error(stop_zutempo("x", kind = "nonsense"), "unknown condition kind")
})
