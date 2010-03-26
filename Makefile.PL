use strict;
use warnings;
use inc::Module::Install;
use Config;

all_from 'lib/Text/ClearSilver.pm';

use_ppport 3.19;
cc_warnings;

test_requires 'Test::More' => 0.88; # done_testing()
test_requires 'Test::Requires';

unless(grep { $_ eq '--no-build-cs' } @ARGV){
    system $^X, 'tool/build_cs.pl';
}

cc_src_paths qw(xs);

cc_include_paths qw(src src/util src/cgi src/cs);
cc_append_to_libs [ neo_cs => 'src/libs' ],
    qw(neo_utl neo_cgi z);

tests_recursive 't', 't/*';

auto_set_repository() if -d '.git';

clean_files qw(
    Text-ClearSilver-* *.stackdump
    *.gcda *.gcno *.gcov
    nytprof *.out
    cover_db
);

realclean_files
    map  { "src/*/*$_" }
    grep { $_ } @Config{qw(_o _a _exe)};

WriteAll(check_nmake => 0);

