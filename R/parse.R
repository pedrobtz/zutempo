# zutempo_parse(): the bulk-reading escape of the string constructors
# (design 6.8).

# The parse goal of each type (src/ztp_parse.h; -1 is a duration string).
ztp_parse_goals <- c(
  plain_date = 0L,
  plain_time = 1L,
  plain_date_time = 0L,
  plain_year_month = 2L,
  plain_month_day = 3L,
  instant = 4L,
  zoned_date_time = 5L,
  duration = -1L
)

#' Read strings as a Temporal type, with `NA` for those that fail
#'
#' The bulk-reading escape of the string constructors. A
#' constructor such as `plain_date()` stops at the first string it cannot
#' read; `zutempo_parse()` reads the rest and returns `NA` for each string
#' that fails, with the reasons in an attribute.
#'
#' A string fails when it does not follow the type's ISO 8601 / RFC 9557
#' grammar, or when it does but names a value the type cannot hold: a date
#' out of range, an unknown time zone, an offset that does not match its
#' zone. Both kinds become `NA`.
#'
#' @param x A character vector.
#' @param type The type to read, as the name of its constructor:
#'   `"plain_date"`, `"plain_time"`, `"plain_date_time"`,
#'   `"plain_year_month"`, `"plain_month_day"`, `"instant"`,
#'   `"zoned_date_time"` or `"duration"`.
#' @param ... Options for the constructor, such as `disambiguation` and
#'   `offset` for `"zoned_date_time"`.
#' @param na_on_error `TRUE` (the default) returns `NA` for a string that
#'   cannot be read. `FALSE` raises the constructor's error for the first
#'   one, as calling the constructor does.
#' @return A vector of the class `type` names, as long as `x`. With
#'   `na_on_error = TRUE` it has the attribute `"parse_errors"`: a data
#'   frame with one row per failed string, giving its `index` in `x`, the
#'   1-based byte `position` where reading stopped (`NA` when the string was
#'   read but its value was rejected), the condition `class` and the
#'   `message`.
#' @seealso [zutempo_parse_errors()] to read the attribute.
#' @examples
#' x <- c("2026-03-07", "2026-13-01", NA, "2026-02-30")
#' d <- zutempo_parse(x, "plain_date")
#' d
#' zutempo_parse_errors(d)
#' try(zutempo_parse(x, "plain_date", na_on_error = FALSE))
#' @export
zutempo_parse <- function(x, type, ..., na_on_error = TRUE) {
  if (!is.character(x)) {
    stop_zutempo("`x` must be a character vector", kind = "type")
  }
  type <- names(ztp_parse_goals)[ztp_match_option(
    type,
    names(ztp_parse_goals),
    "type"
  )]
  if (!isTRUE(na_on_error) && !isFALSE(na_on_error)) {
    stop_zutempo("`na_on_error` must be TRUE or FALSE", kind = "type")
  }
  constructor <- get(type, envir = asNamespace("zutempo"), mode = "function")
  if (!na_on_error) {
    return(constructor(x, ...))
  }
  # The grammar in one pass over the vector.
  check <- .Call(C_ztp_r_parse_check, x, ztp_parse_goals[[type]])
  bad <- which(!is.na(check[["message"]]))
  errors <- data.frame(
    index = as.numeric(bad),
    position = check[["position"]][bad],
    class = rep("zutempo_parse_error", length(bad)),
    message = check[["message"]][bad],
    stringsAsFactors = FALSE
  )
  # The class of a failure the grammar finds is the one the constructor
  # would raise: a calendar other than ISO 8601 is a range error, not a
  # parse error.
  errors[["class"]][is.na(errors[["position"]])] <- "zutempo_range_error"
  x[bad] <- NA_character_
  # Then the values: each failure the constructor reports becomes NA and
  # the rest is read again. This costs one pass per such failure, which
  # is rare next to grammar failures.
  repeat {
    result <- tryCatch(constructor(x, ...), zutempo_error = function(e) e)
    if (!inherits(result, "zutempo_error")) {
      break
    }
    i <- result[["index"]]
    if (is.null(i) || is.na(x[i])) {
      stop(result)
    }
    position <- result[["position"]]
    errors[nrow(errors) + 1L, ] <- list(
      i,
      if (is.null(position)) NA_real_ else position,
      class(result)[1L],
      ztp_strip_element(conditionMessage(result))
    )
    x[i] <- NA_character_
  }
  errors[["message"]] <- ztp_strip_element(errors[["message"]])
  errors <- errors[order(errors[["index"]]), , drop = FALSE]
  rownames(errors) <- NULL
  attr(result, "parse_errors") <- errors
  result
}

#' The strings `zutempo_parse()` could not read
#'
#' @param x The result of [zutempo_parse()].
#' @return The data frame of its `"parse_errors"` attribute: `index`,
#'   `position`, `class` and `message` of each failed string. It has no
#'   rows when every string was read, and is `NULL` for a value that
#'   `zutempo_parse()` did not return.
#' @examples
#' zutempo_parse_errors(zutempo_parse(c("12:30", "25:00"), "plain_time"))
#' @export
zutempo_parse_errors <- function(x) {
  attr(x, "parse_errors", exact = TRUE)
}

# A condition message without the "(element i)" that stop_zutempo() adds:
# the index has a column of its own.
ztp_strip_element <- function(message) {
  sub(" \\(element [0-9.e+]+\\)$", "", message)
}
