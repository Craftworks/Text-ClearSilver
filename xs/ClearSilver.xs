/*
    Text-ClearSilver.xs -  The template processor class

    Copyright(c) 2010 Craftworks. All rights reserved.

    See lib/Text/ClearSilver.pm for details.
*/

#define NEED_newSVpvn_flags_GLOBAL
#define NO_XSLOCKS
#include "Text-ClearSilver.h"

#define MY_CXT_KEY "Text::ClearSilver::_guts" XS_VERSION
/* my_cxt_t is defined in Text-ClearSilver.h */
START_MY_CXT

/* my_cxt accessor for HDF.xs */
my_cxt_t*
tcs_get_my_cxtp(pTHX) {
    dMY_CXT;
    return &MY_CXT;
}

/* in csparse.c */
NEOERR*
tcs_eval_expr(CSPARSE* parse, CSARG* arg, CSARG* result);
const char*
tcs_var_lookup(CSPARSE* parse, const char* name);
long
tcs_var_int_lookup(CSPARSE* parse, const char* name);
HDF*
tcs_var_lookup_obj(CSPARSE* parse, const char* name);

static NEOERR*
tcs_push_args(pTHX_ CSPARSE* const parse, CSARG* args) {
    dSP;

    PUSHMARK(SP);

    while(args) {
        const char* str;
        CSARG val;
        NEOERR* err;
        SV* sv;

        err = tcs_eval_expr(parse, args, &val);

        if(err){
            (void)POPMARK;

            return nerr_pass(err);
        }

        sv = sv_newmortal();
        XPUSHs(sv);

        switch(val.op_type & CS_TYPES){
        case CS_TYPE_STRING:
            assert(val.s);
            sv_setpv(sv, val.s);
            break;

        case CS_TYPE_VAR:
            assert(val.s);
            str = tcs_var_lookup(parse, val.s);
            if(str) {
                sv_setpv(sv, str);
            }
            else { /* HDF node */
                HDF* const hdf = tcs_var_lookup_obj(parse, val.s);
                if(hdf) {
                    sv_setref_pv(sv, C_HDF, hdf);
                }
            }
            break;

        case CS_TYPE_NUM:
            sv_setiv(sv, val.n);
            break;

        case CS_TYPE_VAR_NUM:
            assert(val.s);
            sv_setiv(sv, tcs_var_int_lookup(parse, val.s));
            break;

        default:
            /* something's wrong? */
            break;
        }

        if(val.alloc){
            free(val.s);
        }
        args = args->next;
    }
    PUTBACK;
    return STATUS_OK;
}

/* general cs function wrapper */
static NEOERR*
tcs_function_wrapper(CSPARSE* const parse, CS_FUNCTION* const csf, CSARG* const args, CSARG* const result) {
    dTHX;
    dMY_CXT;
    SV** svp;
    SV* retval;
    NEOERR* err;

    assert(MY_CXT.functions);

    /* XXX: Hey! csf->name_len is not set!! */
    //svp = hv_fetch(MY_CXT.functions, csf->name, csf->name_len, FALSE);
    svp = hv_fetch(MY_CXT.functions, csf->name, strlen(csf->name), FALSE);
    if(!( svp && SvROK(*svp) && SvTYPE(SvRV(*svp)) == SVt_PVAV
            && (svp = av_fetch((AV*)SvRV(*svp), 0, FALSE)) )){
        return nerr_raise(NERR_ASSERT, "Function entry for %s() is broken", csf->name);
    }

    ENTER;
    SAVETMPS;

    err = tcs_push_args(aTHX_ parse, args); /* PUSHMARK & PUSH & PUTBACK */
    if(err != STATUS_OK) {
        err = nerr_pass(err);
        goto cleanup;
    }

    call_sv(*svp, G_SCALAR | G_EVAL);

    {
        dSP;
        SPAGAIN;
        retval = POPs;
        PUTBACK;
    }

    if(sv_true(ERRSV)){
        err =  nerr_raise(NERR_ASSERT,
            "Function %s() died: %s", csf->name, SvPVx_nolen_const(ERRSV));
        goto cleanup;
    }

    if(!(SvIOK(retval) && PERL_ABS(SvIVX(retval)) <= PERL_LONG_MAX)) {
        STRLEN len;
        const char* const pv = SvPV_const(retval, len);
        len++; /* '\0' */

        result->op_type = CS_TYPE_STRING;
        result->s       = (char*)malloc(len);
        result->alloc    = TRUE;
        Copy(pv, result->s, len, char);
    }
    else { /* SvIOK */
        result->op_type = CS_TYPE_NUM;
        result->n       = (long)SvIVX(retval);
    }

    cleanup:
    FREETMPS;
    LEAVE;

    return err;
}

