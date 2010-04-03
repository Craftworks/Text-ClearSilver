#!perl -w
use Text::ClearSilver;
use Template;
use Text::MicroTemplate 'build_mt';
use HTML::Template::Pro;
use Benchmark ':all';

my $cs = Text::ClearSilver->new();

my $tt_tmpl = q{ [% foo  %] } x 10;
my $cs_tmpl = q{ <?cs var:foo ?> } x 10;

my $mt = build_mt(q{ <?=  $_[0] ?> } x 10);
my $ht = HTML::Template::Pro->new(
    scalarref => \(q{ <tmpl_var name="foo"> } x 10),
);
my $tt = Template->new();

printf "%vd %s\n", $^V, $^O;
foreach my $mod(qw(Template Text::MicroTemplate HTML::Template::Pro Text::ClearSilver)) {
    print $mod, ": ", $mod->VERSION, "\n";
}

if(0){
    warn _cs();
    warn _tt();
    warn _mt();
    warn _ht();
    exit;
}

cmpthese( -1, => {
        'cs' => \&_cs,
        'tt' => \&_tt,
        'mt' => \&_mt,
        'ht' => \&_ht,
    },
);

sub _cs {
    $cs->process(\$cs_tmpl, { foo => 'bar' }, \my $out );
    $out;
}

sub _tt {
    $tt->process(\$tt_tmpl, {foo => 'bar'}, \my $out) or die;
    $out;
}

sub _mt {
    $mt->('bar');
}

sub _ht {
    $ht->param(foo => 'bar');
    my $out = $ht->output();
}
