# Operators and the Summary group for the seven value classes other than
# duration(), which has its own (design 6.5).
#
# 0.1.0 has no arithmetic or comparison operators (design 2): each would
# be shorthand for a Temporal operation, and they are for a later
# version. Without these methods base R's would run on the storage and
# keep the class, building values that break design 4.1, or compare the
# storage where temporal_equals() compares the value. So every operator
# is a zutempo_type_error that names the function to use.
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

# The constructor name of a value's class, for messages.
ztp_type_name <- function(x) {
  cls <- oldClass(x)[1L]
  paste0(sub("^zutempo_", "", cls), "()")
}

ztp_ops <- function(generic, e1, e2) {
  x <- if (inherits(e1, ztp_ops_classes)) e1 else e2
  type <- ztp_type_name(x)
  hint <- if (generic %in% c("+", "-")) {
    "use temporal_add() or temporal_subtract()"
  } else if (generic %in% c("==", "!=")) {
    "use temporal_equals()"
  } else if (generic %in% c("<", "<=", ">", ">=")) {
    if (inherits(x, "zutempo_plain_month_day")) {
      "a plain_month_day() has no order; use temporal_equals()"
    } else {
      sprintf("use %s_compare()", sub("\\(\\)$", "", type))
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

# With R 4.3 or later, an operator between a zutempo value and a value of
# another class with its own Ops method (a Date, a duration()) asks
# chooseOpsMethod() which method runs; ours does, so the call is refused
# rather than run on the storage with a warning. Registered in .onLoad.
ztp_choose_ops_method <- function(x, y, mx, my, cl, reverse) TRUE

ztp_summary <- function(generic, args, na.rm) {
  x <- args[[1L]]
  type <- ztp_type_name(x)
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
  missing <- is.na(key)
  if (any(missing)) {
    if (!na.rm) {
      return(x[rep(NA_integer_, if (generic == "range") 2L else 1L)])
    }
    x <- x[!missing]
    key <- key[!missing]
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
