#!/usr/bin/perl

use strict;
$^W = 1;

#use Test::More "no_plan";
 use Test::More tests => 13;

BEGIN {
    $ENV{PERL_TEXT_CSV} = 0;
    use_ok "Text::CSV", ();
    plan skip_all => "Cannot load Text::CSV" if $@;
    }

my $tfn = "_76test.csv"; END { -f $tfn and unlink $tfn; }
my $csv = Text::CSV->new ({ binary => 1, eol => "\n" });

my $fh;
my $foo;
my $bar;
my @foo = ("#", 1..3);

tie $foo, "Foo";
ok ($csv->combine (@$foo),		"combine () from magic");
untie $foo;
is_deeply ([$csv->fields], \@foo,	"column_names ()");

tie $bar, "Bar";
$bar = "#";
ok ($csv->combine ($bar, @{$foo}[1..3]),"combine () from magic");
untie $bar;
is_deeply ([$csv->fields], \@foo,	"column_names ()");

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

open  $fh, "<", $tfn or die "$tfn: $!\n";
tie $bar, "Bar";
ok ($csv->bind_columns (\$bar, \my ($f0, $f1, $f2)), "bind");
ok ($csv->getline ($fh),		"fetch with magic");
is_deeply ([$bar,$f0,$f1,$f2], \@foo,	"columns fetched on magic");
# free any refs
is ($csv->bind_columns (undef), undef,	"bind column clear");
untie $bar;
close $fh;

{   package Foo;
    use strict;
    use warnings;

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
    }

{   package Bar;

    use strict;
    use warnings;

    require Tie::Scalar;
    use vars qw( @ISA );
    @ISA = qw(Tie::Scalar);

    sub FETCH
    {
	return ${$_[0]};
	} # FETCH

    sub STORE
    {
	${$_[0]} = $_[1];
	} # STORE

    sub TIESCALAR
    {
	my $bar;
	bless \$bar, "Bar";
	} # TIESCALAR

    1;
    }
