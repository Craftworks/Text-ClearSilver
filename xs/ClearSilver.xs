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

/* ClearSilver can access ibuf out of range of memory :(
   so extra some memory must be allocated for cs_parse_string().
*/
static const size_t extra_bytes = 8;

/*
    NOTE: Currently, file_cache is always enabled, although it can be disabled.
 */

static NEOERR*
tcs_fileload(void* vcsparse, HDF* const hdf, const char* filename, char** const contents) {
    dTHX;
    dMY_CXT;
    I32 filename_len;
    NEOERR* err = STATUS_OK;
    char fpath[_POSIX_PATH_MAX];
    Stat_t st;
    bool stat_ok = FALSE;

    /* find file */
    if (filename[0] != '/') {
        err = hdf_search_path (hdf, filename, fpath);
        if (((CSPARSE*)vcsparse)->global_hdf && nerr_handle(&err, NERR_NOT_FOUND)) {
            err = hdf_search_path(((CSPARSE*)vcsparse)->global_hdf, filename, fpath);
        }
        if (err != STATUS_OK) return nerr_pass(err);

        filename      = fpath;
    }
    filename_len = strlen(filename);

    /* check cache */
    if(MY_CXT.file_cache){
        Stat_t st;
        SV** const svp = hv_fetch(MY_CXT.file_cache, filename, filename_len, FALSE);

        if(svp){
            SV* const stat_buf = AvARRAY(SvRV(*svp))[0];
            SV* const file_buf = AvARRAY(SvRV(*svp))[1];
            Stat_t* stp_cache;

            if(PerlLIO_stat(filename, &st) < 0) {
                return nerr_raise(NERR_IO, "Failed to stat(%s): %s", filename, Strerror(errno));
            }
            stat_ok = TRUE;

            assert(SvCUR(stat_buf) == sizeof(Stat_t));
            stp_cache = (Stat_t*)SvPVX(stat_buf);
            if(st.st_size == stp_cache->st_size && st.st_mtime == stp_cache->st_mtime) {
                assert(SvCUR(file_buf) == st.st_size);

                *contents = (char*)malloc(st.st_size + extra_bytes);
                Copy(SvPVX(file_buf), *contents, st.st_size + 1, char);
                return STATUS_OK;
            }
        }
    }

    /* load file normally */
    if(!(stat_ok || PerlLIO_stat(filename, &st) >= 0)) {
        return nerr_raise(NERR_IO, "Failed to stat(%s): %s", filename, Strerror(errno));
    }

    ENTER;
    SAVETMPS;
    {
        SV* namesv = newSVpvn_flags(filename, filename_len, SVs_TEMP);
        SV* file_buf;
        SSize_t read_bytes;
        PerlIO* const ifp =  PerlIO_openn(aTHX_
            MY_CXT.input_layer, "r", -1, O_RDONLY, 0, NULL, 1, &namesv);

        if(!ifp){
            err = nerr_raise(NERR_IO, "Failed to open %s: %s", filename, Strerror(errno));
            goto cleanup;
        }

        file_buf = sv_2mortal(newSV(st.st_size));

        read_bytes = PerlIO_read(ifp, SvPVX(file_buf), st.st_size);
        PerlIO_close(ifp);
        if(read_bytes != st.st_size) {
            err = nerr_raise(NERR_IO, "Failed to read (read: %ld bytes, expected %ld bytes)",
                (long)read_bytes, (long)st.st_size);
            goto cleanup;
        }

        SvPOK_on(file_buf);
        SvCUR_set(file_buf, read_bytes);
        *SvEND(file_buf) = '\0';

        *contents = (char*)malloc(read_bytes + extra_bytes);
        Copy(SvPVX(file_buf), *contents, read_bytes + 1, char);

        if(MY_CXT.file_cache){
            SV* cache_entry[2];

            cache_entry[0] = newSVpvn((const char*)&st, sizeof(st));
            cache_entry[1] = SvREFCNT_inc_simple_NN(file_buf);

            (void)hv_store(MY_CXT.file_cache, filename, filename_len,
                newRV_noinc((SV*)av_make(2, cache_entry)), 0U);
        }
    }

    cleanup:
    FREETMPS;
    LEAVE;
    return err;
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
tcs_parse_sv(pTHX_ CSPARSE* const parse, SV* const sv) {
    STRLEN str_len;
    const char* const str = SvPV_const(sv, str_len);

    char* const ibuf = (char*)malloc(str_len + extra_bytes);
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

static void
tcs_set_config(pTHX_ SV* const self, HV* const hv, HDF* const hdf, SV* const key, SV* const val) {
    const char* const keypv = SvPV_nolen_const(key);
    if(isUPPER(*keypv)){ /* builtin config */
        HDF* config;
        CHECK_ERR( hdf_get_node(hdf, "Config", &config) );
        CHECK_ERR( hdf_set_value(config, keypv, SvPV_nolen_const(val)) );
    }
    else { /* extended config */
        if(strEQ(keypv, "input_encoding")) {
            /* TODO */
            (void)hv_store_ent(hv, key, newSVsv(val), 0U);
        }
        else if(strEQ(keypv, "dataset")) {
            tcs_hdf_add(aTHX_ hdf, val);
        }
        else if(strEQ(keypv, "load_path")) {
            HDF* loadpaths;
            CHECK_ERR( hdf_get_node(hdf, "hdf.loadpaths", &loadpaths) );

            tcs_hdf_add(aTHX_ loadpaths, val);
        }
        else if(ckWARN(WARN_MISC)) {
            Perl_warner(aTHX_ packWARN(WARN_MISC), "%s: unknown configuration variable '%s'",
                tcs_get_class_name(aTHX_ self), keypv);
            (void)hv_store_ent(hv, key, newSVsv(val), 0U);
        }
    }
}

static void
tcs_configure(pTHX_ SV* const self, HV* const hv, HDF* const hdf, I32 const ax, I32 const items) {
    if(items == 1) {
        SV* const args_ref = ST(0);
        HV* args;
        HE* he;

        SvGETMAGIC(args_ref);

        if(!(SvROK(args_ref) && SvTYPE(SvRV(args_ref)) == SVt_PVHV
                && !SvOBJECT(SvRV(args_ref)) )){
            croak("%s: single parameters to configure must be a HASH ref",
                tcs_get_class_name(aTHX_ self));
        }
        args = (HV*)SvRV(args_ref);

        hv_iterinit(args);
        while((he = hv_iternext(args))) {
            tcs_set_config(aTHX_ self, hv, hdf, hv_iterkeysv(he), hv_iterval(args, he));
        }
    }
    else {
        I32 i;

        if( (items % 2) != 0 ){
            croak("%s: odd number of parameters to configure",
                tcs_get_class_name(aTHX_ self));
        }

        for(i = 0; i < items; i += 2){
            tcs_set_config(aTHX_ self, hv, hdf, ST(i), ST(i+1));
        }
    }
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
    CHECK_ERR( cgi_register_strfuncs(cs) );
}

void*
tcs_get_struct_ptr(pTHX_ SV* const arg, const char* const klass,
        const char* const func_fq_name, const char* var_name) {
    if(SvROK(arg) && sv_derived_from(arg, klass) && SvIOK(SvRV(arg))){
        return INT2PTR(void*, SvIVX(SvRV(arg)));
    }

    croak("%s: %s is not of type %s", func_fq_name, var_name, klass);
    return NULL; /* NOT REACHED */
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
    MY_CXT.input_layer = NULL;
    MY_CXT.file_cache  = newHV();

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
    MY_CXT.input_layer = NULL;
    MY_CXT.file_cache  = newHV();
    PERL_UNUSED_VAR(items);
}

#endif

void
new(SV* klass, ...)
CODE:
{
    HDF* hdf;
    SV* self;
    HV* hv;
    if(SvROK(klass)){
        croak("Cannot %s->new as an instance method", "Text::ClearSilver");
    }
    hv    = newHV();
    self  = sv_2mortal( newRV_noinc((SV*)hv) );
    ST(0) = sv_bless(self, gv_stashsv(klass, GV_ADD));

    CHECK_ERR( hdf_init(&hdf) );
    sv_setref_pv(*hv_fetchs(hv, "dataset", TRUE), C_HDF, hdf);

    /* ax+1 && items-1 for shift @_ */
    tcs_configure(aTHX_ self, hv, hdf, ax + 1, items - 1);
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

void
dataset(SV* self)
CODE:
{
    ST(0) = *hv_fetchs(tcs_deref_hv(aTHX_ self), "dataset", TRUE);
    XSRETURN(1);
}


#define DEFAULT_OUT ((SV*)PL_defoutgv)

void
process(SV* self, SV* src, SV* vars, SV* volatile dest = DEFAULT_OUT, ...)
CODE:
{
    dXCPT;
    CSPARSE*  cs         = NULL;
    HDF*     hdf         = NULL;
    bool need_ifp_close  = FALSE;
    bool need_ofp_close  = FALSE;
    PerlIO* volatile ifp = NULL;
    PerlIO* volatile ofp = NULL;

    if(!( SvROK(self) && SvOBJECT(SvRV(self)) )){
        croak("Cannot %s->process as a class method", "Text::ClearSilver");
    }

    SvGETMAGIC(src);
    SvGETMAGIC(dest);

    XCPT_TRY_START {
        dMY_CXT;
        HV* const hv = tcs_deref_hv(aTHX_ self);
        const char* input_layer;
        SV** svp;

        CHECK_ERR( hdf_init(&hdf) );

        CHECK_ERR( hdf_copy(hdf, "", (HDF*)tcs_get_struct_ptr(aTHX_
            *hv_fetchs(hv, "dataset", TRUE), C_HDF, "Text::ClearSilver::process", "dataset")) );

        if(!(SvROK(dest) && SvTYPE(SvRV(dest)) <= SVt_PVMG)) { /* not a scalar ref */
            ofp = tcs_sv2io(aTHX_ dest, "w", O_WRONLY|O_CREAT|O_TRUNC, &need_ofp_close);
        }

        tcs_hdf_add(aTHX_ hdf, vars);

        svp = NULL;
        if(items > 4){
            HV* const local_hv = newHV();
            sv_2mortal((SV*)local_hv);
            tcs_configure(aTHX_ self, local_hv, hdf, ax + 4, items - 4);

            svp = hv_fetchs(local_hv, "input_layer", FALSE);
        }
        if(!svp){
            svp = hv_fetchs(hv, "input_layer", FALSE);
        }
        input_layer = svp ? SvPV_nolen_const(*svp) : NULL;


        CHECK_ERR( cs_init(&cs, hdf) );

        svp = hv_fetchs(tcs_deref_hv(aTHX_ self), "functions", FALSE);
        tcs_register_funcs(aTHX_ cs, svp ? tcs_deref_hv(aTHX_ *svp) : NULL);

        cs_register_fileload(cs, cs, tcs_fileload);

        SAVEVPTR(MY_CXT.input_layer);
        MY_CXT.input_layer = input_layer;

        /* parse CS template */
        if(SvROK(src)){
            if(SvTYPE(SvRV(src)) > SVt_PVMG){
                croak("Source must be a scalar reference or a filename, not %"SVf, src);
            }
            CHECK_ERR(tcs_parse_sv(aTHX_ cs, SvRV(src)));
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


void
clear_cache(self)
CODE:
{
    dMY_CXT;
    if(MY_CXT.file_cache){
        ST(0) = sv_2mortal(newRV_noinc((SV*)MY_CXT.file_cache));
        MY_CXT.file_cache = newHV();
    }
    else {
        ST(0) = &PL_sv_undef;
    }
    XSRETURN(1);
}
