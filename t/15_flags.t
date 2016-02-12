#!/usr/bin/perl

use strict;
$^W = 1;	# use warnings core since 5.6

use Test::More tests => 201;

BEGIN {
    $ENV{PERL_TEXT_CSV} = 0;
    use_ok "Text::CSV";
    plan skip_all => "Cannot load Text::CSV" if $@;
}

sub crnlsp
{
    my $csv = shift;
    ok (!$csv->parse (),				"Missing arguments");
    ok ( $csv->parse ("\n"),				"NL");
    if ($csv->eol eq "\r") {
	ok ( $csv->parse ("\r"),			"CR");
	ok ( $csv->parse ("\r\r"),			"CR CR");
	ok ( $csv->parse ("\r "),			"CR + Space");
	ok ( $csv->parse (" \r"),			"Space + CR");
	}
    else {
	ok (!$csv->parse ("\r"),			"CR");
	ok (!$csv->parse ("\r\r"),			"CR CR");
	if ($csv->binary) {
	    ok ( $csv->parse ("\r "),			"CR + Space");
	    ok ( $csv->parse (" \r"),			"Space + CR");
	    }
	else {
	    ok (!$csv->parse ("\r "),			"CR + Space");
	    ok (!$csv->parse (" \r"),			"Space + CR");
	    }
	}
    ok ( $csv->parse ("\r\n"),				"CR NL");
    ok ( $csv->parse ("\n "),				"NL + Space");
    ok ( $csv->parse ("\r\n "),				"CR NL + Space");
    if ($csv->binary) {
	ok ( $csv->parse (qq{"\n"}),			"Quoted NL");
	ok ( $csv->parse (qq{"\r"}),			"Quoted CR");
	ok ( $csv->parse (qq{"\r\n"}),			"Quoted CR NL");
	ok ( $csv->parse (qq{"\n "}),			"Quoted NL + Space");
	ok ( $csv->parse (qq{"\r "}),			"Quoted CR + Space");
	ok ( $csv->parse (qq{"\r\n "}),			"Quoted CR NL + Space");
	}
    else {
	ok (!$csv->parse (qq{"\n"}),			"Quoted NL");
	ok (!$csv->parse (qq{"\r"}),			"Quoted CR");
	ok (!$csv->parse (qq{"\r\n"}),			"Quoted CR NL");
	ok (!$csv->parse (qq{"\n "}),			"Quoted NL + Space");
	ok (!$csv->parse (qq{"\r "}),			"Quoted CR + Space");
	ok (!$csv->parse (qq{"\r\n "}),			"Quoted CR NL + Space");
	}
    ok (!$csv->parse (qq{"\r\r\n"\r}),			"Quoted CR CR NL >CR");
    ok (!$csv->parse (qq{"\r\r\n"\r\r}),		"Quoted CR CR NL >CR CR");
    ok (!$csv->parse (qq{"\r\r\n"\r\r\n}),		"Quoted CR CR NL >CR CR NL");
    ok (!$csv->parse (qq{"\r\r\n"\t \r}),		"Quoted CR CR NL >TAB Space CR");
    ok (!$csv->parse (qq{"\r\r\n"\t \r\r}),		"Quoted CR CR NL >TAB Space CR CR");
    ok (!$csv->parse (qq{"\r\r\n"\t \r\r\n}),		"Quoted CR CR NL >TAB Space CR CR NL");
    } # crnlsp

{   my $csv = Text::CSV->new ();
    my $c99 = chr (0x99);	# A random binary character

    is ($csv->meta_info, undef,				"meta_info () before parse ()");

    ok (1,						"parse () tests - No meta_info");
    crnlsp ($csv);
    ok (!$csv->parse ('"abc'),				"Missing closing \"");
    ok (!$csv->parse ('ab"c'),				"\" outside of \"'s");
    ok (!$csv->parse ('"ab"c"'),			"Bad character sequence");
    ok (!$csv->parse ("ab${c99}c"),			"Binary character");
    ok (!$csv->parse (qq{"ab${c99}c"}),			"Binary character in quotes");
    ok (!$csv->parse (qq("abc\nc")),			"Bad character (NL)");
    ok (!$csv->status (),				"Wrong status ()");
    ok ( $csv->parse ('","'),				"comma - parse ()");
    is ( scalar $csv->fields (), 1,			"comma - fields () - count");
    is ( scalar $csv->meta_info (), 0,			"comma - meta_info () - count");
    is (($csv->fields ())[0], ",",			"comma - fields () - content");
    is (($csv->meta_info ())[0], undef,			"comma - meta_info () - content");
    ok ( $csv->parse (qq("","I said,\t""Hi!""","")),	"Hi! - parse ()");
    is ( scalar $csv->fields (), 3,			"Hi! - fields () - count");
    is ( scalar $csv->meta_info (), 0,			"Hi! - meta_info () - count");
    }

