/*
    Text-ClearSilver-HDF.xs - Represents the HDF* class

    Copyright(c) 2010 Craftworks. All rights reserved.

    See lib/Text/ClearSilver.pm for details.
*/


#include "Text-ClearSilver.h"


static int
tcs_cmp(const void* const in_a, const void* const in_b) {
    dTHX;
    dSP;
    SV* const sort_cmp_cb = tcs_get_my_cxtp(aTHX)->sort_cmp_cb;
    SV* a;
    SV* b;
    int ret;

    assert(sort_cmp_cb);

    ENTER;
    SAVETMPS;

    PUSHMARK(SP);

    /* convert to a type Perl can access */
    a = sv_newmortal();
    sv_setref_pv(a, C_HDF, *((HDF**)in_a));

    b = sv_newmortal();
    sv_setref_pv(b, C_HDF, *((HDF**)in_b));

    EXTEND(SP, 2);
    PUSHs(a);
    PUSHs(b);

    PUTBACK;

    call_sv(sort_cmp_cb, G_SCALAR);

    SPAGAIN;
    ret = POPi;
    PUTBACK;

    FREETMPS;
    LEAVE;

    return ret;
}

static void
tcs_hdf_walk(pTHX_ HDF* const hdf, SV* const key, SV* const sv, HV* const seen) {
    if(SvROK(sv)){
        SV** seen_key;
        SV* const rv = SvRV(sv);

        if(SvOBJECT(rv)){
            /* What we should do? */
            goto set_sv;
        }

        seen_key = hv_fetch(seen, (const char*)rv, sizeof(rv), FALSE);
        if(seen_key){
            /* XXX: hdf_set_symlink() cannot deal with cyclic refs?  */
            /*  hdf_set_symlink(hdf, SvPV_nolen_const(*seen_key), SvPV_nolen_const(key)); */

            /* XXX: hdf_set_copy() cannot deal with cyclic refs? */
            /* CHECK_ERR(hdf_set_copy(hdf, SvPV_nolen_const(key), SvPV_nolen_const(*seen_key))); */

            /* TODO */
            if(ckWARN(WARN_MISC)){
                Perl_warner(aTHX_ packWARN(WARN_MISC),
                    "Ignore duplicated references (%"SVf" == %"SVf")", *seen_key, key);
            }
            return;
        }

        (void)hv_store(seen, (const char*)rv, sizeof(rv), newSVsv(key), 0U);

        if(SvTYPE(rv) == SVt_PVAV || SvTYPE(rv) == SVt_PVHV) {
            STRLEN pos = SvCUR(key);

            if(pos != 0){ /* append '.' if key is not empty */
                sv_catpvs(key, ".");
                pos++;
            }

            if(SvTYPE(rv) == SVt_PVAV){
                AV* const av  = (AV*)rv;
                I32 const len = av_len(av) + 1;
                I32 i;
                for(i = 0; i < len; i++){
                    SV** const svp = av_fetch(av, i, FALSE);
                    if(svp){
                        sv_catpvf(key, "%d", (int)i);
                        tcs_hdf_walk(aTHX_ hdf, key, *svp, seen);
                        SvCUR_set(key, pos); /* reset key */
                        *SvEND(key) = '\0';
                    }
                }
            }
            else { /* SVt_PVHV */
                HV* const hv = (HV*)rv;
                char* keypv;
                I32   keylen;
                SV*   valsv;

                hv_iterinit(hv);
                while((valsv = hv_iternextsv(hv, &keypv, &keylen))){
                    sv_catpvn(key, keypv, keylen);
                    tcs_hdf_walk(aTHX_ hdf, key, valsv, seen);
                    SvCUR_set(key, pos);
                    *SvEND(key) = '\0';
                }
            }

            /* chop the last '.' */
            if(pos != 0 && SvPVX(key)[pos-1] == '.'){
                SvCUR_set(key, pos - 1);
                *SvEND(key) = '\0';
            }

            return;
        }

        /* fall through */
    }

    set_sv:
    if(SvOK(sv)) {
        CHECK_ERR( hdf_set_value(hdf, SvPV_nolen_const(key), SvPV_nolen_const(sv)) );
    }
    /* warn("set %"SVf"=%"SVf"", key, sv); // */
}

