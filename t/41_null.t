#!/usr/bin/perl

use strict;
$^W = 1;

use Test::More tests => 62;

BEGIN {
    $ENV{PERL_TEXT_CSV} = 0;
}

use Text::CSV;

plan skip_all => "Cannot load Text::CSV" if Text::CSV->backend ne 'Text::CSV_PP';

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

my $csv = Text::CSV->new ({
    eol			=> "\n",
    binary		=> 1,
    auto_diag		=> 1,
    blank_is_undef	=> 1,
    });

open FH, ">__test.csv" or die $!;
binmode FH;

for (@pat) {
    ok ($csv->print (*FH, [ $_ ]), "print $exp{$_}");
    }

$csv->always_quote (1);

my $line = ["", undef, "0\n", "", "\0\n0"];
ok ($csv->print (*FH, $line), "print [ ... ]");

close FH;

open FH, "<__test.csv" or die $!;
binmode FH;

foreach my $pat (@pat) {
    ok (my $row = $csv->getline (*FH), "getline $exp{$pat}");
    is ($row->[0], $pat, "data $exp{$pat}");
    }

my $row = $csv->getline (*FH);

is_deeply ($row, $line, "read [ ... ]");

close FH;

unlink "__test.csv";