{   my $csv = Text::CSV->new ({ keep_meta_info => 1 });

    ok (1,						"parse () tests - With flags");
    is ( $csv->meta_info, undef,			"meta_info before parse");

    ok (!$csv->parse (),				"Missing arguments");
    is ( $csv->meta_info, undef,			"meta_info after failing parse");
    crnlsp ($csv);
    ok (!$csv->parse ('"abc'),				"Missing closing \"");
    ok (!$csv->parse ('ab"c'),				"\" outside of \"'s");
    ok (!$csv->parse ('"ab"c"'),			"Bad character sequence");
    ok (!$csv->parse (qq("abc\nc")),			"Bad character (NL)");
    ok (!$csv->status (),				"Wrong status ()");
    ok ( $csv->parse ('","'),				"comma - parse ()");
    is ( scalar $csv->fields (), 1,			"comma - fields () - count");
    is ( scalar $csv->meta_info (), 1,			"comma - meta_info () - count");
    is (($csv->fields ())[0], ",",			"comma - fields () - content");
    is (($csv->meta_info ())[0], 1,			"comma - meta_info () - content");
    ok ( $csv->parse (qq("","I said,\t""Hi!""",)),	"Hi! - parse ()");
    is ( scalar $csv->fields (), 3,			"Hi! - fields () - count");
    is ( scalar $csv->meta_info (), 3,			"Hi! - meta_info () - count");

    is (($csv->fields ())[0], "",			"Hi! - fields () - field 1");
    is (($csv->meta_info ())[0], 1,			"Hi! - meta_info () - field 1");
    is (($csv->fields ())[1], qq(I said,\t"Hi!"),	"Hi! - fields () - field 2");
    is (($csv->meta_info ())[1], 1,			"Hi! - meta_info () - field 2");
    is (($csv->fields ())[2], "",			"Hi! - fields () - field 3");
    is (($csv->meta_info ())[2], 0,			"Hi! - meta_info () - field 3");
    }

{   my $csv = Text::CSV->new ({ keep_meta_info => 1, eol => "\r" });

    ok (1,						"parse () tests - With flags");
    is ( $csv->meta_info, undef,			"meta_info before parse");

    ok (!$csv->parse (),				"Missing arguments");
    is ( $csv->meta_info, undef,			"meta_info after failing parse");
    crnlsp ($csv);
    ok (!$csv->parse ('"abc'),				"Missing closing \"");
    ok (!$csv->parse ('ab"c'),				"\" outside of \"'s");
    ok (!$csv->parse ('"ab"c"'),			"Bad character sequence");
    ok (!$csv->parse (qq("abc\nc")),			"Bad character (NL)");
    ok (!$csv->status (),				"Wrong status ()");
    ok ( $csv->parse ('","'),				"comma - parse ()");
    is ( scalar $csv->fields (), 1,			"comma - fields () - count");
    is ( scalar $csv->meta_info (), 1,			"comma - meta_info () - count");
    is (($csv->fields ())[0], ",",			"comma - fields () - content");
    is (($csv->meta_info ())[0], 1,			"comma - meta_info () - content");
    ok ( $csv->parse (qq("","I said,\t""Hi!""",)),	"Hi! - parse ()");
    is ( scalar $csv->fields (), 3,			"Hi! - fields () - count");
    is ( scalar $csv->meta_info (), 3,			"Hi! - meta_info () - count");

    is (($csv->fields ())[0], "",			"Hi! - fields () - field 1");
    is (($csv->meta_info ())[0], 1,			"Hi! - meta_info () - field 1");
    is (($csv->fields ())[1], qq(I said,\t"Hi!"),	"Hi! - fields () - field 2");
    is (($csv->meta_info ())[1], 1,			"Hi! - meta_info () - field 2");
    is (($csv->fields ())[2], "",			"Hi! - fields () - field 3");
    is (($csv->meta_info ())[2], 0,			"Hi! - meta_info () - field 3");
    }

{   my $csv = Text::CSV->new ({ keep_meta_info => 1, binary => 1 });

    is ($csv->is_quoted (0), undef,		"is_quoted () before parse");
    is ($csv->is_binary (0), undef,		"is_binary () before parse");

    my $bintxt = chr ($] < 5.006 ? 0xbf : 0x20ac);
    ok ( $csv->parse (qq{,"1","a\rb",0,"a\nb",1,\x8e,"a\r\n","$bintxt","",}),
			"parse () - mixed quoted/binary");
    is (scalar $csv->fields, 11,		"fields () - count");
    my @fflg;
    ok (@fflg = $csv->meta_info,		"meta_info ()");
    is (scalar @fflg, 11,			"meta_info () - count");
    is_deeply ([ @fflg ], [ 0, 1, 3, 0, 3, 0, 2, 3, 3, 1, 0 ], "meta_info ()");

    is ($csv->is_quoted (0), 0,			"fflag 0 - not quoted");
    is ($csv->is_binary (0), 0,			"fflag 0 - not binary");
    is ($csv->is_quoted (2), 1,			"fflag 2 - quoted");
    is ($csv->is_binary (2), 1,			"fflag 2 - binary");

    is ($csv->is_quoted (6), 0,			"fflag 5 - not quoted");
    is ($csv->is_binary (6), 1,			"fflag 5 - binary");

    is ($csv->is_quoted (-1), undef,		"fflag -1 - undefined");
    is ($csv->is_binary (-8), undef,		"fflag -8 - undefined");

    is ($csv->is_quoted (21), undef,		"fflag 21 - undefined");
    is ($csv->is_binary (98), undef,		"fflag 98 - undefined");
    }

