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
  # A standard time alone; an unquoted name.
  expect_identical(utoff("EST5", "2026-01-01T00:00"), -18000L)
  # DST with neither an offset nor rules: one hour ahead, on the US rules
  # POSIX gives as the default (M3.2.0,M11.1.0).
  expect_identical(
    utoff(
      "EST5EDT",
      c(
        "2026-01-15T12:00",
        "2026-03-08T06:59:59",
        "2026-03-08T07:00:00",
        "2026-07-15T12:00",
        "2026-11-01T06:00:00"
      )
    ),
    c(-18000L, -18000L, -14400L, -14400L, -18000L)
  )
  # Offsets with minutes and seconds, as zic writes for local mean time.
  expect_identical(utoff("<-034630>3:46:30", "2026-01-01T00:00"), -13590L)
  expect_identical(
    utoff(
      "<+0020>-0:20<+0120>-1:20:00,M3.5.0,M10.5.0/3",
      c("2026-01-15T12:00", "2026-07-15T12:00")
    ),
    c(1200L, 4800L)
  )
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
    for (x in c("+05:30:15", "Ab$c", "Europe/Par is")) {
      e <- expect_error(
        zutempo:::ztp_tz_ensure(x),
        class = "zutempo_range_error",
        info = x
      )
      expect_false(inherits(e, "zutempo_tz_error"), info = x)
    }
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
    # The wording ("not in the database at ...") is in test-messages.R.
    expect_error(
      temporal_to_string(
        instant("2026-07-01T16:00Z"),
        time_zone = "America/New_York"
      ),
      class = "zutempo_tz_error"
    )
    info <- zutempo_info()
    expect_identical(info$tzdir, empty)
    expect_true(is.na(info$tz_version))
    expect_true(is.na(info$tz_form))
  })
})

