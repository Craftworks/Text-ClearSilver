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
    system $^X, 'tool/get_cs.pl' if not -e 'clearsilver';
    system $^X, 'tool/build_cs.pl';
}

cc_src_paths qw(xs);

cc_include_paths qw(clearsilver clearsilver/util clearsilver/cgi clearsilver/cs);
cc_append_to_libs [ neo_cs => 'clearsilver/libs' ],
    qw(neo_utl neo_cgi z);

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

