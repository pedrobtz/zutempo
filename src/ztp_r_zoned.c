/*
 * ztp_r_zoned.c -- .Call glue for ZonedDateTime (design 4.2). A vector is
 * a complex instant per element (as Instant) with an integer zone code per
 * element into a table of identifiers; the glue opens each identifier of
 * the table once and loops over the elements.
 */

#include "ztp_r.h"
#include "ztp_zoned.h"
#include "ztp_parse.h"
#include "ztp_relative.h"

#include <string.h>

/* The zones of a table, parsed; the identifiers are canonical and loaded
   (R/tz.R did that), so a failure here is a programming error. */
static ztp_zone *ztp_r_zones_open(SEXP zones)
{
    R_xlen_t n = Rf_xlength(zones);
    ztp_zone *out = (ztp_zone *)R_alloc((size_t)(n ? n : 1), sizeof *out);
    ztp_ctx ctx;

    ztp_ctx_init(&ctx);
    for (R_xlen_t i = 0; i < n; i++) {
        const char *s = Rf_translateCharUTF8(STRING_ELT(zones, i));
        if (ztp_zone_parse(&ctx, (size_t)i + 1, s, strlen(s), &out[i]) != ZTP_OK) ztp_r_raise(&ctx);
    }
    return out;
}

static const ztp_zone *ztp_r_zone_of(const ztp_zone *zones, SEXP codes, R_xlen_t i)
{
    int code = INTEGER(codes)[i];
    return code == NA_INTEGER ? NULL : &zones[code - 1];
}

static bool ztp_r_zoned_get(SEXP x, R_xlen_t i, zuf_i128 *ns)
{
    const Rcomplex *p = COMPLEX(x);
    if (ISNAN(p[i].r)) return false;
    *ns = ztp_epoch_ns_join(p[i].r, p[i].i);
    return true;
}

static void ztp_r_zoned_put(SEXP out, R_xlen_t i, zuf_i128 ns)
{
    ztp_epoch_ns_split(ns, &COMPLEX(out)[i].r, &COMPLEX(out)[i].i);
}

static void ztp_r_zoned_put_na(SEXP out, R_xlen_t i)
{
    COMPLEX(out)[i].r = NA_REAL;
    COMPLEX(out)[i].i = NA_REAL;
}

/* InterpretISODateTimeOffset over vectors: local days and nanoseconds of
   day, zone codes, a behaviour per element, an offset per element (NA
   when the behaviour needs none), and whether the offset matches to the
   minute. The options are scalars. */
SEXP ztp_r_zoned_interpret(SEXP days, SEXP ns, SEXP codes, SEXP zones, SEXP behaviour,
                           SEXP offset_ns, SEXP disambiguation, SEXP offset_option,
                           SEXP match_minutes)
{
    R_xlen_t n = Rf_xlength(days);
    const ztp_zone *tz = ztp_r_zones_open(zones);
    const double *pd = REAL(days), *pn = REAL(ns), *po = REAL(offset_ns);
    const int *pb = INTEGER(behaviour), *pm = LOGICAL(match_minutes);
    ztp_disambiguation dis = (ztp_disambiguation)Rf_asInteger(disambiguation);
    ztp_offset_option opt = (ztp_offset_option)Rf_asInteger(offset_option);
    SEXP out = PROTECT(Rf_allocVector(CPLXSXP, n));
    ztp_ctx ctx;

    ztp_ctx_init(&ctx);
    for (R_xlen_t i = 0; i < n; i++) {
        const ztp_zone *zone = ztp_r_zone_of(tz, codes, i);
        zuf_i128 result;
        if (zone == NULL || ISNAN(pd[i]) || ISNAN(pn[i])) {
            ztp_r_zoned_put_na(out, i);
            continue;
        }
        if (ztp_interpret_iso_date_time_offset(&ctx, (size_t)i + 1, (int64_t)pd[i], (int64_t)pn[i],
                                               (ztp_offset_behaviour)pb[i],
                                               ISNAN(po[i]) ? 0 : (int64_t)po[i], zone, dis, opt,
                                               pm[i] == TRUE, &result) != ZTP_OK)
            ztp_r_raise(&ctx);
        ztp_r_zoned_put(out, i, result);
    }
    UNPROTECT(1);
    return out;
}

