// Translate test262's Temporal tests into zutempo's oracle format (design
// 11, roadmap stage 11).
//
//   node tools/test262/extract.mjs [cache-dir]
//
// The cache is a sparse checkout of tc39/test262 at the commit
// inst/spec/PINS names, with harness/ and test/built-ins/Temporal/
// (tools/test262/README.md). Each test file runs in a fresh vm context with
// test262's harness and temporal-polyfill's script build, whose Temporal
// records every call the test makes into it: the member, the receiver, the
// arguments and the result or the class of the error. A file whose
// assertions all pass contributes the calls R can express: no getters,
// proxies or functions among the arguments, no calendar but ISO 8601, no
// member that only JavaScript has. Their results are the values the
// file's assertions accept. They are written as
// tests/testthat/test262/<Type>.json.gz, in the format of the oracle, with a
// report of what was translated and why the rest was not
// (tools/test262/REPORT.md).

import { createHash } from "node:crypto";
import { gzipSync } from "node:zlib";
import { readFileSync, readdirSync, statSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname, join, relative } from "node:path";
import { fileURLToPath } from "node:url";
import vm from "node:vm";
import { types as utilTypes } from "node:util";

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, "..", "..");
const cache = process.argv[2] ?? join(here, "cache");
const pins = readFileSync(join(root, "inst", "spec", "PINS"), "utf8");
const commit = /^Test262Commit:\s*(\S+)/m.exec(pins)[1];
const head = readFileSync(join(cache, ".git", "FETCH_HEAD"), "utf8");
if (!head.startsWith(commit)) {
  console.error(`The cache is not at the pinned commit ${commit}; see tools/test262/README.md.`);
  process.exit(2);
}
const polyfillDir = join(root, "tools", "temporal-oracle", "node_modules", "temporal-polyfill");
const polyfill = readFileSync(join(polyfillDir, "global.js"), "utf8");
const polyfillVersion = JSON.parse(readFileSync(join(polyfillDir, "package.json"), "utf8")).version;

const harnessCache = new Map();
const harness = (name) => {
  if (!harnessCache.has(name)) harnessCache.set(name, readFileSync(join(cache, "harness", name), "utf8"));
  return harnessCache.get(name);
};

function walk(dir) {
  const out = [];
  for (const name of readdirSync(dir).sort()) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) out.push(...walk(p));
    else if (name.endsWith(".js") && !name.includes("_FIXTURE")) out.push(p);
  }
  return out;
}

// The frontmatter fields this tool reads: includes, flags, negative.
function frontmatter(src) {
  const m = /\/\*---([\s\S]*?)---\*\//.exec(src);
  const meta = { includes: [], flags: [], negative: false };
  if (!m) return meta;
  const text = m[1];
  const list = (key) => {
    const inline = new RegExp(`^${key}:\\s*\\[([^\\]]*)\\]`, "m").exec(text);
    if (inline) return inline[1].split(",").map((s) => s.trim()).filter(Boolean);
    const block = new RegExp(`^${key}:\\s*\\n((?:\\s+-\\s*.+\\n?)+)`, "m").exec(text);
    if (block) return block[1].split("\n").map((s) => s.replace(/^\s*-\s*/, "").trim()).filter(Boolean);
    return [];
  };
  meta.includes = list("includes");
  meta.flags = list("flags");
  meta.negative = /^negative:/m.test(text);
  return meta;
}

