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

# must not 'ClearSilver' nor 'clearsilver', which confuses EU::MM
my $cs_dir = 'cs';

unless(grep { $_ eq '--no-build-cs' } @ARGV){
    system $^X, 'tool/get_cs.pl',   $cs_dir if not -e $cs_dir;
    system $^X, 'tool/build_cs.pl', $cs_dir;
}

cc_src_paths qw(xs);

cc_include_paths $cs_dir, map{ "$cs_dir/$_" } qw(util cgi cs);
cc_append_to_libs
    [ neo_cs  => "$cs_dir/libs" ], # CSPARSE
    [ neo_utl => "$cs_dir/libs" ], # HDF and other utils
;

tests_recursive 't', 't/*';

auto_set_repository() if -d '.git';

no_index directly => [$cs_dir, qw(tool patch)];

clean_files qw(
    Text-ClearSilver-* *.stackdump
    *.gcda *.gcno *.gcov
    nytprof *.out
    cover_db
);

realclean_files $cs_dir;

WriteAll(check_nmake => 0);