static NEOERR*
tcs_sprintf_function(CSPARSE* const parse, CS_FUNCTION* const csf, CSARG* args, CSARG* const result) {
    dTHX;
    NEOERR* err;

    PERL_UNUSED_ARG(csf);

    ENTER;
    SAVETMPS;

    err = tcs_push_args(aTHX_ parse, args); /* PUSHMARK & PUSH & PUTBACK */
    if(err != STATUS_OK) {
        err = nerr_pass(err);
        goto cleanup;
    }

    {
        dSP; dMARK; dORIGMARK;
        I32 const items  = SP - MARK;

        if(items < 1){
            err = nerr_raise(NERR_ASSERT, "Too few arguments for sprintf()");
        }
        else {
            SV* const retval = sv_newmortal();
            STRLEN len;
            const char* pv;

            do_sprintf(retval, items, MARK + 1);

            pv = SvPV_const(retval, len);
            len++; /* '\0' */

            result->op_type = CS_TYPE_STRING;
            result->s       = (char*)malloc(len);
            result->alloc    = TRUE;
            Copy(pv, result->s, len, char);
        }

        SP = ORIGMARK;
        PUTBACK;
    }

    cleanup:
    FREETMPS;
    LEAVE;

    return err;
}

NEOERR*
tcs_parse_string (CSPARSE* const parse, const char* const str, size_t const str_len)
{
    /* ClearSilver can access ibuf out of range of memory :(
       so extra some memory must be allocated.
    */
    static const size_t extra_memory = 10;
    char* const ibuf = (char*)calloc(str_len + extra_memory, sizeof(char));
    if(ibuf == NULL){
        return nerr_raise (NERR_NOMEM,
            "Unable to allocate memory");
    }

    Copy(str, ibuf, str_len + 1, char); /* with '\0' */
    return cs_parse_string(parse, ibuf, str_len);
}

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

static CV*
tcs_sv2cv(pTHX_ SV* const func) {
    HV* stash; /* unused */
    GV* gv;    /* unused */
    CV* const cv = sv_2cv(func, &stash, &gv, 0);
    if(!cv){
        croak("Not a CODE reference");
    }
    return cv;
}

static HV*
tcs_deref_hv(pTHX_ SV* const hvref) {
    if(!(SvROK(hvref) && SvTYPE(SvRV(hvref)) == SVt_PVHV)) {
        croak("Not a HASH reference");
    }
    return (HV*)SvRV(hvref);
}


static NEOERR*
tcs_html_escape(const char* src, char** out) {
    return nerr_pass(neos_html_escape(src, strlen(src), out));
}

static NEOERR*
tcs_url_escape(const char* src, char** out) {
    return nerr_pass(neos_url_escape(src, out, NULL /* other */));
}

static NEOERR*
tcs_js_escape(const char* src, char** out) {
    return nerr_pass(neos_js_escape(src, out));
}


void
tcs_register_funcs(pTHX_ CSPARSE* const cs, HV* const funcs) {

    /* functions registered by users */
    if(funcs) {
        dMY_CXT;
        char* key;
        I32 keylen;
        SV* val;

        SAVEVPTR(MY_CXT.functions);
        MY_CXT.functions = funcs;

        hv_iterinit(funcs);
        while((val = hv_iternextsv(funcs, &key, &keylen))) {
            AV* pair;
            if(!(SvROK(val) && SvTYPE(SvRV(val)) == SVt_PVAV)){
                croak("Function entry for %s() is broken", key);
            }
            pair = (AV*)SvRV(val);

            CHECK_ERR( cs_register_function(cs, key,
                SvIVx(*av_fetch(pair, 1, TRUE)), tcs_function_wrapper) );
        }
    }

    /* TCS specific builtins */
    CHECK_ERR( cs_register_function(cs, "sprintf", -1, tcs_sprintf_function) );

    /* functions from cgi_register_strfuncs() */

    CHECK_ERR( cs_register_esc_strfunc(cs, "html_escape", tcs_html_escape) );
    CHECK_ERR( cs_register_esc_strfunc(cs, "url_escape",  tcs_url_escape) );
    CHECK_ERR( cs_register_esc_strfunc(cs, "js_escape",   tcs_js_escape) );
}

