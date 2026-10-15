# Lazy registration of the vctrs and pillar methods (design 4.1): both
# packages are Suggests, so their methods are registered when they load.

.onLoad <- function(libname, pkgname) {
  for (cls in ztp_plain_classes) {
    ztp_register_vctrs(cls)
  }
  invisible()
}

ztp_register_vctrs <- function(cls) {
  constructor <- switch(
    cls,
    zutempo_plain_date = new_plain_date,
    zutempo_plain_time = new_plain_time,
    zutempo_plain_date_time = new_plain_date_time,
    zutempo_plain_year_month = new_plain_year_month,
    zutempo_plain_month_day = new_plain_month_day
  )
  abbr <- switch(
    cls,
    zutempo_plain_date = "pl_date",
    zutempo_plain_time = "pl_time",
    zutempo_plain_date_time = "pl_dttm",
    zutempo_plain_year_month = "pl_ym",
    zutempo_plain_month_day = "pl_md"
  )
  self <- paste0(cls, ".", cls)
  ztp_s3_register("vctrs::vec_ptype2", self, function(x, y, ...) constructor())
  ztp_s3_register("vctrs::vec_cast", self, function(x, to, ...) x)
  ztp_s3_register("vctrs::vec_ptype_abbr", cls, function(x, ...) abbr)
  ztp_s3_register("vctrs::vec_ptype_full", cls, function(x, ...) cls)
  ztp_s3_register("pillar::pillar_shaft", cls, function(x, ...) {
    pillar::new_pillar_shaft_simple(format(x), align = "right")
  })
}

# Register an S3 method for a generic in another package, now if that
# package is loaded and otherwise when it loads. The standard pattern
# from vctrs, in base R.
ztp_s3_register <- function(generic, class, method) {
  pieces <- strsplit(generic, "::", fixed = TRUE)[[1L]]
  package <- pieces[[1L]]
  generic <- pieces[[2L]]
  register <- function(...) {
    envir <- asNamespace(package)
    if (exists(generic, envir = envir, inherits = FALSE)) {
      registerS3method(generic, class, method, envir = envir)
    }
  }
  setHook(packageEvent(package, "onLoad"), register)
  if (isNamespaceLoaded(package)) {
    register()
  }
  invisible()
}
