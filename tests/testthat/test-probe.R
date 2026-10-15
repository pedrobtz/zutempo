test_that("the probe reaches zufast's calendar algorithms", {
  civil <- ztp_probe_civil(c(0, -1, 20513, -719528))
  expect_identical(civil$year, c(1970L, 1969L, 2026L, 0L))
  expect_identical(civil$month, c(1L, 12L, 3L, 1L))
  expect_identical(civil$day, c(1L, 31L, 1L, 1L))
})

test_that("the probe propagates NA and names the failing element", {
  civil <- ztp_probe_civil(c(1, NA, 2))
  expect_identical(civil$year, c(1970L, NA, 1970L))
  cond <- tryCatch(
    ztp_probe_civil(c(1, 2, 0.5)),
    error = identity
  )
  expect_s3_class(cond, "zutempo_range_error")
  expect_identical(cond$index, 3)
  expect_error(ztp_probe_civil(2^40), class = "zutempo_range_error")
})

test_that("the probe reaches zufast's 128-bit arithmetic exactly", {
  expect_identical(ztp_probe_mul(6, 7), "42")
  expect_identical(ztp_probe_mul(-6, 7), "-42")
  # 2^53 * 10^9 does not fit an int64_t, nor a double exactly.
  expect_identical(ztp_probe_mul(2^53, 1e9), "9007199254740992000000000")
  # The largest product: (-2^63)^2 = 2^126.
  expect_identical(
    ztp_probe_mul(-2^63, -2^63),
    "85070591730234615865843651857942052864"
  )
  expect_identical(ztp_probe_mul(c(2, NA), c(3, 4)), c("6", NA))
  expect_error(ztp_probe_mul(1.5, 2), class = "zutempo_range_error")
  expect_error(ztp_probe_mul(1:2, 1), class = "zutempo_type_error")
})
