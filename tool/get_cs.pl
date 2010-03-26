#!perl -w

use strict;
use LWP::Simple;

my $version = shift || '0.10.5';
mirrot(
    "http://www.clearsilver.net/downloads/clearsilver-$version.tar.gz",
    "clearsilver.tar.gz",
);
