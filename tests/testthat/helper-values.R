# One vector of each plain class, with an NA, for the plumbing tests.
plain_values <- function() {
  list(
    plain_date(c("2026-01-31", "2026-02-01", NA)),
    plain_time(c("12:30", "00:00:00.000000001", NA)),
    plain_date_time(c("2026-01-31T12:30", "2026-02-01", NA)),
    plain_year_month(c("2026-01", "2026-02", NA)),
    plain_month_day(c("01-31", "02-01", NA))
  )
}

# The zufast fast path and the package's own parser must agree on every
# string the fast path accepts (design 9).
parse_describe <- function(x, goal = 0L, path) {
  .Call(zutempo:::C_ztp_r_parse_describe, x, goal, path)
}
