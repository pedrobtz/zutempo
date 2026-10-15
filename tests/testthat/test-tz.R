test_that("every fixture zone gives zdump's offsets at every transition, fat and slim", {
  transitions <- tz_fixture_transitions()
  for (form in c("slim", "fat")) {
    with_tzdir(tz_fixture_dir(form), {
      for (zone in unique(transitions$zone)) {
        rows <- transitions[transitions$zone == zone, ]
        if (zone == "UTC") {
          # "UTC" never reaches the database (design 8); load its file by hand
          # so the reader sees it too.
          path <- file.path(tz_fixture_dir(form), zone)
          .Call(
            zutempo:::C_ztp_r_tz_load,
            zone,
            readBin(path, "raw", n = file.size(path))
          )
          id <- zone
        } else {
          id <- zutempo:::ztp_tz_ensure(zone)
        }
        expect_identical(id, zone, info = paste(form, zone))
        at <- .Call(zutempo:::C_ztp_r_tz_utoff, id, rows$utc_seconds)
        expect_identical(
          at$utoff,
          rows$utoff,
          info = paste(form, zone, "offset at start")
        )
        # Temporal has no DST flag; zdump's comes from the C library, which
        # inverts it for zones with negative DST (Dublin, Casablanca), so
        # the flag is checked against the file below, not here. An
        # abbreviation zdump leaves out (an uninhabited zone's "-00") is NA.
        has_abbr <- !is.na(rows$abbr)
        expect_identical(
          at$abbr[has_abbr],
          rows$abbr[has_abbr],
          info = paste(form, zone, "abbr")
        )
        # One second before each transition, the previous state holds.
        if (nrow(rows) > 1L) {
          before <- .Call(
            zutempo:::C_ztp_r_tz_utoff,
            id,
            rows$utc_seconds[-1L] - 1
          )
          expect_identical(
            before$utoff,
            rows$utoff[-nrow(rows)],
            info = paste(form, zone, "offset before")
          )
        }
      }
    })
  }
})

test_that("the DST flag and abbreviation come from the file's types", {
  with_tzdir(tz_fixture_dir("slim"), {
    ny <- zutempo:::ztp_tz_ensure("America/New_York")
    at <- .Call(
      zutempo:::C_ztp_r_tz_utoff,
      ny,
      Re(unclass(instant(c("2026-01-15T12:00Z", "2026-07-15T12:00Z", NA))))
    )
    expect_identical(at$utoff, c(-18000L, -14400L, NA))
    expect_identical(at$isdst, c(FALSE, TRUE, NA))
    expect_identical(at$abbr, c("EST", "EDT", NA))
    # Dublin's winter is the "DST" period in the database since tzdata 2018.
    dublin <- zutempo:::ztp_tz_ensure("Europe/Dublin")
    at <- .Call(
      zutempo:::C_ztp_r_tz_utoff,
      dublin,
      Re(unclass(instant(c(
        "1980-01-15T12:00Z",
        "1980-07-15T12:00Z",
        "2026-01-15T12:00Z",
        "2026-07-15T12:00Z"
      ))))
    )
    expect_identical(at$utoff, c(0L, 3600L, 0L, 3600L))
    expect_identical(at$isdst, c(TRUE, FALSE, TRUE, FALSE))
    expect_identical(at$abbr, c("GMT", "IST", "GMT", "IST"))
  })
})

test_that("the slim-file regression of design 0 holds on the slim fixture", {
  with_tzdir(tz_fixture_dir("slim"), {
    id <- zutempo:::ztp_tz_ensure("America/New_York")
    expect_true(
      .Call(zutempo:::C_ztp_r_tz_last_explicit, id) <
        as.numeric(as.POSIXct("2008-01-01", tz = "UTC"))
    )
    gap <- .Call(
      zutempo:::C_ztp_r_tz_possible,
      id,
      unclass(plain_date("2026-03-08")),
      unclass(plain_time("02:30"))
    )
    fold <- .Call(
      zutempo:::C_ztp_r_tz_possible,
      id,
      unclass(plain_date("2026-11-01")),
      unclass(plain_time("01:30"))
    )
    plain <- .Call(
      zutempo:::C_ztp_r_tz_possible,
      id,
      unclass(plain_date("2026-07-01")),
      unclass(plain_time("12:00"))
    )
    expect_length(gap[[1L]], 0L)
    expect_length(fold[[1L]], 2L)
    expect_length(plain[[1L]], 1L)
    expect_identical(
      new_instant(fold[[1L]]),
      instant(c("2026-11-01T05:30Z", "2026-11-01T06:30Z"))
    )
    expect_identical(new_instant(plain[[1L]]), instant("2026-07-01T16:00Z"))
  })
})

