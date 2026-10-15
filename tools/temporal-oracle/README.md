# temporal-oracle

Generates the oracle cases under `tests/testthat/oracle/` from
`temporal-polyfill`, pinned by `package.json` and `package-lock.json`
(design §11). The cases are data in `cases.js`; the expected values come
from the engine, never from a person.

```sh
cd tools/temporal-oracle
npm ci                 # the pinned polyfill
npm run generate       # rewrites tests/testthat/oracle/*.json
npm run check-native   # Node 26+: diff the polyfill against native Temporal
```

Commit the regenerated JSON with the change to `cases.js` that produced it.
`tests/testthat/helper-oracle.R` runs every case of a file against the R
functions.
