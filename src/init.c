/*
 * init.c -- registration of the package's native routines.
 *
 * Every symbol but R_init_zutempo is hidden (src/Makevars passes
 * $(C_VISIBILITY)), so the entry point carries attribute_visible. R
 * reaches native code through the registered table alone:
 * R_useDynamicSymbols(dll, FALSE) stops .Call() from looking up symbols
 * by name, and R_forceSymbols(dll, TRUE) makes the R side use the
 * registered symbol objects rather than strings.
 */

#define R_NO_REMAP
#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>
#include <R_ext/Visibility.h>

static const R_CallMethodDef call_methods[] = {
  {NULL, NULL, 0}
};

attribute_visible void R_init_zutempo(DllInfo *dll) {
  R_registerRoutines(dll, NULL, call_methods, NULL, NULL);
  R_useDynamicSymbols(dll, FALSE);
  R_forceSymbols(dll, TRUE);
}
