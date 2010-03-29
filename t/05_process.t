#!perl -w

use strict;
use Test::More;
use SelectSaver;

use Text::ClearSilver;

my $tcs = Text::ClearSilver->new();

isa_ok $tcs, 'Text::ClearSilver';
my $out;
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
    VarEscapeMode => 'html',
    TagStart      => 'tcs',
    dataset       => { common_var => 'ok' },
);

like $tcs->dataset->dump, qr/\b Config \b/xms, 'dataset includes Config';
like $tcs->dataset->dump, qr/\b VarEscapeMode \b/xms, 'dataset includes VarEscapeMode';
like $tcs->dataset->dump, qr/\b TagStart \b/xms, 'dataset includes TagStart';

$tcs->process(\'<?tcs var:foo ?>', { foo => '<bar>' }, \$out);
is $out, '&lt;bar&gt;', 'with Config';

$tcs->process(\'<?tcs var:foo ?>', { foo => '<bar>' }, \$out, VarEscapeMode => 'none');
is $out, '<bar>', 'config in place';

$tcs->process(\'<?tcs var:html_escape(foo) ?>', { foo => '<bar>' }, \$out, VarEscapeMode => 'none');
is $out, '&lt;bar&gt;', 'config in place';

$tcs->process(\'<?tcs var:common_var ?>', {}, \$out);
is $out, 'ok', 'dataset from instance';

done_testing;
