# for developpers:
# First, do $ cpanm < author/requires.cpanm after cloning the repository.
#
# Then, do Makefile.PL. The repository does not include ClearSilver dist,
# so Makefile.PL try to get the dist via Internet with tools/get_cs.pl.


use strict;
use warnings;
use inc::Module::Install;
use Config;

if(not -x '/bin/sh'){
    warn <<'END_MSG';
Text::ClearSilver requires /bin/sh for the configuration of
ClearSilver engine, but it is not found on this system.
END_MSG
    exit(0);
}

all_from 'lib/Text/ClearSilver.pm';

use_ppport 3.19;
cc_warnings;

test_requires 'Test::More' => 0.88; # done_testing()
test_requires 'Test::Requires';

unless(grep { $_ eq '--no-build-cs' } @ARGV){
    system $^X, 'tool/get_cs.pl' if not -e 'clearsilver';
    system $^X, 'tool/build_cs.pl';
}

cc_src_paths qw(xs);

cc_include_paths qw(clearsilver clearsilver/util clearsilver/cgi clearsilver/cs);
cc_append_to_libs
    [ neo_cs  => 'clearsilver/libs' ], # CSPARSE
    [ neo_utl => 'clearsilver/libs' ], # HDF and other utils
;

tests_recursive 't', 't/*';

auto_set_repository() if -d '.git';

clean_files qw(
    Text-ClearSilver-* *.stackdump
    *.gcda *.gcno *.gcov
    nytprof *.out
    cover_db
);

realclean_files 'clearsilver';

WriteAll(check_nmake => 0);

