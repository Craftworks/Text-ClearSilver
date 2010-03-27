/*
    ClearSilver-CS.xs - Represents the CSPARSE* class

    Copyright(c) 2010 Craftworks. All rights reserved.

    See lib/Text/ClearSilver.pm for details.
*/

#include "Text-ClearSilver.h"

NEOERR*
tcs_output_to_sv(void* sv, char* s) {
    dTHX;
    assert(sv);
    assert(s);

    if(*s){
        sv_catpv((SV*)sv, s);
    }

    return STATUS_OK;
}

NEOERR*
tcs_output_to_io(void* io, char* s) {
    dTHX;
    bool ok;
    assert(io);
    assert(s);

    if(*s){
        ENTER;
        SAVETMPS;

        ok = Perl_do_print(aTHX_ newSVpvn_flags(s, strlen(s), SVs_TEMP), (PerlIO*)io);

        FREETMPS;
        LEAVE;
    }
    else {
        ok = TRUE;
    }

    return ok
        ? STATUS_OK
        : nerr_raise(NERR_IO, "Unable to output to the filehandle");
}


/*
    NOTE: Methods which seem to return NEOERR* throw errors when they fail,
          otherwise return undef.
 */

MODULE = Text::ClearSilver::CS    PACKAGE = Text::ClearSilver::CS   PREFIX = cs_

PROTOTYPES: DISABLE

void
cs_new(SV* klass, SV* hdf_src)
CODE:
{
    SV* self;
    CSPARSE* cs;
    HDF*     hdf;
    SV* hdf_sv;

    if(SvROK(klass)){
        croak("%s->new must be called as a class method", C_CS);
    }

    self = sv_newmortal();
    if(sv_derived_from(hdf_src, C_HDF) && SvROK(hdf_src)) {
        hdf    = INT2PTR(HDF*, SvUV(SvRV(hdf_src)) );
        hdf_sv = hdf_src;
    }
    else {
        hdf    = tcs_new_hdf(aTHX_ hdf_src);
        hdf_sv = sv_newmortal();
        sv_setref_pv(hdf_sv, C_HDF, hdf);
    }

    CHECK_ERR( cs_init(&cs, hdf) );

    /* Accoding to src/cgi/cgi.c,
       cgi_register_strfuncs() includes:
        url_escape
        html_escape
        text_html
        js_escape
        html_strip
        url_validate
    */
    CHECK_ERR( cgi_register_strfuncs(cs) );

    sv_setref_pv(self, SvPV_nolen_const(klass), cs);

    /* CS has a hdf */
    if(hdf_sv){
        static MGVTBL text_clearsilver_vtbl;
        sv_magicext(SvRV(self), hdf_sv, PERL_MAGIC_ext,
            &text_clearsilver_vtbl, NULL, 0);
    }
    ST(0) = self;
}

void
cs_DESTROY(Text::ClearSilver::CS cs)

void
cs_render(Text::ClearSilver::CS cs, PerlIO* ofp = NULL)
CODE:
{
    dXSTARG;
    NEOERR* err;
    if(ofp) {
        sv_setsv(TARG, &PL_sv_undef);
        err = cs_render(cs, ofp, tcs_output_to_io);
    }
    else {
        sv_setpvs(TARG, "");
        err = cs_render(cs, TARG, tcs_output_to_sv);
    }
    CHECK_ERR(err);
    ST(0) = TARG;
    XSRETURN(1);
}

NEOERR*
cs_parse_file(Text::ClearSilver::CS cs, const char* cs_file)

NEOERR*
cs_parse_string(Text::ClearSilver::CS cs, SV* in_str)
CODE:
{
    STRLEN len;
    const char* const str = SvPV_const(in_str, len);
    RETVAL = tcs_parse_string(cs, str, len);
}
OUTPUT:
    RETVAL

void
cs_dump(Text::ClearSilver::CS cs)
CODE:
{
    dXSTARG;
    sv_setpvs(TARG, "");
    cs_dump(cs, (void*)TARG, tcs_output_to_sv);
    ST(0) = TARG;
    XSRETURN(1);
}

