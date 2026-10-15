for (case in oracle_cases("PlainTime")) {
  test_that(paste("oracle PlainTime", case$id), {
    oracle_check("PlainTime", case)
  })
}
