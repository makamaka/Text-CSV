#!/usr/bin/perl

use strict;
$^W = 1;

use Test::More tests => 1082;

BEGIN {
    $ENV{PERL_TEXT_CSV} = 0;
    require_ok "Text::CSV";
    plan skip_all => "Cannot load Text::CSV" if $@;
    require "./t/util.pl";
    }

$| = 1;

# Embedded newline tests

my $tfn = "_45eol.csv"; END { -f $tfn and unlink $tfn; }
my $def_rs = $/;

foreach my $rs ("\n", "\r\n", "\r") {
    for $\ (undef, $rs) {

	my $csv = Text::CSV->new ({ binary => 1 });
	   $csv->eol ($/ = $rs) unless defined $\;

	foreach my $pass (0, 1) {
	    my $fh;
	    if ($pass == 0) {
		open $fh, ">", $tfn or die "$tfn: $!\n";
		}
	    else {
		open $fh, "<", $tfn or die "$tfn: $!\n";
		}

	    foreach my $eol ("", "\r", "\n", "\r\n", "\n\r") {
		my $s_eol = join " - ", map { defined $_ ? $_ : "<undef>" } $\, $rs, $eol;
		   $s_eol =~ s/\r/\\r/g;
		   $s_eol =~ s/\n/\\n/g;

		my @p;
		my @f = ("", 1,
		    $eol, " $eol", "$eol ", " $eol ", "'$eol'",
		    "\"$eol\"", " \" $eol \"\n ", "EOL");

		if ($pass == 0) {
		    ok ($csv->combine (@f),		"combine |$s_eol|");
		    ok (my $str = $csv->string,		"string  |$s_eol|");
		    my $state = $csv->parse ($str);
		    ok ($state,				"parse   |$s_eol|");
		    if ($state) {
			ok (@p = $csv->fields,		"fields  |$s_eol|");
			}
		    else{
			is ($csv->error_input, $str,	"error   |$s_eol|");
			}

		    print $fh $str;
		    }
		else {
		    ok (my $row = $csv->getline ($fh),	"getline |$s_eol|");
		    is (ref $row, "ARRAY",		"row     |$s_eol|");
		    @p = @$row;
		    }

		local $, = "|";
		is_binary ("@p", "@f",			"result  |$s_eol|");
		}

	    close $fh;
	    }

	unlink $tfn;
	}
    }
$/ = $def_rs;

{   my $csv = Text::CSV->new ({ escape_char => undef });

    ok ($csv->parse (qq{"x"\r\n}), "Trailing \\r\\n with no escape char");

    is ($csv->eol ("\r"), "\r", "eol set to \\r");
    ok ($csv->parse (qq{"x"\r}),   "Trailing \\r with no escape char");

    ok ($csv->allow_whitespace (1), "Allow whitespace");
    ok ($csv->parse (qq{"x" \r}),  "Trailing \\r with no escape char");
    }

SKIP: {
    $] < 5.008 and skip "\$\\ tests don't work in perl 5.6.x and older", 2;
    {   local $\ = "#\r\n";
	my $csv = Text::CSV->new ();
	open my $fh, ">", $tfn or die "$tfn: $!\n";
	$csv->print ($fh, [ "a", 1 ]);
	close   $fh;
	open    $fh, "<", $tfn or die "$tfn: $!\n";
	local $/;
	is (<$fh>, "a,1#\r\n", "Strange \$\\");
	close   $fh;
	unlink  $tfn;
	}
    {   local $\ = "#\r\n";
	my $csv = Text::CSV->new ({ eol => $\ });
	open my $fh, ">", $tfn or die "$tfn: $!\n";
	$csv->print ($fh, [ "a", 1 ]);
	close   $fh;
	open    $fh, "<", $tfn or die "$tfn: $!\n";
	local $/;
	is (<$fh>, "a,1#\r\n", "Strange \$\\ + eol");
	close   $fh;
	unlink  $tfn;
	}
    }
$/ = $def_rs;