void
tcs_hdf_add(pTHX_ HDF* const hdf, SV* const sv) {
    assert(sv);
    SvGETMAGIC(sv);

    if(SvROK(sv)){
        if(SvOBJECT(SvRV(sv)) && SvIOK(SvRV(sv)) && sv_derived_from(sv, C_HDF)) {
            CHECK_ERR( hdf_copy(hdf, "" /* root */, INT2PTR(HDF*, SvIVX(SvRV(sv)) )) );
        }
        else {
            SV* const key  = newSVpvs_flags("", SVs_TEMP);
            HV* const seen = newHV();
            sv_2mortal((SV*)seen);

            tcs_hdf_walk(aTHX_ hdf, key, sv, seen);
        }
    }
    else if(SvOK(sv)){
        CHECK_ERR( hdf_read_string(hdf, SvPV_nolen_const(sv)) );
    }
}

HDF*
tcs_new_hdf(pTHX_ SV* const sv) {
    HDF* hdf;

    CHECK_ERR( hdf_init(&hdf) );

    if(sv){
        tcs_hdf_add(aTHX_ hdf, sv);
    }

    return hdf;
}

/*
    NOTE: Methods which seem to return NEOERR* throw errors when they fail,
          otherwise return undef.
 */

MODULE = Text::ClearSilver::HDF    PACKAGE = Text::ClearSilver::HDF    PREFIX = hdf_

PROTOTYPES: DISABLE

void
new(SV* klass, SV* arg = NULL)
CODE:
{
    SV* self;
    if(SvROK(klass)){
        croak("%s->new must be called as a class method", C_CS);
    }

    self = sv_newmortal();
    sv_setref_pv(self, SvPV_nolen_const(klass), tcs_new_hdf(aTHX_ arg));
    ST(0) = self;
    XSRETURN(1);
}

void
hdf_DESTROY(Text::ClearSilver::HDF hdf)

NEOERR*
hdf_set_value(Text::ClearSilver::HDF hdf, const char* key, const char* value)

const char*
hdf_get_value(Text::ClearSilver::HDF hdf, const char* key, const char* default_value = NULL)

NEOERR*
hdf_copy(Text::ClearSilver::HDF dest, const char* name, Text::ClearSilver::HDF src);

NEOERR*
hdf_read_file(Text::ClearSilver::HDF hdf, const char* filename)


#define HDF_DUMP_TYPE_DOTTED  0
#define HDF_DUMP_TYPE_COMPACT 1
#define HDF_DUMP_TYPE_PRETTY  2

void
hdf_dump(Text::ClearSilver::HDF hdf, int dump_type = HDF_DUMP_TYPE_PRETTY)
CODE:
{
    dXSTARG;
    STRING str;

    string_init(&str);
    hdf_dump_str(hdf, "", dump_type, &str);
    sv_setpvn(TARG, str.buf, str.len);
    string_clear(&str);

    ST(0) = TARG;
    XSRETURN(1);
}

NEOERR*
hdf_write_file(Text::ClearSilver::HDF hdf, SV* dest)
CODE:
{
    bool ok;
    STRING str;
    PerlIO* const ofp = PerlIO_openn(aTHX_
        NULL, "w", -1, O_WRONLY | O_CREAT, 0, NULL, 1, &dest);

    string_init(&str);
    RETVAL = hdf_dump_str(hdf, "", HDF_DUMP_TYPE_PRETTY, &str);

    ok = ( PerlIO_write(ofp, str.buf, str.len) == str.len );

    string_clear(&str);
    if(PerlIO_close(ofp) == -1){
        ok = FALSE;
    }

    if(!ok){
        croak("Cannot finish hdf_write_file: %"SVf, get_sv("!", GV_ADD));
    }
}

Text::ClearSilver::HDF
hdf_get_obj(Text::ClearSilver::HDF hdf, const char* name)

Text::ClearSilver::HDF
hdf_get_child(Text::ClearSilver::HDF hdf, const char* name)

Text::ClearSilver::HDF
hdf_obj_child(Text::ClearSilver::HDF hdf)

const char*
hdf_obj_value(Text::ClearSilver::HDF hdf)

const char*
hdf_obj_name(Text::ClearSilver::HDF self)

Text::ClearSilver::HDF
hdf_obj_next(Text::ClearSilver::HDF hdf)

NEOERR*
hdf_sort_obj(Text::ClearSilver::HDF hdf, SV* cb)
CODE:
{
    my_cxt_t* const cxt = tcs_get_my_cxtp(aTHX);
    SAVEVPTR(cxt->sort_cmp_cb);
    cxt->sort_cmp_cb = cb;
    RETVAL = hdf_sort_obj(hdf, tcs_cmp);
}
OUTPUT:
    RETVAL


NEOERR*
hdf_set_symlink(Text::ClearSilver::HDF self, const char* src, const char* dest)

NEOERR*
hdf_remove_tree(Text::ClearSilver::HDF self, const char* name)