/* ParseISODateTime with TemporalDateTimeString[+Zoned]: the parts the R
   side needs to resolve the zone and interpret the offset. */
SEXP ztp_r_zoned_parse(SEXP x)
{
    R_xlen_t n = Rf_xlength(x);
    const char *names[] = {"day", "ns", "behaviour", "offset_ns", "match_minutes", "tz", ""};
    SEXP out = PROTECT(Rf_mkNamed(VECSXP, names));
    SEXP day = SET_VECTOR_ELT(out, 0, Rf_allocVector(REALSXP, n));
    SEXP ns = SET_VECTOR_ELT(out, 1, Rf_allocVector(REALSXP, n));
    SEXP behaviour = SET_VECTOR_ELT(out, 2, Rf_allocVector(INTSXP, n));
    SEXP offset = SET_VECTOR_ELT(out, 3, Rf_allocVector(REALSXP, n));
    SEXP match = SET_VECTOR_ELT(out, 4, Rf_allocVector(LGLSXP, n));
    SEXP tz = SET_VECTOR_ELT(out, 5, Rf_allocVector(STRSXP, n));
    ztp_ctx ctx;

    ztp_ctx_init(&ctx);
    for (R_xlen_t i = 0; i < n; i++) {
        ztp_parsed p;
        ztp_iso_date d;
        const char *s;

        if (STRING_ELT(x, i) == NA_STRING) {
            REAL(day)[i] = NA_REAL;
            REAL(ns)[i] = NA_REAL;
            INTEGER(behaviour)[i] = NA_INTEGER;
            REAL(offset)[i] = NA_REAL;
            LOGICAL(match)[i] = NA_LOGICAL;
            SET_STRING_ELT(tz, i, NA_STRING);
            continue;
        }
        s = Rf_translateCharUTF8(STRING_ELT(x, i));
        if (ztp_parse(&ctx, (size_t)i + 1, s, strlen(s), ZTP_PARSE_ZONED, &p, NULL) != ZTP_OK)
            ztp_r_raise(&ctx);
        d.year = p.year;
        d.month = p.month;
        d.day = p.day;
        REAL(day)[i] = (double)ztp_epoch_day_from_iso_date(&d);
        REAL(ns)[i] = (double)ztp_ns_from_iso_time(&p.time);
        INTEGER(behaviour)[i] = !p.has_time ? ZTP_OFFSET_BEHAVIOUR_START_OF_DAY
                                : p.has_z ? ZTP_OFFSET_BEHAVIOUR_EXACT
                                : p.has_offset ? ZTP_OFFSET_BEHAVIOUR_OPTION
                                : ZTP_OFFSET_BEHAVIOUR_WALL;
        REAL(offset)[i] = p.has_offset ? (double)p.offset_ns : NA_REAL;
        LOGICAL(match)[i] = !p.offset_has_seconds;
        SET_STRING_ELT(tz, i, Rf_mkCharCE(p.tz, CE_UTF8));
    }
    UNPROTECT(1);
    return out;
}

/* GetISODateTimeFor: the local date-time as a PlainDateTime vector. */
SEXP ztp_r_zoned_local(SEXP x, SEXP codes, SEXP zones)
{
    R_xlen_t n = Rf_xlength(x);
    const ztp_zone *tz = ztp_r_zones_open(zones);
    SEXP out = PROTECT(Rf_allocVector(CPLXSXP, n));

    for (R_xlen_t i = 0; i < n; i++) {
        const ztp_zone *zone = ztp_r_zone_of(tz, codes, i);
        zuf_i128 epoch;
        int32_t day;
        int64_t ns_of_day;
        if (zone == NULL || !ztp_r_zoned_get(x, i, &epoch)) {
            ztp_r_zoned_put_na(out, i);
            continue;
        }
        ztp_zoned_local(zone, epoch, &day, &ns_of_day, NULL);
        COMPLEX(out)[i].r = (double)day;
        COMPLEX(out)[i].i = (double)ns_of_day;
    }
    UNPROTECT(1);
    return out;
}

