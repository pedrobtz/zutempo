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
  position <- check[["position"]][bad]
  grammar <- list(
    index = as.numeric(bad),
    position = position,
    # The class of a failure the grammar finds is the one the constructor
    # would raise: a calendar other than ISO 8601 is a range error, not a
    # parse error.
    class = c(
      "zutempo_parse_error",
      "zutempo_range_error"
    )[is.na(position) + 1L],
    message = check[["message"]][bad]
  )
  x[bad] <- NA_character_
  zones <- if (type == "zoned_date_time") ztp_parse_zones(x) else NULL
  if (!is.null(zones)) {
    x[zones[["index"]]] <- NA_character_
  }
  values <- ztp_parse_values(x, constructor, ...)
  x[values[["index"]]] <- NA_character_
  # Every failure is NA now, so this pass succeeds.
  result <- constructor(x, ...)
  parts <- list(grammar, zones, values)
  column <- function(f, empty) c(empty, unlist(lapply(parts, `[[`, f)))
  errors <- data.frame(
    index = column("index", double()),
    position = column("position", double()),
    class = column("class", character()),
    message = ztp_strip_element(column("message", character())),
    stringsAsFactors = FALSE
  )
  errors <- errors[order(errors[["index"]]), , drop = FALSE]
  rownames(errors) <- NULL
  attr(result, "parse_errors") <- errors
  result
}

# The zone of each zoned string, resolved once per distinct identifier:
# one misspelt zone fails every element that names it. The grammar has
# passed, so ztp_r_zoned_parse() does not fail. NULL when every zone is
# known.
ztp_parse_zones <- function(x) {
  ids <- .Call(C_ztp_r_zoned_parse, x)[["tz"]]
  groups <- split(seq_along(ids), factor(ids, levels = unique(ids)))
  failed <- lapply(names(groups), function(id) {
    hit <- groups[[id]]
    tryCatch(
      {
        ztp_tz_ensure(id, index = hit[1L])
        NULL
      },
      zutempo_error = function(e) {
        list(
          index = as.numeric(hit),
          position = rep(NA_real_, length(hit)),
          class = rep(class(e)[1L], length(hit)),
          message = rep(conditionMessage(e), length(hit))
        )
      }
    )
  })
  failed <- failed[!vapply(failed, is.null, TRUE)]
  if (!length(failed)) {
    return(NULL)
  }
  lapply(
    c(
      index = "index",
      position = "position",
      class = "class",
      message = "message"
    ),
    function(f) unlist(lapply(failed, `[[`, f))
  )
}

# The failures the constructor reports for strings that follow the
# grammar: a value out of range, an offset that does not match its zone.
# The constructor stops at the first, so x is read in chunks: a failure
# becomes NA and its chunk is read again, and the chunk grows after a
# success and shrinks after a failure. A chunk is then about as long as
# the gap between failures, which makes the cost linear in length(x) and
# in the number of failures.
ztp_parse_values <- function(x, constructor, ...) {
  n <- length(x)
  index <- double()
  position <- double()
  class <- character()
  message <- character()
  start <- 1L
  size <- 64L
  while (start <= n) {
    end <- min(n, start + size - 1L)
    chunk <- x[start:end]
    e <- tryCatch(
      {
        constructor(chunk, ...)
        NULL
      },
      zutempo_error = function(e) e
    )
    if (is.null(e)) {
      start <- end + 1L
      size <- min(2L * size, n)
      next
    }
    i <- e[["index"]]
    if (is.null(i) || i > length(chunk) || is.na(chunk[i])) {
      stop(e)
    }
    k <- length(index) + 1L
    index[k] <- start + i - 1
    position[k] <- if (is.null(e[["position"]])) NA_real_ else e[["position"]]
    class[k] <- class(e)[1L]
    message[k] <- conditionMessage(e)
    x[start + i - 1L] <- NA_character_
    size <- max(16L, size %/% 2L)
  }
  list(index = index, position = position, class = class, message = message)
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
