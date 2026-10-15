# test262 translation

`extract.mjs` turns test262's Temporal tests into cases the R suite runs
(design 11, roadmap stage 11). Each test file runs under Node in a fresh
`vm` context with test262's harness and `temporal-polyfill`'s script build,
whose Temporal records every call the test makes into it. A file whose
assertions all pass contributes the calls R can express, with the results
those assertions accept. `REPORT.md` gives the share translated and the
reason for every file left out.

```sh
# A sparse checkout of test262 at the pinned commit (inst/spec/PINS).
C=tools/test262/cache
git init -q $C
git -C $C remote add origin https://github.com/tc39/test262.git
git -C $C sparse-checkout set --no-cone /harness/ /test/built-ins/Temporal/
git -C $C fetch -q --depth 1 --filter=blob:none origin "$(sed -n 's/^Test262Commit: //p' inst/spec/PINS)"
git -C $C checkout -q FETCH_HEAD

# The polyfill comes from the oracle's pinned dependencies.
(cd tools/temporal-oracle && npm ci)

node tools/test262/extract.mjs   # writes tests/testthat/test262/*.json.gz and REPORT.md
```

Run it with a Node that has no native Temporal, or the context's native one
is replaced; either way the polyfill is what records. Regenerate when the
test262 pin or the polyfill changes, then rerun
`devtools::test(filter = "test262")`. A new failure is a bug to fix, or a
deliberate difference to add to `tests/testthat/test262/differences.csv`
with its reason.
