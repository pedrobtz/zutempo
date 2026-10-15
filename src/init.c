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
    {"ztp_r_plain_date_from_fields", (DL_FUNC)&ztp_r_plain_date_from_fields, 4},
    {"ztp_r_plain_date_parse", (DL_FUNC)&ztp_r_plain_date_parse, 1},
    {"ztp_r_plain_date_field", (DL_FUNC)&ztp_r_plain_date_field, 2},
    {"ztp_r_plain_date_format", (DL_FUNC)&ztp_r_plain_date_format, 2},
    {"ztp_r_plain_time_from_fields", (DL_FUNC)&ztp_r_plain_time_from_fields, 7},
    {"ztp_r_plain_time_parse", (DL_FUNC)&ztp_r_plain_time_parse, 1},
    {"ztp_r_plain_time_field", (DL_FUNC)&ztp_r_plain_time_field, 2},
    {"ztp_r_plain_time_round", (DL_FUNC)&ztp_r_plain_time_round, 4},
    {"ztp_r_plain_time_format", (DL_FUNC)&ztp_r_plain_time_format, 2},
    {"ztp_r_plain_date_time_from_fields", (DL_FUNC)&ztp_r_plain_date_time_from_fields, 10},
    {"ztp_r_plain_date_time_parse", (DL_FUNC)&ztp_r_plain_date_time_parse, 1},
    {"ztp_r_plain_date_time_combine", (DL_FUNC)&ztp_r_plain_date_time_combine, 2},
    {"ztp_r_plain_date_time_field", (DL_FUNC)&ztp_r_plain_date_time_field, 2},
    {"ztp_r_plain_date_time_round", (DL_FUNC)&ztp_r_plain_date_time_round, 4},
    {"ztp_r_plain_date_time_format", (DL_FUNC)&ztp_r_plain_date_time_format, 3},
    {"ztp_r_plain_year_month_from_fields", (DL_FUNC)&ztp_r_plain_year_month_from_fields, 3},
    {"ztp_r_plain_year_month_parse", (DL_FUNC)&ztp_r_plain_year_month_parse, 1},
    {"ztp_r_plain_year_month_format", (DL_FUNC)&ztp_r_plain_year_month_format, 2},
    {"ztp_r_plain_month_day_from_fields", (DL_FUNC)&ztp_r_plain_month_day_from_fields, 4},
    {"ztp_r_plain_month_day_parse", (DL_FUNC)&ztp_r_plain_month_day_parse, 1},
    {"ztp_r_plain_month_day_format", (DL_FUNC)&ztp_r_plain_month_day_format, 2},
    {"ztp_r_parse_describe", (DL_FUNC)&ztp_r_parse_describe, 3},
    {"ztp_r_instant_parse", (DL_FUNC)&ztp_r_instant_parse, 1},
    {"ztp_r_instant_from_epoch_ms", (DL_FUNC)&ztp_r_instant_from_epoch_ms, 1},
    {"ztp_r_instant_from_epoch_ns", (DL_FUNC)&ztp_r_instant_from_epoch_ns, 1},
    {"ztp_r_instant_epoch_ms", (DL_FUNC)&ztp_r_instant_epoch_ms, 1},
    {"ztp_r_instant_epoch_ns_string", (DL_FUNC)&ztp_r_instant_epoch_ns_string, 1},
    {"ztp_r_instant_add", (DL_FUNC)&ztp_r_instant_add, 2},
    {"ztp_r_instant_until", (DL_FUNC)&ztp_r_instant_until, 6},
    {"ztp_r_instant_round", (DL_FUNC)&ztp_r_instant_round, 4},
    {"ztp_r_instant_format", (DL_FUNC)&ztp_r_instant_format, 3},
    {"ztp_r_zone_normalise", (DL_FUNC)&ztp_r_zone_normalise, 1},
    {"ztp_r_zoned_interpret", (DL_FUNC)&ztp_r_zoned_interpret, 9},
    {"ztp_r_zoned_parse", (DL_FUNC)&ztp_r_zoned_parse, 1},
    {"ztp_r_zoned_local", (DL_FUNC)&ztp_r_zoned_local, 3},
    {"ztp_r_zoned_offset", (DL_FUNC)&ztp_r_zoned_offset, 3},
    {"ztp_r_zoned_start_of_day", (DL_FUNC)&ztp_r_zoned_start_of_day, 3},
    {"ztp_r_zoned_hours_in_day", (DL_FUNC)&ztp_r_zoned_hours_in_day, 3},
    {"ztp_r_zoned_format", (DL_FUNC)&ztp_r_zoned_format, 6},
    {"ztp_r_zone_equals", (DL_FUNC)&ztp_r_zone_equals, 2},
    {"ztp_r_format_offset_exact", (DL_FUNC)&ztp_r_format_offset_exact, 1},
    {"ztp_r_parse_offset_string", (DL_FUNC)&ztp_r_parse_offset_string, 1},
    {"ztp_r_tz_load", (DL_FUNC)&ztp_r_tz_load, 2},
    {"ztp_r_tz_reset", (DL_FUNC)&ztp_r_tz_reset, 0},
    {"ztp_r_tz_loaded", (DL_FUNC)&ztp_r_tz_loaded, 1},
    {"ztp_r_tz_utoff", (DL_FUNC)&ztp_r_tz_utoff, 2},
    {"ztp_r_tz_possible", (DL_FUNC)&ztp_r_tz_possible, 3},
    {"ztp_r_tz_transition", (DL_FUNC)&ztp_r_tz_transition, 3},
    {"ztp_r_tz_last_explicit", (DL_FUNC)&ztp_r_tz_last_explicit, 1},
    {"ztp_r_tz_links_version", (DL_FUNC)&ztp_r_tz_links_version, 0},
    {"ztp_r_tz_link_target", (DL_FUNC)&ztp_r_tz_link_target, 1},
    {"ztp_r_tz_rule_utoff", (DL_FUNC)&ztp_r_tz_rule_utoff, 2},
    {"ztp_r_duration_create", (DL_FUNC)&ztp_r_duration_create, 1},
    {"ztp_r_duration_parse", (DL_FUNC)&ztp_r_duration_parse, 1},
    {"ztp_r_duration_format", (DL_FUNC)&ztp_r_duration_format, 2},
    {"ztp_r_duration_add", (DL_FUNC)&ztp_r_duration_add, 2},
    {"ztp_r_duration_round", (DL_FUNC)&ztp_r_duration_round, 7},
    {"ztp_r_duration_total", (DL_FUNC)&ztp_r_duration_total, 3},
    {"ztp_r_duration_compare", (DL_FUNC)&ztp_r_duration_compare, 3},
    {"ztp_r_plain_date_add", (DL_FUNC)&ztp_r_plain_date_add, 3},
    {"ztp_r_plain_date_until", (DL_FUNC)&ztp_r_plain_date_until, 6},
    {"ztp_r_plain_time_add", (DL_FUNC)&ztp_r_plain_time_add, 2},
    {"ztp_r_plain_time_until", (DL_FUNC)&ztp_r_plain_time_until, 6},
    {"ztp_r_plain_date_time_add", (DL_FUNC)&ztp_r_plain_date_time_add, 3},
    {"ztp_r_plain_date_time_until", (DL_FUNC)&ztp_r_plain_date_time_until, 6},
    {"ztp_r_plain_year_month_add", (DL_FUNC)&ztp_r_plain_year_month_add, 3},
    {"ztp_r_plain_year_month_until", (DL_FUNC)&ztp_r_plain_year_month_until, 6},
    {NULL, NULL, 0}
};

attribute_visible void R_init_zutempo(DllInfo *dll)
{
    R_registerRoutines(dll, NULL, call_methods, NULL, NULL);
    R_useDynamicSymbols(dll, FALSE);
    R_forceSymbols(dll, TRUE);
}
