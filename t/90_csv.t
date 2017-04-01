#!/usr/bin/perl

use strict;
$^W = 1;
use Config;

#use Test::More "no_plan";
 use Test::More tests => 45;

BEGIN {
    $ENV{PERL_TEXT_CSV} = 0;
    use_ok "Text::CSV", ("csv");
    plan skip_all => "Cannot load Text::CSV" if $@;
    require "./t/util.pl";
    }

my $tfn  = "_90test.csv"; END { -f $tfn and unlink $tfn }
my $data =
    "foo,bar,baz\n".
    "1,2,3\n".
    "2,a b,\n";
open  FH, ">", $tfn or die "$tfn: $!";
print FH $data;
close FH;

my @hdr = qw( foo bar baz );
my $aoa = [
    \@hdr,
    [ 1, 2, 3 ],
    [ 2, "a b", "" ],
    ];
my $aoh = [
    { foo => 1, bar => 2, baz => 3 },
    { foo => 2, bar => "a b", baz => "" },
    ];

SKIP: for my $io ([ $tfn, "file" ], [ \*FH, "globref" ], [ *FH, "glob" ], [ \$data, "ScalarIO"] ) {
    $] < 5.008 && ref $io->[0] eq "SCALAR" and skip "No ScalarIO support for $]", 1;
    open FH, "<", $tfn or die "$tfn: $!\n";
    is_deeply (csv ({ in => $io->[0] }), $aoa, "AOA $io->[1]");
    close FH;
    }

SKIP: for my $io ([ $tfn, "file" ], [ \*FH, "globref" ], [ *FH, "glob" ], [ \$data, "ScalarIO"] ) {
    $] < 5.008 && ref $io->[0] eq "SCALAR" and skip "No ScalarIO support for $]", 1;
    open FH, "<", $tfn or die "$tfn: $!\n";
    is_deeply (csv (in => $io->[0], headers => "auto"), $aoh, "AOH $io->[1]");
    close FH;
    }

is_deeply (csv (in => $tfn, headers => { bar => "tender" }), [
    { foo => 1, tender => 2,     baz => 3 },
    { foo => 2, tender => "a b", baz => "" },
    ], "AOH with header map");

my @aoa = @{$aoa}[1,2];
is_deeply (csv (file => $tfn, headers  => "skip"),    \@aoa, "AOA skip");
is_deeply (csv (file => $tfn, fragment => "row=2-3"), \@aoa, "AOA fragment");

if ($] >= 5.008001) {
    is_deeply (csv (in => $tfn, encoding => "utf-8", headers => ["a", "b", "c"],
		    fragment => "row=2", sep_char => ","),
	   [{ a => 1, b => 2, c => 3 }], "AOH headers fragment");
    is_deeply (csv (in => $tfn, enc      => "utf-8", headers => ["a", "b", "c"],
		    fragment => "row=2", sep_char => ","),
	   [{ a => 1, b => 2, c => 3 }], "AOH headers fragment");
    }
else {
    ok (1, q{This perl does not support open with "<:encoding(...)"});
    ok (1, q{This perl does not support open with "<:encoding(...)"});
    }

ok (csv (in => $aoa, out => $tfn), "AOA out file");
is_deeply (csv (in => $tfn), $aoa, "AOA parse out");

ok (csv (in => $aoh, out => $tfn, headers => "auto"), "AOH out file");
is_deeply (csv (in => $tfn, headers => "auto"), $aoh, "AOH parse out");

ok (csv (in => $aoh, out => $tfn, headers => "skip"), "AOH out file no header");
is_deeply (csv (in => $tfn, headers => [keys %{$aoh->[0]}]),
    $aoh, "AOH parse out no header");

my $idx = 0;
sub getrowa { return $aoa->[$idx++]; }
sub getrowh { return $aoh->[$idx++]; }

ok (csv (in => \&getrowa, out => $tfn), "out from CODE/AR");
is_deeply (csv (in => $tfn), $aoa, "data from CODE/AR");

$idx = 0;
ok (csv (in => \&getrowh, out => $tfn, headers => \@hdr), "out from CODE/HR");
is_deeply (csv (in => $tfn, headers => "auto"), $aoh, "data from CODE/HR");