test_that("zutempo_info() describes the fixture databases", {
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

test_that("the tzdata version is read from each file that can give it", {
  version_of <- function(files) {
    dir <- withr::local_tempdir()
    for (f in names(files)) {
      writeLines(files[[f]], file.path(dir, f))
    }
    zutempo:::ztp_tz_version(dir)
  }
  # macOS's +VERSION, R's own VERSION, then tzdata.zi (Linux).
  expect_identical(version_of(list("+VERSION" = "2026f")), "2026f")
  expect_identical(version_of(list(VERSION = "2026b")), "2026b")
  expect_identical(
    version_of(list("tzdata.zi" = c("# version 2026a", "R Barb 1932 o -"))),
    "2026a"
  )
  expect_identical(
    version_of(list("+VERSION" = "2026f", "tzdata.zi" = "# version 2026a")),
    "2026f"
  )
  # An empty VERSION says nothing, and tzdata.zi is read instead.
  expect_identical(
    version_of(list(VERSION = "", "tzdata.zi" = "# version 2026a")),
    "2026a"
  )
  expect_identical(
    version_of(list("tzdata.zi" = "R Barb 1932 o -")),
    NA_character_
  )
  expect_identical(version_of(list()), NA_character_)
  expect_identical(zutempo:::ztp_tz_version(NA_character_), NA_character_)
})

test_that("zutempo_info() reads the version from tzdata.zi", {
  dir <- file.path(withr::local_tempdir(), "zoneinfo")
  dir.create(dir)
  file.copy(
    list.files(tz_fixture_dir("slim"), full.names = TRUE),
    dir,
    recursive = TRUE
  )
  writeLines(
    c("# version 2026a", "R Barb 1932 o -"),
    file.path(dir, "tzdata.zi")
  )
  with_tzdir(dir, {
    expect_identical(zutempo_info()[["tz_version"]], "2026a")
    # tzdata.zi is not a zone.
    expect_false("tzdata.zi" %in% zutempo:::ztp_tz_current()[["index"]][["id"]])
  })
})

test_that("zutempo_info() describes this machine's database", {
  zutempo_tz_reset()
  withr::defer(zutempo_tz_reset())
  info <- zutempo_info()
  skip_without_tzdb()
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
  withr::defer(zutempo_tz_reset())
  path <- file.path(tz_fixture_dir("slim"), "Asia/Tokyo")
  bytes <- readBin(path, "raw", n = file.size(path))
  at <- tzif_layout(bytes)
  # The layout read the file as zic wrote it: nine transitions, three
  # types and the footer "JST-9".
  expect_identical(
    unlist(at[c("timecnt", "typecnt")]),
    c(timecnt = 9, typecnt = 3)
  )
  expect_identical(rawToChar(bytes[at$footer:length(bytes)]), "\nJST-9\n")
  # The messages, which tell the damage apart, are in test-messages.R.
  damaged <- tzif_damaged()
  expect_length(damaged, 11L)
  for (what in names(damaged)) {
    expect_error(
      .Call(zutempo:::C_ztp_r_tz_load, "Fuzz/Zone", damaged[[what]]),
      class = "zutempo_tz_error",
      info = what
    )
  }
  expect_silent(.Call(zutempo:::C_ztp_r_tz_load, "Fuzz/Zone", bytes))
})

test_that("two candidate instants found out of order are sorted", {
  # A zone that moves to +01:00 two hours before a local noon, back to
  # +00:00 half an hour before it, and to +01:00 again an hour after. Noon
  # is then 11:00Z under +01:00 and 12:00Z under +00:00. The offsets
  # probed a day either side are +00:00 and then +01:00, so the later
  # instant is found first; "earlier" must still give the earlier one.
  noon <- as.numeric(as.POSIXct("2026-03-07 12:00:00", tz = "UTC"))
  dir <- file.path(withr::local_tempdir(), "zoneinfo")
  dir.create(file.path(dir, "Test"), recursive = TRUE)
  writeBin(
    tzif_v1_transitions(
      times = noon + c(-7200, -1800, 3600),
      idx = c(1L, 0L, 1L),
      utoffs = c(0, 3600)
    ),
    file.path(dir, "Test", "Zone")
  )
  with_tzdir(dir, {
    p <- plain_date_time("2026-03-07T12:00")
    expect_identical(
      format(temporal_to_zoned_date_time(
        p,
        "Test/Zone",
        disambiguation = "earlier"
      )),
      "2026-03-07T12:00:00+01:00[Test/Zone]"
    )
    expect_identical(
      format(temporal_to_zoned_date_time(
        p,
        "Test/Zone",
        disambiguation = "later"
      )),
      "2026-03-07T12:00:00+00:00[Test/Zone]"
    )
  })
})

test_that("the database is looked up once per setting, and again after a reset", {
  dir <- file.path(withr::local_tempdir(), "zoneinfo")
  withr::local_options(list(zutempo.tzdir = dir))
  zutempo_tz_reset()
  withr::defer(zutempo_tz_reset())
  # The directory does not exist yet, so the lookup goes past it.
  expect_false(identical(zutempo_info()[["tzdir"]], dir))
  dir.create(dir)
  file.copy(
    list.files(tz_fixture_dir("slim"), full.names = TRUE),
    dir,
    recursive = TRUE
  )
  # The lookup is kept for the same setting ...
  expect_false(identical(zutempo_info()[["tzdir"]], dir))
  # ... until a reset.
  zutempo_tz_reset()
  expect_identical(zutempo_info()[["tzdir"]], dir)
})

test_that("each platform tries its directories in base R's order", {
  withr::local_options(list(zutempo.tzdir = NULL))
  withr::local_envvar(TZDIR = NA)
  r_copy <- file.path(R.home("share"), "zoneinfo")
  local_mocked_bindings(ztp_dir_exists = function(paths) {
    rep(TRUE, length(paths))
  })
  tried <- function(platform) {
    with_mocked_bindings(
      zutempo:::ztp_tz_find(),
      ztp_tz_platform = function() platform
    )
  }
  linux <- tried("Linux")
  expect_identical(linux$tried, c("/usr/share/zoneinfo", r_copy))
  expect_identical(linux$dir, "/usr/share/zoneinfo")
  darwin <- tried("Darwin")
  expect_identical(darwin$tried, c(r_copy, "/var/db/timezone/zoneinfo"))
  expect_identical(darwin$dir, r_copy)
  windows <- tried("windows")
  expect_identical(windows$tried, r_copy)
  expect_identical(windows$dir, r_copy)
  # Another Unix reads the system's database first, as Linux does.
  expect_identical(tried("SunOS")$tried, linux$tried)
})

test_that("the lookup takes the first directory that exists", {
  withr::local_options(list(zutempo.tzdir = NULL))
  withr::local_envvar(TZDIR = NA)
  r_copy <- file.path(R.home("share"), "zoneinfo")
  local_mocked_bindings(
    ztp_tz_platform = function() "Linux",
    ztp_dir_exists = function(paths) paths == r_copy
  )
  found <- zutempo:::ztp_tz_find()
  expect_identical(found$dir, r_copy)
  expect_identical(found$tried, c("/usr/share/zoneinfo", r_copy))
})

test_that("the option comes before TZDIR, and both know R's special values", {
  withr::local_options(list(zutempo.tzdir = NULL))
  withr::local_envvar(TZDIR = NA)
  r_copy <- file.path(R.home("share"), "zoneinfo")
  local_mocked_bindings(
    ztp_tz_platform = function() "Linux",
    ztp_dir_exists = function(paths) rep(TRUE, length(paths))
  )
  withr::with_envvar(c(TZDIR = "internal"), {
    expect_identical(
      zutempo:::ztp_tz_find()$tried,
      c(r_copy, "/usr/share/zoneinfo")
    )
  })
  withr::with_envvar(c(TZDIR = "macOS"), {
    expect_identical(
      zutempo:::ztp_tz_find()$tried,
      c("/var/db/timezone/zoneinfo", "/usr/share/zoneinfo", r_copy)
    )
  })
  # An empty TZDIR is no setting.
  withr::with_envvar(c(TZDIR = ""), {
    expect_identical(
      zutempo:::ztp_tz_find()$tried,
      c("/usr/share/zoneinfo", r_copy)
    )
  })
  withr::with_options(list(zutempo.tzdir = "/opt/zoneinfo"), {
    withr::with_envvar(c(TZDIR = "macOS"), {
      expect_identical(
        zutempo:::ztp_tz_find()$tried,
        c(
          "/opt/zoneinfo",
          "/var/db/timezone/zoneinfo",
          "/usr/share/zoneinfo",
          r_copy
        )
      )
    })
  })
  withr::with_options(list(zutempo.tzdir = "internal"), {
    expect_identical(zutempo:::ztp_tz_find()$dir, r_copy)
  })
})

test_that("with no database anywhere, named zones are tz errors and UTC works", {
  withr::local_options(list(zutempo.tzdir = NULL))
  withr::local_envvar(TZDIR = NA)
  local_mocked_bindings(ztp_dir_exists = function(paths) {
    rep(FALSE, length(paths))
  })
  zutempo_tz_reset()
  withr::defer(zutempo_tz_reset())
  info <- zutempo_info()
  expect_true(is.na(info$tzdir))
  expect_true(is.na(info$tz_version))
  expect_error(
    zoned_date_time(c(
      "2026-03-07T12:00[UTC]",
      "2026-03-07T12:00[Europe/Paris]"
    )),
    class = "zutempo_tz_error"
  )
  expect_identical(
    format(zoned_date_time("2026-03-07T12:00[+01:00]")),
    "2026-03-07T12:00:00+01:00[+01:00]"
  )
  expect_identical(
    temporal_to_string(instant("2026-07-01T16:00Z"), time_zone = "UTC"),
    "2026-07-01T16:00:00+00:00"
  )
})
