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

# Skip a test that needs the machine's time zone database when there is
# none. When one of the directories base R reads exists but the lookup
# found nothing, the lookup is broken: fail rather than skip, so a
# regression in R/tz.R cannot turn the tests that need it into skips.
skip_without_tzdb <- function() {
  if (!is.na(zutempo_info()[["tzdir"]])) {
    return(invisible())
  }
  known <- c(
    file.path(R.home("share"), "zoneinfo"),
    "/usr/share/zoneinfo",
    "/var/db/timezone/zoneinfo"
  )
  exists <- dir.exists(known)
  if (any(exists)) {
    stop(sprintf(
      "the lookup found no time zone database, but %s exists",
      known[exists][1L]
    ))
  }
  skip("no time zone database on this machine")
}

# Where the parts of a version 2+ TZif file start, as 1-based positions in
# its bytes (RFC 8536 section 3), for tests that damage one part.
tzif_layout <- function(bytes) {
  be32 <- function(at) sum(as.numeric(bytes[at + 0:3]) * 256^(3:0))
  counts <- function(header) {
    stats::setNames(
      lapply(seq(20, 40, by = 4), function(o) be32(header + o)),
      c("isutcnt", "isstdcnt", "leapcnt", "timecnt", "typecnt", "charcnt")
    )
  }
  v1 <- counts(1L)
  # The bytes per entry of each count in a version 1 block.
  block1 <- sum(unlist(v1) * c(1, 1, 8, 5, 6, 1))
  header2 <- as.integer(1 + 44 + block1)
  v2 <- counts(header2)
  times <- header2 + 44L
  idx <- as.integer(times + 8 * v2$timecnt)
  types <- as.integer(idx + v2$timecnt)
  chars <- as.integer(types + 6 * v2$typecnt)
  footer <- as.integer(
    chars + v2$charcnt + 12 * v2$leapcnt + v2$isstdcnt + v2$isutcnt
  )
  c(
    v2[c("timecnt", "typecnt", "charcnt")],
    list(
      header2 = header2,
      times = times,
      idx = idx,
      types = types,
      footer = footer
    )
  )
}

# The fixture Asia/Tokyo damaged in each way the TZif reader checks, by
# name, for tests of the reader's errors.
tzif_damaged <- function() {
  path <- file.path(tz_fixture_dir("slim"), "Asia/Tokyo")
  bytes <- readBin(path, "raw", n = file.size(path))
  at <- tzif_layout(bytes)
  patch <- function(offset, value) {
    b <- bytes
    b[offset + seq_along(value) - 1L] <- as.raw(value)
    b
  }
  # The second transition equal to the first.
  repeated <- patch(at$times + 8L, as.integer(bytes[at$times + 0:7]))
  list(
    "too short for a header" = bytes[1:20],
    "a header with a bad version" = as.raw(c(
      0x54,
      0x5a,
      0x69,
      0x66,
      0x32,
      rep(0xff, 60)
    )),
    "empty" = raw(0),
    "truncated in the 32-bit block" = bytes[seq_len(at$header2 + 10L)],
    "a second header without its magic" = patch(at$header2 + 3L, 0x58),
    "truncated in the 64-bit block" = bytes[seq_len(length(bytes) - 40L)],
    "transitions not ascending" = repeated,
    "a transition type past the types" = patch(at$idx, 3L),
    "an abbreviation index past the characters" = patch(at$types + 5L, 12L),
    "a footer without its closing newline" = bytes[-length(bytes)],
    "a footer that is not a TZ rule" = c(
      bytes[seq_len(at$footer)],
      charToRaw("nonsense,,\n")
    )
  )
}

# Load one of tzif_damaged()'s files as the zone "Fuzz/Zone".
tzif_load_damaged <- function(what) {
  damaged <- tzif_damaged()
  stopifnot(what %in% names(damaged))
  .Call(zutempo:::C_ztp_r_tz_load, "Fuzz/Zone", damaged[[what]])
}
