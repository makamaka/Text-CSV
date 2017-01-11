#!/usr/bin/perl

use strict;
$^W = 1;

 use Test::More tests => 120;
#use Test::More "no_plan";

my %err;

BEGIN {
    $ENV{PERL_TEXT_CSV} = 0;
    require_ok "Text::CSV";
    plan skip_all => "Cannot load Text::CSV" if $@;
    require "t/util.pl";

    open PP, "< lib/Text/CSV_PP.pm" or die "Cannot read error messages from PP\n";
    while (<PP>) {
        m/^        ([0-9]{4}) => "([^"]+)"/ and $err{$1} = $2;
	}
    }

$| = 1;

my $csv = Text::CSV->new ();
is (Text::CSV::error_diag (), "",	"Last failure for new () - OK");
is_deeply ([ $csv->error_diag ], [ 0, "", 0, 0, 0], "OK in list context");

sub parse_err {
    my ($n_err, $p_err, $r_err, $f_err, $str) = @_;
    my $s_err = $err{$n_err};
    my $STR = _readable ($str);
    is ($csv->parse ($str), 0,	"$n_err - Err for parse ('$STR')");
    is ($csv->error_diag () + 0, $n_err, "$n_err - Diag in numerical context");
    is ($csv->error_diag (),     $s_err, "$n_err - Diag in string context");
    my ($c_diag, $s_diag, $p_diag, $r_diag, $f_diag) = $csv->error_diag ();
    is ($c_diag, $n_err,	"$n_err - Num diag in list context");
    is ($s_diag, $s_err,	"$n_err - Str diag in list context");
    is ($p_diag, $p_err,	"$n_err - Pos diag in list context");
    } # parse_err

