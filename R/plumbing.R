# The vector plumbing shared by every zutempo class (design 4.1): values
# are plain R vectors with a class attribute, so the methods here keep
# that class through subsetting, combination and printing.

ztp_plain_classes <- c(
  "zutempo_plain_date",
  "zutempo_plain_time",
  "zutempo_plain_date_time",
  "zutempo_plain_year_month",
  "zutempo_plain_month_day"
)

new_plain_date <- function(days = integer()) {
  structure(days, class = "zutempo_plain_date")
}

new_plain_time <- function(ns = double()) {
  structure(ns, class = "zutempo_plain_time")
}

new_plain_date_time <- function(z = complex()) {
  z[is.na(z)] <- NA_complex_
  structure(z, class = "zutempo_plain_date_time")
}

new_plain_year_month <- function(months = integer()) {
  structure(months, class = "zutempo_plain_year_month")
}

new_plain_month_day <- function(codes = integer()) {
  structure(codes, class = "zutempo_plain_month_day")
}

# A missing complex value is NA in both parts: R's coercion of a bare NA
# leaves the imaginary part 0, which would make two missing date-times
# differ.
ztp_restore <- function(data, template) {
  if (is.complex(data)) {
    data[is.na(data)] <- NA_complex_
  }
  class(data) <- oldClass(template)
  data
}

ztp_is_plain <- function(x) {
  inherits(x, ztp_plain_classes)
}

ztp_check_same_class <- function(x, value, what) {
  if (!identical(oldClass(value), oldClass(x))) {
    stop_zutempo(
      sprintf(
        "%s must be a %s, not a %s",
        what,
        oldClass(x)[1L],
        paste(class(value), collapse = "/")
      ),
      kind = "type"
    )
  }
}

# Recycling by R's rule restricted to length 1 or a common length; a
# zero-length argument gives a zero-length result.
ztp_recycle <- function(args) {
  lens <- lengths(args)
  n <- if (length(lens) && any(lens == 0L)) 0L else max(lens, 0L)
  bad <- lens != 1L & lens != n
  if (any(bad)) {
    stop_zutempo(
      sprintf(
        "arguments cannot be recycled to a common length (lengths %s)",
        paste(lens, collapse = ", ")
      ),
      kind = "type"
    )
  }
  lapply(args, function(a) if (length(a) == n) a else rep_len(a, n))
}

ztp_check_dots_empty <- function(...) {
  if (...length() > 0L) {
    nms <- ...names()
    what <- if (is.null(nms)) {
      "unnamed arguments"
    } else {
      paste0("`", nms[nzchar(nms)], "`", collapse = ", ")
    }
    stop_zutempo(paste("unused arguments:", what), kind = "type")
  }
}

# A field argument: numeric, or a logical vector of NAs (R's bare NA).
ztp_is_field_like <- function(x) {
  !ztp_is_plain(x) && (is.numeric(x) || (is.logical(x) && all(is.na(x))))
}

ztp_as_field <- function(x, name) {
  if (is.null(x)) {
    return(NULL)
  }
  if (!ztp_is_field_like(x)) {
    stop_zutempo(
      sprintf("`%s` must be numeric, not %s", name, class(x)[1L]),
      kind = "type"
    )
  }
  as.double(x)
}

# --- subsetting and combination ------------------------------------------

ztp_subset <- function(x, i) {
  ztp_restore(unclass(x)[i], x)
}

ztp_subset2 <- function(x, i) {
  ztp_restore(unclass(x)[[i]], x)
}

ztp_assign <- function(x, i, value) {
  if (is.null(value)) {
    stop_zutempo("cannot assign NULL", kind = "type")
  }
  if (!all(is.na(value)) || ztp_is_plain(value)) {
    ztp_check_same_class(x, value, "the replacement value")
  }
  data <- unclass(x)
  data[i] <- unclass(value)
  ztp_restore(data, x)
}

# NULL arguments drop out and a bare NA (a logical of NAs) joins as a
# missing value, as c() on a Date allows; anything else must share the
# class.
ztp_combine <- function(x, dots) {
  dots <- dots[!vapply(dots, is.null, logical(1L))]
  for (d in dots) {
    if (is.logical(d) && all(is.na(d))) {
      next
    }
    ztp_check_same_class(x, d, "every argument of c()")
  }
  ztp_restore(do.call(c, lapply(dots, unclass)), x)
}