$idx = 0;
ok (csv (in => \&getrowh, out => $tfn), "out from CODE/HR (auto headers)");
is_deeply (csv (in => $tfn, headers => "auto"), $aoh, "data from CODE/HR");
unlink $tfn;

# Basic "key" checks
SKIP: {
    $] < 5.008 and skip "No ScalarIO support for $]", 2;
    is_deeply (csv (in => \"key,value\n1,2\n", key => "key"),
		    { 1 => { key => 1, value => 2 }}, "key");
    is_deeply (csv (in => \"1,2\n", key => "key", headers => [qw( key value )]),
		    { 1 => { key => 1, value => 2 }}, "key");
    }

# Some "out" checks
open my $fh, ">", $tfn or die "$tfn: $!\n";
csv (in => [{ a => 1 }], out => $fh);
csv (in => [{ a => 1 }], out => $fh, headers => undef);
csv (in => [{ a => 1 }], out => $fh, headers => "auto");
csv (in => [{ a => 1 }], out => $fh, headers => ["a"]);
csv (in => [{ b => 1 }], out => $fh, headers => { b => "a" });
close $fh;
{   open  $fh, "<", $tfn or die "$tfn: $!\n";
    my $dta = do {local $/; <$fh>};
    my @layers = eval { PerlIO::get_layers ($fh); };
    close $fh;
    grep m/crlf/ => @layers and $dta =~ s/\n/\r\n/g;
    is ($dta, "a\r\n1\r\n" x 5, "AoH to out");
    }

# check internal defaults
{
    my $ad = 1;

    sub check
    {
	my ($csv, $ar) = @_;
	is ($csv->auto_diag,	$ad,	"default auto_diag ($ad)");
	is ($csv->binary,	1,	"default binary");
	is ($csv->eol,		"\r\n",	"default eol");
	} # check

    # Note that 5.6.x writes to a *file* named SCALAR(0x50414A10)
    open my $fh, ">", \my $out or die "IO: $!\n";
    csv (in => [[1,2]], out => $fh, on_in => \&check);

    # Check that I can overrule auto_diag
    $ad = 0;
    csv (in => [[1,2]], out => $fh, on_in => \&check, auto_diag => 0);
    }
$] < 5.008 and unlink glob "SCALAR(*)";

# errors
{   my $err;
    local $SIG{__DIE__} = sub { $err = shift; };
    my $r = eval { csv (in => undef); };
    is ($r, undef, "csv needs in or file");
    like ($err, qr{^usage:}, "error");
    undef $err;
    }

eval {
    exists  $Config{useperlio} &&
    defined $Config{useperlio} &&
    $] >= 5.008                &&
    $Config{useperlio} eq "define" or skip "No scalar ref in this perl", 5;
    my $out = "";
    open my $fh, ">", \$out or die "IO: $!\n";
    ok (csv (in => [[ 1, 2, 3 ]], out => $fh), "out to fh to scalar ref");
    is ($out, "1,2,3\r\n",	"Scalar out");
    $out = "";
    ok (csv (in => [[ 1, 2, 3 ]], out => \$out), "out to scalar ref");
    is ($out, "1,2,3\r\n",	"Scalar out");

    is_deeply (csv (in => \qq{1,"2 3"}, quo => undef, esc => undef),
	       [["1", q{"2 3"}]], "quo => undef");
    };

{   my $csv = Text::CSV->new ({ binary => 1, auto_diag => 1 });
    my $expect = [["a"],[1],["a"],[1],["a"],[1],["a"],[1],["a"],[1]];
    is_deeply ($csv->csv (in => $tfn),        $expect, "csv from object");
    is_deeply (csv (in => $tfn, csv => $csv), $expect, "csv from attribute");
    }

{   local *STDOUT;
    my $ofn = "_STDOUT.csv";
    open STDOUT, ">", $ofn or die "$ofn: $!\n";
    csv (in => $tfn, quote_always => 1, fragment => "row=1-2",
	on_in => sub { splice @{$_[1]}, 1; }, eol => "\n");
    close STDOUT;
    open my $oh, "<", $ofn or die "$ofn: $!\n";
    my $dta = do { local (@ARGV, $/) = $ofn; <> };
    is ($dta, qq{"a"\n"1"\n}, "Chained csv call inherited attributes");
    unlink $ofn;
    }