test_that("the slim-file regression holds on R's own database when it is here", {
  dir <- r_zoneinfo()
  skip_if(is.na(dir), "R's share/zoneinfo is not installed")
  with_tzdir(dir, {
    id <- zutempo:::ztp_tz_ensure("America/New_York")
    gap <- .Call(
      zutempo:::C_ztp_r_tz_possible,
      id,
      unclass(plain_date("2026-03-08")),
      unclass(plain_time("02:30"))
    )
    fold <- .Call(
      zutempo:::C_ztp_r_tz_possible,
      id,
      unclass(plain_date("2026-11-01")),
      unclass(plain_time("01:30"))
    )
    expect_length(gap[[1L]], 0L)
    expect_length(fold[[1L]], 2L)
  })
})

test_that("transitions walk the explicit list and then the footer rule", {
  with_tzdir(tz_fixture_dir("slim"), {
    id <- zutempo:::ztp_tz_ensure("America/New_York")
    x <- instant("2026-01-01T00:00Z")
    nxt <- new_instant(.Call(
      zutempo:::C_ztp_r_tz_transition,
      id,
      unclass(x),
      1L
    ))
    expect_identical(nxt, instant("2026-03-08T07:00Z"))
    nxt2 <- new_instant(.Call(
      zutempo:::C_ztp_r_tz_transition,
      id,
      unclass(nxt),
      1L
    ))
    expect_identical(nxt2, instant("2026-11-01T06:00Z"))
    prev <- new_instant(.Call(
      zutempo:::C_ztp_r_tz_transition,
      id,
      unclass(nxt),
      -1L
    ))
    expect_identical(prev, instant("2025-11-02T06:00Z"))
    prev_at <- new_instant(.Call(
      zutempo:::C_ztp_r_tz_transition,
      id,
      unclass(instant("2026-03-08T07:00:00.000000001Z")),
      -1L
    ))
    expect_identical(prev_at, instant("2026-03-08T07:00Z"))
    far <- new_instant(.Call(
      zutempo:::C_ztp_r_tz_transition,
      id,
      unclass(instant("+275760-09-12T00:00Z")),
      1L
    ))
    expect_true(is.na(far))
    # Explicit transitions from the start of the file, and none before them.
    first <- new_instant(.Call(
      zutempo:::C_ztp_r_tz_transition,
      id,
      unclass(instant("-271821-04-20T00:00Z")),
      1L
    ))
    expect_false(is.na(first))
    none <- new_instant(.Call(
      zutempo:::C_ztp_r_tz_transition,
      id,
      unclass(instant("-271821-04-20T00:00Z")),
      -1L
    ))
    expect_true(is.na(none))
    # A zone without DST rules has no transitions after its last change.
    tokyo <- zutempo:::ztp_tz_ensure("Asia/Tokyo")
    expect_true(is.na(new_instant(.Call(
      zutempo:::C_ztp_r_tz_transition,
      tokyo,
      unclass(x),
      1L
    ))))
    utc <- zutempo:::ztp_tz_ensure("Etc/UTC")
    expect_true(is.na(new_instant(.Call(
      zutempo:::C_ztp_r_tz_transition,
      utc,
      unclass(x),
      1L
    ))))
    expect_true(is.na(new_instant(.Call(
      zutempo:::C_ztp_r_tz_transition,
      utc,
      unclass(x),
      -1L
    ))))
  })
})

test_that("transitions continue past a fat file's last explicit entry", {
  with_tzdir(tz_fixture_dir("fat"), {
    id <- zutempo:::ztp_tz_ensure("America/New_York")
    last <- .Call(zutempo:::C_ztp_r_tz_last_explicit, id)
    expect_true(last > as.numeric(as.POSIXct("2037-01-01", tz = "UTC")))
    step <- function(x, dir) {
      new_instant(.Call(
        zutempo:::C_ztp_r_tz_transition,
        id,
        unclass(instant(x)),
        dir
      ))
    }
    expect_identical(
      step("2040-01-01T00:00Z", 1L),
      instant("2040-03-11T07:00Z")
    )
    expect_identical(
      step("2040-01-01T00:00Z", -1L),
      instant("2039-11-06T06:00Z")
    )
    # Across the seam between the explicit list and the footer.
    expect_identical(
      step(format(new_instant(complex(real = last, imaginary = 0))), 1L),
      instant("2038-03-14T07:00Z")
    )
    expect_identical(
      step("2038-03-14T07:00Z", -1L),
      new_instant(complex(real = last, imaginary = 0))
    )
    # Offsets agree on both sides of the seam too.
    at <- .Call(zutempo:::C_ztp_r_tz_utoff, id, c(last - 1, last, last + 1))
    expect_identical(at$utoff, c(-14400L, -18000L, -18000L))
  })
})

