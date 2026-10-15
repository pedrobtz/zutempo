for (case in oracle_cases("Duration")) {
  test_that(paste("oracle Duration", case[["id"]]), {
    oracle_check("Duration", case)
  })
}
