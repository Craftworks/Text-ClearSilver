#!perl -w
use strict;
use Text::ClearSilver;

# loop test for memory usage

while(1) {
    my $cs = Text::ClearSilver::CS->new(\%ENV);
    $cs->parse_string(q{<?cs var:HOME ?>});
    $cs->render;
}
