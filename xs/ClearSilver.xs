/*
    Text-ClearSilver.xs -  The template processor class

    Copyright(c) 2010 Craftworks. All rights reserved.

    See lib/Text/ClearSilver.pm for details.
*/

#define NEED_newSVpvn_flags_GLOBAL
#define NO_XSLOCKS
#include "Text-ClearSilver.h"

void
tcs_throw_error(pTHX_ NEOERR* const err) {
    SV* sv;
    STRING errstr;
    string_init(&errstr);
    nerr_error_string(err, &errstr);
    sv = newSVpvn_flags(errstr.buf, errstr.len, SVs_TEMP);
    string_clear(&errstr);

    Perl_croak(aTHX_ "ClearSilver: %"SVf, sv);
}

static const char*
tcs_get_class_name(pTHX_ SV* const self) {
    if(SvROK(self) && SvOBJECT(SvRV(self))){
        HV* const stash = SvSTASH(SvRV(self));
        return HvNAME_get(stash);
    }
    else {
        return SvPV_nolen_const(self);
    }
}

static HV*
tcs_buildargs(pTHX_ SV* const self, I32 const ax, I32 const items) {
    HV* args;

    if(items == 1){
        SV* const args_ref = ST(0);
        SvGETMAGIC(args_ref);
        if(!(SvROK(args_ref) && SvTYPE(SvRV(args_ref)) == SVt_PVHV
                && !SvOBJECT(SvRV(args_ref)) )){
            croak("Single parameters to %s's configure routine must be a HASH ref",
                tcs_get_class_name(aTHX_ self));
        }
        args = newHVhv((HV*)SvRV(args_ref));
        sv_2mortal((SV*)args);
    }
    else{
        I32 i;

        if( (items % 2) != 0 ){
            croak("Odd number of parameters to %s's configure routine",
                tcs_get_class_name(aTHX_ self));
        }

        args = newHV();
        sv_2mortal((SV*)args);
        for(i = 0; i < items; i += 2){
            (void)hv_store_ent(args, ST(i), newSVsv(ST(i+1)), 0U);
        }

    }
    return args;
}

static PerlIO*
tcs_sv2io(pTHX_ SV* sv, const char* const mode, int const imode, bool* const need_closep) {
    if(isGV(sv) || (SvROK(sv) && (isGV(SvRV(sv)) || SvTYPE(SvRV(sv)) == SVt_PVIO))){
        return IoIFP(sv_2io(sv));
    }
    else {
        PerlIO* const fp = PerlIO_openn(aTHX_
            NULL, mode, -1, imode, 0, NULL, 1, &sv);
        if(!fp){
            croak("Cannot open %"SVf": %"SVf, sv, get_sv("!", GV_ADD));
        }
        *need_closep = TRUE;
        return fp;
    }
}

static void
tcs_set_config(pTHX_ HDF* const hdf, HV* const config) {
    SV** svp = hv_fetchs(config, "VarEscapeMode", FALSE);
    if(svp && sv_true(*svp)){
        hdf_set_value(hdf, "Config.VarEscapeMode", SvPV_nolen_const(*svp));
    }

    svp = hv_fetchs(config, "TagStart", FALSE);
    if(svp && sv_true(*svp)){
        hdf_set_value(hdf, "Config.TagStart", SvPV_nolen_const(*svp));
    }

    svp = hv_fetchs(config, "EnableAuditMode", FALSE);
    if(svp && SvOK(*svp)){
        hdf_set_int_value(hdf, "Config.EnableAuditMode", sv_true(*svp));
    }
}

MODULE = Text::ClearSilver    PACKAGE = Text::ClearSilver

PROTOTYPES: DISABLE

BOOT:
{
    XS(boot_Text__ClearSilver__HDF);
    XS(boot_Text__ClearSilver__CS);

    PUSHMARK(SP);
    boot_Text__ClearSilver__HDF(aTHX_ cv);
    SPAGAIN;

    PUSHMARK(SP);
    boot_Text__ClearSilver__CS(aTHX_ cv);
    SPAGAIN;
}

void
new(SV* klass, ...)
CODE:
{
    SV* self;
    if(SvROK(klass)){
        croak("Cannot %s->new as an instance method", "Text::ClearSilver");
    }

    /* shift @_ */
    ax++;
    items--;
    self = newRV_inc((SV*)tcs_buildargs(aTHX_ klass, ax, items));
    sv_2mortal(self);
    ST(0) = sv_bless(self, gv_stashsv(klass, GV_ADD));
    XSRETURN(1);
}

#define DEFAULT_OUT ((SV*)PL_defoutgv)

void
process(SV* self, SV* src, SV* vars, SV* volatile dest = DEFAULT_OUT, ...)
CODE:
{
    dXCPT;
    HV* volatile args    = NULL;
    CSPARSE*  cs         = NULL;
    HDF*     hdf         = NULL;
    bool need_ifp_close  = FALSE;
    bool need_ofp_close  = FALSE;
    PerlIO* volatile ifp = NULL;
    PerlIO* volatile ofp = NULL;

    if(!( SvROK(self) && SvOBJECT(SvRV(self)) )){
        croak("Cannot %s->process as a class method", "Text::ClearSilver");
    }

    if(items > 4){
        args = tcs_buildargs(aTHX_ self, ax + 4, items - 4);
    }

    SvGETMAGIC(src);

    XCPT_TRY_START {
        ofp = tcs_sv2io(aTHX_ dest, "w", O_WRONLY|O_CREAT|O_TRUNC, &need_ofp_close);

        hdf = tcs_new_hdf(aTHX_ vars);

        tcs_set_config(aTHX_ hdf, (HV*)SvRV(self));
        if(args) {
            tcs_set_config(aTHX_ hdf, args);
        }

        CHECK_ERR( cs_init(&cs, hdf) );
        CHECK_ERR( cgi_register_strfuncs(cs) );

        if(SvROK(src)){
            STRLEN len;
            const char* pv;
            char* buff;
            if(SvTYPE(SvRV(src)) > SVt_PVMG){
                croak("Source must be a scalar reference or a filename, not %"SVf, src);
            }
            pv   = SvPV_const(SvRV(src), len);
            buff = (char*)malloc(len);
            if(!buff) {
                croak("ClearSilver: out of memory");
            }
            Copy(pv, buff, len + 1, char); /* with "\0" */

            CHECK_ERR( cs_parse_string(cs, buff, len) );
        }
        else {
            CHECK_ERR( cs_parse_file(cs, SvPV_nolen_const(src)) );
        }

        CHECK_ERR(cs_render(cs, ofp, tcs_output_to_io));
    }
    XCPT_TRY_END

    if(need_ifp_close) PerlIO_close(ifp);
    if(need_ofp_close) PerlIO_close(ofp);

    cs_destroy(&cs);
    hdf_destroy(&hdf);

    XCPT_CATCH {
        XCPT_RETHROW;
    }
}
