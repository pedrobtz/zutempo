# The boundary between R and C: values that no constructor makes, and
# arguments that bypass the R layer, are type errors rather than crashes
# or silently wrong results.

test_that("a zoned value with corrupt zone codes is a type error", {
  z <- zoned_date_time("2024-01-01T00:00[UTC]")
  out_of_range <- z
  attr(out_of_range, "zone") <- 5000000L
  expect_error(year(out_of_range), class = "zutempo_type_error")
  expect_error(format(out_of_range), class = "zutempo_type_error")
  expect_error(time_zone_id(out_of_range), class = "zutempo_type_error")
  zero <- z
  attr(zero, "zone") <- 0L
  expect_error(format(zero), class = "zutempo_type_error")
  long <- z
  attr(long, "zone") <- c(1L, 1L)
  expect_error(format(long), class = "zutempo_type_error")
  short <- rep(z, 4L)
  attr(short, "zone") <- c(1L, 1L)
  expect_error(format(short), class = "zutempo_type_error")
  missing <- z
  attr(missing, "zone") <- NULL
  expect_error(format(missing), class = "zutempo_type_error")
  double <- z
  attr(double, "zone") <- 1
  expect_error(format(double), class = "zutempo_type_error")
  no_table <- z
  attr(no_table, "zones") <- 1L
  expect_error(format(no_table), class = "zutempo_type_error")
  # The C glue checks the codes as well as the R side.
  expect_error(
    .Call(zutempo:::C_ztp_r_zoned_offset, unclass(z)[1], 2L, "UTC"),
    class = "zutempo_type_error"
  )
  expect_error(
    .Call(zutempo:::C_ztp_r_zoned_offset, rep(unclass(z)[1], 2), 1L, "UTC"),
    class = "zutempo_type_error"
  )
  expect_error(
    .Call(zutempo:::C_ztp_r_zoned_offset, unclass(z)[1], 1L, NA_character_),
    class = "zutempo_type_error"
  )
})

test_that("an instant with a non-integral part is a type error", {
  half <- structure(
    complex(real = 0.5, imaginary = 0),
    class = "zutempo_instant"
  )
  expect_error(format(half), class = "zutempo_type_error")
  expect_error(epoch_nanoseconds(half), class = "zutempo_type_error")
  frac <- structure(
    complex(real = 0, imaginary = 0.5),
    class = "zutempo_instant"
  )
  expect_error(format(frac), class = "zutempo_type_error")
  huge <- structure(
    complex(real = 1e300, imaginary = 0),
    class = "zutempo_instant"
  )
  expect_error(format(huge), class = "zutempo_type_error")
  big_ns <- structure(
    complex(real = 0, imaginary = 2e9),
    class = "zutempo_instant"
  )
  expect_error(format(big_ns), class = "zutempo_type_error")
  z <- zoned_date_time("2024-01-01T00:00[UTC]")
  bad <- unclass(z)
  bad[1] <- complex(real = 0.5, imaginary = 0)
  attributes(bad) <- attributes(z)
  expect_error(format(bad), class = "zutempo_type_error")
})

test_that("a duration with a corrupt field is a type error", {
  fields <- unclass(duration(hours = 1))
  fractional <- fields
  fractional$hours <- 0.5
  expect_error(
    format(structure(fractional, class = "zutempo_duration")),
    class = "zutempo_type_error"
  )
  mixed <- fields
  mixed$minutes <- -1
  expect_error(
    format(structure(mixed, class = "zutempo_duration")),
    class = "zutempo_type_error"
  )
  huge <- fields
  huge$seconds <- 1e300
  expect_error(
    temporal_add(
      instant("2024-01-01T00:00:00Z"),
      structure(huge, class = "zutempo_duration")
    ),
    class = "zutempo_type_error"
  )
})

test_that("assigning a field of a duration with $<- is a type error", {
  d <- duration(days = 1:3)
  expect_error(d$hours <- 5, class = "zutempo_type_error")
  expect_identical(format(d), c("P1D", "P2D", "P3D"))
})

test_that("the glue checks that a duration's ten fields are doubles of one length", {
  fields <- unclass(duration(days = 1:3))
  short <- fields
  short$hours <- 5
  expect_error(
    format(structure(short, class = "zutempo_duration")),
    class = "zutempo_type_error"
  )
  integer_field <- fields
  integer_field$hours <- 1:3
  expect_error(
    format(structure(integer_field, class = "zutempo_duration")),
    class = "zutempo_type_error"
  )
  nine <- fields[-10]
  expect_error(
    .Call(zutempo:::C_ztp_r_duration_format, nine, -1L, 1, 9L, 0L),
    class = "zutempo_type_error"
  )
  expect_error(
    .Call(zutempo:::C_ztp_r_duration_format, 1, -1L, 1, 9L, 0L),
    class = "zutempo_type_error"
  )
})

