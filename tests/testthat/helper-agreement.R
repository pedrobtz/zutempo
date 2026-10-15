# Helpers of test-agreement.R: zutempo's offsets against base R's
# (design 11).

agreement_zones <- function() {
  ids <- zutempo:::ztp_tz_current()[["index"]][["id"]]
  sort(ids)
}

agreement_first <- -2208988800 # 1900-01-01T00:00Z
agreement_last <- 4102444800 # 2100-01-01T00:00Z

# The UTC instants (whole seconds) where each zone's offset changes between
# 1900 and 2100, as a list by zone.
agreement_transitions <- function(ids) {
  z <- zoned_date_time(paste0("1900-01-01T00:00Z[", ids, "]"))
  out <- vector("list", length(ids))
  live <- seq_along(ids)
  while (length(live)) {
    nxt <- temporal_get_time_zone_transition(z[live], "next")
    secs <- unclass(as.POSIXct(nxt, tz = "UTC"))
    keep <- !is.na(secs) & secs < agreement_last
    for (k in which(keep)) {
      out[[live[k]]] <- c(out[[live[k]]], secs[k])
    }
    z[live[keep]] <- nxt[keep]
    live <- live[keep]
  }
  out
}

# Offsets that differ at `secs` (UTC seconds) in `zone`, as a data frame.
agreement_mismatches <- function(zone, secs) {
  mine <- offset_nanoseconds(temporal_to_zoned_date_time_iso(
    instant(.POSIXct(secs, tz = "UTC")),
    zone
  )) /
    1e9
  base <- unclass(as.POSIXlt(.POSIXct(secs, tz = zone)))[["gmtoff"]]
  bad <- which(is.na(base) | mine != base)
  data.frame(
    zone = rep(zone, length(bad)),
    at = secs[bad],
    zutempo = mine[bad],
    base = base[bad]
  )
}

# The mismatches not covered by a documented difference.
agreement_unexplained <- function(found) {
  known <- utils::read.csv(
    test_path("agreement", "differences.csv"),
    stringsAsFactors = FALSE
  )
  if (!nrow(found) || !nrow(known)) {
    return(found)
  }
  from <- unclass(as.POSIXct(known[["from"]], tz = "UTC"))
  to <- unclass(as.POSIXct(known[["to"]], tz = "UTC"))
  covered <- vapply(
    seq_len(nrow(found)),
    function(i) {
      any(
        (known[["zone"]] == found[["zone"]][i] | known[["zone"]] == "*") &
          found[["at"]][i] >= from &
          found[["at"]][i] < to
      )
    },
    logical(1)
  )
  found[!covered, , drop = FALSE]
}

agreement_report <- function(found) {
  if (!nrow(found)) {
    return("")
  }
  shown <- utils::head(found, 20L)
  paste(
    sprintf(
      "%s at %s: zutempo %s, base R %s",
      shown[["zone"]],
      format(.POSIXct(shown[["at"]], tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ"),
      shown[["zutempo"]],
      shown[["base"]]
    ),
    collapse = "\n"
  )
}
