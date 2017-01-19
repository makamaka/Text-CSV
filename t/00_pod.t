print STDERR "# PERL_TEXT_CSV: ", (defined $ENV{PERL_TEXT_CSV} ? "$ENV{PERL_TEXT_CSV}" : "undef"), "\n";
#!/usr/bin/perl

use strict;
$^W = 1;

use Test::More;

eval "use Test::Pod 1.00";
plan skip_all => "Test::Pod 1.00 required for testing POD" if $@;
all_pod_files_ok ();
