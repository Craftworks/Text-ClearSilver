#!perl -w
use strict;
use Text::ClearSilver;

# loop test for memory usage

# XXX: THIS HAS MEMORY LEAKS!

# cs_parse_string() seems to leaks memory on syntax error

while(1) {
    my $tcs = Text::ClearSilver->new();

    eval {
        my $out = '';
        # intentinaly syntax error
        #open my $ifp, '<', \'<?cs var:foo >';
        $tcs->process(\'<?cs var:foo >', { foo => 'bar' }, \$out);
    };
}
