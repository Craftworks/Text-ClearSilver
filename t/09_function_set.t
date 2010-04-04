#!perl -w

use strict;
use Test::More;

use Text::ClearSilver;
use Carp ();

foreach (1 .. 2) {
    note $_;

    my $tcs = Text::ClearSilver->new(function_set => [qw(string html)]);

    my $out;

    $tcs->process(\q{<?cs var:lc("FOO") ?>}, {}, \$out);
    is $out, "foo", 'lc';

    $tcs->process(\q{<?cs var:uc("foo") ?>}, {}, \$out);
    is $out, "FOO", 'uc';

    $tcs->process(\q{<?cs var:lcfirst("FOO") ?>}, {}, \$out);
    is $out, "fOO", 'lcfirst';

    $tcs->process(\q{<?cs var:ucfirst("foo") ?>}, {}, \$out);
    is $out, "Foo", 'ucfirst';

    $tcs->process(\q{<?cs var:substr("foo", 1) ?>}, {}, \$out);
    is $out, "oo", 'substr';

    $tcs->process(\q{<?cs var:substr("foo", 1, 1) ?>}, {}, \$out);
    is $out, "o", 'substr';

    $tcs->process(\qq{<?cs var:nl2br("\n\n") ?>}, {}, \$out);
    is $out, "<br />\n<br />\n", 'nl2br';

}

done_testing;