#' @export
`[.zutempo_plain_date` <- function(x, i, ...) ztp_subset(x, i)
#' @export
`[.zutempo_plain_time` <- function(x, i, ...) ztp_subset(x, i)
#' @export
`[.zutempo_plain_date_time` <- function(x, i, ...) ztp_subset(x, i)

#' @export
`[[.zutempo_plain_date` <- function(x, i, ...) ztp_subset2(x, i)
#' @export
`[[.zutempo_plain_time` <- function(x, i, ...) ztp_subset2(x, i)
#' @export
`[[.zutempo_plain_date_time` <- function(x, i, ...) ztp_subset2(x, i)

#' @export
`[<-.zutempo_plain_date` <- function(x, i, value) ztp_assign(x, i, value)
#' @export
`[<-.zutempo_plain_time` <- function(x, i, value) ztp_assign(x, i, value)
#' @export
`[<-.zutempo_plain_date_time` <- function(x, i, value) ztp_assign(x, i, value)

#' @export
`[[<-.zutempo_plain_date` <- function(x, i, value) ztp_assign(x, i, value)
#' @export
`[[<-.zutempo_plain_time` <- function(x, i, value) ztp_assign(x, i, value)
#' @export
`[[<-.zutempo_plain_date_time` <- function(x, i, value) ztp_assign(x, i, value)

#' @export
c.zutempo_plain_date <- function(...) ztp_combine(..1, list(...))
#' @export
c.zutempo_plain_time <- function(...) ztp_combine(..1, list(...))
#' @export
c.zutempo_plain_date_time <- function(...) ztp_combine(..1, list(...))

#' @export
rep.zutempo_plain_date <- function(x, ...) ztp_restore(rep(unclass(x), ...), x)
#' @export
rep.zutempo_plain_time <- function(x, ...) ztp_restore(rep(unclass(x), ...), x)
#' @export
rep.zutempo_plain_date_time <- function(x, ...) {
  ztp_restore(rep(unclass(x), ...), x)
}

#' @export
unique.zutempo_plain_date <- function(x, ...) {
  ztp_restore(unique(unclass(x), ...), x)
}
#' @export
unique.zutempo_plain_time <- function(x, ...) {
  ztp_restore(unique(unclass(x), ...), x)
}
#' @export
unique.zutempo_plain_date_time <- function(x, ...) {
  ztp_restore(unique(unclass(x), ...), x)
}

#' @export
`length<-.zutempo_plain_date` <- function(x, value) {
  ztp_restore(`length<-`(unclass(x), value), x)
}
#' @export
`length<-.zutempo_plain_time` <- function(x, value) {
  ztp_restore(`length<-`(unclass(x), value), x)
}
#' @export
`length<-.zutempo_plain_date_time` <- function(x, value) {
  ztp_restore(`length<-`(unclass(x), value), x)
}

#' @export
as.data.frame.zutempo_plain_date <- function(x, ...) {
  as.data.frame.vector(x, ...)
}
#' @export
as.data.frame.zutempo_plain_time <- function(x, ...) {
  as.data.frame.vector(x, ...)
}
#' @export
as.data.frame.zutempo_plain_date_time <- function(x, ...) {
  as.data.frame.vector(x, ...)
}

# --- ordering --------------------------------------------------------------

# Chronological order: epoch days and nanoseconds of day sort as numbers;
# a date-time sorts by its real part (the day) then its imaginary part
# (the time), exactly, through order() rather than a lossy double.

#' @export
xtfrm.zutempo_plain_date <- function(x) as.vector(unclass(x))
#' @export
xtfrm.zutempo_plain_time <- function(x) as.vector(unclass(x))
#' @export
xtfrm.zutempo_plain_date_time <- function(x) {
  z <- unclass(x)
  o <- order(Re(z), Im(z), na.last = NA)
  out <- rep(NA_real_, length(z))
  if (length(o)) {
    s <- z[o]
    n <- length(s)
    new <- c(TRUE, Re(s)[-1L] != Re(s)[-n] | Im(s)[-1L] != Im(s)[-n])
    out[o] <- cumsum(new)
  }
  out
}

