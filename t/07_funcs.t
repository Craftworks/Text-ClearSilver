#!perl -w

use strict;
use Test::More;
use SelectSaver;

use Text::ClearSilver;
use Carp ();

foreach (1 .. 2) {
    note $_;

    my $tcs = Text::ClearSilver->new();

    $tcs->register_function( lc => sub { lc $_[0] }, 1);
    $tcs->register_function( uc => sub { uc $_[0] }, 1);
    $tcs->register_function( add => sub{ $_[0] + $_[1] }, 2);

    $tcs->register_function( take_node => sub{
        return $_[0]->obj_child->obj_value;
    });

    $tcs->register_function( croak => \&Carp::croak );

    my $out = '';
    $tcs->process(\'<?cs var:lc(foo) ?> <?cs var:uc(foo) ?>', { foo => '<FoO>' }, \$out);
    is $out, '<foo> <FOO>', "register_function";

    $out = '';
    $tcs->process(\'<?cs var:add(#42, #2) ?>', {}, \$out);
    is $out, 44;

    $out = '';
    $tcs->process(\'<?cs var:sprintf("%1$d %2$d", #10, #20) ?>', {}, \$out);
    is $out, '10 20', 'sprintf';

    $out = '';
    $tcs->process(\'<?cs var:take_node(Foo) ?>', { Foo => { bar => 42 } }, \$out);
    is $out, 42, 'take HDF node';

    $out = '';
    $tcs->process(\'<?cs var:sprintf("%2$d %1$d", #10, #20) ?>', {}, \$out);
    is $out, '20 10', 'builtin sprintf';

    eval {
        $out = '';
        $tcs->process(\'<?cs var:croak(foo) ?>', { foo => "bar" }, \$out);
    };
    like $@, qr/\b bar \b/xms, "die in callback";
    is $out, '';

    eval {
        $out = '';
        $tcs->process(\'<?cs var:sprintf() ?>', {}, \$out);
    };
    like $@, qr/Too few arguments for sprintf/;
    is $out, '';
}

done_testing;