// The recorder, run inside each test's context after the polyfill: it
// wraps every constructor, static method, prototype method and getter of
// the eight types so that each call the test makes (not the calls the
// polyfill makes into itself) is recorded with what R needs to replay it.
const recorder = String.raw`
(function () {
  "use strict";
  const T = globalThis.Temporal;
  const isProxy = globalThis.__zutempoIsProxy;
  delete globalThis.__zutempoIsProxy;
  const types = ["Instant", "ZonedDateTime", "PlainDateTime", "PlainDate",
                 "PlainTime", "PlainYearMonth", "PlainMonthDay", "Duration"];
  const originals = {};
  for (const t of types) originals[t] = T[t];
  const rec = [];
  let depth = 0;
  Object.defineProperty(globalThis, "__zutempoRecord", { value: rec });
  const BAD = { bad: true };
  const typeOf = (v) => {
    for (const t of types) if (v instanceof originals[t]) return t;
    return null;
  };
  const iso = (v) => !("calendarId" in v) || v.calendarId === "iso8601";
  // A Temporal value in a form that reads back exactly: a zoned value as
  // its instant in its zone, since toString() rounds the offset; a
  // year-month or month-day with its reference day or year; a duration as
  // its ten fields, since toString() balances the subsecond ones.
  const durationFields = ["years", "months", "weeks", "days", "hours", "minutes",
    "seconds", "milliseconds", "microseconds", "nanoseconds"];
  const exact = (v, t) => {
    if (t === "ZonedDateTime") return v.toInstant().toString() + "[" + v.timeZoneId + "]";
    if (t === "PlainYearMonth" || t === "PlainMonthDay") return v.toString({ calendarName: "critical" });
    if (t === "Duration") {
      const fields = {};
      for (const f of durationFields) if (v[f] !== 0) fields[f] = v[f];
      return { fields };
    }
    return v.toString();
  };
  function ser(v) {
    if (v === undefined) return undefined;
    if (v === null) return BAD;
    switch (typeof v) {
      // R strings cannot hold NUL or unpaired surrogates.
      case "string": return v.includes("\0") || !v.isWellFormed() ? BAD : v;
      case "boolean": return v;
      case "number": return Number.isFinite(v) && !Object.is(v, -0) ? v : BAD;
      case "bigint": return { $bigint: v.toString() };
      case "object": break;
      default: return BAD;
    }
    if (isProxy(v)) return BAD;
    const t = typeOf(v);
    if (t) {
      if (!iso(v)) return BAD;
      const e = exact(v, t);
      return typeof e === "string" ? { $type: t, value: e } : { $type: t, ...e };
    }
    if (Array.isArray(v) || Object.getPrototypeOf(v) !== Object.prototype) return BAD;
    const out = {};
    for (const key of Reflect.ownKeys(v)) {
      if (typeof key !== "string") return BAD;
      const d = Object.getOwnPropertyDescriptor(v, key);
      if (!("value" in d) || !d.enumerable) return BAD;
      if (key === "calendar" && d.value !== "iso8601") return BAD;
      const s = ser(d.value);
      if (s === BAD) return BAD;
      if (s !== undefined) out[key] = s;
    }
    return out;
  }
  function result(v) {
    if (v === undefined || v === null) return null;
    if (typeof v === "bigint") return v.toString();
    if (typeof v !== "object") return v;
    const t = typeOf(v);
    if (!t || !iso(v)) return BAD;
    return { string: v.toString(), type: t };
  }
  function record(entry, call) {
    let value, threw = false, error;
    depth++;
    try { value = call(); } catch (e) { threw = true; error = e; } finally { depth--; }
    if (entry) {
      depth++;
      try {
        if (threw) {
          const name = error instanceof RangeError ? "RangeError"
            : error instanceof TypeError ? "TypeError" : null;
          if (name) { entry.throws = name; rec.push(entry); }
        } else {
          const r = result(value);
          if (r !== BAD) { entry.result = r; rec.push(entry); }
        }
      } finally { depth--; }
    }
    if (threw) throw error;
    return value;
  }
  // R has no BigInt; a decimal string stands for one only where Temporal
  // takes epoch nanoseconds.
  const bigintAllowed = (kind, type, name, i) => i === 0 &&
    ((kind === "static" && name === "fromEpochNanoseconds") ||
     (kind === "new" && (type === "Instant" || type === "ZonedDateTime")));
  function entryFor(kind, type, name, receiver, args) {
    depth++;
    try {
      const entry = { kind, type, op: name };
      if (kind === "method" || kind === "get") {
        if (typeOf(receiver) !== type || !iso(receiver)) return null;
        entry.on = exact(receiver, type);
      }
      const out = [];
      for (const [i, a] of args.entries()) {
        if (typeof a === "bigint" && !bigintAllowed(kind, type, name, i)) return null;
        const s = ser(a);
        if (s === BAD) return null;
        out.push(s === undefined ? { $undefined: true } : s);
      }
      while (out.length && out[out.length - 1].$undefined) out.pop();
      if (out.some((a) => a.$undefined)) return null;
      entry.args = out;
      return entry;
    } finally { depth--; }
  }
  function keep(fn, wrapper) {
    Object.defineProperty(wrapper, "name", Object.getOwnPropertyDescriptor(fn, "name"));
    Object.defineProperty(wrapper, "length", Object.getOwnPropertyDescriptor(fn, "length"));
    return wrapper;
  }
  for (const t of types) {
    const C = originals[t];
    for (const key of Reflect.ownKeys(C.prototype)) {
      if (typeof key !== "string" || key === "constructor") continue;
      const d = Object.getOwnPropertyDescriptor(C.prototype, key);
      if (typeof d.value === "function") {
        const fn = d.value;
        d.value = keep(fn, { [key](...args) {
          if (depth > 0) return Reflect.apply(fn, this, args);
          return record(entryFor("method", t, key, this, args), () => Reflect.apply(fn, this, args));
        } }[key]);
      } else if (typeof d.get === "function") {
        const fn = d.get;
        d.get = keep(fn, { get() {
          if (depth > 0) return Reflect.apply(fn, this, []);
          return record(entryFor("get", t, key, this, []), () => Reflect.apply(fn, this, []));
        } }.get);
      } else continue;
      Object.defineProperty(C.prototype, key, d);
    }
    for (const key of Reflect.ownKeys(C)) {
      if (typeof key !== "string" || ["prototype", "length", "name"].includes(key)) continue;
      const d = Object.getOwnPropertyDescriptor(C, key);
      if (typeof d.value !== "function") continue;
      const fn = d.value;
      d.value = keep(fn, { [key](...args) {
        if (depth > 0) return Reflect.apply(fn, this, args);
        return record(this === C ? entryFor("static", t, key, null, args) : null,
                      () => Reflect.apply(fn, this, args));
      } }[key]);
      Object.defineProperty(C, key, d);
    }
    const proxy = new Proxy(C, {
      construct(target, args, newTarget) {
        if (depth > 0) return Reflect.construct(target, args, newTarget);
        const entry = newTarget === proxy ? entryFor("new", t, "new", null, args) : null;
        return record(entry, () => Reflect.construct(target, args, newTarget === proxy ? target : newTarget));
      },
    });
    const d = Object.getOwnPropertyDescriptor(T, t);
    d.value = proxy;
    Object.defineProperty(T, t, d);
  }
})();
`;

