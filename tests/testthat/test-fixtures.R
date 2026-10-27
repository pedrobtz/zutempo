# The committed fixtures say which pins they were made from; these tests
# compare that with inst/spec/PINS, so a pin bump without regenerating the
# fixtures fails here. The headers are read without parsing the cases.

test_that("the zone fixtures come from the pinned tzdata release", {
  version <- readLines(test_path("tzdata", "VERSION"), warn = FALSE)
  expect_identical(version, unname(fixture_pins()[["Tzdata"]]))
})

test_that("the test262 cases come from the pinned test262 commit", {
  files <- list.files(test_path("test262"), pattern = "\\.json\\.gz$")
  skip_if(length(files) == 0L, "the test262 cases are not built")
  commits <- vapply(
    files,
    function(f) {
      con <- gzfile(test_path("test262", f), "rb")
      on.exit(close(con))
      fixture_header_field(rawToChar(readBin(con, "raw", 300L)), "test262")
    },
    ""
  )
  expect_identical(
    unname(commits),
    rep(unname(fixture_pins()[["Test262Commit"]]), length(files))
  )
})

test_that("the oracle files share one engine and an older or equal tzdata", {
  files <- list.files(test_path("oracle"), pattern = "\\.json$")
  heads <- vapply(
    files,
    function(f) {
      paste(readLines(test_path("oracle", f), n = 5L), collapse = "\n")
    },
    ""
  )
  engines <- unique(vapply(heads, fixture_header_field, "", "engine"))
  tz <- unique(vapply(heads, fixture_header_field, "", "tz"))
  expect_length(engines, 1L)
  expect_length(tz, 1L)
  expect_match(engines, "^temporal-polyfill [0-9.]+$")
  # temporal-polyfill reads zones through Intl, so "tz" is the tzdata of
  # the ICU in the Node that generated the files (process.versions.tz),
  # not a pin: a Node with ICU's 2026d data is not released yet. The zone
  # cases run on the 2026d fixtures, so a zone whose rules changed between
  # the two releases would fail its oracle case, not pass unnoticed.
  expect_match(tz, "^[0-9]{4}[a-z]$")
  expect_true(tz <= fixture_pins()[["Tzdata"]])
  # The engine is the one tools/temporal-oracle pins, when the tools are
  # here (R CMD build leaves them out).
  lock <- test_path("..", "..", "tools", "temporal-oracle", "package.json")
  skip_if_not(file.exists(lock), "tools/temporal-oracle is not here")
  skip_if_not_installed("jsonlite")
  pinned <- jsonlite::fromJSON(lock)[["dependencies"]][["temporal-polyfill"]]
  expect_identical(engines, paste("temporal-polyfill", pinned))
})
