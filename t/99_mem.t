#!/usr/bin/perl

use strict;
$^W = 1;

use Test::More tests => 12;
BEGIN { $ENV{PERL_TEXT_CSV} = $ENV{TEST_PERL_TEXT_CSV} || 0; }
use Text::CSV;

foreach my $key (qw( sep quote eol )) {
    my $csv = Text::CSV->new ({ binary => 1 });
    $csv->{$key} = "X" x 8000;
    my $input = "a,b,c\n";
    open my $fh, "<", \$input;
    eval {
	my $rv = $csv->getline ($fh);
	diag "  $key: rv=", (defined $rv ? "OK" : "undef"), "\n";
	};
    like ($@, qr{INI - \U$key\E too long},
	"Cannot set $key to a value longer than 16");
    }

{   # Aggressive lifetime probe for csv->undef_str
    my $csv = Text::CSV->new ({ binary => 1 });

    my $marker = "U" . ("X" x 4096);
    ok ($csv->undef_str ($marker), 	"Set undef_str");
    ok ($csv->combine ("a", undef, "c"),"Forces cache build");
    ok (my $str = $csv->string,		"Combined");
    like ($str, qr{^a,UXXXXXXX},	"Expected content");
    is (length $str, 4101,		"Expected length");

    # Now drop the only remaining ref to the SV holding our 4097-byte PV.
    $marker = undef;			# caller's lexical drops to 0 (no other refs except hash)
    delete $csv->{undef_str};		# hash drops its ref ? SV freed if no held ref

    # Allocator pressure to recycle the freed region with attacker bytes.
    my @junk = map { "GARBAGE_" . ("Z" x 4080) . "_$_" } 1..200;
    @junk = ();

    # Trigger Combine path that reads csv->undef_str
    ok ($csv->combine ("a", undef, "c"),"Combine again");
    ok (my $out = $csv->string,		"Get string");
    # If memory was overwritten, the second output's middle field will not
    # match the original "U...XXX...". Compare a known prefix.
    like ($str, qr{^a,UXXXXXXX},	"Expected content");
    is (length $out, 4101,		"Expected length");
    }
