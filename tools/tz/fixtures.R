#!/usr/bin/env Rscript
# Build the committed time zone fixtures (design 11): fat and slim TZif files
# for a set of zones with awkward histories, compiled with zic from the tzdata
# release named in inst/spec/PINS, and the transitions zdump reports for each
# zone from 1850 to 2100 as the expected offsets. Base R, zic and zdump. Run
# from the package root:
#
#   Rscript tools/tz/fixtures.R
#
# Writes tests/testthat/tzdata/{fat,slim}/<zone>, tests/testthat/tzdata/
# transitions.tsv and tests/testthat/tzdata/VERSION.

zones <- c(
  "America/New_York", # the design's slim-file regression
  "Europe/Lisbon", # last explicit slim transition in 1996
  "Australia/Lord_Howe", # 30-minute DST
  "Pacific/Apia", # skipped 2011-12-30
  "Pacific/Kiritimati", # +14
  "America/St_Johns", # -03:30 with DST
  "Africa/Casablanca", # Ramadan rules, explicit to 2087, negative DST
  "Asia/Kolkata", # +05:30, no DST
  "Asia/Calcutta", # its link
  "Europe/Dublin", # negative DST in winter
  "Antarctica/Troll", # +2 hours of DST
  "America/Santiago", # southern DST with a 24:00 rule
  "Pacific/Auckland", # southern DST
  "Asia/Tehran", # DST abolished in 2022
  "America/Sao_Paulo", # DST abolished in 2019
  "Africa/Cairo", # DST reinstated in 2023
  "Europe/Moscow", # offset changes without DST
  "Asia/Tokyo", # no DST since 1951
  "America/Anchorage", # -10 to -9, date line history
  "Etc/UTC", # the trivial file
  "UTC", # its link
  "Etc/GMT-14" # a fixed offset by name
)

pins <- read.dcf("inst/spec/PINS")
version <- pins[1L, "Tzdata"]
url <- sprintf(
  "https://data.iana.org/time-zones/releases/tzdata%s.tar.gz",
  version
)
work <- tempfile("tzdata")
dir.create(work)
tarball <- file.path(work, basename(url))
download.file(url, tarball, mode = "wb", quiet = TRUE)
src <- file.path(work, "src")
dir.create(src)
untar(tarball, exdir = src)
found <- trimws(readLines(file.path(src, "version"), warn = FALSE))
found <- found[nzchar(found)][1L]
if (found != version) {
  stop(sprintf(
    "the tarball says tzdata %s, inst/spec/PINS says %s",
    found,
    version
  ))
}
sources <- file.path(
  src,
  c(
    "africa",
    "antarctica",
    "asia",
    "australasia",
    "europe",
    "northamerica",
    "southamerica",
    "etcetera",
    "backward"
  )
)

out <- "tests/testthat/tzdata"
unlink(out, recursive = TRUE)
for (form in c("fat", "slim")) {
  built <- file.path(work, form)
  status <- system2("zic", c("-b", form, "-d", built, sources))
  if (status != 0) {
    stop("zic failed")
  }
  for (zone in zones) {
    dest <- file.path(out, form, zone)
    dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
    file.copy(file.path(built, zone), dest)
  }
}

# The state at the start of the range comes from zdump -i, whose first data
# line has the offset and abbreviation in force; zdump -v then prints two
# lines per transition, the last second of the old offset and the first of
# the new, and the "new" lines give every later state.
range_start <- as.numeric(as.POSIXct("1850-01-01", tz = "UTC"))

parse_offset <- function(x) {
  # "+00", "-05", "+0530", "-034630": hours, then optional minutes, seconds.
  sign <- ifelse(startsWith(x, "-"), -1L, 1L)
  digits <- sub("^[+-]", "", x)
  parts <- substring(digits, c(1, 3, 5), c(2, 4, 6))
  parts[!nzchar(parts)] <- "0"
  v <- as.integer(parts)
  sign * (v[1] * 3600L + v[2] * 60L + v[3])
}

initial_state <- function(zone, dir) {
  lines <- system2(
    "zdump",
    c("-i", "-c", "1850,2100", zone),
    env = paste0("TZDIR=", dir),
    stdout = TRUE
  )
  first <- lines[grepl("^-\t", lines)][1L]
  fields <- strsplit(first, "\t")[[1L]]
  data.frame(
    zone = zone,
    utc_seconds = range_start,
    utoff = parse_offset(fields[3L]),
    isdst = as.integer(length(fields) >= 5L && fields[5L] == "1"),
    abbr = fields[4L],
    stringsAsFactors = FALSE
  )
}

parse_zdump <- function(zone, dir) {
  lines <- system2(
    "zdump",
    c("-v", "-c", "1850,2100", zone),
    env = paste0("TZDIR=", dir),
    stdout = TRUE
  )
  re <- "^(\\S+)\\s+(\\S+ \\S+\\s+\\d+ \\d\\d:\\d\\d:\\d\\d \\d+) UT = .* (\\S+) isdst=(\\d) gmtoff=(-?\\d+)$"
  lines <- lines[grepl(re, lines)]
  utc <- sub(re, "\\2", lines)
  epoch <- as.numeric(as.POSIXct(
    utc,
    format = "%a %b %d %H:%M:%S %Y",
    tz = "UTC"
  ))
  data.frame(
    zone = zone,
    utc_seconds = epoch,
    utoff = as.integer(sub(re, "\\5", lines)),
    isdst = as.integer(sub(re, "\\4", lines)),
    abbr = sub(re, "\\3", lines),
    stringsAsFactors = FALSE
  )
}
rows <- list()
for (zone in zones) {
  d <- parse_zdump(zone, file.path(work, "slim"))
  stopifnot(!anyNA(d$utc_seconds))
  fat <- parse_zdump(zone, file.path(work, "fat"))
  if (!identical(fat, d)) {
    stop("fat and slim disagree under zdump for ", zone)
  }
  # A transition's "after" line is exactly one second past its "before"
  # line; zdump also prints the range boundaries, which have no pair.
  is_after <- c(FALSE, diff(d$utc_seconds) == 1)
  after <- d[is_after, ]
  rows[[zone]] <- rbind(initial_state(zone, file.path(work, "slim")), after)
}
transitions <- do.call(rbind, rows)
rownames(transitions) <- NULL
write.table(
  transitions,
  file.path(out, "transitions.tsv"),
  sep = "\t",
  quote = FALSE,
  row.names = FALSE
)
writeLines(version, file.path(out, "VERSION"))
cat(sprintf(
  "%d zones, %d transition rows, tzdata %s -> %s\n",
  length(zones),
  nrow(transitions),
  version,
  out
))
