# Operators and the Math, Complex and Summary groups for the seven value
# classes other than duration(), which has its own (design 6.5).
#
# 0.1.0 has no arithmetic or comparison operators (design 2): each would
# be shorthand for a Temporal operation, and they are for a later
# version. Without these methods base R's would run on the storage and
# keep the class, building values that break design 4.1, or compare the
# storage where temporal_equals() compares the value. So every operator
# is a zutempo_type_error that names the function to use. The Math and
# Complex groups (abs(), round(), cummax(), Re(), ...) are refused for
# the same reason: they would run on the storage and keep the class.
#
# min(), max() and range() are not operators: they take the order sort()
# already uses (xtfrm(), design 4.1), which is the type's compare()
# static. plain_month_day() has no compare() in Temporal, so it has no
# minimum either.

ztp_ops_classes <- c(
  "zutempo_plain_date",
  "zutempo_plain_time",
  "zutempo_plain_date_time",
  "zutempo_plain_year_month",
  "zutempo_plain_month_day",
  "zutempo_instant",
  "zutempo_zoned_date_time"
)

# The constructor name of a value's class, for messages: "plain_date" for
# a plain_date().
ztp_type_name <- function(x) {
  sub("^zutempo_", "", oldClass(x)[1L])
}

ztp_ops <- function(generic, e1, e2) {
  x <- if (inherits(e1, ztp_ops_classes)) e1 else e2
  name <- ztp_type_name(x)
  type <- paste0(name, "()")
  hint <- if (generic %in% c("+", "-")) {
    "use temporal_add() or temporal_subtract()"
  } else if (generic %in% c("==", "!=")) {
    "use temporal_equals()"
  } else if (generic %in% c("<", "<=", ">", ">=")) {
    if (inherits(x, "zutempo_plain_month_day")) {
      "a plain_month_day() has no order; use temporal_equals()"
    } else {
      sprintf("use %s_compare()", name)
    }
  } else {
    NULL
  }
  stop_zutempo(
    paste0(
      sprintf("`%s` is not defined for a %s", generic, type),
      if (!is.null(hint)) paste0("; ", hint)
    ),
    kind = "type"
  )
}

#' @export
Ops.zutempo_plain_date <- function(e1, e2) ztp_ops(.Generic, e1, e2)
#' @export
Ops.zutempo_plain_time <- function(e1, e2) ztp_ops(.Generic, e1, e2)
#' @export
Ops.zutempo_plain_date_time <- function(e1, e2) ztp_ops(.Generic, e1, e2)
#' @export
Ops.zutempo_plain_year_month <- function(e1, e2) ztp_ops(.Generic, e1, e2)
#' @export
Ops.zutempo_plain_month_day <- function(e1, e2) ztp_ops(.Generic, e1, e2)
#' @export
Ops.zutempo_instant <- function(e1, e2) ztp_ops(.Generic, e1, e2)
#' @export
Ops.zutempo_zoned_date_time <- function(e1, e2) ztp_ops(.Generic, e1, e2)

# The Math and Complex groups. round() and its kin name temporal_round()
# where the type has one.
ztp_math <- function(generic, x) {
  type <- paste0(ztp_type_name(x), "()")
  rounds <- inherits(
    x,
    c(
      "zutempo_plain_time",
      "zutempo_plain_date_time",
      "zutempo_instant",
      "zutempo_zoned_date_time"
    )
  )
  hint <- if (
    rounds && generic %in% c("round", "signif", "trunc", "floor", "ceiling")
  ) {
    "use temporal_round()"
  }
  stop_zutempo(
    paste0(
      sprintf("`%s()` is not defined for a %s", generic, type),
      if (!is.null(hint)) paste0("; ", hint)
    ),
    kind = "type"
  )
}

