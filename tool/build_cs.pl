#!perl -w

use strict;
use Fatal qw(chdir);
use Config;

my $cs_dir = shift(@ARGV) || die "Usage: $0 CS_BUILD_DIRECTRY\n";

my @configure_args = qw(
    --disable-compression
    --disable-apache
    --disable-python
    --disable-perl
    --disable-ruby
    --disable-java
    --disable-csharp
    --enable-gettext
);

chdir $cs_dir;

# for configure
$ENV{CC}      = $Config{cc};
$ENV{CFLAGS}  = $Config{ccflags} . ' ' . $Config{optimize};
$ENV{LDFLAGS} = $Config{ldflags};
#$ENV{LIBS}    = $Config{libs};

xsystem('./configure', @configure_args);
xsystem('make');

sub xsystem {
    print "@_\n";
    system(@_) == 0
        or die "Fail!\n";
}
