# The committed time zone fixtures (tools/tz/fixtures.R): fat and slim TZif
# files for a set of zones and the transitions zdump reports for them.

tz_fixture_dir <- function(form = c("slim", "fat")) {
  form <- match.arg(form)
  test_path("tzdata", form)
}

tz_fixture_transitions <- function() {
  read.delim(test_path("tzdata", "transitions.tsv"), stringsAsFactors = FALSE)
}

# Run code with zutempo reading zones from `dir`, with a fresh cache
# before and after.
with_tzdir <- function(dir, code) {
  zutempo_tz_reset()
  withr::defer(zutempo_tz_reset())
  withr::local_options(list(zutempo.tzdir = dir))
  force(code)
}

# Whether base R's own copy of the database is on this machine.
r_zoneinfo <- function() {
  dir <- file.path(R.home("share"), "zoneinfo")
  if (dir.exists(dir)) dir else NA_character_
}
