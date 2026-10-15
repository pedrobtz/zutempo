# The test262 cases of tools/test262/extract.mjs (design 11): calls that
# test262's Temporal tests make, with the results its assertions accept, in
# the oracle's format plus three shapes the oracle does not use: `get` (a
# property), `new` (a constructor) and `$bigint` arguments. Each type's
# cases run under one expectation, which names every failing case, to keep
# the expectation count (and gctorture's cost) small.

test262_cases <- function(type) {
  skip_if_not_installed("jsonlite")
  path <- test_path("test262", paste0(type, ".json.gz"))
  skip_if_not(file.exists(path), "the test262 cases are not built")
  con <- gzfile(path, "rt")
  on.exit(close(con))
  doc <- jsonlite::fromJSON(
    paste(readLines(con, warn = FALSE), collapse = "\n"),
    simplifyVector = FALSE
  )
  stopifnot(identical(doc[["type"]], type))
  doc[["cases"]]
}

# Cases where zutempo differs from JavaScript on purpose (design 6.9 and
# 10), by id or by a pattern over ids, with the reason.
test262_differences <- function() {
  utils::read.csv(
    test_path("test262", "differences.csv"),
    stringsAsFactors = FALSE
  )
}

test262_is_difference <- function(ids, differences) {
  hit <- rep(FALSE, length(ids))
  for (pattern in differences[["pattern"]]) {
    hit <- hit | grepl(pattern, ids)
  }
  hit
}

# An argument as R takes it: a BigInt as its decimal string, otherwise as
# the oracle reads arguments.
test262_arg <- function(arg) {
  if (is.list(arg) && !is.null(arg[["$bigint"]])) {
    return(arg[["$bigint"]])
  }
  if (is.list(arg) && !is.null(arg[["$type"]]) && !is.null(arg[["fields"]])) {
    return(do.call(oracle_constructor(arg[["$type"]]), arg[["fields"]]))
  }
  oracle_arg(arg)
}

# ToRelativeTemporalObject for a bag: a zoned date-time when it has a time
# zone, else the date of a date-time (the time fields are read, then
# dropped).
test262_relative_to <- function(bag) {
  bag <- oracle_arg(bag)
  if (!is.null(bag[["calendar"]])) {
    zutempo:::ztp_check_calendar(bag[["calendar"]])
    bag[["calendar"]] <- NULL
  }
  if (!is.null(bag[["time_zone"]])) {
    return(do.call(zoned_date_time, bag))
  }
  bag[["offset_string"]] <- NULL
  time <- c(
    "hour",
    "minute",
    "second",
    "millisecond",
    "microsecond",
    "nanosecond"
  )
  bag <- bag[setdiff(names(bag), time)]
  do.call(plain_date, bag)
}

# A bag's `calendar` is read where JavaScript reads it (from() and the
# values it converts to): ISO 8601 is dropped, as R has only that calendar,
# and anything else raises the error it would.
test262_drop_calendar <- function(bag) {
  if (!is.null(bag[["calendar"]])) {
    zutempo:::ztp_check_calendar(bag[["calendar"]])
    bag[["calendar"]] <- NULL
  }
  bag
}

# A constructor's calendar or zone is an identifier, not an ISO string
# that names one.
test262_identifier <- function(x, what) {
  ok <- is.character(x) &&
    length(x) == 1L &&
    grepl("^([+-][0-9]{2}(:?[0-9]{2})?|[A-Za-z._][A-Za-z0-9._+/-]*)$", x)
  if (!ok) {
    zutempo:::stop_zutempo(sprintf("not a %s identifier", what), kind = "range")
  }
  x
}

test262_days_in_month <- function(year, month) {
  leap <- (year %% 4 == 0 & year %% 100 != 0) | year %% 400 == 0
  c(31, if (leap) 29 else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31)[month]
}

# The option arguments whose invalid values are a zutempo_type_error where
# JavaScript throws a RangeError (design 10).
test262_option_names <- c(
  "rounding_mode",
  "smallest_unit",
  "largest_unit",
  "overflow",
  "disambiguation",
  "offset",
  "fractional_second_digits",
  "calendar_name",
  "time_zone_name",
  "unit",
  "direction",
  "rounding_increment"
)

