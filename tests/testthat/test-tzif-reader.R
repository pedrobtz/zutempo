# Crafted TZif files and TZ strings that the reader must refuse.

test_that("a TZif abbreviation index past the abbreviations is a tz error", {
  load <- function(b) .Call(zutempo:::C_ztp_r_tz_load, "Fuzz/Zone", b)
  withr::defer(zutempo_tz_reset())
  expect_error(load(tzif_v1(200L)), class = "zutempo_tz_error")
  expect_error(load(tzif_v1(0L)), class = "zutempo_tz_error")
  expect_error(
    load(tzif_v1(4L, c(charToRaw("ABC"), as.raw(0)))),
    class = "zutempo_tz_error"
  )
  # A well-formed file with the same layout loads and reads.
  expect_silent(load(tzif_v1(0L, c(charToRaw("ABC"), as.raw(0)))))
  at <- .Call(zutempo:::C_ztp_r_tz_utoff, "Fuzz/Zone", 0)
  expect_identical(at$utoff, 3600L)
  expect_identical(at$abbr, "ABC")
})

test_that("a TZ string abbreviation must be ASCII letters, digits or signs", {
  rule <- function(s) .Call(zutempo:::C_ztp_r_tz_rule_utoff, s, 0)
  expect_identical(rule("<+0330>-3:30"), 12600L)
  expect_identical(rule("<-03>3"), -10800L)
  expect_error(rule("<é>-1"), class = "zutempo_tz_error")
  expect_error(rule("<a b>-1"), class = "zutempo_tz_error")
  expect_error(rule("<>-1"), class = "zutempo_tz_error")
})

test_that("a UTC offset of a day or more is a tz error", {
  load <- function(b) .Call(zutempo:::C_ztp_r_tz_load, "Fuzz/Zone", b)
  withr::defer(zutempo_tz_reset())
  chars <- c(charToRaw("ABC"), as.raw(0))
  expect_error(
    load(tzif_v1(0L, chars, utoff = 86400)),
    class = "zutempo_tz_error"
  )
  expect_error(
    load(tzif_v1(0L, chars, utoff = -86400)),
    class = "zutempo_tz_error"
  )
  expect_silent(load(tzif_v1(0L, chars, utoff = -86399)))
  rule <- function(s) .Call(zutempo:::C_ztp_r_tz_rule_utoff, s, 0)
  expect_identical(rule("<-2359>23:59"), -86340L)
  expect_error(rule("<-24>24"), class = "zutempo_tz_error")
  expect_error(
    rule("AAA-23:30BBB,M3.2.0,M11.1.0"),
    class = "zutempo_tz_error"
  )
})
