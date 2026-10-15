test_that("every oracle case for ZonedDateTime agrees with the engine", {
  # On the committed slim fixtures, so the result does not depend on the
  # machine's database (roadmap stage 7).
  with_tzdir(tz_fixture_dir("slim"), oracle_run_cases("ZonedDateTime"))
})
