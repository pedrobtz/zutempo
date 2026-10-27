# One vector of each value class other than duration(), in reverse
# chronological order with an NA last, for the operator tests.
ops_values <- function() {
  list(
    plain_date = plain_date(c("2026-02-01", "2026-01-31", NA)),
    plain_time = plain_time(c("12:30", "00:00:00.000000001", NA)),
    plain_date_time = plain_date_time(c("2026-02-01", "2026-01-31T12:30", NA)),
    plain_year_month = plain_year_month(c("2026-02", "2026-01", NA)),
    plain_month_day = plain_month_day(c("02-01", "01-31", NA)),
    instant = instant(c("2026-02-01T00:00Z", "2026-01-31T12:30Z", NA)),
    zoned_date_time = zoned_date_time(c(
      "2026-02-01T00:00[+01:00]",
      "2026-01-31T12:30[UTC]",
      NA
    ))
  )
}
