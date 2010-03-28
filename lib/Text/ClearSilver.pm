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

        Config => {
            VarEscapeMode => 'html', # html,js,url, or none
            TagStart      => 'cs',   # <?cs ... >
        }
    );

    $cs->register_function( lcfirst => sub{ lcfirst $_[0] });

    my %vars = (
        foo => 'bar',         # as var:foo
        baz => { qux => 42 }, # as var:baz.qux
    );
    $cs->process(\q{<?cs var:lcfirst(foo) ?>},
        \%vars,
        \*STDOUT); # => Bar

=head1 DESCRIPTION

Text::ClearSilver is a Perl binding to the B<ClearSilver> template engine.

=head1 INTERFACE

=head2 The Text::ClearSilver class

=head3 C<< Text::ClearSilver->new(Config => \%config) :TCS >>

Creates a Text::ClearSilver processor.

Configuration parameters may be:

=over 4

=item C<< VarEscapeMode => ( 'html' | 'js' | 'url' | 'none' ) >>

=item C<< TagStart => $str >>

=item C<< EnableAuditMode => $bool >>

=back

=head3 C<< $cs->register_function($name, \&func, $n_args = -1 ) :Void >>

Registers a named function in the TCS processor.

If you set the number of arguments E<gt>= 0, it will be checked at parsing
time, rather than runtime.

=head3 C<< $cs->process($source, $data, ?$output, %config) :Void >>

Processes a ClearSilver template. The first parameter, I<$source>, indicates
the input template as a filename, filehandle, or scalar reference.
The second, I<$data>, indicates template variables which may be a HDF data set,
HASH reference, ARRAY reference. The result of process is printed to the
optional third parameter, I<$output>, which may be a filename, filehandle,
or scalar reference. If the third parameter is omitted, the default filehandle
will be used. Optional I<%config> are the same as I<%config> for C<new()>.

=head2 The Text::ClearSilver::HDF class

This is a low-level interface to the C<< HDF* >> data structure.

=head3 B<< Text::ClearSilver::HDF->new($hdf_source) :HDF >>

Creates a HDF data set and initializes it with I<$hdf_source>, which
may be a reference to data structure or an HDF string.

Note that any scalar values, including blessed references, will be simply
stringified.

=head3 B<< $hdf->add($hdf_source) :Void >>

Adds I<$hdf_source> into the data set.

I<$hdf_source> may be a reference to data structure or an HDF string.

=head3 B<< $hdf->get_value($name, ?$default_value) :Str >>

Returns the value of a named node in the data set.

=head3 B<< $hdf->get_obj($name) :HDF >>

Returns the data set node at a named location.

=head3 B<< $hdf->get_node($name) :HDF >>

Similar to C<get_obj> except all the nodes are created if they do not exist.

=head3 B<< $hdf->get_child($name) :HDF >>

Returns the first child of a named node.

=head3 B<< $hdf->obj_child :HDF >>

Returns the first child of the data set.

=head3 B<< $hdf->obj_next :HDF >>

Returns the next node of the data set.

=head3 B<< $hdf->obj_top :HDF >>

Returns the top node of the node, which is returned by C<new>.

=head3 B<< $hdf->obj_name :Str >>

Returns the name of the node.

=head3 B<< $hdf->obj_value :Str >>

Returns the value of the node.

=head3 B<< $hdf->set_value($name) :Void >>

Sets the value of a named node.

=head3 B<< $hdf->set_copy($dest_name, $src_name) :Void >>

Copies a value from one location in the data set to another.

=head3 B<< $hdf->set_symlink($src_name, $dest_name) :Void >>

Sets a part of the data set to link to another.

=head3 B<< $hdf->sort_obj(\&compare) :Void >>

Sorts the children of the data set.

A I<&compare> callback is given a pair of HDF nodes.
For example, here is a function to sort a data set by names:

    $hdf->sort_obj(sub {
        my($a, $b) = @_;
        return $a->obj_name cmp $b->obj_name;
    });

=head3 B<< $hdf->read_file($filename) :Void >>

Reads an HDF data file.

=head3 B<< $hdf->write_file($filename) :Void >>

Writes an HDF data file.

=head3 B<< $hdf->dump() :Str >>

Serializes the data set to an HDF string, which can be passed into C<add()>.

=head3 B<< $hdf->remove_tree($name) :Void >>

Removes a named node of the data set.

=head3 B<< $hdf->copy($name, $source) :Void >>

Copies a named node of a data set to the data set.

if I<$name> is empty, all the I<$souece> node will be copied.

=head2 Text::ClearSilver::CS

This is a low-level interface to the C<< CSPARSE* >> template engine.

=head3 B<< Text::ClearSilver::CS->new($hdf_source) :CS >>

Creates a CS context with I<$hdf_source>, which
may be a reference to data structure or an HDF string..

=head3 B<< $cs->parse_file($file) :Void >>

Parses a CS template file.

=head3 B<< $cs->parse_string($string) :Void >>

Parses a CS template string.

=head3 B<< $cs->render() :Str >>

Renders the CS parse tree and returns the result as a string.

=head3 B<< $cs->render($filehandle) :Void >>

Renders the CS parse tree and print the result to a filehandle.

=head3 B<< $cs->dump() :Str >>

Dumps the CS parse tree for debugging.

=head1 APPENDIX

=head2 ClearSilver keywords

Here are ClearSilver keywords.

See L<http://www.clearsilver.net/docs/man_templates.hdf> for details.

=over 4

=item C<name>

=item C<var>

=item C<uvar>

=item C<evar>

=item C<lvar>

=item C<if>

=item C<else>

=item C<elseif>

=item C<elif>

=item C<each>

=item C<with>

=item C<include>

=item C<linclude>

=item C<def>

=item C<call>

=item C<set>

=item C<loop>

=item C<alt>

=item C<escape>

=back

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

L<Template>

=head1 AUTHORS

Craftworks E<lt>craftwork(at)cpan.orgE<gt>

Goro Fuji (gfx) E<lt>gfuji(at)cpan.orgE<gt>

=head1 ACKNOWLEDGMENT

The ClearSilver template engine is developed by Neotonic Software Corp,
and Copyright (c) 2003 Brandon Long.

See L<http://www.clearsilver.net/license.hdf> for the ClearSilver Software License.

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2010, Craftworks. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. See L<perlgpl> and L<perlartistic>.

=cut