test_that("condition messages are UTF-8 and never cut a character", {
  e <- tryCatch(
    plain_date(paste0(strrep("a", 35), "ééééé")),
    error = identity
  )
  expect_s3_class(e, "zutempo_parse_error")
  expect_true(validUTF8(conditionMessage(e)))
  expect_identical(Encoding(conditionMessage(e)), "UTF-8")
  expect_match(conditionMessage(e), "é...", fixed = TRUE)
  e <- tryCatch(plain_date("é"), error = identity)
  expect_identical(Encoding(conditionMessage(e)), "UTF-8")
  expect_match(conditionMessage(e), "\"é\"", fixed = TRUE)
  e <- tryCatch(
    duration(paste0("P", strrep("1", 35), "éééé")),
    error = identity
  )
  expect_true(validUTF8(conditionMessage(e)))
  e <- tryCatch(
    instant_from_epoch_nanoseconds(strrep("é", 200)),
    error = identity
  )
  expect_s3_class(e, "zutempo_range_error")
  expect_true(validUTF8(conditionMessage(e)))
  expect_identical(Encoding(conditionMessage(e)), "UTF-8")
})

test_that("plain values outside their type's range are type errors", {
  expect_error(
    format(structure(1e30, class = "zutempo_plain_time")),
    class = "zutempo_type_error"
  )
  expect_error(
    hour(structure(-1, class = "zutempo_plain_time")),
    class = "zutempo_type_error"
  )
  expect_error(
    format(structure(0.5, class = "zutempo_plain_time")),
    class = "zutempo_type_error"
  )
  expect_error(
    format(structure(99999L, class = "zutempo_plain_month_day")),
    class = "zutempo_type_error"
  )
  expect_error(
    format(structure(2L * 32L + 30L, class = "zutempo_plain_month_day")),
    class = "zutempo_type_error"
  )
  expect_error(
    format(structure(.Machine$integer.max, class = "zutempo_plain_date")),
    class = "zutempo_type_error"
  )
  expect_error(
    format(structure(.Machine$integer.max, class = "zutempo_plain_year_month")),
    class = "zutempo_type_error"
  )
  expect_error(
    format(structure(
      complex(real = 0, imaginary = -1),
      class = "zutempo_plain_date_time"
    )),
    class = "zutempo_type_error"
  )
  expect_error(
    format(structure(
      complex(real = 1e12, imaginary = 0),
      class = "zutempo_plain_date_time"
    )),
    class = "zutempo_type_error"
  )
  # The values at the ends of each range still work.
  expect_identical(format(plain_date("+275760-09-13")), "+275760-09-13")
  expect_identical(
    format(plain_time("23:59:59.999999999")),
    "23:59:59.999999999"
  )
  expect_identical(format(plain_month_day("02-29")), "02-29")
  expect_identical(format(plain_year_month("-271821-04")), "-271821-04")
})

test_that("the glue checks the type and length of each argument", {
  d <- unclass(duration(days = 1))
  expect_error(
    .Call(zutempo:::C_ztp_r_plain_date_add, 1:3, d, 0L),
    class = "zutempo_type_error"
  )
  expect_error(
    .Call(zutempo:::C_ztp_r_plain_date_format, c(1, 2), 0L),
    class = "zutempo_type_error"
  )
  expect_error(
    .Call(zutempo:::C_ztp_r_plain_date_until, 1:3, 1:2, 3L, 3L, 1, 0L),
    class = "zutempo_type_error"
  )
  expect_error(
    .Call(zutempo:::C_ztp_r_plain_time_from_fields, 1, 1, 1, 1, 1, 1:2, 0L),
    class = "zutempo_type_error"
  )
  expect_error(
    .Call(zutempo:::C_ztp_r_plain_date_parse, 1),
    class = "zutempo_type_error"
  )
  expect_error(
    .Call(zutempo:::C_ztp_r_instant_format, 1, NULL, -1L),
    class = "zutempo_type_error"
  )
  expect_error(
    .Call(
      zutempo:::C_ztp_r_zoned_interpret,
      c(0, 0),
      0,
      1L,
      "UTC",
      0L,
      NA_real_,
      0L,
      0L,
      TRUE
    ),
    class = "zutempo_type_error"
  )
  expect_error(
    .Call(zutempo:::C_ztp_r_tz_utoff, "UTC", 1L),
    class = "zutempo_type_error"
  )
})

test_that("loading the package again does not pile up hooks", {
  count <- function() {
    length(getHook(packageEvent("vctrs", "onLoad"))) +
      length(getHook(packageEvent("pillar", "onLoad")))
  }
  zutempo:::.onLoad(NULL, "zutempo")
  before <- count()
  zutempo:::.onLoad(NULL, "zutempo")
  zutempo:::.onLoad(NULL, "zutempo")
  expect_identical(count(), before)
})
