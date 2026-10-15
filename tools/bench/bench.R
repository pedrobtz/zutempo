# Benchmarks for the performance targets of design 12, and zutempo next to
# clock on the operations both offer. Not run on CRAN or in CI: run it by
# hand on an idle machine and record the output in tools/bench/RESULTS.md.
#
#   Rscript tools/bench/bench.R
#
# Needs bench and clock, and zutempo installed or loadable from the
# package root with pkgload. Every input has 10^6 elements.

if (requireNamespace("pkgload", quietly = TRUE) && file.exists("DESCRIPTION")) {
  pkgload::load_all(quiet = TRUE)
} else {
  library(zutempo)
}
stopifnot(
  requireNamespace("bench", quietly = TRUE),
  requireNamespace("clock", quietly = TRUE)
)

n <- 1e6
set.seed(1)
zone <- "America/New_York"
seconds <- floor(stats::runif(n, 0, 2^31))
nanos <- floor(stats::runif(n, 0, 1e9))
ct <- .POSIXct(seconds, tz = "UTC")
utc <- paste0(
  format(ct, "%Y-%m-%dT%H:%M:%S", tz = "UTC"),
  sprintf(".%09.0f", nanos)
)

# Inputs for each operation, built outside the timings.
rfc3339 <- paste0(utc, "+00:00")
rfc3339_clock <- paste0(utc, "Z")
x_instant <- instant(rfc3339)
x_zoned <- temporal_to_zoned_date_time_iso(x_instant, zone)
rfc9557 <- format(x_zoned)
local <- temporal_to_plain_date_time(x_zoned)
local_strings <- format(local)
sys <- clock::sys_time_parse(
  rfc3339_clock,
  format = "%Y-%m-%dT%H:%M:%SZ",
  precision = "nanosecond"
)
zoned_clock <- clock::as_zoned_time(sys, zone)
naive <- clock::as_naive_time(zoned_clock)
zoned_strings_clock <- format(zoned_clock, format = "%Y-%m-%dT%H:%M:%S%Ez[%Z]")
dates <- temporal_to_plain_date(local)
ymd <- clock::as_year_month_day(clock::as_date(as.Date(dates)))

run <- function(name, expr_zutempo, expr_clock = NULL) {
  exprs <- list(zutempo = expr_zutempo)
  if (!is.null(expr_clock)) {
    exprs[["clock"]] <- expr_clock
  }
  res <- bench::mark(
    exprs = exprs,
    iterations = 5,
    check = FALSE,
    filter_gc = FALSE
  )
  data.frame(
    operation = name,
    package = names(exprs),
    median_s = as.numeric(res[["median"]]),
    mem_mb = as.numeric(res[["mem_alloc"]]) / 2^20
  )
}

results <- rbind(
  # Design 12, the five targets.
  run(
    "Parse RFC 3339 strings with offset into Instant",
    quote(instant(rfc3339)),
    quote(clock::sys_time_parse(
      rfc3339_clock,
      format = "%Y-%m-%dT%H:%M:%SZ",
      precision = "nanosecond"
    ))
  ),
  run(
    "Parse RFC 9557 strings with a bracketed zone into ZonedDateTime",
    quote(zoned_date_time(rfc9557)),
    quote(clock::zoned_time_parse_complete(
      zoned_strings_clock,
      precision = "nanosecond"
    ))
  ),
  run(
    "Instant to ZonedDateTime field access, one zone",
    quote(hour(temporal_to_zoned_date_time_iso(x_instant, zone))),
    quote(clock::get_hour(clock::as_year_month_day(clock::as_naive_time(
      clock::as_zoned_time(sys, zone)
    ))))
  ),
  run(
    "PlainDateTime to ZonedDateTime, compatible, one zone",
    quote(temporal_to_zoned_date_time(local, zone)),
    quote(clock::as_zoned_time(
      naive,
      zone,
      nonexistent = "shift-forward",
      ambiguous = "earliest"
    ))
  ),
  run(
    "Format ZonedDateTime to strings",
    quote(format(x_zoned)),
    quote(format(zoned_clock, format = "%Y-%m-%dT%H:%M:%S%Ez[%Z]"))
  ),
  # Other operations both packages offer.
  run(
    "Parse ISO date-times without offset",
    quote(plain_date_time(local_strings)),
    quote(clock::naive_time_parse(
      local_strings,
      format = "%Y-%m-%dT%H:%M:%S",
      precision = "nanosecond"
    ))
  ),
  run(
    "Add one month to dates",
    quote(temporal_add(dates, "P1M")),
    quote(clock::add_months(ymd, 1, invalid = "previous"))
  ),
  run(
    "Date fields: year, month, day",
    quote(list(year(dates), month(dates), day(dates))),
    quote(list(
      clock::get_year(ymd),
      clock::get_month(ymd),
      clock::get_day(ymd)
    ))
  ),
  run(
    "Instant to POSIXct and back",
    quote(instant(as.POSIXct(x_instant))),
    quote(clock::as_sys_time(as.POSIXct(sys)))
  )
)

targets <- c(
  "Parse RFC 3339 strings with offset into Instant" = 0.3,
  "Parse RFC 9557 strings with a bracketed zone into ZonedDateTime" = 0.5,
  "Instant to ZonedDateTime field access, one zone" = 0.1,
  "PlainDateTime to ZonedDateTime, compatible, one zone" = 0.2,
  "Format ZonedDateTime to strings" = 0.4
)
results[["target_s"]] <- unname(targets[results[["operation"]]])
results[["target_s"]][results[["package"]] != "zutempo"] <- NA

cat(sprintf(
  "R %s on %s, %s; zutempo %s, clock %s, %s elements\n\n",
  paste(R.version$major, R.version$minor, sep = "."),
  R.version$platform,
  if (Sys.info()[["sysname"]] == "Darwin") {
    system("sysctl -n machdep.cpu.brand_string", intern = TRUE)
  } else {
    Sys.info()[["machine"]]
  },
  format(utils::packageVersion("zutempo")),
  format(utils::packageVersion("clock")),
  format(n, big.mark = ",")
))
print(results, row.names = FALSE, digits = 3)
