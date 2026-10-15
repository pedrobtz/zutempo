// Run the cases of cases.js through an engine and write one JSON file per
// type into tests/testthat/oracle/ (design 11, roadmap stage 1).
//
//   node generate.js                  temporal-polyfill, write the files
//   node generate.js --check-native   compare temporal-polyfill with this
//                                     Node's native Temporal (Node 26+),
//                                     exit 1 on any difference, write nothing
//
// The output depends only on cases.js and the engine, so running it twice
// gives identical files. The header records the engine and the tzdata
// release of the Node binary (process.versions.tz) for cases that depend
// on zone rules.

import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { cases, fields } from "./cases.js";

const here = dirname(fileURLToPath(import.meta.url));
const outDir = join(here, "..", "..", "tests", "testthat", "oracle");

function polyfillVersion() {
  const pkg = JSON.parse(
    readFileSync(join(here, "node_modules", "temporal-polyfill", "package.json"), "utf8"),
  );
  return pkg.version;
}

function describe(Temporal, type, value) {
  if (value === null || value === undefined) return null;
  if (typeof value === "number" || typeof value === "boolean" || typeof value === "string") {
    return value;
  }
  const out = { string: value.toString() };
  let resultType = null;
  for (const t of Object.keys(fields)) {
    if (value instanceof Temporal[t]) resultType = t;
  }
  if (resultType === null) return out;
  out.type = resultType;
  const names = fields[resultType];
  {
    out.fields = {};
    for (const name of names) {
      const v = value[name];
      // A BigInt (epochNanoseconds) travels as its decimal string.
      out.fields[name] = v === undefined ? null : typeof v === "bigint" ? v.toString() : v;
    }
  }
  return out;
}

function materialise(Temporal, arg) {
  if (arg !== null && typeof arg === "object" && "$type" in arg) {
    return Temporal[arg.$type].from(arg.value);
  }
  if (arg !== null && typeof arg === "object" && !Array.isArray(arg)) {
    // A bag of fields may hold typed values (toZonedDateTime's plainTime).
    return Object.fromEntries(
      Object.entries(arg).map(([k, v]) => [k, materialise(Temporal, v)]),
    );
  }
  return arg;
}

function run(Temporal, type, c) {
  const record = { id: c.id, op: c.op };
  if (c.on !== undefined) record.on = c.on;
  record.args = c.args ?? [];
  if (c.options !== undefined) record.options = c.options;
  try {
    const target = c.on === undefined ? Temporal[type] : Temporal[type].from(c.on);
    const args = record.args.map((a) => materialise(Temporal, a));
    if (c.options !== undefined) args.push(c.options);
    const value = target[c.op](...args);
    record.result = describe(Temporal, type, value);
  } catch (e) {
    record.throws = e instanceof RangeError ? "RangeError"
      : e instanceof TypeError ? "TypeError"
      : e.constructor.name;
  }
  return record;
}

function generate(Temporal, engine) {
  const files = {};
  for (const type of Object.keys(cases)) {
    const doc = {
      type,
      engine,
      tz: process.versions.tz ?? null,
      cases: cases[type].map((c) => run(Temporal, type, c)),
    };
    files[`${type}.json`] = JSON.stringify(doc, null, 2) + "\n";
  }
  return files;
}

// "temporal-polyfill/implementation", not "temporal-polyfill": the main
// entry point hands back the native Temporal when the Node has one, which
// would make the oracle native and check-native compare native with itself.
const { Temporal: Polyfill } = await import("temporal-polyfill/implementation");

// Cases where this Node's native Temporal is known to disagree with the
// specification, and the polyfill does not. check-native reports them but
// does not fail on them, and fails if one of them stops differing, so the
// list stays current.
const knownNative = {
  "Duration.json round-month-relative":
    "P1Y rounded to months relative to a date gives P1Y1M; test262's " +
    "Duration/prototype/round/exact-multiple-of-larger-unit-plaindate.js wants P1Y",
  "PlainTime.json from-string-basic":
    '"123045" is rejected as ambiguous with a month-day; it is not, since ' +
    "a DateSpecMonthDay has four digits (AnnotatedTime early errors)",
};
const polyfill = generate(Polyfill, `temporal-polyfill ${polyfillVersion()}`);

if (process.argv.includes("--check-native")) {
  if (typeof globalThis.Temporal === "undefined") {
    console.error("This Node has no native Temporal; Node 26 or later is needed.");
    process.exit(2);
  }
  const native = generate(globalThis.Temporal, `node ${process.versions.node}`);
  let differences = 0;
  const seen = new Set();
  for (const name of Object.keys(polyfill)) {
    const a = JSON.parse(polyfill[name]).cases;
    const b = JSON.parse(native[name]).cases;
    for (let i = 0; i < a.length; i++) {
      const x = JSON.stringify(a[i]);
      const y = JSON.stringify(b[i]);
      if (x === y) continue;
      const key = `${name} ${a[i].id}`;
      if (key in knownNative) {
        seen.add(key);
        console.log(`${key} (known native bug: ${knownNative[key]})`);
        continue;
      }
      differences++;
      console.log(`${key}\n  polyfill: ${x}\n  native:   ${y}`);
    }
  }
  for (const key of Object.keys(knownNative)) {
    if (!seen.has(key)) {
      differences++;
      console.log(`${key} no longer differs; remove it from knownNative`);
    }
  }
  console.log(`${differences} unexpected difference(s), ${seen.size} known`);
  process.exit(differences === 0 ? 0 : 1);
}

mkdirSync(outDir, { recursive: true });
for (const [name, text] of Object.entries(polyfill)) {
  writeFileSync(join(outDir, name), text);
  console.log(`wrote ${join("tests", "testthat", "oracle", name)}`);
}
