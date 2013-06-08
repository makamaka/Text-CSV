#!/usr/bin/perl

use strict;
$^W = 1;	# use warnings core since 5.6

use Test::More tests => 118;

BEGIN {
    $ENV{PERL_TEXT_CSV} = 0;
    use_ok "Text::CSV";
    plan skip_all => "Cannot load Text::CSV" if $@;
    }

my $csv;
ok ($csv = Text::CSV->new,				"new ()");

is ($csv->quote_char,			'"',		"quote_char");
is ($csv->escape_char,			'"',		"escape_char");
is ($csv->sep_char,			',',		"sep_char");
is ($csv->eol,				'',		"eol");
is ($csv->always_quote,			0,		"always_quote");
is ($csv->binary,			0,		"binary");
is ($csv->keep_meta_info,		0,		"keep_meta_info");
is ($csv->allow_loose_quotes,		0,		"allow_loose_quotes");
is ($csv->allow_loose_escapes,		0,		"allow_loose_escapes");
#is ($csv->allow_unquoted_escape,    0, "allow_unquoted_escape");
is ($csv->allow_whitespace,		0,		"allow_whitespace");
is ($csv->blank_is_undef,		0,		"blank_is_undef");
is ($csv->empty_is_undef,		0,		"empty_is_undef");
is ($csv->auto_diag,			0,		"auto_diag");
is ($csv->verbatim,			0,		"verbatim");
is ($csv->quote_space,			1,		"quote_space");
is ($csv->quote_null,			1,		"quote_null");
is ($csv->quote_binary,         1,      "quote_binary");

is ($csv->binary (1),			1,		"binary (1)");
my @fld = ( 'txt =, "Hi!"', "Yes", "", 2, undef, "1.09", "\r", undef );
ok ($csv->combine (@fld),				"combine");
is ($csv->string,
    qq{"txt =, ""Hi!""",Yes,,2,,1.09,"\r",},	"string");

is ($csv->sep_char (";"),		';',		"sep_char (;)");
is ($csv->quote_char ("="),		'=',		"quote_char (=)");
is ($csv->eol (undef),			"",		"eol (undef)");
is ($csv->eol (""),			"",		"eol ('')");
is ($csv->eol ("\r"),			"\r",		"eol (\\r)");
is ($csv->keep_meta_info (1),		1,		"keep_meta_info (1)");
is ($csv->always_quote (undef),		0,		"always_quote (undef)");
is ($csv->always_quote (1),		1,		"always_quote (1)");
is ($csv->allow_loose_quotes (1),	1,		"allow_loose_quotes (1)");
is ($csv->allow_loose_escapes (1),	1,		"allow_loose_escapes (1)");
#is ($csv->allow_unquoted_escape (1),    1,      "allow_unquoted_escape (1)");
is ($csv->allow_whitespace (1),		1,		"allow_whitespace (1)");
is ($csv->blank_is_undef (1),		1,		"blank_is_undef (1)");
is ($csv->empty_is_undef (1),		1,		"empty_is_undef (1)");
is ($csv->auto_diag (1),		1,		"auto_diag (1)");
is ($csv->verbatim (1),			1,		"verbatim (1)");
is ($csv->quote_space (1),		1,		"quote_space (1)");
is ($csv->quote_null (1),		1,		"quote_null (1)");
is ($csv->escape_char ("\\"),		"\\",		"escape_char (\\)");
ok ($csv->combine (@fld),				"combine");
is ($csv->string,
    qq{=txt \\=, "Hi!"=;=Yes=;==;=2=;;=1.09=;=\r=;\r},	"string");

is ($csv->quote_space (0),		0,		"quote_space (0)");
is ($csv->quote_null (0),		0,		"quote_null (0)");
is ($csv->quote_binary (0),     0,      "quote_binary (0)");

# Funny settings, all three translate to \0 internally
ok ($csv = Text::CSV->new ({
    sep_char	=> undef,
    quote_char	=> undef,
    escape_char	=> undef,
    }),						"new (undef ...)");
