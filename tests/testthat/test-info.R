test_that("zutempo_info() returns the pins of inst/spec/PINS", {
  info <- zutempo_info()
  pins <- read.dcf(system.file("spec", "PINS", package = "zutempo"))
  expect_s3_class(info, "zutempo_info")
  expect_identical(info$spec_repository, "tc39/proposal-temporal")
  expect_identical(info$spec_commit, unname(pins[1L, "SpecificationCommit"]))
  expect_identical(info$test262_repository, "tc39/test262")
  expect_identical(info$test262_commit, unname(pins[1L, "Test262Commit"]))
  expect_identical(info$tzdata, unname(pins[1L, "Tzdata"]))
  expect_match(info$spec_commit, "^[0-9a-f]{40}$")
  expect_match(info$test262_commit, "^[0-9a-f]{40}$")
  expect_match(info$spec_date, "^[0-9]{4}-[0-9]{2}-[0-9]{2}$")
  expect_match(info$test262_date, "^[0-9]{4}-[0-9]{2}-[0-9]{2}$")
  expect_match(info$tzdata, "^[0-9]{4}[a-z]$")
})

test_that("zutempo_info() reports the build", {
  info <- zutempo_info()
  expect_identical(info$package, as.character(getNamespaceVersion("zutempo")))
  expect_match(info$zufast, "^[0-9]+\\.[0-9]+\\.[0-9]+")
  expect_type(info$int128, "logical")
  expect_length(info$int128, 1L)
  # CI's fallback leg sets ZUTEMPO_CFLAGS=-DZUF_NO_INT128 before the build
  # (src/Makevars). When it did, the engine must say so.
  if (grepl("ZUF_NO_INT128", Sys.getenv("ZUTEMPO_CFLAGS"), fixed = TRUE)) {
    expect_false(info$int128)
  }
})

test_that("zutempo_info() prints every pin", {
  info <- zutempo_info()
  out <- capture.output(print(info))
  expect_match(out, substr(info$spec_commit, 1, 12), all = FALSE)
  expect_match(out, substr(info$test262_commit, 1, 12), all = FALSE)
  expect_match(out, info$tzdata, all = FALSE, fixed = TRUE)
  expect_match(out, info$zufast, all = FALSE, fixed = TRUE)
})