ok (1, "Auto-detecting \\r");
{   my @row = qw( a b c ); local $" = ",";
    for (["\n", "\\n"], ["\r\n", "\\r\\n"], ["\r", "\\r"]) {
	my ($eol, $s_eol) = @$_;
	open my $fh, ">", $tfn or die "$tfn: $!\n";
	print   $fh qq{@row$eol@row$eol@row$eol\x91};
	close   $fh;
	open    $fh, "<", $tfn or die "$tfn: $!\n";
	my $c = Text::CSV->new ({ binary => 1, auto_diag => 1 });
	is ($c->eol (),			"",		"default EOL");
	is_deeply ($c->getline ($fh),	[ @row ],	"EOL 1 $s_eol");
	is ($c->eol (),	$eol eq "\r" ? "\r" : "",	"EOL");
	is_deeply ($c->getline ($fh),	[ @row ],	"EOL 2 $s_eol");
	is_deeply ($c->getline ($fh),	[ @row ],	"EOL 3 $s_eol");
	close   $fh;
	unlink  $tfn;
	}
    }

ok (1, "Specific \\r test from tfrayner");
{   $/ = "\r";
    open my $fh, ">", $tfn or die "$tfn: $!\n";
    print   $fh qq{a,b,c$/}, qq{"d","e","f"$/};
    close   $fh;
    open    $fh, "<", $tfn or die "$tfn: $!\n";
    my $c = Text::CSV->new ({ eol => $/ });

    my $row;
    local $" = " ";
    ok ($row = $c->getline ($fh),	"getline 1");
    is (scalar @$row, 3,		"# fields");
    is ("@$row", "a b c",		"fields 1");
    ok ($row = $c->getline ($fh),	"getline 2");
    is (scalar @$row, 3,		"# fields");
    is ("@$row", "d e f",		"fields 2");
    close   $fh;
    unlink  $tfn;
    }
$/ = $def_rs;

ok (1, "EOL undef");
{   $/ = "\r";
    ok (my $csv = Text::CSV->new ({ eol => undef }), "new csv with eol => undef");
    open my $fh, ">", $tfn or die "$tfn: $!\n";
    ok ($csv->print ($fh, [1, 2, 3]), "print");
    ok ($csv->print ($fh, [4, 5, 6]), "print");
    close   $fh;

    open    $fh, "<", $tfn or die "$tfn: $!\n";
    ok (my $row = $csv->getline ($fh),	"getline 1");
    is (scalar @$row, 5,		"# fields");
    is_deeply ($row, [ 1, 2, 34, 5, 6],	"fields 1");
    close   $fh;
    unlink  $tfn;
    }
$/ = $def_rs;

foreach my $eol ("!", "!!", "!\n", "!\n!", "!!!!!!!!", "!!!!!!!!!!",
		 "\n!!!!!\n!!!!!", "!!!!!\n!!!!!\n", "%^+_\n\0!X**",
		 "\r\n", "\r") {
    (my $s_eol = $eol) =~ s/\n/\\n/g;
    $s_eol =~ s/\r/\\r/g;
    $s_eol =~ s/\0/\\0/g;
    ok (1, "EOL $s_eol");
    ok (my $csv = Text::CSV->new ({ eol => $eol }), "new csv with eol => $s_eol");
    open my $fh, ">", $tfn or die "$tfn: $!\n";
    ok ($csv->print ($fh, [1, 2, 3]), "print");
    ok ($csv->print ($fh, [4, 5, 6]), "print");
    close $fh;

    foreach my $rs (undef, "", "\n", $eol, "!", "!\n", "\n!", "!\n!", "\n!\n") {
	local $/ = $rs;
	(my $s_rs = defined $rs ? $rs : "-- undef --") =~ s/\n/\\n/g;
	ok (1, "with RS $s_rs");
	open $fh, "<", $tfn or die "$tfn: $!\n";
	ok (my $row = $csv->getline ($fh),	"getline 1");
	is (scalar @$row, 3,			"field count");
	is_deeply ($row, [ 1, 2, 3],		"fields 1");
	ok (   $row = $csv->getline ($fh),	"getline 2");
	is (scalar @$row, 3,			"field count");
	is_deeply ($row, [ 4, 5, 6],		"fields 2");
	close $fh;
	}
    unlink $tfn;
    }
$/ = $def_rs;

