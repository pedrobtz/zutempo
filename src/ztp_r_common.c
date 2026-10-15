/* ztp_r_common.c -- raising conditions, and zutempo_info()'s native part. */

#include "ztp_r.h"
#include "ztp_probe.h"

void ztp_r_raise(const ztp_ctx *ctx)
{
    /* stop_zutempo(message, kind, index) in the package namespace. The
       index travels as a double so that long vectors are covered; R turns
       0 into NULL. */
    SEXP name = PROTECT(Rf_mkString("zutempo"));
    SEXP ns = PROTECT(R_FindNamespace(name));
    SEXP message = PROTECT(Rf_mkString(ctx->msg));
    SEXP kind = PROTECT(Rf_mkString(ztp_status_kind(ctx->status)));
    SEXP index = PROTECT(Rf_ScalarReal((double)ctx->index));
    SEXP call = PROTECT(Rf_lang4(Rf_install("stop_zutempo"), message, kind,
                                 index));
    Rf_eval(call, ns);
    /* Not reached: stop_zutempo() signals an error. Unprotect for form. */
    UNPROTECT(6);
    Rf_error("zutempo: stop_zutempo() returned");
}

SEXP ztp_r_info(void)
{
    const char *names[] = {"zufast", "int128", ""};
    SEXP out = PROTECT(Rf_mkNamed(VECSXP, names));
    SET_VECTOR_ELT(out, 0, Rf_mkString(ztp_probe_zufast_version()));
    SET_VECTOR_ELT(out, 1, Rf_ScalarLogical(ztp_probe_have_int128()));
    UNPROTECT(1);
    return out;
}
