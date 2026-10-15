# test262's Temporal tests, translated by tools/test262/extract.mjs (design
# 11). Every translated case passes, or matches a pattern of
# test262/differences.csv, which gives the reason (design 6.9 and 10). The
# cases use named zones, read from the machine's database; not on CRAN,
# where they would take too long.

for (type in c(
  "Instant",
  "ZonedDateTime",
  "PlainDateTime",
  "PlainDate",
  "PlainTime",
  "PlainYearMonth",
  "PlainMonthDay",
  "Duration"
)) {
  local({
    type <- type
    test_that(sprintf("test262 cases for %s pass", type), {
      skip_on_cran()
      # The cases reach the same C glue as the oracle, which gctorture
      # already runs; here they would only take time.
      skip_if(identical(Sys.getenv("ZUTEMPO_GCTORTURE_SAMPLE"), "true"))
      skip_if(
        is.na(zutempo_info()[["tzdir"]]),
        "no time zone database on this machine"
      )
      test262_run_cases(type)
    })
  })
}
