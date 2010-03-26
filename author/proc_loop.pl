#!perl -w
use strict;
use Text::ClearSilver;

# loop test for memory usage

while(1) {
    my $tcs = Text::ClearSilver->new();

    my $out = '';
    $tcs->process(\'<?cs var:foo ?>', { foo => 'bar' }, \$out);
}