test_that("the POSIX footer rule handles every form in the files and the v3 hours", {
  utoff <- function(rule, when) {
    .Call(
      zutempo:::C_ztp_r_tz_rule_utoff,
      rule,
      Re(unclass(instant(paste0(when, "Z"))))
    )
  }
  # Quoted names and a 30-minute DST (Lord Howe, southern hemisphere).
  expect_identical(
    utoff(
      "<+1030>-10:30<+11>-11,M10.1.0,M4.1.0",
      c("2026-01-15T00:00", "2026-07-15T00:00")
    ),
    c(39600L, 37800L)
  )
  # A fixed zone.
  expect_identical(utoff("<+13>-13", "2026-01-15T00:00"), 46800L)
  # Negative DST: Dublin's winter is the DST period.
  expect_identical(
    utoff(
      "IST-1GMT0,M10.5.0,M3.5.0/1",
      c("2026-01-15T12:00", "2026-07-15T12:00")
    ),
    c(0L, 3600L)
  )
  # Two hours of DST, a 24:00 rule, a Julian day and a zero-based day.
  expect_identical(
    utoff(
      "<+00>0<+02>-2,M3.5.0/1,M10.5.0/3",
      c("2026-01-15T12:00", "2026-07-15T12:00")
    ),
    c(0L, 7200L)
  )
  expect_identical(
    utoff(
      "<-04>4<-03>,M9.1.6/24,M4.1.6/24",
      c("2026-01-15T12:00", "2026-07-15T12:00")
    ),
    c(-10800L, -14400L)
  )
  expect_identical(
    utoff("EST5EDT,J60,J300", c("2026-02-28T12:00", "2026-03-02T12:00")),
    c(-18000L, -14400L)
  )
  expect_identical(
    utoff("EST5EDT,59,299", c("2024-02-28T12:00", "2024-03-01T12:00")),
    c(-18000L, -14400L)
  )
  # Hours beyond 24 (TZif version 3): -24 moves the change to 00:00 local
  # the day before (05:00 UTC); 26 to 02:00 local the day after.
  expect_identical(
    utoff(
      "EST5EDT,M3.2.0/-24,M11.1.0/26",
      c("2026-03-07T04:59:59", "2026-03-07T05:00:00")
    ),
    c(-18000L, -14400L)
  )
  expect_identical(
    utoff(
      "EST5EDT,M3.2.0/-24,M11.1.0/26",
      c("2026-11-02T05:59:59", "2026-11-02T06:00:00")
    ),
    c(-14400L, -18000L)
  )
  # The exact instants of New York's 2026 changes.
  expect_identical(
    utoff(
      "EST5EDT,M3.2.0,M11.1.0",
      c(
        "2026-03-08T06:59:59",
        "2026-03-08T07:00:00",
        "2026-11-01T05:59:59",
        "2026-11-01T06:00:00"
      )
    ),
    c(-18000L, -14400L, -14400L, -18000L)
  )
  expect_error(utoff("EST5", "2026-01-01T00:00") |> invisible(), NA)
  expect_error(
    .Call(zutempo:::C_ztp_r_tz_rule_utoff, "nonsense,,", 0),
    class = "zutempo_tz_error"
  )
})

test_that("identifiers match case-insensitively and come back in the database's case", {
  with_tzdir(tz_fixture_dir("slim"), {
    expect_identical(
      zutempo:::ztp_tz_ensure("america/new_york"),
      "America/New_York"
    )
    expect_identical(zutempo:::ztp_tz_ensure("ASIA/KOLKATA"), "Asia/Kolkata")
    expect_identical(zutempo:::ztp_tz_ensure("utc"), "UTC")
    expect_identical(zutempo:::ztp_tz_ensure("+0530"), "+05:30")
    expect_error(
      zutempo:::ztp_tz_ensure("Europe/Atlantis"),
      class = "zutempo_tz_error"
    )
    expect_error(
      zutempo:::ztp_tz_ensure("+05:30:15"),
      class = "zutempo_range_error"
    )
    expect_identical(
      temporal_to_string(
        instant("2026-07-01T16:00Z"),
        time_zone = "America/New_York"
      ),
      "2026-07-01T12:00:00-04:00"
    )
    expect_identical(
      temporal_to_string(
        instant("2026-01-01T00:00Z"),
        time_zone = "asia/calcutta"
      ),
      "2026-01-01T05:30:00+05:30"
    )
  })
})

