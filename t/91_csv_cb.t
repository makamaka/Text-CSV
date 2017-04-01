#!/usr/bin/perl

use strict;
$^W = 1;

#use Test::More "no_plan";
 use Test::More tests => 48;

BEGIN {
    $ENV{PERL_TEXT_CSV} = 0;
    use_ok "Text::CSV", ("csv");
    plan skip_all => "Cannot load Text::CSV" if $@;
    require "./t/util.pl";
    }

my $tfn  = "_91test.csv"; END { -f $tfn and unlink $tfn }
my $data =
    "foo,bar,baz\n".
    "1,2,3\n".
    "2,a b,\n";
open  FH, ">", $tfn or die "$tfn: $!";
print FH $data;
close FH;

my $aoa = [
    [qw( foo bar baz )],
    [ 1, 2, 3 ],
    [ 2, "a b", "" ],
    ];
my $aoh = [
    { foo => 1, bar => 2,     baz => 3  },
    { foo => 2, bar => "a b", baz => "" },
    ];

for (qw( after_in on_in before_out )) {
    is_deeply (csv (in => $tfn, $_ => sub {}), $aoa, "callback $_ on AOA with empty sub");
    is_deeply (csv (in => $tfn, callbacks => { $_ => sub {} }), $aoa, "callback $_ on AOA with empty sub");
    }
is_deeply (csv (in => $tfn, after_in => sub {},
    callbacks => { on_in => sub {} }), $aoa, "callback after_in and on_in on AOA");

for (qw( after_in on_in before_out )) {
    is_deeply (csv (in => $tfn, headers => "auto", $_ => sub {}), $aoh, "callback $_ on AOH with empty sub");
    is_deeply (csv (in => $tfn, headers => "auto", callbacks => { $_ => sub {} }), $aoh, "callback $_ on AOH with empty sub");
    }
is_deeply (csv (in => $tfn, headers => "auto", after_in => sub {},
    callbacks => { on_in => sub {} }), $aoh, "callback after_in and on_in on AOH");

is_deeply (csv (in => $tfn, after_in => sub { push @{$_[1]}, "A" }), [
    [qw( foo bar baz A )],
    [ 1, 2, 3, "A" ],
    [ 2, "a b", "", "A" ],
    ], "AOA ith after_in callback");

is_deeply (csv (in => $tfn, headers => "auto", after_in => sub { $_[1]{baz} = "A" }), [
    { foo => 1, bar => 2, baz => "A" },
    { foo => 2, bar => "a b", baz => "A" },
    ], "AOH with after_in callback");

is_deeply (csv (in => $tfn, filter => { 2 => sub { /a/ }}), [
    [qw( foo bar baz )],
    [ 2, "a b", "" ],
    ], "AOA with filter on col 2");
is_deeply (csv (in => $tfn, filter => { 2 => sub { /a/ },
					 1 => sub { length > 1 }}), [
    [qw( foo bar baz )],
    ], "AOA with filter on col 1 and 2");
is_deeply (csv (in => $tfn, filter => { foo => sub { $_ > 1 }}), [
    { foo => 2, bar => "a b", baz => "" },
    ], "AOH with filter on column name");

is_deeply (csv (in => $tfn, headers => "lc"),
	    [ { foo => 1, bar => 2,     baz => 3 },
	      { foo => 2, bar => "a b", baz => "" }],
	    "AOH with lc headers");
is_deeply (csv (in => $tfn, headers => "uc"),
	    [ { FOO => 1, BAR => 2,     BAZ => 3 },
	      { FOO => 2, BAR => "a b", BAZ => "" }],
	    "AOH with lc headers");
is_deeply (csv (in => $tfn, headers => sub { lcfirst uc $_[0] }),
	    [ { fOO => 1, bAR => 2,     bAZ => 3 },
	      { fOO => 2, bAR => "a b", bAZ => "" }],
	    "AOH with mangled headers");

open  FH, ">>", $tfn or die "$tfn: $!";
print FH <<"EOD";
3,3,3
4,5,6
5,7,9
6,9,12
7,11,15
8,13,18
EOD
close FH;

is_deeply (csv (in => $tfn,
	filter => { foo => sub { $_ > 2 && $_[1][2] - $_[1][1] < 4 }}), [
    { foo => 3, bar => 3, baz =>  3 },
    { foo => 4, bar => 5, baz =>  6 },
    { foo => 5, bar => 7, baz =>  9 },
    { foo => 6, bar => 9, baz => 12 },
    ], "AOH with filter on column name + on other numbered fields");

is_deeply (csv (in => $tfn,
	filter => { foo => sub { $_ > 2 && $_{baz}  - $_{bar}  < 4 }}), [
    { foo => 3, bar => 3, baz =>  3 },
    { foo => 4, bar => 5, baz =>  6 },
    { foo => 5, bar => 7, baz =>  9 },
    { foo => 6, bar => 9, baz => 12 },
    ], "AOH with filter on column name + on other named fields");

# Check content ref in on_in AOA
{   my $aoa = csv (
	in          => $tfn,
	filter      => { 1 => sub { m/^[3-9]/ }},
	on_in       => sub {
	    is ($_[1][1], 2 * $_[1][0] - 3, "AOA $_[1][0]: b = 2a - 3 \$_[1][]");
	    });
    }
# Check content ref in on_in AOH
{   my $aoa = csv (
	in          => $tfn,
	headers     => "auto",
	filter      => { foo => sub { m/^[3-9]/ }},
	after_parse => sub {
	    is ($_[1]{bar}, 2 * $_[1]{foo} - 3, "AOH $_[1]{foo}: b = 2a - 3 \$_[1]{}");
	    });
    }
# Check content ref in on_in AOH with aliases %_
{   %_ = ( brt => 42 );
    my $aoa = csv (
	in          => $tfn,
	headers     => "auto",
	filter      => { foo => sub { m/^[3-9]/ }},
	on_in       => sub {
	    is ($_{bar}, 2 * $_{foo} - 3, "AOH $_{foo}: b = 2a - 3 \$_{}");
	    });
    is_deeply (\%_, { brt => 42 }, "%_ restored");
    }

# Add to %_ in callback
is_deeply (csv (in      => $tfn,
		headers => "auto",
		filter  => { 1 => sub { $_ eq "4" }},
		on_in   => sub { $_{brt} = 42; }),
	    [{ foo => 4, bar => 5, baz => 6, brt => 42 }],
	    "AOH with addition to %_ in on_in");

open  FH, ">", $tfn or die "$tfn: $!";
print FH <<"EOD";
3,3,3

5,7,9
,
"",
,, ,
,"",
,," ",
""
8,13,18
EOD
close FH;

is_deeply (csv (in => $tfn, filter => "not_blank"),
	    [[3,3,3],[5,7,9],["",""],["",""],["",""," ",""],
	     ["","",""],["",""," ",""],[8,13,18]],
	    "filter => not_blank");
is_deeply (csv (in => $tfn, filter => "not_empty"),
	    [[3,3,3],[5,7,9],["",""," ",""],["",""," ",""],[8,13,18]],
	    "filter => not_empty");
is_deeply (csv (in => $tfn, filter => "filled"),
	    [[3,3,3],[5,7,9],[8,13,18]],
	    "filter => filled");
