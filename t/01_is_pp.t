#!/usr/bin/perl

use strict;
$^W = 1;    # use warnings core since 5.6

use Test::More tests => 4;

BEGIN {
    $ENV{PERL_TEXT_CSV} = 0;
    use_ok "Text::CSV";
    plan skip_all => "Cannot load Text::CSV" if $@;
    }

{
    ok my $csv = Text::CSV->new;
    ok $csv->is_pp;
    is $csv->module => 'Text::CSV_PP';
}