// Members R has no counterpart for (design 2): JavaScript conversions and
// locale formatting.
const jsOnly = new Set(["valueOf", "toJSON", "toLocaleString"]);

// The index of the options bag among each member's arguments, so that the
// bag travels as `options` (named arguments in R) rather than as a field
// bag.
function optionsIndex(kind, type, op) {
  if (kind === "static") return op === "from" ? 1 : op === "compare" && type === "Duration" ? 2 : -1;
  if (kind !== "method") return -1;
  if (["with", "add", "subtract", "until", "since"].includes(op)) return 1;
  if (["round", "total", "toString"].includes(op)) return 0;
  if (op === "toZonedDateTime" && type === "PlainDateTime") return 1;
  return -1;
}

const testRoot = join(cache, "test", "built-ins", "Temporal");
const files = walk(testRoot);
const out = {};
const skipped = new Map();
const skip = (file, reason) => {
  if (!skipped.has(reason)) skipped.set(reason, []);
  skipped.get(reason).push(relative(join(cache, "test"), file));
};
let translated = 0;
const seen = new Set();

for (const file of files) {
  const src = readFileSync(file, "utf8");
  const meta = frontmatter(src);
  const rel = relative(join(cache, "test"), file);
  if (meta.negative) { skip(file, "a negative test (an early or parse error)"); continue; }
  if (meta.flags.some((f) => ["async", "module", "raw"].includes(f))) {
    skip(file, "an async, module or raw test");
    continue;
  }
  if (/\/Now\//.test(rel)) { skip(file, "Temporal.Now: the result depends on the clock"); continue; }
  const context = vm.createContext({ __zutempoIsProxy: utilTypes.isProxy });
  try {
    vm.runInContext("delete globalThis.Temporal;", context);
    vm.runInContext(polyfill, context);
    vm.runInContext(recorder, context);
    for (const inc of ["assert.js", "sta.js", ...meta.includes]) {
      vm.runInContext(harness(inc), context, { filename: inc });
    }
    const body = meta.flags.includes("onlyStrict") ? `"use strict";\n${src}` : src;
    vm.runInContext(body, context, { filename: rel, timeout: 10000 });
  } catch (e) {
    skip(file, `fails on temporal-polyfill ${polyfillVersion}`);
    continue;
  }
  const rec = context.__zutempoRecord;
  let n = 0;
  rec.forEach((entry, i) => {
    if (jsOnly.has(entry.op)) return;
    const k = optionsIndex(entry.kind, entry.type, entry.op);
    const c = { id: `${rel}#${i + 1}`, op: entry.op };
    if (entry.kind === "get") c.get = true;
    if (entry.kind === "new") c.new = true;
    if (entry.on !== undefined) c.on = entry.on;
    const args = entry.args.slice();
    if (k >= 0 && args.length > k && args[k] && typeof args[k] === "object" && !("$type" in args[k]) && !("$bigint" in args[k])) {
      c.options = args[k];
      args.splice(k, 1);
    }
    c.args = args;
    if ("throws" in entry) c.throws = entry.throws; else c.result = entry.result;
    // One case per distinct call: test262 repeats calls across files.
    const key = createHash("sha1").update(JSON.stringify([entry.type, { ...c, id: undefined }])).digest("hex");
    if (seen.has(key)) return;
    seen.add(key);
    (out[entry.type] ??= []).push(c);
    n++;
  });
  if (n) translated++;
  else skip(file, "no call R can express (JavaScript mechanics, other calendars or duplicates)");
}

const outDir = join(root, "tests", "testthat", "test262");
mkdirSync(outDir, { recursive: true });
let cases = 0;
for (const [type, list] of Object.entries(out).sort()) {
  cases += list.length;
  const doc = { type, engine: `temporal-polyfill ${polyfillVersion}`, test262: commit, cases: list };
  // Compressed: the cases ship with the package's tests.
  writeFileSync(join(outDir, `${type}.json.gz`), gzipSync(JSON.stringify(doc) + "\n", { level: 9 }));
}

const share = (100 * translated / files.length).toFixed(1);
let report = `# test262 translation report

Written by \`tools/test262/extract.mjs\`; do not edit by hand.

- test262 commit: \`${commit}\`
- engine for the recorded results: temporal-polyfill ${polyfillVersion}
- files under \`test/built-ins/Temporal\`: ${files.length}
- files translated (at least one case): ${translated} (${share}%)
- cases written to \`tests/testthat/test262/\`: ${cases}

The share is reported, not targeted (design 11). \`tests/testthat/test-test262.R\`
runs every case; a case that fails because zutempo differs from JavaScript on
purpose (design 6.9 and 10) is listed in
\`tests/testthat/test262/differences.csv\` with the reason.

## Cases by type

| Type | Cases |
| --- | --- |
`;
for (const [type, list] of Object.entries(out).sort()) report += `| ${type} | ${list.length} |\n`;
report += `\n## Files not translated, by reason\n\n| Reason | Files |\n| --- | --- |\n`;
for (const [reason, list] of [...skipped.entries()].sort((a, b) => b[1].length - a[1].length)) {
  report += `| ${reason} | ${list.length} |\n`;
}
report += `\n<details><summary>Every file not translated</summary>\n\n`;
for (const [reason, list] of [...skipped.entries()].sort()) {
  report += `### ${reason}\n\n${list.map((f) => `- \`${f}\``).join("\n")}\n\n`;
}
report += `</details>\n`;
writeFileSync(join(here, "REPORT.md"), report);
console.log(`${translated} of ${files.length} files (${share}%), ${cases} cases`);
for (const [reason, list] of skipped) console.log(`  ${list.length}  ${reason}`);
