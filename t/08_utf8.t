#!perl -w

use strict;
use Test::More;
use SelectSaver;

use Text::ClearSilver;
use utf8;

my $tcs = Text::ClearSilver->new(encoding => 'utf8');

my $template = <<"END";
"<?cs var:ja ?>" means "<?cs var:en ?>" in Japanese Kanji
END

my $out;
my %var = (ja => "駱駝", en => 'camel');

undef $out;
$tcs->process(\$template, \%var, \$out);
is $out, qq{"駱駝" means "camel" in Japanese Kanji\n}, "encoding => 'utf8'";

undef $out;
$tcs->process(\$template, \%var, \$out, encoding => 'bytes');
isnt $out, qq{"駱駝" means "camel" in Japanese Kanji\n}, "encoding => 'bytes' breaks the output";

undef $out;
$tcs->process('camel.tcs', \%var, \$out, load_path => [qw(t/data)]);
is $out, qq{"駱駝"は英語で"camel"といいます。\n}, "encoding => 'utf8'";

undef $out;
$tcs->process('camel.tcs', \%var, \$out, load_path => [qw(t/data)], encoding => 'bytes');
isnt $out, qq{"駱駝"は英語で"camel"といいます。\n}, "encoding => 'bytes' breaks the output";


done_testing;
