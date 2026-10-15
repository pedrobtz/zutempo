for (case in oracle_cases("PlainMonthDay")) {
  test_that(paste("oracle PlainMonthDay", case[["id"]]), {
    oracle_check("PlainMonthDay", case)
  })
}
