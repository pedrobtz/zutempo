for (case in oracle_cases("PlainDate")) {
  test_that(paste("oracle PlainDate", case$id), {
    oracle_check_plain_date(case)
  })
}