test262_option_error <- function(error) {
  pattern <- sprintf("^`(%s)` ", paste(test262_option_names, collapse = "|"))
  inherits(error, "zutempo_type_error") &&
    grepl(pattern, conditionMessage(error))
}

# A JavaScript constructor call. Constructors take ISO fields and never
# constrain, so the R constructor runs with overflow = "reject".
test262_new <- function(type, args) {
  a <- function(i, default = NULL) {
    if (length(args) >= i) args[[i]] else default
  }
  calendar <- function(i) {
    if (!is.null(a(i))) {
      if (!is.character(a(i))) {
        zutempo:::stop_zutempo("the calendar must be a string", kind = "type")
      }
      if (tolower(test262_identifier(a(i), "calendar")) != "iso8601") {
        zutempo:::stop_zutempo("only the ISO 8601 calendar", kind = "range")
      }
    }
  }
  switch(
    type,
    Instant = instant_from_epoch_nanoseconds(a(1)),
    ZonedDateTime = {
      calendar(3)
      if (!is.character(a(2))) {
        zutempo:::stop_zutempo("the time zone must be a string", kind = "type")
      }
      temporal_to_zoned_date_time_iso(
        instant_from_epoch_nanoseconds(a(1)),
        test262_identifier(a(2), "time zone")
      )
    },
    PlainDate = {
      calendar(4)
      plain_date(a(1), a(2), a(3), overflow = "reject")
    },
    PlainTime = do.call(plain_time, c(args, list(overflow = "reject"))),
    PlainDateTime = {
      calendar(10)
      do.call(
        plain_date_time,
        c(utils::head(args, 9L), list(overflow = "reject"))
      )
    },
    PlainYearMonth = {
      calendar(3)
      x <- plain_year_month(a(1), a(2), overflow = "reject")
      # The reference day must make a valid ISO date; R keeps none.
      day <- a(4, 1)
      if (
        is.numeric(day) && (day < 1 || day > test262_days_in_month(a(1), a(2)))
      ) {
        zutempo:::stop_zutempo("invalid reference day", kind = "range")
      }
      x
    },
    PlainMonthDay = {
      calendar(3)
      # The reference year must make a valid ISO date; R keeps none.
      year <- a(4, 1972)
      if (is.numeric(a(1)) && is.numeric(a(2)) && is.numeric(year)) {
        if (a(2) < 1 || a(2) > test262_days_in_month(year, a(1))) {
          zutempo:::stop_zutempo("invalid reference year", kind = "range")
        }
        plain_date(year, a(1), a(2), overflow = "reject")
      }
      plain_month_day(a(1), a(2), year = 1972, overflow = "reject")
    },
    Duration = do.call(duration, args)
  )
}

# A bag where R takes a value: a duration for add, subtract and
# Duration.compare(); the receiver's type for since, until, equals and the
# compare() statics.
test262_bag_type <- function(type, op) {
  if (op %in% c("add", "subtract") || (type == "Duration" && op == "compare")) {
    return("Duration")
  }
  if (op %in% c("withPlainTime", "toPlainDateTime")) {
    return("PlainTime")
  }
  if (op %in% c("since", "until", "equals", "compare")) {
    return(type)
  }
  NULL
}

