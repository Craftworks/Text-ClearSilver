#!perl -w

use strict;
use Test::More;
use SelectSaver;

use Text::ClearSilver;

my $tcs = Text::ClearSilver->new();

isa_ok $tcs, 'Text::ClearSilver';
my $out = '';
$tcs->process(\'<?cs var:foo ?>', { foo => 'bar' }, \$out);
is $out, 'bar', 'process to scalar ref';

$out = '';

{
    open my $ofp, '>', \$out;
    my $ss = SelectSaver->new($ofp);
    $tcs->process(\'<?cs var:foo ?>', { foo => 'baz' });

    print "-"; # should not be closed
}

is $out, 'baz-', 'process with defout';


$tcs = Text::ClearSilver->new(
    Config => {
        VarEscapeMode => 'html',
        TagStart      => 'tcs',
    },
);

$out = '';
$tcs->process(\'<?tcs var:foo ?>', { foo => '<bar>' }, \$out);

is $out, '&lt;bar&gt;', 'with Config';

$out = '';
$tcs->process(\'<?tcs var:foo ?>', { foo => '<bar>' }, \$out, VarEscapeMode => 'none');
is $out, '<bar>', 'config in place';

$out = '';
$tcs->process(\'<?tcs var:html_escape(foo) ?>', { foo => '<bar>' }, \$out, VarEscapeMode => 'none');
is $out, '&lt;bar&gt;', 'config in place';

done_testing;