MODULE = Text::ClearSilver    PACKAGE = Text::ClearSilver

PROTOTYPES: DISABLE

BOOT:
{
    XS(boot_Text__ClearSilver__HDF);
    XS(boot_Text__ClearSilver__CS);
    MY_CXT_INIT;
    MY_CXT.sort_cmp_cb = NULL;
    MY_CXT.functions   = NULL;

    PUSHMARK(SP);
    boot_Text__ClearSilver__HDF(aTHX_ cv);
    SPAGAIN;

    PUSHMARK(SP);
    boot_Text__ClearSilver__CS(aTHX_ cv);
    SPAGAIN;
}

#ifdef USE_ITHREADS

void
CLONE(...)
CODE:
{
    MY_CXT_CLONE;
    MY_CXT.sort_cmp_cb = NULL;
    MY_CXT.functions   = NULL;
    PERL_UNUSED_VAR(items);
}

#endif

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

void
register_function(SV* self, SV* name, SV* func, int n_args = -1)
CODE:
{
    SV** const svp = hv_fetchs(tcs_deref_hv(aTHX_ self), "functions", FALSE);
    HV* hv;
    SV* pair[2];
    if(svp) {
        hv = tcs_deref_hv(aTHX_ *svp);
    }
    else {
        hv = newHV();
        (void)hv_stores(tcs_deref_hv(aTHX_ self), "functions", newRV_noinc((SV*)hv));
    }

    pair[0] = newRV_inc((SV*)tcs_sv2cv(aTHX_ func));
    pair[1] = newSViv(n_args);

    (void)hv_store_ent(hv, name, newRV_noinc((SV*)av_make(2, pair)), 0U);
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
        HDF* config = NULL;
        SV** svp;

        if(!(SvROK(dest) && SvTYPE(SvRV(dest)) <= SVt_PVMG)) { /* not a scalar ref */
            ofp = tcs_sv2io(aTHX_ dest, "w", O_WRONLY|O_CREAT|O_TRUNC, &need_ofp_close);
        }

        hdf = tcs_new_hdf(aTHX_ vars);

        CHECK_ERR( hdf_get_node(hdf, "Config", &config) );

        svp = hv_fetchs(tcs_deref_hv(aTHX_ self), "Config", FALSE);
        if(svp){
            tcs_hdf_add(aTHX_ config, *svp);
        }
        if(args) {
            tcs_hdf_add(aTHX_ config, sv_2mortal(newRV_inc((SV*)args)));
        }

        CHECK_ERR( cs_init(&cs, hdf) );

        svp = hv_fetchs(tcs_deref_hv(aTHX_ self), "functions", FALSE);
        tcs_register_funcs(aTHX_ cs, svp ? tcs_deref_hv(aTHX_ *svp) : NULL);

        /* parse CS template */
        if(SvROK(src)){
            STRLEN len;
            const char* pv;

            if(SvTYPE(SvRV(src)) > SVt_PVMG){
                croak("Source must be a scalar reference or a filename, not %"SVf, src);
            }
            pv   = SvPV_const(SvRV(src), len);

            CHECK_ERR(tcs_parse_string(cs, pv, len));
        }
        else {
            CHECK_ERR( cs_parse_file(cs, SvPV_nolen_const(src)) );
        }

        /* render */
        if(ofp) {
            CHECK_ERR( cs_render(cs, ofp, tcs_output_to_io) );
        }
        else {
            sv_setpvs(SvRV(dest), "");
            CHECK_ERR( cs_render(cs, SvRV(dest), tcs_output_to_sv) );
        }
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


