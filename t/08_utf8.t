#!perl -w

use strict;
use Test::More;
use SelectSaver;

use Text::ClearSilver;
use utf8;

my $tcs = Text::ClearSilver->new();

my $template = <<"END";
"<?cs var:camel ?>" means "camel" in Japanese Kanji
END

my $out;
$tcs->process(\$template, { camel => "\x{99f1}\x{99dd}" }, \$out);

{
    local $TODO = "output should be utf8-flagged";

    ok utf8::is_utf8($out), "fill in utf8-flagged strings";

}

utf8::decode($out) if !utf8::is_utf8($out);
is $out, qq{"\x{99f1}\x{99dd}" means "camel" in Japanese Kanji\n};

done_testing;