/* GetOffsetNanosecondsFor per element. */
SEXP ztp_r_zoned_offset(SEXP x, SEXP codes, SEXP zones)
{
    R_xlen_t n = Rf_xlength(x);
    const ztp_zone *tz = ztp_r_zones_open(zones);
    SEXP out = PROTECT(Rf_allocVector(REALSXP, n));

    for (R_xlen_t i = 0; i < n; i++) {
        const ztp_zone *zone = ztp_r_zone_of(tz, codes, i);
        zuf_i128 epoch;
        if (zone == NULL || !ztp_r_zoned_get(x, i, &epoch)) {
            REAL(out)[i] = NA_REAL;
            continue;
        }
        REAL(out)[i] = (double)ztp_zone_offset_at(zone, epoch);
    }
    UNPROTECT(1);
    return out;
}

SEXP ztp_r_zoned_start_of_day(SEXP x, SEXP codes, SEXP zones)
{
    R_xlen_t n = Rf_xlength(x);
    const ztp_zone *tz = ztp_r_zones_open(zones);
    SEXP out = PROTECT(Rf_allocVector(CPLXSXP, n));
    ztp_ctx ctx;

    ztp_ctx_init(&ctx);
    for (R_xlen_t i = 0; i < n; i++) {
        const ztp_zone *zone = ztp_r_zone_of(tz, codes, i);
        zuf_i128 epoch, start;
        int32_t day;
        int64_t ns_of_day;
        if (zone == NULL || !ztp_r_zoned_get(x, i, &epoch)) {
            ztp_r_zoned_put_na(out, i);
            continue;
        }
        ztp_zoned_local(zone, epoch, &day, &ns_of_day, NULL);
        if (ztp_zone_start_of_day(&ctx, (size_t)i + 1, zone, day, &start) != ZTP_OK) ztp_r_raise(&ctx);
        ztp_r_zoned_put(out, i, start);
    }
    UNPROTECT(1);
    return out;
}

SEXP ztp_r_zoned_hours_in_day(SEXP x, SEXP codes, SEXP zones)
{
    R_xlen_t n = Rf_xlength(x);
    const ztp_zone *tz = ztp_r_zones_open(zones);
    SEXP out = PROTECT(Rf_allocVector(REALSXP, n));
    ztp_ctx ctx;

    ztp_ctx_init(&ctx);
    for (R_xlen_t i = 0; i < n; i++) {
        const ztp_zone *zone = ztp_r_zone_of(tz, codes, i);
        zuf_i128 epoch;
        double hours;
        if (zone == NULL || !ztp_r_zoned_get(x, i, &epoch)) {
            REAL(out)[i] = NA_REAL;
            continue;
        }
        if (ztp_zoned_hours_in_day(&ctx, (size_t)i + 1, zone, epoch, &hours) != ZTP_OK) ztp_r_raise(&ctx);
        REAL(out)[i] = hours;
    }
    UNPROTECT(1);
    return out;
}

SEXP ztp_r_zoned_format(SEXP x, SEXP codes, SEXP zones, SEXP precision, SEXP show_offset,
                        SEXP show_zone)
{
    R_xlen_t n = Rf_xlength(x);
    const ztp_zone *tz = ztp_r_zones_open(zones);
    int prec = Rf_asInteger(precision);
    bool offset = Rf_asLogical(show_offset) == TRUE;
    ztp_show_zone zone_mode = (ztp_show_zone)Rf_asInteger(show_zone);
    SEXP out = PROTECT(Rf_allocVector(STRSXP, n));

    for (R_xlen_t i = 0; i < n; i++) {
        const ztp_zone *zone = ztp_r_zone_of(tz, codes, i);
        zuf_i128 epoch;
        char buf[ZTP_FORMAT_ZONED_CAP];
        if (zone == NULL || !ztp_r_zoned_get(x, i, &epoch)) {
            SET_STRING_ELT(out, i, NA_STRING);
            continue;
        }
        ztp_format_zoned(buf, epoch, zone, prec, offset, zone_mode);
        SET_STRING_ELT(out, i, Rf_mkCharCE(buf, CE_UTF8));
    }
    UNPROTECT(1);
    return out;
}

