#' What zutempo was built against
#'
#' The versions and pins that decide zutempo's behaviour: the package and
#' `zufast` versions, whether the 128-bit arithmetic uses the compiler's
#' `__int128`, and the commits of the Temporal specification and of test262
#' the package follows, with the tzdata release its fixtures come from. The
#' pins live in `inst/spec/PINS` and move only on purpose.
#'
#' The time zone fields describe the database zutempo reads:
#' `tzdir`, the directory found by base R's lookup order (`NA` when none
#' exists), `tz_version`, the tzdata release it declares, `tz_form`,
#' whether its files carry explicit transitions far into the future
#' (`"fat"`) or stop at the last rule change (`"slim"`), and
#' `tz_links_version`, the tzdata release the built-in link table comes
#' from.
#'
#' @return A list of class `zutempo_info` with elements `package`, `zufast`,
#'   `int128`, `spec_repository`, `spec_commit`, `spec_date`,
#'   `test262_repository`, `test262_commit`, `test262_date`, `tzdata`,
#'   `tzdir`, `tz_version`, `tz_form` and `tz_links_version`.
#' @examples
#' zutempo_info()
#' @export
zutempo_info <- function() {
  pins <- read.dcf(system.file("spec", "PINS", package = "zutempo"))
  pin <- function(field) unname(pins[1L, field])
  native <- .Call(C_ztp_r_info)
  structure(
    list(
      package = unname(getNamespaceVersion("zutempo")),
      zufast = native[["zufast"]],
      int128 = native[["int128"]],
      spec_repository = pin("Specification"),
      spec_commit = pin("SpecificationCommit"),
      spec_date = pin("SpecificationDate"),
      test262_repository = pin("Test262"),
      test262_commit = pin("Test262Commit"),
      test262_date = pin("Test262Date"),
      tzdata = pin("Tzdata"),
      tzdir = ztp_tz_current()[["dir"]],
      tz_version = ztp_tz_current()[["version"]],
      tz_form = ztp_tz_form(),
      tz_links_version = .Call(C_ztp_r_tz_links_version)
    ),
    class = "zutempo_info"
  )
}

#' @export
print.zutempo_info <- function(x, ...) {
  cat("zutempo ", x[["package"]], "\n", sep = "")
  cat(
    "  zufast ",
    x[["zufast"]],
    ", 128-bit arithmetic: ",
    if (isTRUE(x[["int128"]])) "__int128" else "portable",
    "\n",
    sep = ""
  )
  cat(
    "  specification: ",
    x[["spec_repository"]],
    "@",
    substr(x[["spec_commit"]], 1, 12),
    " (",
    x[["spec_date"]],
    ")\n",
    sep = ""
  )
  cat(
    "  test262: ",
    x[["test262_repository"]],
    "@",
    substr(x[["test262_commit"]], 1, 12),
    " (",
    x[["test262_date"]],
    ")\n",
    sep = ""
  )
  cat(
    "  tzdata pin: ",
    x[["tzdata"]],
    "; link table: ",
    x[["tz_links_version"]],
    "\n",
    sep = ""
  )
  cat(
    "  tz database: ",
    if (is.na(x[["tzdir"]])) {
      "none found"
    } else {
      paste0(x[["tzdir"]], " (", x[["tz_version"]], ", ", x[["tz_form"]], ")")
    },
    "\n",
    sep = ""
  )
  invisible(x)
}
