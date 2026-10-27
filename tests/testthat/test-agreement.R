# Agreement with base R (design 11): zutempo's UTC offset equals the
# gmtoff of as.POSIXlt() for every zone in the database, from 1900 to 2100,
# except where agreement/differences.csv lists a documented difference.
# This checks interoperability, not correctness: both read the machine's
# database, and where R and the specification disagree, zutempo follows
# the specification. Not on CRAN. The exhaustive version, every hour, runs
# with ZUTEMPO_EXTENDED_TESTS=true (the `agreement` job of the full run).

test_that("offsets agree with base R at every transition and sampled hours", {
  skip_on_cran()
  # Seconds normally, far longer under gctorture, which this test cannot
  # tell anything new: its C calls are the ones the oracle makes.
  skip_if(identical(Sys.getenv("ZUTEMPO_GCTORTURE_SAMPLE"), "true"))
  skip_without_tzdb()
  # Both read the same files: base R's default can be another database
  # than zutempo's (R's own copy on macOS even when the system's is newer),
  # and a version that changed a zone's rules would differ for that reason
  # alone. TZDIR is what both look at first.
  withr::local_envvar(TZDIR = zutempo_info()[["tzdir"]])
  ids <- agreement_zones()
  transitions <- agreement_transitions(ids)
  # Both sides of every transition, where offsets change, and every 997th
  # hour between them (a stride prime to the day and the week).
  sample <- seq(agreement_first, agreement_last, by = 997 * 3600)
  found <- do.call(
    rbind,
    lapply(seq_along(ids), function(i) {
      t <- transitions[[i]]
      agreement_mismatches(ids[i], sort(unique(c(sample, t, t - 1))))
    })
  )
  unexplained <- agreement_unexplained(found)
  expect(nrow(unexplained) == 0L, agreement_report(unexplained))
})

test_that("offsets agree with base R at every hour from 1900 to 2100", {
  skip_on_cran()
  skip_if_not(
    identical(Sys.getenv("ZUTEMPO_EXTENDED_TESTS"), "true"),
    "ZUTEMPO_EXTENDED_TESTS is not set"
  )
  skip_without_tzdb()
  # Both read the same files: base R's default can be another database
  # than zutempo's (R's own copy on macOS even when the system's is newer),
  # and a version that changed a zone's rules would differ for that reason
  # alone. TZDIR is what both look at first.
  withr::local_envvar(TZDIR = zutempo_info()[["tzdir"]])
  hours <- seq(agreement_first, agreement_last, by = 3600)
  found <- do.call(
    rbind,
    lapply(agreement_zones(), agreement_mismatches, secs = hours)
  )
  unexplained <- agreement_unexplained(found)
  expect(nrow(unexplained) == 0L, agreement_report(unexplained))
})