#' @export
Math.zutempo_plain_date <- function(x, ...) ztp_math(.Generic, x)
#' @export
Math.zutempo_plain_time <- function(x, ...) ztp_math(.Generic, x)
#' @export
Math.zutempo_plain_date_time <- function(x, ...) ztp_math(.Generic, x)
#' @export
Math.zutempo_plain_year_month <- function(x, ...) ztp_math(.Generic, x)
#' @export
Math.zutempo_plain_month_day <- function(x, ...) ztp_math(.Generic, x)
#' @export
Math.zutempo_instant <- function(x, ...) ztp_math(.Generic, x)
#' @export
Math.zutempo_zoned_date_time <- function(x, ...) ztp_math(.Generic, x)

#' @export
Complex.zutempo_plain_date <- function(z) ztp_math(.Generic, z)
#' @export
Complex.zutempo_plain_time <- function(z) ztp_math(.Generic, z)
#' @export
Complex.zutempo_plain_date_time <- function(z) ztp_math(.Generic, z)
#' @export
Complex.zutempo_plain_year_month <- function(z) ztp_math(.Generic, z)
#' @export
Complex.zutempo_plain_month_day <- function(z) ztp_math(.Generic, z)
#' @export
Complex.zutempo_instant <- function(z) ztp_math(.Generic, z)
#' @export
Complex.zutempo_zoned_date_time <- function(z) ztp_math(.Generic, z)

# With R 4.3 or later, an operator between a zutempo value and a value of
# another class with its own Ops method (a Date, a duration()) asks
# chooseOpsMethod() which method runs; ours does, so the call is refused
# rather than run on the storage with a warning. Registered in .onLoad.
ztp_choose_ops_method <- function(x, y, mx, my, cl, reverse) TRUE

ztp_summary <- function(generic, args, na.rm) {
  x <- args[[1L]]
  type <- paste0(ztp_type_name(x), "()")
  if (!generic %in% c("min", "max", "range")) {
    stop_zutempo(
      sprintf("`%s()` is not defined for a %s", generic, type),
      kind = "type"
    )
  }
  if (inherits(x, "zutempo_plain_month_day")) {
    stop_zutempo(
      sprintf(
        "`%s()` is not defined for a %s, which has no order",
        generic,
        type
      ),
      kind = "type"
    )
  }
  if (length(args) > 1L) {
    x <- do.call(c, args)
  }
  key <- xtfrm(x)
  na <- is.na(key)
  if (any(na)) {
    if (!na.rm) {
      return(x[rep(NA_integer_, if (generic == "range") 2L else 1L)])
    }
    x <- x[!na]
    key <- key[!na]
  }
  if (!length(x)) {
    stop_zutempo(
      sprintf("`%s()` of a %s with no values", generic, type),
      kind = "range"
    )
  }
  lo <- which.min(key)
  hi <- which.max(key)
  switch(generic, min = x[lo], max = x[hi], range = x[c(lo, hi)])
}

#' @export
Summary.zutempo_plain_date <- function(..., na.rm = FALSE) {
  ztp_summary(.Generic, list(...), na.rm)
}
#' @export
Summary.zutempo_plain_time <- function(..., na.rm = FALSE) {
  ztp_summary(.Generic, list(...), na.rm)
}
#' @export
Summary.zutempo_plain_date_time <- function(..., na.rm = FALSE) {
  ztp_summary(.Generic, list(...), na.rm)
}
#' @export
Summary.zutempo_plain_year_month <- function(..., na.rm = FALSE) {
  ztp_summary(.Generic, list(...), na.rm)
}
#' @export
Summary.zutempo_plain_month_day <- function(..., na.rm = FALSE) {
  ztp_summary(.Generic, list(...), na.rm)
}
#' @export
Summary.zutempo_instant <- function(..., na.rm = FALSE) {
  ztp_summary(.Generic, list(...), na.rm)
}
#' @export
Summary.zutempo_zoned_date_time <- function(..., na.rm = FALSE) {
  ztp_summary(.Generic, list(...), na.rm)
}
