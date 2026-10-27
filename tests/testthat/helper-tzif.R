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
