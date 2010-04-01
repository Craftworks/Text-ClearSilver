#!perl -w
use Text::ClearSilver;
use Template;
use Text::MicroTemplate 'render_mt';
use Benchmark ':all';

my $cs = Text::ClearSilver->new(
    VarEscapeMode => 'html',    # html,js,url, or none
    TagStart      => 'cs',      # <?cs ... >
);

$cs->register_function( lcfirst => sub { lcfirst $_[0] } );

my $tt = Template->new();

printf "%vd %s\n", $^V, $^O;
print "Template: $Template::VERSION\n";
print "Text::MicroTemplate: $Text::MicroTemplate::VERSION\n";
print "Text::ClearSilver: $Text::ClearSilver::VERSION\n";

#arn _cs();
#arn _tt();
#arn _mt();

cmpthese( -1, => {
        'cs' => \&_cs,
        'tt' => \&_tt,
        'mt' => \&_mt,
    },
);

sub _cs {
    $cs->process( \q{<?cs var:lcfirst(foo) ?>}, { foo => 'bar' }, \my $out );
    $out;
}

sub _tt {
    $tt->process(\q{[% foo | lcfirst %]}, {foo => 'bar'}, \my $out) or die;
    $out;
}

sub _mt {
    render_mt(q{<?= lcfirst $_[0] ?>}, 'bar');
}
