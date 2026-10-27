# Lazy registration of the vctrs and pillar methods (design 4.1): both
# packages are Suggests, so their methods are registered when they load.

.onLoad <- function(libname, pkgname) {
  for (cls in ztp_atomic_classes) {
    ztp_register_vctrs(cls)
  }
  ztp_register_vctrs_duration()
  ztp_register_vctrs_zoned()
  if (exists("chooseOpsMethod", envir = baseenv(), inherits = FALSE)) {
    for (cls in ztp_ops_classes) {
      registerS3method(
        "chooseOpsMethod",
        cls,
        ztp_choose_ops_method,
        envir = baseenv()
      )
    }
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
    zutempo_plain_month_day = new_plain_month_day,
    zutempo_instant = new_instant
  )
  abbr <- switch(
    cls,
    zutempo_plain_date = "pl_date",
    zutempo_plain_time = "pl_time",
    zutempo_plain_date_time = "pl_dttm",
    zutempo_plain_year_month = "pl_ym",
    zutempo_plain_month_day = "pl_md",
    zutempo_instant = "instant"
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
  # Tag the hook, and drop one with the same tag from an earlier load, so
  # that loading the package again does not pile hooks up.
  tag <- paste(generic, class)
  attr(register, "zutempo_hook") <- tag
  hook <- packageEvent(package, "onLoad")
  ztp_drop_hooks(hook, function(t) identical(t, tag))
  setHook(hook, register)
  if (isNamespaceLoaded(package)) {
    register()
  }
  invisible()
}

# Remove the hooks of `hook` whose tag satisfies `drop`.
ztp_drop_hooks <- function(hook, drop = function(tag) TRUE) {
  hooks <- getHook(hook)
  keep <- vapply(
    hooks,
    function(h) {
      tag <- attr(h, "zutempo_hook", exact = TRUE)
      is.null(tag) || !drop(tag)
    },
    logical(1L)
  )
  if (!all(keep)) {
    setHook(hook, hooks[keep], "replace")
  }
  invisible()
}

.onUnload <- function(libpath) {
  for (package in c("vctrs", "pillar")) {
    ztp_drop_hooks(packageEvent(package, "onLoad"))
  }
  library.dynam.unload("zutempo", libpath)
  invisible()
}

ztp_register_vctrs_duration <- function() {
  cls <- "zutempo_duration"
  self <- paste0(cls, ".", cls)
  ztp_s3_register("vctrs::vec_proxy", cls, function(x, ...) {
    data <- unclass(x)
    attributes(data) <- list(names = names(data))
    vctrs::new_data_frame(data, n = length(data[[1L]]))
  })
  ztp_s3_register("vctrs::vec_restore", cls, function(x, to, ...) {
    new_duration(lapply(as.list(x), as.double))
  })
  ztp_s3_register("vctrs::vec_ptype2", self, function(x, y, ...) new_duration())
  ztp_s3_register("vctrs::vec_cast", self, function(x, to, ...) x)
  ztp_s3_register("vctrs::vec_ptype_abbr", cls, function(x, ...) "duration")
  ztp_s3_register("vctrs::vec_ptype_full", cls, function(x, ...) cls)
  ztp_s3_register("pillar::pillar_shaft", cls, function(x, ...) {
    pillar::new_pillar_shaft_simple(format(x), align = "right")
  })
}

# A zoned_date_time() is a record for vctrs: its proxy is a data frame of
# the instant and the identifier of each element (design 4.2).
ztp_register_vctrs_zoned <- function() {
  cls <- "zutempo_zoned_date_time"
  self <- paste0(cls, ".", cls)
  ztp_s3_register("vctrs::vec_proxy", cls, function(x, ...) {
    vctrs::new_data_frame(
      list(instant = ztp_zdt_instant(x), zone = ztp_zdt_ids(x)),
      n = length(x)
    )
  })
  ztp_s3_register("vctrs::vec_restore", cls, function(x, to, ...) {
    ztp_zoned_build(as.complex(x[["instant"]]), as.character(x[["zone"]]))
  })
  ztp_s3_register("vctrs::vec_ptype2", self, function(x, y, ...) {
    new_zoned_date_time()
  })
  ztp_s3_register("vctrs::vec_cast", self, function(x, to, ...) x)
  ztp_s3_register("vctrs::vec_ptype_abbr", cls, function(x, ...) "zdt")
  ztp_s3_register("vctrs::vec_ptype_full", cls, function(x, ...) cls)
  ztp_s3_register("pillar::pillar_shaft", cls, function(x, ...) {
    pillar::new_pillar_shaft_simple(format(x), align = "right")
  })
}
