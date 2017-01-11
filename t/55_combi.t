#!/usr/bin/perl

use strict;
$^W = 1;

use Test::More tests => 9074;

BEGIN {
    $ENV{PERL_TEXT_CSV} = 0;
    require_ok "Text::CSV";
    plan skip_all => "Cannot load Text::CSV" if $@;
    require "t/util.pl";
    }

my $csv = Text::CSV->new ({ binary => 1 });

my @attrib  = qw( quote_char escape_char sep_char );
my @special = ('"', "'", ",", ";", "\t", "\\", "~");
# Add undef, once we can return undef
my @input   = ( "", 1, "1", 1.4, "1.4", " - 1,4", "1+2=3", "' ain't it great '",
    '"foo"! said the `bär', q{the ~ in "0 \0 this l'ne is \r ; or "'"} );
my $ninput  = scalar @input;
my $string  = join "=", "", @input, "";
my %fail;

ok (1, "--     qc     ec     sc     ac");
sub combi
{
    my %attr = @_;
    my $combi = join " ", "--",
	map { sprintf "%6s", _readable $attr{$_} } @attrib, "always_quote";
    ok (1, $combi);
    foreach my $attr (sort keys %attr) {
	$csv->$attr ($attr{$attr});
	is ($csv->$attr (), $attr{$attr},  "check $attr");
	}

    my $ret = $csv->combine (@input);

    if ($attr{sep_char} eq $attr{quote_char} ||
	$attr{sep_char} eq $attr{escape_char}) {
	is ($ret, undef, "Illegal combo for combine");

	ok (!$csv->parse ("foo"), "illegal combo for parse");
	return;
	}

    ok ($ret, "combine");
    ok (my $str = $csv->string, "string");
    SKIP: {
	ok (my $ok = $csv->parse ($str), "parse");

	unless ($ok) {
	    $fail{parse}{$combi} = $csv->error_input;
	    skip "parse () failed",  3;
	    }

	ok (my @ret = $csv->fields, "fields");
	unless (@ret) {
	    $fail{fields}{$combi} = $csv->error_input;
	    skip "fields () failed", 2;
	    }

	is (scalar @ret, $ninput,   "$ninput fields");
	unless (scalar @ret == $ninput) {
	    $fail{'$#fields'}{$combi} = $str;
	    skip "# fields failed",  1;
	    }

	my $ret = join "=", "", @ret, "";
	is ($ret, $string,          "content");
	}
    } # combi

foreach my $aq (0, 1) {
foreach my $qc (@special) {
foreach my $ec (@special, "+") {
foreach my $sc (@special, "\0") {
    combi (
	sep_char         => $sc,
	quote_char       => $qc,
	escape_char      => $ec,
	always_quote     => $aq,
	);
    }
   }
  }
 }

foreach my $fail (sort keys %fail) {
    print STDERR "Failed combi for $fail ():\n",
		 "--     qc     ec     sc     ac\n";
    foreach my $combi (sort keys %{$fail{$fail}}) {
	printf STDERR "%-20s - %s\n", map { _readable $_ } $combi, $fail{$fail}{$combi};
	}
    }
1;
