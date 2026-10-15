# Every exported function is documented with examples (roadmap stage 12).

test_that("every export has a help topic with an examples section", {
  skip_on_cran()
  # From the installed help, or from man/ when the package is loaded from
  # source (devtools::test()), which has no help database.
  path <- find.package("zutempo")
  rd <- if (dir.exists(file.path(path, "man"))) {
    tools::Rd_db(dir = path)
  } else {
    tools::Rd_db("zutempo")
  }
  skip_if(length(rd) == 0L, "the help database is not installed")
  topics <- lapply(rd, function(x) {
    tags <- vapply(x, function(e) attr(e, "Rd_tag"), "")
    aliases <- unlist(lapply(x[tags == "\\alias"], as.character))
    list(aliases = aliases, examples = any(tags == "\\examples"))
  })
  exports <- getNamespaceExports("zutempo")
  documented <- unlist(lapply(topics, `[[`, "aliases"))
  with_examples <- unlist(lapply(topics, function(t) {
    if (t[["examples"]]) t[["aliases"]]
  }))
  expect_identical(setdiff(exports, documented), character())
  expect_identical(setdiff(exports, with_examples), character())
})
