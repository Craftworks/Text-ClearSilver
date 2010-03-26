#!perl -w

use strict;
use LWP::Simple qw(mirror);
use File::Path qw(remove_tree);
use Archive::Tar;

my $version = shift || '0.10.5';

print "getting the ClearSilver distribution ...\n";
my $distfile = "clearsilver.tar.gz";
mirror(
    "http://www.clearsilver.net/downloads/clearsilver-$version.tar.gz",
    $distfile,
);

print "extracting from $distfile ...\n";
Archive::Tar->extract_archive($distfile);

remove_tree "clearsilver";
rename "clearsilver-$version" => "clearsilver";

print "done.\n";
