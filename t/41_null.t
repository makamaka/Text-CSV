#!/usr/bin/perl

use strict;
$^W = 1;

use Test::More tests => 128;

BEGIN {
    $ENV{PERL_TEXT_CSV} = 0;
    plan skip_all => "Cannot load Text::CSV" if $@;
    }

use Text::CSV;

my @pat = (
    "00", 
    "\00",
    "0\0",
    "\0\0",

    "0\n0",
    "\0\n0",
    "0\n\0",
    "\0\n\0",

    "\"0\n0",
    "\"\0\n0",
    "\"0\n\0",
    "\"\0\n\0",

    "\"0\n\"0",
    "\"\0\n\"0",
    "\"0\n\"\0",
    "\"\0\n\"\0",

    "0\n0",
    "\0\n0",
    "0\n\0",
    "\0\n\0",
    );
my %exp = map {
    my $x = $_;
    $x =~ s/\0/\\0/g;
    $x =~ s/\n/\\n/g;
    ($_ => $x);
    } @pat;
my $line = ["", undef, "0\n", "", "\0\0\n0"];

my $csv = Text::CSV->new ({
    eol			=> "\n",
    binary		=> 1,
    auto_diag		=> 1,
    blank_is_undef	=> 1,
    });

ok ($csv->combine (@$line), "combine [ ... ]");
is ($csv->string, qq{,,"0\n",,""0"0\n0"\n}, "string");

open FH, ">__test.csv" or die $!;
binmode FH;

for (@pat) {
    ok ($csv->print (*FH, [ $_ ]), "print $exp{$_}");
    }

$csv->always_quote (1);

ok ($csv->print (*FH, $line), "print [ ... ]");

close FH;

open FH, "<__test.csv" or die $!;
binmode FH;

foreach my $pat (@pat) {
    ok (my $row = $csv->getline (*FH), "getline $exp{$pat}");
    is ($row->[0], $pat, "data $exp{$pat}");
    }

is_deeply ($csv->getline (*FH), $line, "read [ ... ]");

close FH;

unlink "__test.csv";

$csv = Text::CSV->new ({
    eol			=> "\n",
    binary		=> 1,
    auto_diag		=> 1,
    blank_is_undef	=> 1,
    quote_null		=> 0,
    });

ok ($csv->combine (@$line), "combine [ ... ]");
is ($csv->string, qq{,,"0\n",,"\0\0\n0"\n}, "string");

open FH, ">__test.csv" or die $!;
binmode FH;

for (@pat) {
    ok ($csv->print (*FH, [ $_ ]), "print $exp{$_}");
    }

$csv->always_quote (1);

ok ($csv->print (*FH, $line), "print [ ... ]");

close FH;

open FH, "<__test.csv" or die $!;
binmode FH;

foreach my $pat (@pat) {
    ok (my $row = $csv->getline (*FH), "getline $exp{$pat}");
    is ($row->[0], $pat, "data $exp{$pat}");
    }

is_deeply ($csv->getline (*FH), $line, "read [ ... ]");

close FH;

unlink "__test.csv";
