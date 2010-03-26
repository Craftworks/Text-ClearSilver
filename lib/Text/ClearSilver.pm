package Text::ClearSilver;

use 5.008_001;
use strict;

our $VERSION = '0.001';

use XSLoader;
XSLoader::load(__PACKAGE__, $VERSION);

1;
__END__

=head1 NAME

Text::ClearSilver - Perl interface to the ClearSilver template engine

=head1 VERSION

This document describes Text::ClearSilver version 0.001.

=head1 SYNOPSIS

    use Text::ClearSilver;

    my $cs = Text::ClearSilver->new(
        # ClearSilver configuration
        VarEscapeMode => 'html', # html,js,url, or none
        TagStart      => 'cs',   # <?cs ... >
    );

    my %vars => (
        foo => 'bar',         # as var:foo
        baz => { qux => 42 }, # as var:baz.qux
    );
    $cs->process(\q{<?cs var:foo ?>}, \%vars, \*STDOUT);

=head1 DESCRIPTION

Text::ClearSilver is a Perl binding to the B<ClearSilver> template engine.

=head1 INTERFACE

=head2 Text::ClearSilver

=head3 C<< Text::ClearSilver->new(%config) >>

=head2 Text::ClearSilver::HDF

This is a low-level interface to the C<< HDF* >> data structure.

=head3 C<< Text::ClearSilver::HDF->new($hdf_source | \%data) >>

=head2 Text::ClearSilver::CS

This is a low-level interface to the C<< CSPARSE* >> template engine.

=head3 C<< Text::ClearSilver::CS->new($hdf_source | \%data | $hdf) >>

=head1 DEPENDENCIES

Perl 5.8.1 or later, and a C compiler.

=head1 BUGS

All complex software has bugs lurking in it, and this module is no
exception. If you find a bug please either email me, or add the bug
to cpan-RT.

=head1 SEE ALSO

L<http://www.clearsilver.net/>

L<Data::ClearSilver::HDF>

L<Catalyst::View::ClearSilver>

=head1 AUTHORS

Craftworks (XXXX@XXXX)

Goro Fuji (gfx) E<lt>gfuji(at)cpan.orgE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2010, XXXX. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. See L<perlartistic> for details.

This product includes ClearSilver developed by 
Neotonic Software Corp.  (L<http://www.neotonic.com/>).

=cut
