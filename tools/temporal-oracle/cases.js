// The oracle cases, one array per Temporal type (design 11). A case is
//
//   { id, op, args, options? }
//
// where `op` is the Temporal member run (`from`, `compare`, ...) and `args`
// its arguments, as plain JSON. generate.js runs each case through an
// engine and records either the result (its toString() and, for a value,
// the properties listed in `fields` below) or the class of the error it
// threw. Everything here is data: a case says what to run, never what to
// expect. The expectation comes from the engine.
//
// Stage 1 holds a handful of PlainDate cases so the loop is proven; stage 2
// onwards fills each type (roadmap).
//
// Not here: behaviour the design documents as different from an engine
// (design 2 and 6.9), such as a non-ISO calendar annotation, which native
// engines accept and zutempo rejects. Those are tested in the package.

export const fields = {
  PlainDate: [
    "year", "month", "monthCode", "day", "dayOfWeek", "dayOfYear",
    "weekOfYear", "yearOfWeek", "daysInWeek", "daysInMonth", "daysInYear",
    "monthsInYear", "inLeapYear", "era", "eraYear", "calendarId",
  ],
};

export const cases = {
  PlainDate: [
    { id: "from-string", op: "from", args: ["2026-01-31"] },
    { id: "from-string-leap-day", op: "from", args: ["2024-02-29"] },
    { id: "from-string-not-leap-day", op: "from", args: ["2026-02-29"] },
    { id: "from-fields", op: "from", args: [{ year: 2026, month: 3, day: 7 }] },
    { id: "from-fields-constrain", op: "from",
      args: [{ year: 2026, month: 2, day: 31 }] },
    { id: "from-fields-reject", op: "from",
      args: [{ year: 2026, month: 2, day: 31 }], options: { overflow: "reject" } },
    { id: "from-expanded-max", op: "from", args: ["+275760-09-13"] },
    { id: "from-expanded-past-max", op: "from", args: ["+275760-09-14"] },
    { id: "from-expanded-min", op: "from", args: ["-271821-04-19"] },
    { id: "from-expanded-past-min", op: "from", args: ["-271821-04-18"] },
    { id: "from-negative-zero-year", op: "from", args: ["-000000-01-01"] },
    { id: "from-year-end-week-1", op: "from", args: ["2024-12-31"] },
    { id: "from-year-start-week-53", op: "from", args: ["2027-01-01"] },
    { id: "compare-less", op: "compare", args: ["2026-01-31", "2026-02-01"] },
    { id: "compare-equal", op: "compare", args: ["2026-01-31", "2026-01-31"] },
    { id: "compare-greater", op: "compare", args: ["2026-02-01", "2026-01-31"] },
  ],
};
