#!/usr/bin/perl

use strict;
$^W = 1;	# use warnings;
$|  = 1;

use Config;
use Test::More;

BEGIN {
    unless (exists  $Config{useperlio} &&
	    defined $Config{useperlio} &&
	    $] >= 5.008                && # perlio was experimental in 5.6.2, but not reliable
	    $Config{useperlio} eq "define") {
	plan skip_all => "No reliable perlIO available";
	}
    else {
	plan tests => 105;
	}
    }

BEGIN {
    $ENV{PERL_TEXT_CSV} = 0;
    use_ok "Text::CSV";
    plan skip_all => "Cannot load Text::CSV" if $@;
    require "t/util.pl";
    }

$/ = "\n";
$\ = undef;

my $io;
my $io_str = "";
my $csv = Text::CSV->new ();

open  $io, ">", \$io_str or die "IO: $!";
ok (!$csv->print ($io, ["abc", "def\007", "ghi"]), "print bad character");
close $io;

for ( [  1, 1, 1, '""'				],
      [  2, 1, 1, '', ''			],
      [  3, 1, 0, '', 'I said, "Hi!"', ''	],
      [  4, 1, 0, '"', 'abc'			],
      [  5, 1, 0, 'abc', '"'			],
      [  6, 1, 1, 'abc', 'def', 'ghi'		],
      [  7, 1, 1, "abc\tdef", 'ghi'		],
      [  8, 1, 0, '"abc'			],
      [  9, 1, 0, 'ab"c'			],
      [ 10, 1, 0, '"ab"c"'			],
      [ 11, 0, 0, qq("abc\nc")			],
      [ 12, 1, 1, q(","), ','			],
      [ 13, 1, 0, qq("","I said,\t""Hi!""",""), '', qq(I said,\t"Hi!"), '' ],
      ) {
    my ($tst, $validp, $validg, @arg, $row) = @$_;

    open  $io, ">", \$io_str or die "IO: $!";
    is ($csv->print ($io, \@arg), $validp||"", "$tst - print ()");
    close $io;

    open  $io, ">", \$io_str or die "IO: $!";
    print $io join ",", @arg;
    close $io;

    open  $io, "<", \$io_str or die "IO: $!";
    $row = $csv->getline ($io);
    unless ($validg) {
	is ($row, undef, "$tst - false getline ()");
	next;
	}
    ok ($row, "$tst - good getline ()");
    $tst == 12 and @arg = (",", "", "");
    foreach my $a (0 .. $#arg) {
	(my $exp = $arg[$a]) =~ s/^"(.*)"$/$1/;
	is ($row->[$a], $exp, "$tst - field $a");
	}
    }

# This test because of a problem with DBD::CSV

ok (1, "Tests for DBD::CSV");
open  $io, ">", \$io_str or die "IO: $!";
$csv->binary (1);
$csv->eol    ("\r\n");
ok ($csv->print ($io, [ "id", "name"			]), "Bad character");
ok ($csv->print ($io, [   1,  "Alligator Descartes"	]), "Name 1");
ok ($csv->print ($io, [  "3", "Jochen Wiedmann"		]), "Name 2");
ok ($csv->print ($io, [   2,  "Tim Bunce"		]), "Name 3");
ok ($csv->print ($io, [ " 4", "Andreas Köîig"		]), "Name 4");
ok ($csv->print ($io, [   5				]), "Name 5");
close $io;

my $expected = <<"CONTENTS";
id,name\015
1,"Alligator Descartes"\015
3,"Jochen Wiedmann"\015
2,"Tim Bunce"\015
" 4","Andreas Köîig"\015
5\015
CONTENTS

open  $io, "<", \$io_str or die "IO: $!";
my $content = do { local $/; <$io> };
close $io;
is ($content, $expected, "Content");
open  $io, ">", \$io_str or die "IO: $!";
print $io $content;
close $io;
open  $io, "<", \$io_str or die "IO: $!";

my $fields;
print "# Retrieving data\n";
for (0 .. 5) {
    ok ($fields = $csv->getline ($io),			"Fetch field $_");
    is ($csv->eof, "",					"EOF");
    print "# Row $_: $fields (@$fields)\n";
    }
is ($csv->getline ($io), undef,				"Fetch field 6");
is ($csv->eof, 1,					"EOF");

# Edge cases
$csv = Text::CSV->new ({ escape_char => "+" });
for ([  1, 1,    0, "\n"		],
     [  2, 1,    0, "+\n"		],
     [  3, 1,    0, "+"			],
     [  4, 0, 2021, qq{"+"\n}		],
     [  5, 0, 2025, qq{"+\n}		],
     [  6, 0, 2011, qq{""+\n}		],
     [  7, 0, 2027, qq{"+"}		],
     [  8, 0, 2024, qq{"+}		],
     [  9, 0, 2011, qq{""+}		],
     [ 10, 0, 2037, "\r"		],
     [ 11, 0, 2031, "\r\r"		],
     [ 12, 0, 2032, "+\r\r"		],
     [ 13, 0, 2032, "+\r\r+"		],
     [ 14, 0, 2022, qq{"\r"}		],
     [ 15, 0, 2022, qq{"\r\r" }		],
     [ 16, 0, 2022, qq{"\r\r"\t}	],
     [ 17, 0, 2025, qq{"+\r\r"}		],
     [ 18, 0, 2025, qq{"+\r\r+"}	],
     [ 19, 0, 2022, qq{"\r"\r}		],
     [ 20, 0, 2022, qq{"\r\r"\r}	],
     [ 21, 0, 2025, qq{"+\r\r"\r}	],
     [ 22, 0, 2025, qq{"+\r\r+"\r}	],
     ) {
    my ($tst, $valid, $err, $str) = @$_;
    $io_str = $str;
    open $io, "<", \$io_str or die "IO: $!"; binmode $io;
    my $row = $csv->getline ($io);
    close $io;
    my @err  = $csv->error_diag;
    my $sstr = _readable ($str);
    ok ($valid ? $row : !$row, "$tst - getline ESC +, '$sstr'");
    is ($err[0], $err, "Error expected $err");
    }