# --- text -------------------------------------------------------------------

#' @export
format.zutempo_plain_date <- function(x, ...) temporal_to_string(x)
#' @export
format.zutempo_plain_time <- function(x, ...) temporal_to_string(x)
#' @export
format.zutempo_plain_date_time <- function(x, ...) temporal_to_string(x)

#' @export
as.character.zutempo_plain_date <- function(x, ...) temporal_to_string(x)
#' @export
as.character.zutempo_plain_time <- function(x, ...) temporal_to_string(x)
#' @export
as.character.zutempo_plain_date_time <- function(x, ...) temporal_to_string(x)

ztp_print <- function(x, ...) {
  cat(sprintf("<%s[%d]>\n", oldClass(x)[1L], length(x)))
  if (length(x)) {
    print(format(x), quote = FALSE, ...)
  }
  invisible(x)
}

#' @export
print.zutempo_plain_date <- function(x, ...) ztp_print(x, ...)
#' @export
print.zutempo_plain_time <- function(x, ...) ztp_print(x, ...)
#' @export
print.zutempo_plain_date_time <- function(x, ...) ztp_print(x, ...)

# --- the partial-date classes ----------------------------------------------

#' @export
`[.zutempo_plain_year_month` <- function(x, i, ...) ztp_subset(x, i)
#' @export
`[[.zutempo_plain_year_month` <- function(x, i, ...) ztp_subset2(x, i)
#' @export
`[<-.zutempo_plain_year_month` <- function(x, i, value) ztp_assign(x, i, value)
#' @export
`[[<-.zutempo_plain_year_month` <- function(x, i, value) ztp_assign(x, i, value)
#' @export
c.zutempo_plain_year_month <- function(...) ztp_combine(..1, list(...))
#' @export
rep.zutempo_plain_year_month <- function(x, ...) {
  ztp_restore(rep(unclass(x), ...), x)
}
#' @export
unique.zutempo_plain_year_month <- function(x, ...) {
  ztp_restore(unique(unclass(x), ...), x)
}
#' @export
`length<-.zutempo_plain_year_month` <- function(x, value) {
  ztp_restore(`length<-`(unclass(x), value), x)
}
#' @export
as.data.frame.zutempo_plain_year_month <- function(x, ...) {
  as.data.frame.vector(x, ...)
}
#' @export
xtfrm.zutempo_plain_year_month <- function(x) as.vector(unclass(x))
#' @export
format.zutempo_plain_year_month <- function(x, ...) temporal_to_string(x)
#' @export
as.character.zutempo_plain_year_month <- function(x, ...) temporal_to_string(x)
#' @export
print.zutempo_plain_year_month <- function(x, ...) ztp_print(x, ...)

#' @export
`[.zutempo_plain_month_day` <- function(x, i, ...) ztp_subset(x, i)
#' @export
`[[.zutempo_plain_month_day` <- function(x, i, ...) ztp_subset2(x, i)
#' @export
`[<-.zutempo_plain_month_day` <- function(x, i, value) ztp_assign(x, i, value)
#' @export
`[[<-.zutempo_plain_month_day` <- function(x, i, value) ztp_assign(x, i, value)
#' @export
c.zutempo_plain_month_day <- function(...) ztp_combine(..1, list(...))
#' @export
rep.zutempo_plain_month_day <- function(x, ...) {
  ztp_restore(rep(unclass(x), ...), x)
}
#' @export
unique.zutempo_plain_month_day <- function(x, ...) {
  ztp_restore(unique(unclass(x), ...), x)
}
#' @export
`length<-.zutempo_plain_month_day` <- function(x, value) {
  ztp_restore(`length<-`(unclass(x), value), x)
}
#' @export
as.data.frame.zutempo_plain_month_day <- function(x, ...) {
  as.data.frame.vector(x, ...)
}
#' @export
xtfrm.zutempo_plain_month_day <- function(x) as.vector(unclass(x))
#' @export
format.zutempo_plain_month_day <- function(x, ...) temporal_to_string(x)
#' @export
as.character.zutempo_plain_month_day <- function(x, ...) temporal_to_string(x)
#' @export
print.zutempo_plain_month_day <- function(x, ...) ztp_print(x, ...)