{   open my $fh, "<", "files/macosx.csv" or die "files/macosx.csv: $!";
    ok (1, "MacOSX exported file");
    ok (my $csv = Text::CSV->new ({ auto_diag => 1, binary => 1 }), "new csv");
    ok (my $row = $csv->getline ($fh),	"getline 1");
    is (scalar @$row, 15,		"field count");
    is ($row->[7], "",			"field 8");
    ok (   $row = $csv->getline ($fh),	"getline 2");
    is (scalar @$row, 15,		"field count");
    is ($row->[6], "Category",		"field 7");
    ok (   $row = $csv->getline ($fh),	"getline 3");
    is (scalar @$row, 15,		"field count");
    is ($row->[5], "Notes",		"field 6");
    ok (   $row = $csv->getline ($fh),	"getline 4");
    is (scalar @$row, 15,		"field count");
    is ($row->[7], "Points",		"field 8");
    ok (   $row = $csv->getline ($fh),	"getline 5");
    is (scalar @$row, 15,		"field count");
    is ($row->[7], 11,			"field 8");
    ok (   $row = $csv->getline ($fh),	"getline 6");
    is (scalar @$row, 15,		"field count");
    is ($row->[8], 34,			"field 9");
    ok (   $row = $csv->getline ($fh),	"getline 7");
    is (scalar @$row, 15,		"field count");
    is ($row->[7], 12,			"field 8");
    ok (   $row = $csv->getline ($fh),	"getline 8");
    is (scalar @$row, 15,		"field count");
    is ($row->[8], 2,			"field 9");
    ok (   $row = $csv->getline ($fh),	"getline 9");
    is (scalar @$row, 15,		"field count");
    is ($row->[3], "devs",		"field 4");
    ok (   $row = $csv->getline ($fh),	"getline 10");
    is (scalar @$row, 15,		"field count");
    is ($row->[3], "",			"field 4");
    ok (   $row = $csv->getline ($fh),	"getline 11");
    is (scalar @$row, 15,		"field count");
    is ($row->[6], "Mean",		"field 7");
    ok (   $row = $csv->getline ($fh),	"getline 12");
    is (scalar @$row, 15,		"field count");
    is ($row->[6], "Median",		"field 7");
    ok (   $row = $csv->getline ($fh),	"getline 13");
    is (scalar @$row, 15,		"field count");
    is ($row->[6], "Mode",		"field 7");
    ok (   $row = $csv->getline ($fh),	"getline 14");
    is (scalar @$row, 15,		"field count");
    is ($row->[6], "Min",		"field 7");
    ok (   $row = $csv->getline ($fh),	"getline 15");
    is (scalar @$row, 15,		"field count");
    is ($row->[6], "Max",		"field 7");
    ok (   $row = $csv->getline ($fh),	"getline 16");
    is (scalar @$row, 15,		"field count");
    is ($row->[0], "",			"field 1");
    close $fh;
    }

{   ok (my $csv = Text::CSV->new ({ auto_diag => 1, binary => 1 }), "new csv");
    ok ($csv->eol ("--"), "eol = --");
    ok ($csv->parse (qq{1,"2--3",4}),			"no eol");
    is_deeply ([$csv->fields], [ "1", "2--3", 4 ],	"parse");
    ok ($csv->parse (qq{1,"2--3",4--}),			"eol");
    is_deeply ([$csv->fields], [ "1", "2--3", 4 ],	"parse");
    ok ($csv->parse (qq{1,"2--3",4,--}),		",eol");
    is_deeply ([$csv->fields], [ "1", "2--3", 4, "" ],	"parse");

    open my $fh, ">", $tfn or die "$tfn: $!\n";
    print   $fh qq{1,"2--3",4--};
    print   $fh qq{1,"2--3",4,--};
    print   $fh qq{1,"2--3",4};
    close   $fh;
    open    $fh, "<", $tfn or die "$tfn: $!\n";
    is_deeply ($csv->getline ($fh), [ "1", "2--3", 4 ],		"getline eol");
    is_deeply ($csv->getline ($fh), [ "1", "2--3", 4, "" ],	"getline ,eol");
    is_deeply ($csv->getline ($fh), [ "1", "2--3", 4 ],		"getline eof");
    close   $fh;
    }

{   ok (my $csv = Text::CSV->new (), "new csv");
    ok ($csv->parse (qq{"a","b","c"\r\n}), "parse \\r\\n");
    is_deeply ([$csv->fields], [qw( a b c )], "result");
    ok ($csv->allow_loose_escapes (1), "allow loose escapes");
    ok ($csv->parse (qq{"a","b","c"\r\n}), "parse \\r\\n");
    is_deeply ([$csv->fields], [qw( a b c )], "result");
    }

1;