parse_err 2027, 5,  1, 2, qq{2023,",2008-04-05,"Foo, Bar",\n}; # "

$csv = Text::CSV->new ({ escape_char => "+", eol => "\n" });
is ($csv->error_diag (), "",		"No errors yet");

parse_err 2010,  3,  1, 1, qq{"x"\r};
parse_err 2011,  3,  2, 1, qq{"x"x};

parse_err 2021,  2,  3, 1, qq{"\n"};
parse_err 2022,  2,  4, 1, qq{"\r"};
parse_err 2025,  3,  5, 1, qq{"+ "};
parse_err 2026,  3,  6, 1, qq{"\0 "};
parse_err 2027,  1,  7, 1,   '"';
parse_err 2031,  1,  8, 1, qq{\r };
parse_err 2032,  2,  9, 1, qq{ \r};
parse_err 2034,  2, 10, 2, qq{1, "bar",2};
parse_err 2037,  1, 11, 1, qq{\0 };

{   my @warn;
    local $SIG{__WARN__} = sub { push @warn, @_ };
    $csv->error_diag ();
    ok (@warn == 1, "Got error message");
    like ($warn[0], qr{^# CSV_PP ERROR: 2037 - EIF}, "error content");
    }

is (Text::CSV->new ({ ecs_char => ":" }), undef, "Unsupported option");

{   my @warn;
    local $SIG{__WARN__} = sub { push @warn, @_ };
    Text::CSV::error_diag ();
    ok (@warn == 1, "Error_diag in void context ::");
    like ($warn[0], qr{^# CSV_PP ERROR: 1000 - INI}, "error content");
    }
{   my @warn;
    local $SIG{__WARN__} = sub { push @warn, @_ };
    Text::CSV->error_diag ();
    ok (@warn == 1, "Error_diag in void context ->");
    like ($warn[0], qr{^# CSV_PP ERROR: 1000 - INI}, "error content");
    }

{   my @warn;
    local $SIG{__WARN__} = sub { push @warn, @_ };
    is (Text::CSV->new ({ auto_diag => 0, ecs_char => ":" }), undef,
	"Unsupported option");
    ok (@warn == 0, "Error_diag in from new ({ auto_diag => 0})");
    }
{   my @warn;
    local $SIG{__WARN__} = sub { push @warn, @_ };
    is (Text::CSV->new ({ auto_diag => 1, ecs_char => ":" }), undef,
	"Unsupported option");
    ok (@warn == 1, "Error_diag in from new ({ auto_diag => 1})");
    like ($warn[0], qr{^# CSV_PP ERROR: 1000 - INI}, "error content");
    }

is (Text::CSV::error_diag (), "INI - Unknown attribute 'ecs_char'",
					"Last failure for new () - FAIL");
is (Text::CSV->error_diag (), "INI - Unknown attribute 'ecs_char'",
					"Last failure for new () - FAIL");
is (Text::CSV::error_diag (bless {}, "Foo"), "INI - Unknown attribute 'ecs_char'",
					"Last failure for new () - FAIL");
$csv->SetDiag (0);
is (0 + $csv->error_diag (),    0,			"Reset error NUM");
is (    $csv->error_diag (),   "",			"Reset error STR");

ok (1, "Test auto_diag");
$csv = Text::CSV->new ({ auto_diag => 1 });
{   my @warn;
    local $SIG{__WARN__} = sub { push @warn, @_ };
    is ($csv->{_RECNO}, 0, "No records read yet");
    is ($csv->parse ('"","'), 0, "1 - bad parse");
    ok (@warn == 1, "1 - One error");
    like ($warn[0], qr '^# CSV_PP ERROR: 2027 -', "1 - error message");
    is ($csv->{_RECNO}, 1, "One record read");
    }
{   my @warn;
    local $SIG{__WARN__} = sub { push @warn, @_ };
    is ($csv->diag_verbose (3), 3, "Set diag_verbose");
    is ($csv->parse ('"","'), 0, "1 - bad parse");
    ok (@warn == 1, "1 - One error");
    @warn = split m/\n/ => $warn[0];
    ok (@warn == 3, "1 - error plus two lines");
    like ($warn[0], qr '^# CSV_PP ERROR: 2027 -', "1 - error message");
    like ($warn[1], qr '^"","',                   "1 - input line");
    is ($csv->{_RECNO}, 2, "Another record read");
    }
{   ok ($csv->{auto_diag} = 2, "auto_diag = 2 to die");
    eval { $csv->parse ('"","') };
    like ($@, qr '^# CSV_PP ERROR: 2027 -', "2 - error message");
    }

{   my $csv = Text::CSV->new ();
    ok ($csv->parse (q{1,"abc"}), "Valid parse");
    is ($csv->error_input (), undef, "Undefined error_input");
    is ($csv->{_ERROR_INPUT}, undef, "Undefined error_input");
    }

{   my $err = "";
    local $SIG{__DIE__} = sub { $err = shift; };
    ok (my $csv = Text::CSV->new, "new");
    eval { $csv->print_hr (*STDERR, {}); };
    is (0 + $csv->error_diag, 3009, "Missing column names");
    ok ($csv->column_names ("foo"), "set columns");
    eval { $csv->print_hr (*STDERR, []); };
    is (0 + $csv->error_diag, 3010, "print_hr needs a hashref");
    }

{   my $csv = Text::CSV->new ({ sep_char => "=" });
    eval { $csv->quote ("::::::::::::::"); };
    is (0 + $csv->error_diag,    0, "Can set quote to something long");
    eval { $csv->quote ("="); };
    is (0 + $csv->error_diag, 1001, "Cannot set quote to current sep");
    }

{   my $csv = Text::CSV->new ({ quote_char => "=" });
    eval { $csv->sep ("::::::::::::::"); };
    is (0 + $csv->error_diag,    0, "Can set sep to something long");
    eval { $csv->sep (undef); };
    is (0 + $csv->error_diag, 1008, "Can set sep to undef");
    eval { $csv->sep ("="); };
    is (0 + $csv->error_diag, 1001, "Cannot set sep to current sep");
    }

}

1;
