# Operators and the Summary group on the seven value classes other than
# duration(): 0.1.0 has no arithmetic or comparison operators (design 2),
# and min(), max() and range() follow the order sort() uses.

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

test_that("arithmetic operators are type errors on every value class", {
  for (x in ops_values()) {
    for (op in c("+", "-", "*", "/", "^", "%%", "%/%")) {
      f <- match.fun(op)
      expect_error(f(x, 1), class = "zutempo_type_error", info = op)
      expect_error(f(1, x), class = "zutempo_type_error", info = op)
      expect_error(f(x, x), class = "zutempo_type_error", info = op)
    }
    expect_error(-x, class = "zutempo_type_error")
    expect_error(+x, class = "zutempo_type_error")
  }
})

test_that("comparison and logical operators are type errors", {
  for (x in ops_values()) {
    for (op in c("==", "!=", "<", "<=", ">", ">=", "&", "|")) {
      f <- match.fun(op)
      expect_error(f(x, x), class = "zutempo_type_error", info = op)
      expect_error(f(x, 1), class = "zutempo_type_error", info = op)
    }
    expect_error(!x, class = "zutempo_type_error")
  }
})

test_that("an operator with another class's method is still refused", {
  skip_if(getRversion() < "4.3.0", "chooseOpsMethod() needs R 4.3")
  d <- plain_date("2026-01-31")
  expect_error(d + duration("P1D"), class = "zutempo_type_error")
  expect_error(duration("P1D") + d, class = "zutempo_type_error")
  expect_error(d == as.Date("2026-01-31"), class = "zutempo_type_error")
  expect_error(as.Date("2026-01-31") < d, class = "zutempo_type_error")
})

test_that("min(), max() and range() agree with sort()", {
  values <- ops_values()
  values[["plain_month_day"]] <- NULL
  for (nm in names(values)) {
    x <- values[[nm]]
    s <- sort(x)
    expect_identical(min(x, na.rm = TRUE), s[1], info = nm)
    expect_identical(max(x, na.rm = TRUE), s[2], info = nm)
    expect_identical(range(x, na.rm = TRUE), s[1:2], info = nm)
    expect_identical(min(x[1], x[2]), s[1], info = nm)
    expect_identical(max(x[1:2], x[0]), s[2], info = nm)
    expect_identical(min(x), x[3], info = nm)
    expect_identical(range(x), x[c(3, 3)], info = nm)
    expect_error(min(x[3], na.rm = TRUE), class = "zutempo_range_error")
    expect_error(max(x[0]), class = "zutempo_range_error")
    expect_error(min(x, 1), class = "zutempo_type_error")
  }
})

test_that("min() of zoned values compares instants and keeps the zone", {
  x <- zoned_date_time(c(
    "2026-01-31T12:00[+05:00]",
    "2026-01-31T09:00[UTC]",
    "2026-01-31T07:00+00:00[+00:00]"
  ))
  expect_identical(format(min(x)), "2026-01-31T12:00:00+05:00[+05:00]")
  expect_identical(format(max(x)), "2026-01-31T09:00:00+00:00[UTC]")
})

test_that("plain_month_day() has no order to summarise", {
  x <- plain_month_day(c("02-01", "01-31"))
  expect_error(min(x), class = "zutempo_type_error")
  expect_error(range(x), class = "zutempo_type_error")
})

test_that("the other Summary functions are type errors", {
  for (x in ops_values()) {
    for (f in list(sum, prod, any, all)) {
      expect_error(f(x), class = "zutempo_type_error")
    }
  }
})

test_that("ordering, unique and rank go through xtfrm()", {
  for (x in ops_values()) {
    expect_identical(order(x), c(2L, 1L, 3L))
    expect_identical(sort(x), x[2:1])
    expect_identical(unique(c(x, x)), x)
    expect_identical(duplicated(c(x, x)), rep(c(FALSE, TRUE), each = 3))
    expect_identical(rank(xtfrm(x), na.last = "keep"), c(2, 1, NA))
    df <- data.frame(v = x, i = 1:3)
    expect_identical(df[order(df[["v"]]), "i"], c(2L, 1L, 3L))
  }
})
