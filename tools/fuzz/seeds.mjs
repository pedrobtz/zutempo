// Write the seed corpora of the RFC 9557 and duration fuzz targets
// (design 11) under tools/fuzz/corpus/: the strings of the oracle cases
// and the ISO strings of test262's harness/temporalHelpers.js at the
// pinned commit (inst/spec/PINS). One file per distinct string, named by
// its SHA-1 as libFuzzer names corpus files.
//
//   node tools/fuzz/seeds.mjs
//
// Needs Node 18 or later (fetch). Regenerate when the oracle or the
// test262 pin changes.

import { createHash } from "node:crypto";
import { readFileSync, readdirSync, mkdirSync, rmSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, "..", "..");
const pins = readFileSync(join(root, "inst", "spec", "PINS"), "utf8");
const test262 = /^Test262Commit:\s*(\S+)/m.exec(pins)[1];

const strings = new Set();
const collect = (value) => {
  if (typeof value === "string") strings.add(value);
  else if (Array.isArray(value)) value.forEach(collect);
  else if (value && typeof value === "object") Object.values(value).forEach(collect);
};
const oracle = join(root, "tests", "testthat", "oracle");
for (const file of readdirSync(oracle).filter((f) => f.endsWith(".json"))) {
  for (const c of JSON.parse(readFileSync(join(oracle, file), "utf8")).cases) {
    collect(c.on);
    collect(c.args);
    collect(c.options);
    if (c.result) collect(c.result.string);
  }
}
const url = `https://raw.githubusercontent.com/tc39/test262/${test262}/harness/temporalHelpers.js`;
const helpers = await (await fetch(url)).text();
for (const m of helpers.matchAll(/"((?:[^"\\\n]|\\.)*)"/g)) strings.add(m[1]);

// A string goes to the duration corpus when it starts like one, to the
// RFC 9557 corpus when it has a digit or a bracket.
const corpora = {
  duration: [...strings].filter((s) => /^[+-]?[Pp]/.test(s)),
  rfc9557: [...strings].filter((s) => /[0-9[]/.test(s) && !/^[+-]?[Pp]/.test(s)),
};
for (const [name, list] of Object.entries(corpora)) {
  const dir = join(here, "corpus", name);
  rmSync(dir, { recursive: true, force: true });
  mkdirSync(dir, { recursive: true });
  for (const s of list) {
    writeFileSync(join(dir, createHash("sha1").update(s).digest("hex")), s);
  }
  console.log(`${name}: ${list.length} seeds`);
}
