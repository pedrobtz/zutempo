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
#'   `x < y`, `x == y`): they raise a `zutempo_type_error`. Use the
#'   functions, such as [temporal_add()], [temporal_equals()] and
#'   [plain_date_compare()]. Durations do compare with `==` and `<`.
#'
#' `sort()`, `order()`, `min()`, `max()` and `range()` use each type's
#' `compare()` order; a zoned value sorts by its instant. A
#' `plain_month_day()` has no `compare()` in Temporal: it sorts by month and
#' day, but has no `min()`, `max()` or `range()`.
#' `rank()` compares with operators, so use `rank(xtfrm(x))`.
#'
#' @keywords internal
"_PACKAGE"

## usethis namespace: start
#' @useDynLib zutempo, .registration = TRUE, .fixes = "C_"
## usethis namespace: end
NULL
