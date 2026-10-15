# Every in-scope member of the pinned specification (inst/spec/members.csv,
# written by tools/spec/members.R) has an exported R function under the
# names of design 5. Members not yet built are listed in `pending`; each
# stage removes the members it builds, and stage 13 requires the vector to
# be empty (design 15, criterion 3).

test_that("every in-scope member has an exported function, or is pending", {
  pending <- c(
    "epoch_milliseconds",
    "epoch_nanoseconds",
    "hours_in_day",
    "instant",
    "instant_compare",
    "instant_from_epoch_milliseconds",
    "instant_from_epoch_nanoseconds",
    "now_instant",
    "now_plain_date_iso",
    "now_plain_date_time_iso",
    "now_plain_time_iso",
    "now_time_zone_id",
    "now_zoned_date_time_iso",
    "offset",
    "offset_nanoseconds",
    "temporal_get_time_zone_transition",
    "temporal_start_of_day",
    "temporal_to_instant",
    "temporal_to_zoned_date_time",
    "temporal_to_zoned_date_time_iso",
    "temporal_with_time_zone",
    "time_zone_id",
    "zoned_date_time",
    "zoned_date_time_compare"
  )
  members <- read.csv(
    system.file("spec", "members.csv", package = "zutempo"),
    stringsAsFactors = FALSE
  )
  in_scope <- unique(members$r_name[members$in_scope])
  exports <- getNamespaceExports("zutempo")

  # The pending list names only real members, each once.
  expect_identical(setdiff(pending, in_scope), character())
  expect_identical(anyDuplicated(pending), 0L)
  # Members whose R name is a base R generic are provided as S3 methods
  # through a group generic, not as exports (design 5: `sign(x)` on a
  # duration dispatches through the Math group).
  through_group <- c(sign = "Math")
  for (name in intersect(names(through_group), in_scope)) {
    expect_false(
      is.null(getS3method(
        through_group[[name]],
        "zutempo_duration",
        optional = TRUE
      )),
      info = name
    )
  }
  in_scope <- setdiff(in_scope, names(through_group))
  pending <- setdiff(pending, names(through_group))
  # Every member that is not pending is exported.
  expect_identical(setdiff(setdiff(in_scope, pending), exports), character())
  # A member that has been built is no longer pending.
  expect_identical(intersect(pending, exports), character())
})

test_that("the member list covers the eight types and Now", {
  members <- read.csv(
    system.file("spec", "members.csv", package = "zutempo"),
    stringsAsFactors = FALSE
  )
  types <- c(
    "Instant",
    "ZonedDateTime",
    "PlainDateTime",
    "PlainDate",
    "PlainTime",
    "PlainYearMonth",
    "PlainMonthDay",
    "Duration",
    "Now"
  )
  expect_setequal(unique(members$type), types)
  expect_identical(
    names(members),
    c("type", "kind", "member", "r_name", "in_scope", "note")
  )
  expect_identical(
    sort(unique(members$member[!members$in_scope])),
    c("toJSON", "toLocaleString", "valueOf")
  )
  expect_identical(anyDuplicated(members[c("type", "kind", "member")]), 0L)
  # The naming rule of design 5, one example per kind.
  r_name_of <- function(type, kind, member) {
    members$r_name[
      members$type == type & members$kind == kind & members$member == member
    ]
  }
  expect_identical(r_name_of("PlainDate", "from", "from"), "plain_date")
  expect_identical(
    r_name_of("PlainDate", "static", "compare"),
    "plain_date_compare"
  )
  expect_identical(r_name_of("PlainDate", "method", "add"), "temporal_add")
  expect_identical(
    r_name_of("PlainDate", "property", "monthCode"),
    "month_code"
  )
  expect_identical(
    r_name_of("Now", "now", "zonedDateTimeISO"),
    "now_zoned_date_time_iso"
  )
  expect_identical(
    r_name_of("ZonedDateTime", "method", "getTimeZoneTransition"),
    "temporal_get_time_zone_transition"
  )
})
