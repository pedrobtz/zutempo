# The wording of zutempo's conditions. Other tests assert on classes and
# fields (design 10); these snapshots catch a garbled message, a lost
# "(element n)" or a wrong byte position in the text.

test_that("a range error names the failing element", {
  expect_snapshot(
    plain_date(c(2026, 2026), 2, c(28, 31), overflow = "reject"),
    error = TRUE
  )
})

test_that("a parse error names the element and the byte", {
  expect_snapshot(plain_date(c("2026-01-31", "2026-13-01")), error = TRUE)
  expect_snapshot(duration("P1Y1Q"), error = TRUE)
  expect_snapshot(plain_date("2026-01-31[!foo=bar]"), error = TRUE)
})

test_that("a type error names the option and its choices", {
  expect_snapshot(
    temporal_round(plain_time("12:00"), "minute", rounding_mode = "up"),
    error = TRUE
  )
  expect_snapshot(temporal_round(plain_time("12:00")), error = TRUE)
})

test_that("tz errors name the zone and where it was looked for", {
  with_tzdir(tz_fixture_dir("slim"), {
    expect_snapshot(
      zoned_date_time("2026-03-07T12:00[Europe/Atlantis]"),
      error = TRUE,
      transform = function(x) gsub(tz_fixture_dir("slim"), "<fixtures>", x)
    )
  })
  expect_snapshot(
    .Call(zutempo:::C_ztp_r_tz_rule_utoff, "nonsense,,", 0),
    error = TRUE
  )
})

test_that("with no database, the tz error lists every directory tried", {
  withr::local_options(list(zutempo.tzdir = NULL))
  withr::local_envvar(TZDIR = NA)
  local_mocked_bindings(
    ztp_tz_platform = function() "Linux",
    ztp_dir_exists = function(paths) rep(FALSE, length(paths))
  )
  zutempo_tz_reset()
  withr::defer(zutempo_tz_reset())
  expect_snapshot(
    zoned_date_time(c("2026-03-07T12:00[UTC]", "2026-03-07T12:00[Asia/Tokyo]")),
    error = TRUE,
    transform = function(x) gsub(R.home("share"), "<R_SHARE>", x, fixed = TRUE)
  )
})

test_that("an error raised in the C glue carries its index in the text", {
  expect_snapshot(ztp_probe_fail("range", 3), error = TRUE)
  expect_snapshot(ztp_probe_fail("range", 0), error = TRUE)
})
