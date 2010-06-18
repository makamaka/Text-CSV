#!/usr/bin/perl

use strict;
$^W = 1;

#use Test::More "no_plan";
 use Test::More tests => 7;

BEGIN {
    $ENV{PERL_TEXT_CSV} = 0;
    use_ok "Text::CSV", ();
    plan skip_all => "Cannot load Text::CSV" if $@;
    }

my $csv = Text::CSV->new ({ binary => 1, eol => "\n" });

my $foo;
my @foo = ("#", 1..3);

SKIP: {
    $] < 5.006 and skip "Need perl 5.6.0 or higher for magic here", 2;
    tie $foo, "Foo";
    ok ($csv->combine (@$foo),		"combine () from magic");
    untie $foo;
    is_deeply ([$csv->fields], \@foo,	"column_names ()");
    }

tie $foo, "Foo";
open  FH, ">_76test.csv";
ok ($csv->print (*FH, $foo),		"print with unused magic scalar");
close FH;
untie $foo;

open  FH, "<_76test.csv";
is_deeply ($csv->getline (*FH), \@foo,	"Content read-back");
close FH;

tie $foo, "Foo";
ok ($csv->column_names ($foo),		"column_names () from magic");
untie $foo;
is_deeply ([$csv->column_names], \@foo,	"column_names ()");

unlink "_76test.csv";

package Foo;

use strict;
local $^W = 1;

require Tie::Scalar;
use vars qw( @ISA );
@ISA = qw(Tie::Scalar);

sub FETCH
{
    [ "#", 1 .. 3 ];
    } # FETCH

sub TIESCALAR
{
    bless [], "Foo";
    } # TIESCALAR

1;
