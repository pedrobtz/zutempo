test_that("the fast and slow parser paths agree", {
  strings <- c(
    "2026-01-31",
    "2026-01-31T12:30",
    "2026-01-31T12:30:45",
    "2026-01-31t12:30:45.5",
    "2026-01-31 12:30:45.123456789",
    "2026-01-31T12:30:45+05:30",
    "2026-01-31T12:30:45-00:00",
    "2026-01-31T12:30:45.999999999+00:00",
    "+275760-09-13",
    "-271821-04-19T00:00:00.000000001",
    "+010000-01-01T00:00",
    "0000-01-01",
    "2024-02-29T23:59:60",
    "2026-01-31T12:30:45,5",
    "2026-01-31T12",
    "2026-01-31T12:30+01",
    "20260131",
    "2026-01-31T123045"
  )
  slow <- parse_describe(strings, path = 1L)
  fast <- parse_describe(strings, path = 2L)
  applies <- fast != "n/a"
  expect_true(any(applies))
  expect_identical(fast[applies], slow[applies])
})

test_that("the fast path never accepts what the slow path rejects", {
  rejected <- c(
    "2026-01-31T12:30Z",
    "2026-01-31T12:30:45.1234567890",
    "-000000-01-01",
    "2026-02-29",
    "2026-01-31T24:00",
    "2026-01-31T",
    "10000-01-01",
    "2026-0131",
    "2026-01-31[!u-ca=iso8601][u-ca=iso8601]",
    "2026-01-31[!x-y=z]",
    "",
    " 2026-01-31",
    "2026-01-31 "
  )
  slow <- parse_describe(rejected, path = 1L)
  fast <- parse_describe(rejected, path = 2L)
  expect_true(all(slow == "error"))
  expect_true(all(fast %in% c("n/a", "error")))
})

test_that("parse errors report the position of the first bad byte", {
  cond <- tryCatch(plain_date("2026-01-3x"), error = identity)
  expect_s3_class(cond, "zutempo_parse_error")
  expect_match(conditionMessage(cond), "byte 10")
  cond <- tryCatch(plain_date("2026-01-31T12:30Z"), error = identity)
  expect_match(conditionMessage(cond), "byte 17")
})
