# The time zone database (design 8): where it is read from, which
# identifiers it has, and loading zones into the engine's session cache.
# The engine parses TZif bytes and holds the cache; this file does every
# part that touches the file system, so the C side stays portable.

ztp_tz_state <- new.env(parent = emptyenv())

# The directories to try, in the order of design 8.1, as a list with the
# directory that exists first (or NA) and everything tried.
ztp_tz_candidates <- function() {
  tried <- character()
  opt <- getOption("zutempo.tzdir")
  if (!is.null(opt)) {
    tried <- c(tried, ztp_tz_special_dir(opt))
  }
  env <- Sys.getenv("TZDIR", unset = NA_character_)
  if (!is.na(env) && nzchar(env)) {
    tried <- c(tried, ztp_tz_special_dir(env))
  }
  r_copy <- file.path(R.home("share"), "zoneinfo")
  sysname <- Sys.info()[["sysname"]]
  if (.Platform$OS.type == "windows") {
    tried <- c(tried, r_copy)
  } else if (identical(sysname, "Darwin")) {
    mac <- "/var/db/timezone/zoneinfo"
    tried <- c(tried, ztp_tz_newer(mac, r_copy))
  } else {
    tried <- c(tried, "/usr/share/zoneinfo", r_copy)
  }
  tried <- unique(tried)
  exists <- dir.exists(tried)
  list(
    dir = if (any(exists)) tried[which(exists)[1L]] else NA_character_,
    tried = tried
  )
}

# R's special values for TZDIR.
ztp_tz_special_dir <- function(x) {
  switch(
    x,
    internal = file.path(R.home("share"), "zoneinfo"),
    macOS = "/var/db/timezone/zoneinfo",
    x
  )
}

# The newer of two databases by version, as R chooses on macOS; a copy
# without a version file ranks after one with it.
ztp_tz_newer <- function(a, b) {
  va <- ztp_tz_version(a)
  vb <- ztp_tz_version(b)
  if (is.na(va) && !is.na(vb)) {
    return(c(b, a))
  }
  if (!is.na(va) && !is.na(vb) && vb > va) {
    return(c(b, a))
  }
  c(a, b)
}

# The tzdata version of a database: +VERSION (macOS), VERSION (R's copy)
# or the "# version" line of tzdata.zi; NA when none says.
ztp_tz_version <- function(dir) {
  if (is.na(dir) || !dir.exists(dir)) {
    return(NA_character_)
  }
  for (f in c("+VERSION", "VERSION")) {
    path <- file.path(dir, f)
    if (file.exists(path)) {
      v <- trimws(readLines(path, n = 1L, warn = FALSE))
      if (length(v) && nzchar(v)) {
        return(v)
      }
    }
  }
  zi <- file.path(dir, "tzdata.zi")
  if (file.exists(zi)) {
    first <- readLines(zi, n = 1L, warn = FALSE)
    if (grepl("^# version ", first)) {
      return(sub("^# version ", "", first))
    }
  }
  NA_character_
}

# Files that are not zones.
ztp_tz_excluded <- function(rel) {
  base <- basename(rel)
  grepl("^(right|posix)/", rel) |
    base %in%
      c(
        "posixrules",
        "localtime",
        "+VERSION",
        "VERSION",
        "tzdata.zi",
        "leapseconds",
        "leap-seconds.list",
        "Factory",
        "SECURITY",
        "README"
      ) |
    grepl("\\.(tab|zi|list)$", base)
}

# The identifiers of a database: one directory walk per session (design
# 8.3), as a data frame of the identifier in the database's case and its
# ASCII-lower-cased form.
ztp_tz_index <- function(dir) {
  rel <- list.files(
    dir,
    recursive = TRUE,
    all.files = FALSE,
    include.dirs = FALSE
  )
  rel <- rel[!ztp_tz_excluded(rel)]
  data.frame(id = rel, lower = tolower(rel), stringsAsFactors = FALSE)
}

