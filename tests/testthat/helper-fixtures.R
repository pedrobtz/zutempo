# Reading the pins of inst/spec/PINS and the headers of the committed
# fixtures (test-fixtures.R).

fixture_pins <- function() {
  read.dcf(system.file("spec", "PINS", package = "zutempo"))[1L, ]
}

# A string field of a JSON header, from the file's first bytes.
fixture_header_field <- function(text, field) {
  pattern <- sprintf("\"%s\": *\"([^\"]*)\"", field)
  hit <- regmatches(text, regexec(pattern, text))[[1L]]
  if (length(hit) == 2L) hit[[2L]] else NA_character_
}
