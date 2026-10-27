## Submission

This is a new submission.

## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new submission.

## Test environments

`R CMD check --as-cran` on GitHub Actions (pedrobtz/r-actions):

* macOS, R release
* Windows, R release and R-devel
* Ubuntu, R release and R oldrel-1
* R-devel containers: clang23, ubuntu-clang, ubuntu-gcc16
* R-hub images: nosuggests (no suggested packages) and nold (no long
  doubles)
* The same runners with the package built without the compiler's
  `__int128`

The compiled code is also run under ASan and UBSan, valgrind, rchk, LTO
and gctorture.

## Method References

The package implements the Temporal proposal of 'ECMA-262', specified at
<https://tc39.es/proposal-temporal/>. There are no published papers
describing the methods.
