# The stage 1 probe (src/ztp_probe.h): one path from R through the glue to
# the engine and zufast's headers, kept so that tests prove the layering.
# Internal; later stages replace it with the real types.

ztp_probe_civil <- function(days) {
  .Call(C_ztp_r_probe_civil, as.double(days))
}

ztp_probe_mul <- function(a, b) {
  a <- as.double(a)
  b <- as.double(b)
  if (length(a) != length(b)) {
    stop_zutempo("a and b must have the same length", kind = "type")
  }
  .Call(C_ztp_r_probe_mul, a, b)
}

ztp_probe_fail <- function(kind, index = 0) {
  .Call(C_ztp_r_probe_fail, as.character(kind), as.double(index))
}
