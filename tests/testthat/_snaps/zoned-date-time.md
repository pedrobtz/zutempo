# an ill-formed zone identifier is reported as one

    Code
      temporal_with_time_zone(z, "Europe/Par$is")
    Condition
      Error:
      ! cannot parse "Europe/Par$is" as a time zone: it is not a valid time zone identifier (element 1)
    Code
      temporal_with_time_zone(z, "Europe/Par is")
    Condition
      Error:
      ! cannot parse "Europe/Par is" as a time zone: it is not a valid time zone identifier (element 1)
    Code
      temporal_with_time_zone(z, "2026-13-01")
    Condition
      Error:
      ! cannot parse "2026-13-01" as a date, time or time zone: unexpected character at byte 8 (element 1)

