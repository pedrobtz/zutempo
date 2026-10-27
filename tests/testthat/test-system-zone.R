# The system time zone: TZ first, in the forms the C library reads, then
# Sys.timezone(); "UTC" with a classed warning when neither can be read.

test_that("a leading colon in TZ is dropped", {
  with_tzdir(tz_fixture_dir("slim"), {
    withr::local_envvar(TZ = ":Europe/Lisbon")
    expect_identical(now_time_zone_id(), "Europe/Lisbon")
    expect_identical(
      time_zone_id(zoned_date_time(.POSIXct(0, tz = ""))),
      "Europe/Lisbon"
    )
    ct <- as.POSIXct(plain_date_time("2026-07-01T12:00"), tz = "")
    expect_identical(attr(ct, "tzone"), "Europe/Lisbon")
  })
})

test_that("a path under the zone directory names its identifier", {
  dir <- normalizePath(tz_fixture_dir("slim"), winslash = "/")
  with_tzdir(dir, {
    withr::local_envvar(TZ = file.path(dir, "Asia", "Tokyo"))
    expect_identical(now_time_zone_id(), "Asia/Tokyo")
    withr::local_envvar(TZ = paste0(":", file.path(dir, "Europe", "Lisbon")))
    expect_identical(now_time_zone_id(), "Europe/Lisbon")
    # A zoneinfo directory other than the one zutempo reads.
    withr::local_envvar(TZ = "/usr/share/zoneinfo/Asia/Tokyo")
    expect_identical(now_time_zone_id(), "Asia/Tokyo")
    withr::local_envvar(TZ = ":/usr/share/zoneinfo/posix/Asia/Tokyo")
    expect_identical(now_time_zone_id(), "Asia/Tokyo")
  })
})

test_that("a zone that cannot be read falls back to UTC with a warning", {
  with_tzdir(tz_fixture_dir("slim"), {
    for (tz in c("Mars/Olympus_Mons", "CET-1CEST", "/nowhere/Mars")) {
      withr::local_envvar(TZ = tz)
      expect_warning(
        expect_identical(now_time_zone_id(), "UTC"),
        class = "zutempo_tz_warning"
      )
    }
    withr::local_envvar(TZ = "UTC")
    expect_no_warning(expect_identical(now_time_zone_id(), "UTC"))
  })
})

test_that("the fallback warning is a zutempo warning", {
  with_tzdir(tz_fixture_dir("slim"), {
    withr::local_envvar(TZ = "Mars/Olympus_Mons")
    cnd <- tryCatch(now_time_zone_id(), warning = function(w) w)
    expect_s3_class(cnd, c("zutempo_tz_warning", "zutempo_warning", "warning"))
  })
})
