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

my $tfn = "_76test.csv"; END { -f $tfn and unlink $tfn; }
my $csv = Text::CSV->new ({ binary => 1, eol => "\n" });

my $fh;
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
open  $fh, ">", $tfn or die "$tfn: $!\n";
ok ($csv->print ($fh, $foo),		"print with unused magic scalar");
close $fh;
untie $foo;

open  $fh, "<", $tfn or die "$tfn: $!\n";
is_deeply ($csv->getline ($fh), \@foo,	"Content read-back");
close $fh;

tie $foo, "Foo";
ok ($csv->column_names ($foo),		"column_names () from magic");
untie $foo;
is_deeply ([$csv->column_names], \@foo,	"column_names ()");


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
