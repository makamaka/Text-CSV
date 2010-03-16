#!/usr/bin/perl

use strict;
$^W = 1;

#use Test::More "no_plan";
 use Test::More tests => 68;

BEGIN {
    $ENV{PERL_TEXT_CSV} = 0;
    use_ok "Text::CSV", ();
    plan skip_all => "Cannot load Text::CSV" if $@;
}

open  FH, ">_test.csv";
print FH <<EOC;
code,name,price,description
1,Dress,240.00,"Evening gown"
2,Drinks,82.78,"Drinks"
3,Sex,-9999.99,"Priceless"
4,Hackathon,0,"QA Hackathon Oslo 2008"
EOC
close FH;

ok (my $csv = Text::CSV->new (),	"new");
is ($csv->column_names, undef,		"No headers yet");

foreach my $args ([\1], ["foo", \1], [{ 1 => 2 }]) {
    eval { $csv->column_names (@$args) };
    like ($@, qr/^EHR/, "croak");
    is ($csv->error_diag () + 0, 3001,	"Bad args to column_names");
    }

ok ($csv->column_names ("name"),	"One single name");
is ($csv->column_names (undef), undef,	"reset column_names");
eval { $csv->column_names (\undef) };
is ($csv->error_diag () + 0, 3001, "No hash please");
eval { $csv->column_names ({ 1 => 2 }) };
is ($csv->error_diag () + 0, 3001, "No hash please");

my $hr;
eval { $hr = $csv->getline_hr (*FH) };
is ($hr, undef,	"getline_hr before column_names");
like ($@, qr/^EHR/, "croak");
is ($csv->error_diag () + 0, 3002, "error code");

ok ($csv->column_names ("name", "code"), "column_names (list)");
is_deeply ([ $csv->column_names ], [ "name", "code" ], "well set");

open  FH, "<_test.csv";
my $row;
ok ($row = $csv->getline (*FH),		"getline headers");
is ($row->[0], "code",			"Header line");
ok ($csv->column_names ($row),		"column_names from array_ref");
is_deeply ([ $csv->column_names ], [ @$row ], "Keys set");
while (my $hr = $csv->getline_hr (*FH)) {
    ok (exists $hr->{code},			"Line has a code field");
    like ($hr->{code}, qr/^[0-9]+$/,		"Code is numeric");
    ok (exists $hr->{name},			"Line has a name field");
    like ($hr->{name}, qr/^[A-Z][a-z]+$/,	"Name");
    }
close FH;

my ($code, $name, $price, $desc) = (1..4);
is ($csv->bind_columns (), undef,		"No bound columns yet");
eval { $csv->bind_columns (\$code) };
is ($csv->error_diag () + 0, 3003,		"Arg cound mismatch");
eval { $csv->bind_columns ({}, {}, {}, {}) };
is ($csv->error_diag () + 0, 3004,		"bad arg types");
is ($csv->column_names (undef), undef,		"reset column_names");
ok ($csv->bind_columns (\($code, $name, $price)), "Bind columns");

eval { $csv->column_names ("foo") };
is ($csv->error_diag () + 0, 3003,		"Arg cound mismatch");
$csv->bind_columns (undef);
eval { $csv->bind_columns ([undef]) };
is ($csv->error_diag () + 0, 3004,		"legal header defenition");

my @bcr = \($code, $name, $price, $desc);
open  FH, "<_test.csv";
ok ($row = $csv->getline (*FH),			"getline headers");
ok ($csv->bind_columns (@bcr),			"Bind columns");
ok ($csv->column_names ($row),			"column_names from array_ref");
is_deeply ([ $csv->column_names ], [ @$row ],	"Keys set");

$row = $csv->getline (*FH);
is_deeply ([ $csv->bind_columns ], [ @bcr ],	"check refs");
is_deeply ($row, [],		"return from getline with bind_columns");

is ($csv->column_names (undef), undef,		"reset column headers");
is ($csv->bind_columns (undef), undef,		"reset bound columns");

my $foo;
ok ($csv->bind_columns (@bcr, \$foo),		"bind too many columns");
($code, $name, $price, $desc, $foo) = (101 .. 105);
ok ($csv->getline (*FH),			"fetch less than expected");
is_deeply ([ $code, $name, $price, $desc, $foo ],
	   [ 2, "Drinks", "82.78", "Drinks", 105 ],	"unfetched not reset");

my @foo = (0) x 0x012345;
ok ($csv->bind_columns (\(@foo)),		"bind a lot of columns");

ok ($csv->bind_columns (\1, \2, \3, \""),	"bind too constant columns");
is ($csv->getline (*FH), undef,			"fetch to read-only ref");
is ($csv->error_diag () + 0, 3008,		"Read-only");

ok ($csv->bind_columns (\$code),		"bind not enough columns");
eval { $row = $csv->getline (*FH) };
is ($csv->error_diag () + 0, 3006,		"cannot read all fields");

close FH;

open  FH, "<_test.csv";

is ($csv->column_names (undef), undef,		"reset column headers");
is ($csv->bind_columns (undef), undef,		"reset bound columns");
is_deeply ([ $csv->column_names (undef, "", "name", "name") ],
	   [ "\cAUNDEF\cA", "", "name", "name" ],	"undefined column header");
ok ($hr = $csv->getline_hr (*FH),		"getline_hr ()");
is (ref $hr, "HASH",				"returned a hashref");
is_deeply ($hr, { "\cAUNDEF\cA" => "code", "" => "name", "name" => "description" },
    "Discarded 3rd field");

close FH;

unlink "_test.csv";
