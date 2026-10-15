#!/usr/bin/env Rscript
# Extract every member of the eight Temporal types and of Temporal.Now from
# the pinned specification into inst/spec/members.csv (roadmap stage 1,
# design 5 and 15 criterion 3). Base R only. Run from the package root:
#
#   Rscript tools/spec/members.R
#
# The spec is read at the commit in inst/spec/PINS; the output is
# deterministic for a given commit, so a diff after re-running means the
# pin moved or this script changed.

pins <- read.dcf("inst/spec/PINS")
commit <- pins[1L, "SpecificationCommit"]
base <- sprintf(
  "https://raw.githubusercontent.com/tc39/proposal-temporal/%s/spec/",
  commit
)

# Spec file per type, in the order the rows are written.
files <- c(
  Instant = "instant",
  ZonedDateTime = "zoneddatetime",
  PlainDateTime = "plaindatetime",
  PlainDate = "plaindate",
  PlainTime = "plaintime",
  PlainYearMonth = "plainyearmonth",
  PlainMonthDay = "plainmonthday",
  Duration = "duration",
  Now = "temporal"
)

# Members that exist for JavaScript alone, with the reason (design 2).
out_of_scope <- c(
  valueOf = "throws in JavaScript; no R counterpart",
  toJSON = "format() covers it",
  toLocaleString = "ECMA-402 (locale formatting) is out of scope"
)

snake <- function(x) {
  x <- gsub("([a-z0-9])([A-Z])", "\\1_\\2", x)
  x <- gsub("([A-Z]+)([A-Z][a-z])", "\\1_\\2", x)
  tolower(x)
}

r_name <- function(type, kind, member) {
  switch(
    kind,
    constructor = ,
    from = snake(type),
    static = paste(snake(type), snake(member), sep = "_"),
    method = paste0("temporal_", snake(member)),
    property = snake(member),
    now = paste0("now_", snake(member))
  )
}

rows <- list()
for (type in names(files)) {
  url <- paste0(base, files[[type]], ".html")
  lines <- readLines(url, warn = FALSE, encoding = "UTF-8")
  heads <- regmatches(lines, regexpr("<h1>[^<]*</h1>", lines))
  heads <- sub("^<h1>", "", sub("</h1>$", "", heads))
  prefix <- paste0("Temporal.", type)
  for (h in heads) {
    kind <- NULL
    member <- NULL
    if (grepl(paste0("^get ", prefix, ".prototype.[A-Za-z]+$"), h)) {
      kind <- "property"
      member <- sub(".*\\.", "", h)
    } else if (grepl(paste0("^", prefix, ".prototype.[A-Za-z]+ \\("), h)) {
      kind <- "method"
      member <- sub(" \\(.*$", "", sub(".*\\.", "", h))
    } else if (
      type == "Now" && grepl(paste0("^", prefix, ".[A-Za-z]+ \\("), h)
    ) {
      kind <- "now"
      member <- sub(" \\(.*$", "", sub(".*\\.", "", h))
    } else if (grepl(paste0("^", prefix, ".[A-Za-z]+ \\("), h)) {
      member <- sub(" \\(.*$", "", sub(".*\\.", "", h))
      kind <- if (member == "from") "from" else "static"
    } else if (grepl(paste0("^", prefix, " \\("), h)) {
      kind <- "constructor"
      member <- type
    } else {
      next
    }
    in_scope <- !(member %in% names(out_of_scope))
    note <- if (in_scope) "" else unname(out_of_scope[[member]])
    rows[[length(rows) + 1L]] <- data.frame(
      type = type,
      kind = kind,
      member = member,
      r_name = r_name(type, kind, member),
      in_scope = in_scope,
      note = note,
      stringsAsFactors = FALSE
    )
  }
}
members <- do.call(rbind, rows)
stopifnot(
  all(names(files) %in% members$type),
  !anyDuplicated(members[c("type", "kind", "member")])
)
write.csv(members, "inst/spec/members.csv", row.names = FALSE, quote = TRUE)
cat(
  sprintf(
    "%d members, %d in scope, %d distinct R names\n",
    nrow(members),
    sum(members$in_scope),
    length(unique(members$r_name[members$in_scope]))
  )
)
