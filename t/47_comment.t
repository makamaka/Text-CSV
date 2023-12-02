#!/usr/bin/perl

use strict;
$^W = 1;

use Test::More;
BEGIN { $ENV{PERL_TEXT_CSV} = $ENV{TEST_PERL_TEXT_CSV} || 0; }
use Text::CSV qw(csv);

BEGIN {
    if ($] < 5.008002) {
	plan skip_all => "These tests require Encode and Unicode support";
	}
    else {
	require Encode;
	plan tests => 61;
	}
    require "./t/util.pl";
    }

$| = 1;

my $tfn = "_47cmnt.csv"; END { -f $tfn and unlink $tfn; }

foreach my $cstr ("#", "//", "Comment", "\xe2\x98\x83") {
    foreach my $rest ("", " 1,2", "a,b") {

	my $csv = Text::CSV->new ({ binary => 1 });
	   $csv->comment_str ($cstr);

	my $fh;
	open  $fh, ">", $tfn or die "$tfn: $!\n";
	print $fh qq{$cstr$rest\n};
	print $fh qq{c,$cstr\n};
	print $fh qq{ $cstr\n};
	print $fh qq{e,$cstr,$rest\n};
	print $fh qq{$cstr\n};
	print $fh qq{g,i$cstr\n};
	print $fh qq{j,"k\n${cstr}k"\n};
	print $fh qq{$cstr\n};
	close $fh;

	open  $fh, "<", $tfn or die "$tfn: $!\n";

	my $cuni = Encode::decode ("utf-8", $cstr);
	my @rest = split m/,/ => $rest, -1; @rest or push @rest => "";

	is_deeply ($csv->getline ($fh), [ "c", $cuni ],		"$cstr , $rest");
	is_deeply ($csv->getline ($fh), [ " $cuni" ],		"leading space");
	is_deeply ($csv->getline ($fh), [ "e", $cuni, @rest ],	"not start of line");
	is_deeply ($csv->getline ($fh), [ "g", "i$cuni" ],	"not start of field");
	is_deeply ($csv->getline ($fh), [ "j", "k\n${cuni}k" ],	"in quoted field after NL");

	close $fh;

	unlink $tfn;
	}
    }

is_deeply (csv (
    in               => *DATA,
    sep_char         => "|",
    headers          => "auto",
    allow_whitespace => 1,
    comment_str      => "#"
    ), [{ id => 42, name => "foo" }], "Last record is comment");

1;
__END__
id | name
#
42 | foo
#
