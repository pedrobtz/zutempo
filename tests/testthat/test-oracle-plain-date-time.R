for (case in oracle_cases("PlainDateTime")) {
  test_that(paste("oracle PlainDateTime", case$id), {
    oracle_check("PlainDateTime", case)
  })
}
