package Text::ClearSilver;

use 5.008_001;
use strict;


#use version(); our $VERSION = version->new('0.10.5.0');
our $VERSION =                              '0.10.5.0'; # workaround ShipIt 0.55
#                                            ^^^^^^      ClearSilver core version
#                                                  ^^    Text::ClearSilver version


use XSLoader;
XSLoader::load(__PACKAGE__, $VERSION);

1;
__END__

=head1 NAME

Text::ClearSilver - Perl interface to the ClearSilver template engine

=head1 VERSION

This document describes Text::ClearSilver version v0.10.5.0.

=head1 SYNOPSIS

    use Text::ClearSilver;

    my $cs = Text::ClearSilver->new(
        # core configuration
        VarEscapeMode => 'html', # html,js,url, or none
        TagStart      => 'cs',   # <?cs ... >

        # extended configuratin
        load_path => [qw(/path/to/template)],
        dataset   => { common_foo => 'value' },
    );

    $cs->register_function( lcfirst => sub{ lcfirst $_[0] } );

    my %vars = (
        foo => 'bar',         # as var:foo
        baz => { qux => 42 }, # as var:baz.qux
    );

    $cs->process(\q{<?cs var:lcfirst(foo) ?>}, \%vars); # => Bar

=head1 DESCRIPTION

Text::ClearSilver is a Perl binding to the B<ClearSilver> template engine.

=head1 INTERFACE

=head2 The Text::ClearSilver class

=head3 C<< Text::ClearSilver->new(%config | \%config) :TCS >>

Creates a Text::ClearSilver processor.

Configuration parameters may be:

=over 4

=item C<< VarEscapeMode => ( 'none' | 'html' | 'js' | 'url' ) >>

Sets variable escaping mode. If it is not C<none>, template variables will be
automatically escaped. Default to C<none>.

This is ClearSilver core feature, and a shortcut for
C<< dataset => { Config => VarEscapeMode => ... } >>.

=item C<< TagStart => $str >>

Sets ClearSilver tag. Default to C<cs>.

This is ClearSilver core feature, and a shortcut for
C<< dataset => { Config => TagStart => ... } >>.

=item C<< load_path => \@path >>

Sets paths which are used to find template files.

This is a shortcut for C<< dataset => { hdf => { loadpaths => \@path } } >>.

=item C<< dataset => $hdf_source >>

Sets a dataset which is used in common.

I<$hdf_source> may be references to data or HDF string.

=back

=head3 C<< $tcs->dataset :HDF >>

Returns the dataset that the processor uses in common.

=head3 C<< $tcs->register_function($name, \&func, $n_args = -1 ) :Void >>

Registers a named function in the TCS processor.

If you set the number of arguments E<gt>= 0, it will be checked at parsing
time, rather than runtime.

Note that Text::ClearSilver defines some builtin functions,
and you cannot re-define them.

Builtin functions are as follows:

=over 4

=item C<subcount(var)>

Returns the number of child nodes for the HDF variable.

=item C<len(var)>

A synonym to C<subcount()>.

=item C<name(local)>

Returns the HDF variable name for a local variable alias.

=item C<first(lolca)>

Returns true if and only if the local variable is the first in a loop or each.

=item C<last(local)>

Returns true if and only if the local variable is the last in a loop or each.

=item C<abs(num)>

Returns the absolute value of the numeric expressions.

=item C<max(num1, num2)>

Returns the larger of two numeric expressions.

=item C<min(num1, num2)>

Returns the smaller of two numeric expressions.

=item C<string.slice(expr, start, end)>

Returns the string slice starting at start and ending at end.

=item C<string.find(expr, substr)>

Returns the numeric position of the substring in the string (if found),
otherwise returns -1.

=item C<string.length(expr)>

Returns the length of the string expression.

=item C<_(expr)>

Only available if the system supports gettext(3), returns the translated
version of the string expression as returned by gettext().

=item C<html_escape(expr)>

Tries HTML escapes to the string expression. This converts characters such as
E<gt>, E<lt>, and E<amp>, into their HTML entities such as E<amp>gt;,
E<amp>lt;, and E<amp>amp;.

=item C<url_escape(expr)>

