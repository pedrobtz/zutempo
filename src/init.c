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

#include "ztp_r.h"

#include <R_ext/Rdynload.h>
#include <R_ext/Visibility.h>

static const R_CallMethodDef call_methods[] = {
    {"ztp_r_info", (DL_FUNC)&ztp_r_info, 0},
    {"ztp_r_probe_civil", (DL_FUNC)&ztp_r_probe_civil, 1},
    {"ztp_r_probe_mul", (DL_FUNC)&ztp_r_probe_mul, 2},
    {"ztp_r_probe_fail", (DL_FUNC)&ztp_r_probe_fail, 2},
    {NULL, NULL, 0}
};

attribute_visible void R_init_zutempo(DllInfo *dll)
{
    R_registerRoutines(dll, NULL, call_methods, NULL, NULL);
    R_useDynamicSymbols(dll, FALSE);
    R_forceSymbols(dll, TRUE);
}
