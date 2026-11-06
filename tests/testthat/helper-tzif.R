# A version 1 TZif file with no transitions, one local time type of
# `utoff` seconds and the given abbreviation bytes, the type pointing at
# `abbr_index`; for tests of the reader on crafted files.
tzif_v1 <- function(abbr_index, chars = raw(0), utoff = 3600) {
  be32 <- function(x) {
    x <- x %% 2^32
    as.raw(c(
      (x %/% 2^24) %% 256,
      (x %/% 2^16) %% 256,
      (x %/% 2^8) %% 256,
      x %% 256
    ))
  }
  c(
    charToRaw("TZif"),
    as.raw(0),
    raw(15),
    be32(0), # isutcnt
    be32(0), # isstdcnt
    be32(0), # leapcnt
    be32(0), # timecnt
    be32(1), # typecnt
    be32(length(chars)), # charcnt
    be32(utoff),
    as.raw(0), # isdst
    as.raw(abbr_index),
    chars
  )
}

# A version 1 TZif file with the given transitions (UTC seconds), the index
# of the type each one starts (0-based) and the types' UTC offsets in
# seconds; type i is called "Ti", and type 0 applies before the first
# transition.
tzif_v1_transitions <- function(times, idx, utoffs) {
  be32 <- function(x) {
    x <- x %% 2^32
    as.raw(c(
      (x %/% 2^24) %% 256,
      (x %/% 2^16) %% 256,
      (x %/% 2^8) %% 256,
      x %% 256
    ))
  }
  abbrs <- paste0("T", seq_along(utoffs) - 1L)
  chars <- unlist(lapply(abbrs, function(a) c(charToRaw(a), as.raw(0))))
  starts <- cumsum(c(0, nchar(abbrs) + 1))[seq_along(abbrs)]
  types <- unlist(lapply(seq_along(utoffs), function(i) {
    c(be32(utoffs[i]), as.raw(0), as.raw(starts[i]))
  }))
  c(
    charToRaw("TZif"),
    as.raw(0),
    raw(15),
    be32(0), # isutcnt
    be32(0), # isstdcnt
    be32(0), # leapcnt
    be32(length(times)), # timecnt
    be32(length(utoffs)), # typecnt
    be32(length(chars)), # charcnt
    unlist(lapply(times, be32)),
    as.raw(idx),
    types,
    chars
  )
}