test262_run <- function(type, case) {
  args <- lapply(case[["args"]], test262_arg)
  op <- case[["op"]]
  if (isTRUE(case[["new"]])) {
    return(test262_new(type, args))
  }
  if (isTRUE(case[["get"]])) {
    on <- case[["on"]]
    x <- if (is.list(on)) {
      do.call(oracle_constructor(type), on[["fields"]])
    } else {
      oracle_constructor(type)(on)
    }
    return(oracle_fn(oracle_snake(op))(x))
  }
  relative <- case[["options"]][["relativeTo"]]
  if (is.list(relative) && is.null(relative[["$type"]])) {
    case[["options"]][["relativeTo"]] <- test262_relative_to(relative)
  } else if (is.list(relative)) {
    case[["options"]][["relativeTo"]] <- test262_arg(relative)
  }
  bag_type <- test262_bag_type(type, op)
  if (!is.null(bag_type)) {
    make <- oracle_constructor(bag_type)
    args <- lapply(args, function(a) {
      if (is.list(a) && is.null(oldClass(a))) {
        do.call(make, test262_drop_calendar(a))
      } else {
        a
      }
    })
  }
  # PlainDate.toZonedDateTime({ timeZone, plainTime }) with a bag for the
  # time.
  if (op == "toZonedDateTime" && length(args) && is.list(args[[1L]])) {
    time <- args[[1L]][["plain_time"]]
    if (is.list(time) && is.null(oldClass(time))) {
      args[[1L]][["plain_time"]] <- do.call(
        plain_time,
        test262_drop_calendar(time)
      )
    }
  }
  if (op == "from" && is.null(case[["on"]])) {
    args <- lapply(args, function(a) {
      if (is.list(a) && is.null(oldClass(a))) test262_drop_calendar(a) else a
    })
  }
  case[["args"]] <- NULL
  oracle_run_with(type, case, args)
}

# Run every case of a type; one expectation lists the failures that are
# not documented differences.
test262_run_cases <- function(type) {
  cases <- oracle_gctorture_sample(test262_cases(type))
  differences <- test262_differences()
  ids <- vapply(cases, function(c) c[["id"]], "")
  cases <- cases[!test262_is_difference(ids, differences)]
  failures <- character()
  for (case in cases) {
    problem <- test262_problem(type, case)
    if (!is.null(problem)) {
      failures <- c(failures, sprintf("%s: %s", case[["id"]], problem))
    }
  }
  expect(
    length(failures) == 0L,
    sprintf(
      "%d of %d test262 cases for %s fail:\n%s",
      length(failures),
      length(cases),
      type,
      paste(utils::head(failures, 40L), collapse = "\n")
    )
  )
  invisible(failures)
}

# NULL when the case passes, else what went wrong.
test262_problem <- function(type, case) {
  value <- tryCatch(test262_run(type, case), error = function(e) e)
  expected_throw <- case[["throws"]]
  if (!is.null(expected_throw)) {
    if (!inherits(value, "error")) {
      return(sprintf("expected a %s, got a value", expected_throw))
    }
    # Design 10: an invalid option value is a type error in R.
    if (expected_throw == "RangeError" && test262_option_error(value)) {
      return(NULL)
    }
    # R raises its own error for a missing argument, where JavaScript
    # passes undefined and throws a TypeError.
    if (
      expected_throw == "TypeError" &&
        grepl("is missing, with no default", conditionMessage(value))
    ) {
      return(NULL)
    }
    if (!inherits(value, oracle_error_class(expected_throw))) {
      return(sprintf(
        "expected a %s, got %s: %s",
        expected_throw,
        class(value)[1L],
        conditionMessage(value)
      ))
    }
    return(NULL)
  }
  if (inherits(value, "error")) {
    return(sprintf(
      "unexpected %s: %s",
      class(value)[1L],
      conditionMessage(value)
    ))
  }
  result <- case[["result"]]
  if (is.null(result)) {
    if (length(value) == 1L && is.na(value)) {
      return(NULL)
    }
    return("expected null")
  }
  if (!is.list(result)) {
    same <- if (is.numeric(result)) {
      isTRUE(all.equal(as.numeric(value), result))
    } else {
      identical(value, result)
    }
    if (same) {
      return(NULL)
    }
    return(sprintf(
      "expected %s, got %s",
      format(result),
      paste(format(value), collapse = " ")
    ))
  }
  got <- tryCatch(
    oracle_fn("temporal_to_string")(value),
    error = function(e) conditionMessage(e)
  )
  if (identical(got, result[["string"]])) {
    return(NULL)
  }
  sprintf("expected %s, got %s", result[["string"]], paste(got, collapse = " "))
}
