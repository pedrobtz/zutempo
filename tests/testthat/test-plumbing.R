plain_values <- function() {
  list(
    plain_date(c("2026-01-31", "2026-02-01", NA)),
    plain_time(c("12:30", "00:00:00.000000001", NA)),
    plain_date_time(c("2026-01-31T12:30", "2026-02-01", NA))
  )
}

test_that("subsetting, combining and repeating keep the class", {
  for (x in plain_values()) {
    cls <- class(x)
    expect_identical(class(x[1:2]), cls)
    expect_identical(class(x[[2]]), cls)
    expect_identical(class(c(x[1], x[2])), cls)
    expect_identical(c(x[1], x[2]), x[1:2])
    expect_identical(class(rep(x[1], 3)), cls)
    expect_identical(class(rev(x)), cls)
    expect_identical(rev(rev(x)), x)
    expect_identical(class(unique(c(x, x))), cls)
    expect_identical(unique(c(x, x)), x)
    expect_identical(is.na(x), c(FALSE, FALSE, TRUE))
    expect_identical(length(x[0]), 0L)
    expect_identical(class(x[0]), cls)
    y <- x
    y[3] <- x[1]
    expect_identical(y[3], x[1])
    y[[2]] <- x[1]
    expect_identical(y[2], x[1])
    y[1] <- NA
    expect_true(is.na(y[1]))
    length(y) <- 5
    expect_identical(class(y), cls)
    expect_true(is.na(y[5]))
    expect_error(y[1] <- 5, class = "zutempo_type_error")
    expect_error(c(x, 1), class = "zutempo_type_error")
  }
  expect_error(
    c(plain_date("2026-01-31"), plain_time("12:00")),
    class = "zutempo_type_error"
  )
})

test_that("sorting is chronological", {
  d <- plain_date(c("2026-02-01", "2026-01-31", NA, "1900-01-01"))
  expect_identical(
    sort(d),
    plain_date(c("1900-01-01", "2026-01-31", "2026-02-01"))
  )
  expect_identical(order(d), c(4L, 2L, 1L, 3L))
  t <- plain_time(c("12:30", "00:00:00.000000001", "23:59"))
  expect_identical(sort(t, decreasing = TRUE), t[c(3, 1, 2)])
})

test_that("printing, format and as.character agree", {
  x <- plain_date(c("2026-01-31", NA))
  expect_identical(format(x), c("2026-01-31", NA))
  expect_identical(as.character(x), format(x))
  out <- capture.output(print(x))
  expect_match(out[1], "<zutempo_plain_date\\[2\\]>", fixed = FALSE)
  expect_match(out[2], "2026-01-31", fixed = TRUE)
  expect_identical(
    capture.output(print(plain_time()[0])),
    "<zutempo_plain_time[0]>"
  )
})

test_that("data frames hold each class and survive rbind and saveRDS", {
  d <- plain_date(c("2026-01-31", NA))
  t <- plain_time(c("12:30", "00:00"))
  dt <- plain_date_time(c("2026-01-31T12:30", NA))
  df <- data.frame(d = d, t = t, dt = dt)
  expect_identical(df$d, d)
  expect_identical(df$dt, dt)
  both <- rbind(df, df)
  expect_identical(both$d, c(d, d))
  expect_identical(both$dt, c(dt, dt))
  out <- capture.output(print(df))
  expect_match(out[2], "2026-01-31 12:30:00 2026-01-31T12:30:00", fixed = TRUE)
  path <- withr::local_tempfile(fileext = ".rds")
  saveRDS(df, path)
  expect_identical(readRDS(path), df)
})

test_that("vctrs slices, combines and casts the classes", {
  skip_if_not_installed("vctrs")
  d <- plain_date(c("2026-01-31", "2026-02-01", NA))
  expect_identical(vctrs::vec_slice(d, 2:3), d[2:3])
  expect_identical(vctrs::vec_c(d[1], d[2]), d[1:2])
  expect_identical(vctrs::vec_ptype_abbr(d), "pl_date")
  dt <- plain_date_time(c("2026-01-31T12:30", NA))
  expect_identical(vctrs::vec_slice(dt, 1), dt[1])
  expect_identical(
    vctrs::vec_rbind(data.frame(x = dt), data.frame(x = dt))$x,
    c(dt, dt)
  )
  expect_identical(vctrs::vec_cast(d, d), d)
  expect_error(
    vctrs::vec_c(d, plain_time("12:00")),
    class = "vctrs_error_incompatible_type"
  )
})

test_that("pillar prints the classes in a tibble-like column", {
  skip_if_not_installed("pillar")
  x <- plain_date_time(c("2026-01-31T12:30", NA))
  shaft <- pillar::pillar_shaft(x)
  expect_s3_class(shaft, "pillar_shaft")
  out <- format(shaft, width = 30)
  expect_match(as.character(out)[1], "2026-01-31T12:30:00", fixed = TRUE)
  expect_identical(pillar::type_sum(plain_time()), "pl_time")
})

test_that("accessors fall back to the function they mask", {
  skip_if_not_installed("withr")
  env <- new.env()
  env$year <- function(x, ...) "masked year"
  withr::local_options(list())
  withr::defer(detach("local:zutempo_test"), envir = parent.frame())
  attach(env, name = "local:zutempo_test", warn.conflicts = FALSE)
  # Call the generic by its namespace: the attached environment sits in
  # front of the package on the search path.
  expect_identical(zutempo::year(structure(1, class = "other")), "masked year")
  expect_identical(zutempo::year(plain_date("2026-01-31")), 2026L)
})

test_that("an accessor with nothing to fall back to is a type error", {
  expect_error(
    nanosecond(structure(1, class = "zutempo_nothing")),
    class = "zutempo_type_error"
  )
})
