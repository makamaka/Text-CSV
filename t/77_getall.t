#!/usr/bin/perl

use strict;
$^W = 1;

use Test::More tests => 11;

BEGIN {
    $ENV{PERL_TEXT_CSV} = 0;
    require_ok "Text::CSV";
    plan skip_all => "Cannot load Text::CSV" if $@;
    require "t/util.pl";
    }

$| = 1;

my @list = (
    [ 1, "a", "\x01", "A" ],
    [ 2, "b", "\x02", "B" ],
    [ 3, "c", "\x03", "C" ],
    [ 4, "d", "\x04", "D" ],
    );

{   ok (my $csv = Text::CSV->new ({ binary => 1, eol => "\n" }), "csv out");
    open  FH, ">_77test.csv" or die "_77test.csv: $!";
    ok ($csv->print (*FH, $_), "write $_->[0]") for @list;
    close FH;
    }

{   ok (my $csv = Text::CSV->new ({ binary => 1 }), "csv in");
    open  FH, "<_77test.csv" or die "_77test.csv: $!";
    is_deeply ($csv->getline_all (*FH), \@list, "Content");
    close FH;
    }

{   ok (my $csv = Text::CSV->new ({ binary => 1 }), "csv in");
    ok ($csv->column_names (my @cn = qw( foo bar bin baz )));
    open  FH, "<_77test.csv" or die "_77test.csv: $!";
    is_deeply ($csv->getline_hr_all (*FH),
	[ map { my %h; @h{@cn} = @$_; \%h } @list ], "Content");
    close FH;
    }

unlink "_77test.csv";