is ($csv->sep_char,		undef,		"sep_char undef");
is ($csv->quote_char,		undef,		"quote_char undef");
is ($csv->escape_char,		undef,		"escape_char undef");
ok ($csv->parse ("foo"),			"parse (foo)");
$csv->sep_char (",");
is ($csv->record_number,    1,      "record_number");
ok ($csv->parse ("foo"),            "parse (foo)");
is ($csv->record_number,    2,      "record_number");
ok ($csv->parse ("foo"),			"parse (foo)");
ok (!$csv->parse ("foo,foo\0bar"),		"parse (foo)");
$csv->escape_char ("\\");
ok (!$csv->parse ("foo,foo\0bar"),		"parse (foo)");
$csv->binary (1);
ok ( $csv->parse ("foo,foo\0bar"),		"parse (foo)");

# Some forbidden combinations
foreach my $ws (" ", "\t") {
    ok ($csv = Text::CSV->new ({ escape_char => $ws }), "New blank escape");
    eval { ok ($csv->allow_whitespace (1), "Allow ws") };
    is (($csv->error_diag)[0], 1002, "Wrong combo");
    ok ($csv = Text::CSV->new ({ quote_char  => $ws }), "New blank quote");
    eval { ok ($csv->allow_whitespace (1), "Allow ws") };
    is (($csv->error_diag)[0], 1002, "Wrong combo");
    ok ($csv = Text::CSV->new ({ allow_whitespace => 1 }), "New ws 1");
    eval { ok ($csv->escape_char ($ws),     "esc") };
    is (($csv->error_diag)[0], 1002, "Wrong combo");
    ok ($csv = Text::CSV->new ({ allow_whitespace => 1 }), "New ws 1");
    eval { ok ($csv->quote_char  ($ws),     "esc") };
    is (($csv->error_diag)[0], 1002, "Wrong combo");
    }
eval { $csv = Text::CSV->new ({
    escape_char      => "\t",
    quote_char       => " ",
    allow_whitespace => 1,
    }) };
like ((Text::CSV::error_diag)[1], qr{^INI - allow_whitespace}, "Wrong combo - error message");
is   ((Text::CSV::error_diag)[0], 1002, "Wrong combo - numeric error");

# Test 1003 in constructor
foreach my $x ("\r", "\n", "\r\n", "x\n", "\rx") {
    foreach my $attr (qw( sep_char quote_char escape_char )) {
	eval { $csv = Text::CSV->new ({ $attr => $x }) };
	is ((Text::CSV::error_diag)[0], 1003, "eol in $attr");
	}
    }
# Test 1003 in methods
foreach my $attr (qw( sep_char quote_char escape_char )) {
    ok ($csv = Text::CSV->new, "New");
    eval { ok ($csv->$attr ("\n"), "$attr => \\n") };
    is (($csv->error_diag)[0], 1003, "not allowed");
    }

# And test erroneous calls
is (Text::CSV::new (0),		   undef,	"new () as function");
is (Text::CSV::error_diag () . '', "usage: my \$csv = Text::CSV_PP->new ([{ option => value, ... }]);",
							"Generic usage () message");
is (Text::CSV->new ({ oel     => "" }), undef,	"typo in attr");
is (Text::CSV::error_diag () . '', "INI - Unknown attribute 'oel'",	"Unsupported attr");
is (Text::CSV->new ({ _STATUS => "" }), undef,	"private attr");
is (Text::CSV::error_diag () . '', "INI - Unknown attribute '_STATUS'",	"Unsupported private attr");

foreach my $arg (undef, 0, "", " ", 1, [], [ 0 ], *STDOUT) {
    is  (Text::CSV->new ($arg),         undef,	"Illegal type for first arg");
    is ((Text::CSV::error_diag)[0], 1000, "Should be a hashref - numeric error");
    }

1;
