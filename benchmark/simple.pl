#!perl
use strict;
use Benchmark qw(:all);

use Text::ClearSilver;
use ClearSilver;
use Data::ClearSilver::HDF;

my $template = <<'CS_END';
Hello, <?cs var:lang ?> world!

<?cs var:foo.0 ?>
<?cs var:foo.1 ?>
<?cs var:foo.2 ?>
CS_END

my %vars = (
    lang => 'ClearSilver',
    foo => [qw(FOO BAR BAZ)],
);

cmpthese -1, {
    'T::CS' => sub {
        my $output = '';
        my $tcs = Text::ClearSilver->new();
        $tcs->process(\$template, \%vars, \$output);
    },
    'CS & D::CS::HDF' => sub {
        my $output;
        my $hdf = Data::ClearSilver::HDF->hdf(\%vars);
        my $cs  = ClearSilver::CS->new($hdf);
        $cs->parseString($template);
        $output = $cs->render();
    },
};