# The current state, rebuilt when the option or TZDIR makes the lookup
# land on another directory (design 8.4). The key is the directory found,
# not the settings: base R's Sys.timezone() sets TZDIR as a side effect,
# which must not throw away a cache that still reads the same files.
ztp_tz_current <- function() {
  found <- ztp_tz_candidates()
  key <- if (is.na(found$dir)) "" else found$dir
  if (!identical(ztp_tz_state$key, key)) {
    ztp_tz_reset_state()
    ztp_tz_state$key <- key
    ztp_tz_state$dir <- found$dir
    ztp_tz_state$tried <- found$tried
    ztp_tz_state$version <- ztp_tz_version(found$dir)
    ztp_tz_state$index <- if (is.na(found$dir)) {
      NULL
    } else {
      ztp_tz_index(found$dir)
    }
  }
  ztp_tz_state
}

ztp_tz_reset_state <- function() {
  .Call(C_ztp_r_tz_reset)
  rm(list = ls(ztp_tz_state, all.names = TRUE), envir = ztp_tz_state)
  invisible()
}

#' Forget the parsed time zones
#'
#' zutempo reads the time zone database the way base R does, and keeps the
#' zones it has parsed for the session (design 8.4). The cache clears by
#' itself when the option `zutempo.tzdir` or the `TZDIR` variable changes;
#' `zutempo_tz_reset()` clears it on demand, for a database that changed
#' under a running session.
#'
#' @return `NULL`, invisibly.
#' @examples
#' zutempo_tz_reset()
#' @export
zutempo_tz_reset <- function() {
  ztp_tz_reset_state()
  invisible(NULL)
}

# Resolve a time zone string: ParseTemporalTimeZoneString first, so an
# ISO string such as "2026-03-07T12:00+01:00" names its zone; then "UTC"
# and offsets through the engine, named zones through the index, loading
# the file on first use. Returns the identifier as Temporal writes it; a
# name not in the database is a zutempo_tz_error naming the directories
# tried.
ztp_tz_ensure <- function(id, index = NULL) {
  id <- .Call(C_ztp_r_time_zone_string, id, index)
  if (grepl("^[+-]", id) || tolower(id) == "utc") {
    return(.Call(C_ztp_r_zone_normalise, id))
  }
  state <- ztp_tz_current()
  if (is.null(state$index)) {
    stop_zutempo(
      sprintf(
        "no time zone database was found for \"%s\"; looked in %s",
        id,
        paste(state$tried, collapse = ", ")
      ),
      kind = "tz",
      index = index
    )
  }
  hit <- match(tolower(id), state$index$lower)
  if (is.na(hit)) {
    stop_zutempo(
      sprintf("time zone \"%s\" is not in the database at %s", id, state$dir),
      kind = "tz",
      index = index
    )
  }
  canonical <- state$index$id[hit]
  if (!.Call(C_ztp_r_tz_loaded, canonical)) {
    path <- file.path(state$dir, canonical)
    bytes <- readBin(path, "raw", n = file.size(path))
    .Call(C_ztp_r_tz_load, canonical, bytes)
  }
  canonical
}

# The zone table of a zoned_date_time(), with every identifier loaded: the
# cache may have been cleared since the vector was made.
ztp_zdt_zones_ready <- function(x) {
  zones <- ztp_zdt_zones(x)
  if (length(zones)) {
    ztp_tz_ensure_all(zones)
  }
  zones
}

# Every distinct identifier of a character vector, resolved; NA stays NA.
ztp_tz_ensure_all <- function(ids) {
  out <- ids
  for (id in unique(ids[!is.na(ids)])) {
    out[!is.na(ids) & ids == id] <- ztp_tz_ensure(
      id,
      index = which(!is.na(ids) & ids == id)[1L]
    )
  }
  out
}

# Whether the database's files carry explicit transitions far into the
# future ("fat") or stop at the last rule change ("slim", design 0), read
# off a zone with DST rules; NA without a database or such a zone.
ztp_tz_form <- function() {
  state <- ztp_tz_current()
  if (is.null(state$index)) {
    return(NA_character_)
  }
  for (zone in c("America/New_York", "Europe/London", "Australia/Sydney")) {
    if (tolower(zone) %in% state$index$lower) {
      id <- ztp_tz_ensure(zone)
      last <- .Call(C_ztp_r_tz_last_explicit, id)
      if (is.na(last)) {
        next
      }
      return(
        if (last >= as.numeric(as.POSIXct("2030-01-01", tz = "UTC"))) {
          "fat"
        } else {
          "slim"
        }
      )
    }
  }
  NA_character_
}