{   my $csv = Text::CSV->new ({ escape_char => "+" });

    ok ( $csv->parse ("+"),		"ESC");
    ok (!$csv->parse ("++"),		"ESC ESC");
    ok ( $csv->parse ("+ "),		"ESC Space");
    ok ( $csv->parse ("+0"),		"ESC NUL");
    ok ( $csv->parse ("+\n"),		"ESC NL");
    ok (!$csv->parse ("+\r"),		"ESC CR");
    ok ( $csv->parse ("+\r\n"),		"ESC CR NL");
    ok (!$csv->parse (qq{"+"}),		"Quo ESC");
    ok (!$csv->parse (qq{""+}),		"Quo ESC >");
    ok ( $csv->parse (qq{"++"}),	"Quo ESC ESC");
    ok (!$csv->parse (qq{"+ "}),	"Quo ESC Space");
    ok ( $csv->parse (qq{"+0"}),	"Quo ESC NUL");
    ok (!$csv->parse (qq{"+\n"}),	"Quo ESC NL");
    ok (!$csv->parse (qq{"+\r"}),	"Quo ESC CR");
    ok (!$csv->parse (qq{"+\r\n"}),	"Quo ESC CR NL");
    }

{   my $csv = Text::CSV->new ({ escape_char => "+", binary => 1 });

    ok ( $csv->parse ("+"),		"ESC");
    ok (!$csv->parse ("++"),		"ESC ESC");
    ok ( $csv->parse ("+ "),		"ESC Space");
    ok ( $csv->parse ("+0"),		"ESC NUL");
    ok ( $csv->parse ("+\n"),		"ESC NL");
    ok (!$csv->parse ("+\r"),		"ESC CR");
    ok ( $csv->parse ("+\r\n"),		"ESC CR NL");
    ok (!$csv->parse (qq{"+"}),		"Quo ESC");
    ok ( $csv->parse (qq{"++"}),	"Quo ESC ESC");
    ok (!$csv->parse (qq{"+ "}),	"Quo ESC Space");
    ok ( $csv->parse (qq{"+0"}),	"Quo ESC NUL");
    ok (!$csv->parse (qq{"+\n"}),	"Quo ESC NL");
    ok (!$csv->parse (qq{"+\r"}),	"Quo ESC CR");
    ok (!$csv->parse (qq{"+\r\n"}),	"Quo ESC CR NL");
    }

ok (1, "Testing always_quote");
{   my $csv = Text::CSV->new ({ always_quote => 0 });
    ok ($csv->combine (1..3),		"Combine");
    is ($csv->string, q{1,2,3},		"String");
    is ($csv->always_quote, 0,		"Attr 0");
    ok ($csv->always_quote (1),		"Attr 1");
    ok ($csv->combine (1..3),		"Combine");
    is ($csv->string, q{"1","2","3"},	"String");
    is ($csv->always_quote, 1,		"Attr 1");
    is ($csv->always_quote (0), 0,	"Attr 0");
    ok ($csv->combine (1..3),		"Combine");
    is ($csv->string, q{1,2,3},		"String");
    is ($csv->always_quote, 0,		"Attr 0");
    }

ok (1, "Testing quote_space");
{   my $csv = Text::CSV->new ({ quote_space => 1 });
    ok ($csv->combine (1, " ", 3),	"Combine");
    is ($csv->string, q{1," ",3},	"String");
    is ($csv->quote_space, 1,		"Attr 1");
    is ($csv->quote_space (0), 0,	"Attr 0");
    ok ($csv->combine (1, " ", 3),	"Combine");
    is ($csv->string, q{1, ,3},		"String");
    is ($csv->quote_space, 0,		"Attr 0");
    is ($csv->quote_space (1), 1,	"Attr 1");
    ok ($csv->combine (1, " ", 3),	"Combine");
    is ($csv->string, q{1," ",3},	"String");
    is ($csv->quote_space, 1,		"Attr 1");
    }

# https://rt.cpan.org/Public/Bug/Display.html?id=109097
ok (1, "Testing quote_char as undef");
{   my $csv = Text::CSV->new ({ quote_char => undef });
    is ($csv->escape_char, '"',		"Escape Char defaults to double quotes");
    ok ($csv->combine ('space here', '"quoted"', '"quoted and spaces"'),	"Combine");
    is ($csv->string, q{space here,""quoted"",""quoted and spaces""},		"String");
    }
