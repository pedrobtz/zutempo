# Condition classes (design 10).
#
#   zutempo_error                 root of every class below
#     zutempo_range_error         values or results out of range
#       zutempo_parse_error       unparsable strings
#       zutempo_tz_error          unknown zones, missing database
#     zutempo_type_error          wrong classes, invalid option values
#
#   zutempo_warning               root of the warnings
#     zutempo_tz_warning          a system time zone that cannot be read
#
# Every condition raised from a vectorised call carries `index`, the
# 1-based position of the first failing element, or NULL when no element
# applies. A parse error also carries `position`, the 1-based byte of the
# string where it failed (design 10). An error about an option argument
# (an invalid `rounding_mode`, a missing `smallest_unit`) carries `option`,
# the argument's name. The C glue reaches this function through
# ztp_r_raise().

zutempo_condition_classes <- list(
  range = "zutempo_range_error",
  parse = c("zutempo_parse_error", "zutempo_range_error"),
  tz = c("zutempo_tz_error", "zutempo_range_error"),
  type = "zutempo_type_error"
)

stop_zutempo <- function(
  message,
  kind = "range",
  index = NULL,
  call = NULL,
  position = NULL,
  option = NULL
) {
  classes <- zutempo_condition_classes[[kind]]
  if (is.null(classes)) {
    stop("unknown condition kind: ", kind)
  }
  if (!is.null(index) && (length(index) != 1L || is.na(index) || index < 1)) {
    index <- NULL
  }
  if (!is.null(index)) {
    index <- as.numeric(index)
    message <- sprintf(
      "%s (element %s)",
      message,
      format(index, scientific = FALSE)
    )
  }
  if (
    !is.null(position) &&
      (length(position) != 1L || is.na(position) || position < 1)
  ) {
    position <- NULL
  }
  fields <- list(message = message, call = call, index = index)
  if (!is.null(position)) {
    fields[["position"]] <- as.numeric(position)
  }
  if (!is.null(option)) {
    fields[["option"]] <- as.character(option)
  }
  cond <- structure(
    class = c(classes, "zutempo_error", "error", "condition"),
    fields
  )
  stop(cond)
}

zutempo_warning_classes <- list(
  tz = "zutempo_tz_warning"
)

warn_zutempo <- function(message, kind = "tz", call = NULL) {
  classes <- zutempo_warning_classes[[kind]]
  if (is.null(classes)) {
    stop("unknown condition kind: ", kind)
  }
  cond <- structure(
    class = c(classes, "zutempo_warning", "warning", "condition"),
    list(message = message, call = call)
  )
  warning(cond)
}