test_that("links resolve to their primary identifier for TimeZoneEquals", {
  link <- function(x) .Call(zutempo:::C_ztp_r_tz_link_target, x)
  expect_identical(link("Asia/Calcutta"), "Asia/Kolkata")
  expect_identical(link("asia/calcutta"), "Asia/Kolkata")
  expect_identical(link("Asia/Kolkata"), NA_character_)
  expect_identical(link("UTC"), "Etc/UTC")
  expect_identical(link(c("GB", NA)), c("Europe/London", NA))
  expect_match(.Call(zutempo:::C_ztp_r_tz_links_version), "^[0-9]{4}[a-z]$")
  expect_identical(
    .Call(zutempo:::C_ztp_r_tz_links_version),
    zutempo_info()$tzdata
  )
})

test_that("without a database, UTC and offsets work and named zones are tz errors", {
  empty <- withr::local_tempdir()
  with_tzdir(empty, {
    expect_identical(
      temporal_to_string(instant("2026-07-01T16:00Z"), time_zone = "+02:00"),
      "2026-07-01T18:00:00+02:00"
    )
    expect_identical(
      temporal_to_string(instant("2026-07-01T16:00Z"), time_zone = "UTC"),
      "2026-07-01T16:00:00+00:00"
    )
    cond <- tryCatch(
      temporal_to_string(
        instant("2026-07-01T16:00Z"),
        time_zone = "America/New_York"
      ),
      error = identity
    )
    expect_s3_class(cond, "zutempo_tz_error")
    expect_match(conditionMessage(cond), "not in the database")
    info <- zutempo_info()
    expect_identical(info$tzdir, empty)
    expect_true(is.na(info$tz_version))
    expect_true(is.na(info$tz_form))
  })
})

test_that("zutempo_info() describes the fixture databases and the real one", {
  with_tzdir(tz_fixture_dir("slim"), {
    info <- zutempo_info()
    expect_identical(info$tzdir, tz_fixture_dir("slim"))
    expect_true(is.na(info$tz_version))
    expect_identical(info$tz_form, "slim")
  })
  with_tzdir(tz_fixture_dir("fat"), {
    expect_identical(zutempo_info()$tz_form, "fat")
  })
})

test_that("zutempo_info() describes this machine's database", {
  zutempo_tz_reset()
  withr::defer(zutempo_tz_reset())
  info <- zutempo_info()
  skip_if(is.na(info$tzdir), "no time zone database on this machine")
  expect_true(dir.exists(info$tzdir))
  expect_match(
    info$tz_version,
    "^[0-9]{4}[a-z]$",
    info = paste("database at", info$tzdir, "TZDIR", Sys.getenv("TZDIR"))
  )
  expect_true(info$tz_form %in% c("fat", "slim"), info = info$tzdir)
  out <- capture.output(print(info))
  expect_match(
    out,
    paste0("tz database: ", info$tzdir),
    all = FALSE,
    fixed = TRUE
  )
  # The same clock reading agrees with base R's conversion in a named zone.
  expect_identical(
    temporal_to_string(
      instant("2026-07-01T16:00Z"),
      time_zone = "Europe/Lisbon"
    ),
    sub(
      "([0-9]{2})$",
      ":\\1",
      format(
        as.POSIXct("2026-07-01 16:00:00", tz = "UTC"),
        "%Y-%m-%dT%H:%M:%S%z",
        tz = "Europe/Lisbon"
      )
    )
  )
})

test_that("the cache refreshes when the directory option changes", {
  with_tzdir(tz_fixture_dir("slim"), {
    zutempo:::ztp_tz_ensure("Europe/Dublin")
    expect_true(.Call(zutempo:::C_ztp_r_tz_loaded, "Europe/Dublin"))
    # with_options(), not local_options(): a local_options() evaluated
    # inside with_tzdir()'s code would restore the fixture directory after
    # with_tzdir() has restored the original, and leak it to later tests.
    withr::with_options(list(zutempo.tzdir = tz_fixture_dir("fat")), {
      expect_identical(zutempo_info()$tz_form, "fat")
      expect_false(.Call(zutempo:::C_ztp_r_tz_loaded, "Europe/Dublin"))
    })
  })
})

test_that("a damaged TZif file is a tz error, not a crash", {
  path <- file.path(tz_fixture_dir("slim"), "Asia/Tokyo")
  bytes <- readBin(path, "raw", n = file.size(path))
  bad <- function(b) .Call(zutempo:::C_ztp_r_tz_load, "Fuzz/Zone", b)
  expect_error(bad(bytes[1:20]), class = "zutempo_tz_error")
  expect_error(
    bad(as.raw(c(0x54, 0x5a, 0x69, 0x66, 0x32, rep(0xff, 60)))),
    class = "zutempo_tz_error"
  )
  expect_error(bad(raw(0)), class = "zutempo_tz_error")
  truncated <- bytes[seq_len(length(bytes) - 40L)]
  expect_error(bad(truncated), class = "zutempo_tz_error")
  expect_silent(bad(bytes))
  zutempo_tz_reset()
})
