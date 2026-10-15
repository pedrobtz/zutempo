# The "Members" section of each type's help topic, generated when roxygen
# runs (`@eval ztp_doc_members("PlainDate")`) from inst/spec/members.csv,
# the ledger of every member of the pinned specification, so the topics
# and the ledger cannot drift apart.

ztp_doc_members <- function(type) {
  path <- system.file("spec", "members.csv", package = "zutempo")
  m <- utils::read.csv(path, stringsAsFactors = FALSE)
  m <- m[m[["type"]] == type, , drop = FALSE]
  js <- function(kind, member) {
    switch(
      kind,
      constructor = sprintf("`new Temporal.%s()`", type),
      from = sprintf("`Temporal.%s.from()`", type),
      static = sprintf("`Temporal.%s.%s()`", type, member),
      method = sprintf("`.%s()`", member),
      property = sprintf("`.%s`", member),
      now = sprintf("`Temporal.Now.%s()`", member)
    )
  }
  r <- ifelse(
    m[["in_scope"]],
    sprintf("[%s()]", m[["r_name"]]),
    sprintf("none: %s", m[["note"]])
  )
  order <- c("constructor", "from", "static", "property", "method", "now")
  m[["r"]] <- r
  m <- m[order(match(m[["kind"]], order)), , drop = FALSE]
  rows <- sprintf(
    "| %s | %s |",
    mapply(js, m[["kind"]], m[["member"]]),
    m[["r"]]
  )
  c(
    "@section Members:",
    sprintf(
      "Every member of `Temporal.%s` in the pinned specification",
      type
    ),
    "(`inst/spec/PINS`) and the R function that implements it:",
    "",
    "| Temporal | R |",
    "| --- | --- |",
    rows
  )
}
