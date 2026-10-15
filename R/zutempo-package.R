#' @section Scope:
#' zutempo implements every member of the eight Temporal types and
#' `Temporal.Now` in the pinned specification (`zutempo_info()`), in the
#' ISO 8601 calendar. It does not include:
#'
#' * calendars other than ISO 8601 (Hebrew, Japanese and the others come
#'   from ECMA-402, with CLDR data);
#' * locale formatting (`toLocaleString()`): convert to `POSIXct` and use
#'   base R's `format()`;
#' * custom time zones, or POSIX TZ strings as zone identifiers;
#' * arithmetic and comparison operators on dates and times (`x + d`,
#'   `x < y`): use the functions, such as [temporal_add()] and
#'   [plain_date_compare()]. Durations do compare with `==` and `<`.
#'
#' @keywords internal
"_PACKAGE"

## usethis namespace: start
#' @useDynLib zutempo, .registration = TRUE, .fixes = "C_"
## usethis namespace: end
NULL
