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

undef $out;
my $orig_template = $template = q{<?cs var:sprintf("駱駝") ?>};
$tcs->process(\$template, {}, \$out);
is $template, $orig_template, '$template is not touched';
is $out, '駱駝';

utf8::encode($template);
$orig_template = $template;
$tcs->process(\$template, {}, \$out);
is $template, $orig_template, '$template is not touched';
is $out, '駱駝';

$tcs->register_function(is_utf8 => sub{ utf8::is_utf8($_[0]) });
undef $out;
$tcs->process(\q{<?cs var:is_utf8(foo) ?>}, { foo => "駱駝" }, \$out);
ok $out, 'function arguments are utf8';

undef $out;
$tcs->process(\q{<?cs var:is_utf8(foo) ?>}, { foo => "駱駝" }, \$out, encoding => "bytes");
ok !$out, 'function arguments are not utf8';

$tcs->register_function( 'string.substr' => sub {
    if(@_ == 2){
        return substr $_[0], $_[1];
    }
    elsif(@_ == 3){
        return substr $_[0], $_[1], $_[2];
    }
    else {
        die "wrong number of arguments for substr";
    }
} );

$tcs->process(\q{<?cs var:string.substr("foo ほげ bar", 0, 5) ?>}, {}, \$out);
is $out, "foo ほ", "can define substr()";

done_testing;