/* TimeZoneEquals over pairs of identifiers. */
SEXP ztp_r_zone_equals(SEXP a, SEXP b)
{
    R_xlen_t n = Rf_xlength(a);
    SEXP out = PROTECT(Rf_allocVector(LGLSXP, n));
    ztp_ctx ctx;

    ztp_ctx_init(&ctx);
    for (R_xlen_t i = 0; i < n; i++) {
        ztp_zone za, zb;
        const char *sa, *sb;
        if (STRING_ELT(a, i) == NA_STRING || STRING_ELT(b, i) == NA_STRING) {
            LOGICAL(out)[i] = NA_LOGICAL;
            continue;
        }
        sa = Rf_translateCharUTF8(STRING_ELT(a, i));
        sb = Rf_translateCharUTF8(STRING_ELT(b, i));
        if (ztp_zone_parse(&ctx, (size_t)i + 1, sa, strlen(sa), &za) != ZTP_OK ||
            ztp_zone_parse(&ctx, (size_t)i + 1, sb, strlen(sb), &zb) != ZTP_OK)
            ztp_r_raise(&ctx);
        LOGICAL(out)[i] = ztp_zone_equals(&za, &zb);
    }
    UNPROTECT(1);
    return out;
}

/* FormatUTCOffsetNanoseconds over offsets in nanoseconds. */
SEXP ztp_r_format_offset_exact(SEXP offset_ns)
{
    R_xlen_t n = Rf_xlength(offset_ns);
    SEXP out = PROTECT(Rf_allocVector(STRSXP, n));

    for (R_xlen_t i = 0; i < n; i++) {
        char buf[24];
        if (ISNAN(REAL(offset_ns)[i])) {
            SET_STRING_ELT(out, i, NA_STRING);
            continue;
        }
        ztp_format_offset_exact(buf, (int64_t)REAL(offset_ns)[i]);
        SET_STRING_ELT(out, i, Rf_mkCharCE(buf, CE_UTF8));
    }
    UNPROTECT(1);
    return out;
}

/* ParseDateTimeUTCOffset: an offset string with optional seconds and
   fraction, to nanoseconds; for the offset field of with() and from(). */
SEXP ztp_r_parse_offset_string(SEXP x)
{
    R_xlen_t n = Rf_xlength(x);
    SEXP out = PROTECT(Rf_allocVector(REALSXP, n));
    ztp_ctx ctx;

    ztp_ctx_init(&ctx);
    for (R_xlen_t i = 0; i < n; i++) {
        const char *s;
        size_t len;
        ztp_parsed p;
        char buf[80];
        if (STRING_ELT(x, i) == NA_STRING) {
            REAL(out)[i] = NA_REAL;
            continue;
        }
        s = Rf_translateCharUTF8(STRING_ELT(x, i));
        len = strlen(s);
        /* Reuse the time grammar: "00:00" followed by the offset parses as
           a time with an offset, and nothing else is accepted. */
        if (len == 0 || len > 40 || (s[0] != '+' && s[0] != '-')) {
            ztp_fail(&ctx, ZTP_ERR_RANGE, (size_t)i + 1, "\"%.40s\" is not a UTC offset", s);
            ztp_r_raise(&ctx);
        }
        memcpy(buf, "T00:00", 6);
        memcpy(buf + 6, s, len + 1);
        if (ztp_parse(&ctx, (size_t)i + 1, buf, len + 6, ZTP_PARSE_TIME, &p, NULL) != ZTP_OK ||
            !p.has_offset || p.has_tz) {
            ztp_ctx_init(&ctx);
            ztp_fail(&ctx, ZTP_ERR_RANGE, (size_t)i + 1, "\"%.40s\" is not a UTC offset", s);
            ztp_r_raise(&ctx);
        }
        REAL(out)[i] = (double)p.offset_ns;
    }
    UNPROTECT(1);
    return out;
}