Tries URL encodes to the string expression. This converts characters such as
?, E<amp>, and = into their URL safe equivalents using the %hh syntax.

=item C<js_escape(expr)>

Tries JavaScript escapes to the string expression into valid data for placement
into a JavaScript string. This converts characters such as E<quot>, ', and E<92> into their
JavaScript string safe equivalents E<92>E<quot>,  E<92>', and  E<92>E<92>.

=item C<sprintf(fmt, ...)>

Returns a string formatted by Perl builtin C<sprintf> function.

For example:

    <?cs var:sprintf("%2$s %1$s", "foo", "bar") ?> # => "bar foo"

See L<perlfunc/sprintf> for details.

=back

=head3 C<< $tcs->process($source, $data, ?$output, %config) :Void >>

Processes a ClearSilver template. The first parameter, I<$source>, indicates
the input template as a filename, filehandle, or scalar reference.
The second, I<$data>, indicates template variables which may be a HDF dataset,
HASH reference, ARRAY reference. The result of process is printed to the
optional third parameter, I<$output>, which may be a filename, filehandle,
or scalar reference. If the third parameter is omitted, the default filehandle
will be used. Optional I<%config> are stored into C<Config.*>, i.e.
C<< VarEscapeMode => 'html' >> changes the escaping mode temporally.

=head3 C<< $tcs->clear_cache :HASH >>

Clears the global file cache, and returns the old cache.

=head2 The Text::ClearSilver::HDF class

This is a low-level interface to the C<< HDF* >> (Hierarchial Data Format)
data structure.

=head3 B<< Text::ClearSilver::HDF->new($hdf_source) :HDF >>

Creates a HDF dataset and initializes it with I<$hdf_source>, which
may be a reference to data structure or an HDF string.

Notes:

=over 4

=item *

that any scalar values, including blessed references, will be simply
stringified.

=item *

C<undef> is simply ignored.

=item *

Cyclic references will not be converted correctly (TODO).

=back

=head3 B<< $hdf->add($hdf_source) :Void >>

Adds I<$hdf_source> into the dataset.

I<$hdf_source> may be a reference to data structure or an HDF string.

=head3 B<< $hdf->get_value($name, ?$default_value) :Str >>

Returns the value of a named node in the dataset.

=head3 B<< $hdf->get_obj($name) :HDF >>

Returns the dataset node at a named location.

=head3 B<< $hdf->get_node($name) :HDF >>

Similar to C<get_obj> except all the nodes are created if they do not exist.

=head3 B<< $hdf->get_child($name) :HDF >>

Returns the first child of a named node.

=head3 B<< $hdf->obj_child :HDF >>

Returns the first child of the dataset.

=head3 B<< $hdf->obj_next :HDF >>

Returns the next node of the dataset.

=head3 B<< $hdf->obj_name :Str >>

Returns the name of the node.

=head3 B<< $hdf->obj_value :Str >>

Returns the value of the node.

=head3 B<< $hdf->set_value($name) :Void >>

Sets the value of a named node.

=head3 B<< $hdf->set_copy($dest_name, $src_name) :Void >>

Copies a value from one location in the dataset to another.

=head3 B<< $hdf->set_symlink($src_name, $dest_name) :Void >>

Sets a part of the dataset to link to another.

=head3 B<< $hdf->sort_obj(\&compare) :Void >>

Sorts the children of the dataset.

A I<&compare> callback is given a pair of HDF nodes.
For example, here is a function to sort a dataset by names:

    $hdf->sort_obj(sub {
        my($a, $b) = @_;
        return $a->obj_name cmp $b->obj_name;
    });

=head3 B<< $hdf->read_file($filename) :Void >>

Reads an HDF data file.

=head3 B<< $hdf->write_file($filename) :Void >>

Writes an HDF data file.

=head3 B<< $hdf->dump() :Str >>

Serializes the dataset to an HDF string, which can be passed into C<add()>.

=head3 B<< $hdf->remove_tree($name) :Void >>

Removes a named node of the dataset.

=head3 B<< $hdf->copy($name, $source) :Void >>

Copies a named node of a dataset to the dataset.

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

See L<http://www.clearsilver.net/license.hdf> for ClearSilver Software License.

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2010, Craftworks. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. See L<perlgpl> and L<perlartistic>.

=cut
