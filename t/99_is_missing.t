#!/usr/bin/perl

use strict;
$^W = 1;

# use Test::More "no_plan";
use Test::More tests => 9;

BEGIN {
    $ENV{PERL_TEXT_CSV} = 0;
    use_ok "Text::CSV", ();
    plan skip_all => "Cannot load Text::CSV" if $@;
}

open  FH, ">_75test.csv";
print FH <<EOC;

2
EOC
close FH;

ok (my $csv = Text::CSV->new (),        "new");
is ($csv->is_missing(0), undef, "is_missing()");

open  FH, "<_75test.csv";
ok ($csv->column_names ('code'));
ok (my $hr = $csv->getline_hr (*FH));
is ($csv->is_missing(0), undef, "is_missing()");
ok ($hr = $csv->getline_hr (*FH));
is (int $hr->{code}, 2, "code==2");
isnt ($csv->is_missing(0), undef, "isn't is_missing()");
close FH;
