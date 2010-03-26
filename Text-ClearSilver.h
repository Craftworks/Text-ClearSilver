/*
    Text-ClearSilver.h - XSUBs for Text::ClearSilver

    Copyright(c) 2010 Craftworks. All rights reserved.

    See lib/Text/ClearSilver.pm for details.
*/

#define PERL_NO_GET_CONTEXT
#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>

#include "ppport.h"

/* Need raw malloc() that must be what ClearSilver uses */
#undef malloc

#include "ClearSilver.h"

#define C_HDF "Text::ClearSilver::HDF"
#define C_CS  "Text::ClearSilver::CS"

/* for typemap */
typedef HDF*     Text__ClearSilver__HDF;
typedef CSPARSE* Text__ClearSilver__CS;

#define hdf_DESTROY(p) hdf_destroy(&(p))
#define cs_DESTROY(p)  cs_destroy(&(p))

#define CHECK_ERR(e) STMT_START{ \
        NEOERR* check_error_value = (e); \
        if(check_error_value != STATUS_OK) tcs_throw_error(aTHX_ check_error_value); \
    }STMT_END

void
tcs_throw_error(pTHX_ NEOERR* const err);

/* HDF */
HDF*
tcs_new_hdf(pTHX_ SV* const sv);
void
tcs_hdf_add(pTHX_ HDF* const hdf, SV* const sv);


/* CS */
NEOERR*
tcs_output_to_io(void* io, char* s);

NEOERR*
tcs_output_to_sv(void* io, char* s);

