# a range error names the failing element

    Code
      plain_date(c(2026, 2026), 2, c(28, 31), overflow = "reject")
    Condition
      Error:
      ! 2026-02-31 is not a valid date (element 2)

# a parse error names the element and the byte

    Code
      plain_date(c("2026-01-31", "2026-13-01"))
    Condition
      Error:
      ! cannot parse "2026-13-01" as a date or date-time: month must be 01 to 12 at byte 6 (element 2)

---

    Code
      duration("P1Y1Q")
    Condition
      Error:
      ! cannot parse "P1Y1Q" as a duration: expected a duration designator at byte 4 (element 1)

---

    Code
      plain_date("2026-01-31[!foo=bar]")
    Condition
      Error:
      ! cannot parse "2026-01-31[!foo=bar]" as a date or date-time: an unknown annotation is marked critical with '!' at byte 11 (element 1)

# a type error names the option and its choices

    Code
      temporal_round(plain_time("12:00"), "minute", rounding_mode = "up")
    Condition
      Error:
      ! `rounding_mode` must be one of "ceil", "floor", "expand", "trunc", "halfCeil", "halfFloor", "halfExpand", "halfTrunc", "halfEven", not "up"

---

    Code
      temporal_round(plain_time("12:00"))
    Condition
      Error:
      ! `smallest_unit` is required

# tz errors name the zone and where it was looked for

    Code
      zoned_date_time("2026-03-07T12:00[Europe/Atlantis]")
    Condition
      Error:
      ! time zone "Europe/Atlantis" is not in the database at <fixtures> (element 1)

---

    Code
      .Call(zutempo:::C_ztp_r_tz_rule_utoff, "nonsense,,", 0)
    Condition
      Error:
      ! cannot parse the TZ rule "nonsense,,"

# with no database, the tz error lists every directory tried

    Code
      zoned_date_time(c("2026-03-07T12:00[UTC]", "2026-03-07T12:00[Asia/Tokyo]"))
    Condition
      Error:
      ! no time zone database was found for "Asia/Tokyo"; looked in /usr/share/zoneinfo, <R_SHARE>/zoneinfo (element 2)

# an error raised in the C glue carries its index in the text

    Code
      ztp_probe_fail("range", 3)
    Condition
      Error:
      ! probe: a range error (element 3)

---

    Code
      ztp_probe_fail("range", 0)
    Condition
      Error:
      ! probe: a range error

