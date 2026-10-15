test_that("every oracle case for PlainDate agrees with the engine", {
  # On the committed slim fixtures, so the result does not depend on the
  # machine's database, which may lack the backward links.
  with_tzdir(tz_fixture_dir("slim"), oracle_run_cases("PlainDate"))
})
