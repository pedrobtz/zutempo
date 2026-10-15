for (case in oracle_cases("PlainYearMonth")) {
  test_that(paste("oracle PlainYearMonth", case[["id"]]), {
    oracle_check("PlainYearMonth", case)
  })
}
