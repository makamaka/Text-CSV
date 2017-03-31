#!/usr/bin/perl

use strict;
$^W = 1;

use Test::More;

my $pu;
BEGIN {
    $pu = $ENV{PERL_UNICODE};
    $pu = defined $pu && ($pu eq "" || $pu =~ m/[oD]/ || ($pu =~ m/^[0-9]+$/ && $pu & 16));

    if ($] < 5.008002) {
        plan skip_all => "This test unit requires perl-5.8.2 or higher";
        }
    else {
	my $n = 297;
	$pu and $n -= 120;
	plan tests => $n;
	}

    $ENV{PERL_TEXT_CSV} = 0;

    use_ok "Text::CSV", "csv";
    require Encode;
    require "./t/util.pl";
    }

$| = 1;

ok (my $csv = Text::CSV->new, "new for header tests");
is ($csv->sep_char, ",", "Sep = ,");

my $hdr_lc = [qw( bar foo )];

foreach my $sep (",", ";") {
    my $data = "bAr,foo\n1,2\n3,4,5\n";
    $data =~ s/,/$sep/g;

    $csv->column_names (undef);
    {   open my $fh, "<", \$data;
	ok (my $slf = $csv->header ($fh), "header");
	is ($slf, $csv, "Return self");
	is ($csv->sep_char, $sep, "Sep = $sep");
	is_deeply ([ $csv->column_names ], $hdr_lc, "headers");
	is_deeply ($csv->getline ($fh), [ 1, 2 ],    "Line 1");
	is_deeply ($csv->getline ($fh), [ 3, 4, 5 ], "Line 2");
	close $fh;
	}

    $csv->column_names (undef);
    {   open my $fh, "<", \$data;
	ok (my @hdr = $csv->header ($fh), "header");
	is_deeply (\@hdr, $hdr_lc, "Return headers");
	close $fh;
	}

    $csv->column_names (undef);
    {   open my $fh, "<", \$data;
	ok (my $slf = $csv->header ($fh), "header");
	is ($slf, $csv, "Return self");
	is ($csv->sep_char, $sep, "Sep = $sep");
	is_deeply ([ $csv->column_names ], $hdr_lc, "headers");
	is_deeply ($csv->getline_hr ($fh), { bar => 1, foo => 2 }, "Line 1");
	is_deeply ($csv->getline_hr ($fh), { bar => 3, foo => 4 }, "Line 2");
	close $fh;
	}

    {   open my $fh, "<", \$data;
	is_deeply (csv (in => $fh, bom => 1),
	    [{ bar => 1, foo => 2 }, { bar => 3, foo => 4 }],
	    "use header () from csv () with $sep");
	}

    {   open my $fh, "<", \$data;
	is_deeply (csv (in => $fh, seps => [ ",", ";" ]),
	    [{ bar => 1, foo => 2 }, { bar => 3, foo => 4 }],
	    "use header () from csv () with $sep");
	}

    {   open my $fh, "<", \$data;
	is_deeply (csv (in => $fh, bom => 1, key => "bar"),
	    { 1 => { bar => 1, foo => 2 }, 3 => { bar => 3, foo => 4 }},
	    "use header () from csv (key) with $sep");
	}

    {   open my $fh, "<", \$data;
	is_deeply (csv (in => $fh, munge => "uc", key => "BAR"),
	    { 1 => { BAR => 1, FOO => 2 }, 3 => { BAR => 3, FOO => 4 }},
	    "use header () from csv (key, uc) with $sep");
	}
    }

my $sep_ok = [ "\t", "|", ",", ";", "##", "\xe2\x81\xa3" ];
unless ($pu) {
    foreach my $sep (@$sep_ok) {
	my $data = "bAr,foo\n1,2\n3,4,5\n";
	$data =~ s/,/$sep/g;

	$csv->column_names (undef);
	{   open my $fh, "<", \$data;
	    ok (my $slf = $csv->header ($fh, $sep_ok), "header with specific sep set");
	    is ($slf, $csv, "Return self");
	    is (Encode::encode ("utf-8", $csv->sep), $sep, "Sep = $sep");
	    is_deeply ([ $csv->column_names ], $hdr_lc, "headers");
	    is_deeply ($csv->getline ($fh), [ 1, 2 ],    "Line 1");
	    is_deeply ($csv->getline ($fh), [ 3, 4, 5 ], "Line 2");
	    close $fh;
	    }

	$csv->column_names (undef);
	{   open my $fh, "<", \$data;
	    ok (my @hdr = $csv->header ($fh, $sep_ok), "header with specific sep set");
	    is_deeply (\@hdr, $hdr_lc, "Return headers");
	    close $fh;
	    }

	$csv->column_names (undef);
	{   open my $fh, "<", \$data;
	    ok (my $slf = $csv->header ($fh, { sep_set => $sep_ok }), "header with specific sep set as opt");
	    is ($slf, $csv, "Return self");
	    is (Encode::encode ("utf-8", $csv->sep), $sep, "Sep = $sep");
	    is_deeply ([ $csv->column_names ], $hdr_lc, "headers");
	    is_deeply ($csv->getline ($fh), [ 1, 2 ],    "Line 1");
	    is_deeply ($csv->getline ($fh), [ 3, 4, 5 ], "Line 2");
	    close $fh;
	    }

	$csv->column_names (undef);
	{   open my $fh, "<", \$data;
	    ok (my $slf = $csv->header ($fh, $sep_ok), "header with specific sep set");
	    is ($slf, $csv, "Return self");
	    is (Encode::encode ("utf-8", $csv->sep), $sep, "Sep = $sep");
	    is_deeply ([ $csv->column_names ], $hdr_lc, "headers");
	    is_deeply ($csv->getline_hr ($fh), { bar => 1, foo => 2 }, "Line 1");
	    is_deeply ($csv->getline_hr ($fh), { bar => 3, foo => 4 }, "Line 2");
	    close $fh;
	    }
	}
    }

for ( [ 1010, 0, qq{}		],	# Empty header
      [ 1011, 0, qq{a,b;c,d}	],	# Multiple allowed separators
      [ 1012, 0, qq{a,,b}	],	# Empty header field
      [ 1013, 0, qq{a,a,b}	],	# Non-unique headers
      [ 2027, 1, qq{a,"b\nc",c}	],	# Embedded newline binary on
      [ 2021, 0, qq{a,"b\nc",c}	],	# Embedded newline binary off
      ) {
    my ($err, $bin, $data) = @$_;
    $csv->binary ($bin);
    open my $fh, "<", \$data;
    my $self = eval { $csv->header ($fh); };
    is ($self, undef, "FAIL for '$data'");
    ok ($@, "Error");
    is (0 + $csv->error_diag, $err, "Error code $err");
    close $fh;
    }
{   open my $fh, "<", \"bar,bAr,bAR,BAR\n1,2,3,4";
    $csv->column_names (undef);
    ok ($csv->header ($fh, { munge_column_names => "none", detect_bom => 0 }), "non-unique unfolded headers");
    is_deeply ([ $csv->column_names ], [qw( bar bAr bAR BAR )], "Headers");
    close $fh;
    }
{   open my $fh, "<", \"bar,bAr,bAR,BAR\n1,2,3,4";
    $csv->column_names (undef);
    ok (my @hdr = $csv->header ($fh, { munge_column_names => "none" }), "non-unique unfolded headers");
    is_deeply (\@hdr, [qw( bar bAr bAR BAR )], "Headers from method");
    is_deeply ([ $csv->column_names ], [qw( bar bAr bAR BAR )], "Headers from column_names");
    close $fh;
    }

foreach my $sep (",", ";") {
    my $data = "bAr,foo\n1,2\n3,4,5\n";
    $data =~ s/,/$sep/g;

    $csv->column_names (undef);
    {   open my $fh, "<", \$data;
	ok (my $slf = $csv->header ($fh, { set_column_names => 0 }), "Header without column setting");
	is ($slf, $csv, "Return self");
	is ($csv->sep_char, $sep, "Sep = $sep");
	is_deeply ([ $csv->column_names ], [], "headers");
	is_deeply ($csv->getline ($fh), [ 1, 2 ],    "Line 1");
	is_deeply ($csv->getline ($fh), [ 3, 4, 5 ], "Line 2");
	close $fh;
	}
    $csv->column_names (undef);
    {   open my $fh, "<", \$data;
	ok (my @hdr = $csv->header ($fh, { set_column_names => 0 }), "Header without column setting");
	is_deeply (\@hdr, $hdr_lc, "Headers from method");
	is_deeply ([ $csv->column_names ], [], "Headers from column_names");
	close $fh;
	}
    }

my $n;
for ([ undef, "bar" ], [ "lc", "bar" ], [ "uc", "BAR" ], [ "none", "bAr" ],
     [ sub { "column_".$n++ }, "column_0" ]) {
    my ($munge, $hdr) = @$_;

    my $data = "bAr,foo\n1,2\n3,4,5\n";
    my $how  = defined $munge ? ref $munge ? "CB" : $munge : "undef";

    $n = 0;
    $csv->column_names (undef);
    open my $fh, "<", \$data;
    ok (my $slf = $csv->header ($fh, { munge_column_names => $munge }), "munge header with $how");
    is (($csv->column_names)[0], $hdr, "folded header to $hdr");
    close $fh;

    $n = 0;
    $csv->column_names (undef);
    open $fh, "<", \$data;
    ok (my @hdr = $csv->header ($fh, { munge_column_names => $munge }), "munge header with $how");
    is ($hdr[0], $hdr, "folded header to $hdr");
    close $fh;
    }

my $fnm = "_85hdr.csv"; END { unlink $fnm; }
$csv->binary (1);
$csv->auto_diag (9);
my $str = qq{zoo,b\x{00e5}r\n1,"1 \x{20ac} each"\n};
for (	[ "none"       => ""	],
	[ "utf-8"      => "\xef\xbb\xbf"	],
	[ "utf-16be"   => "\xfe\xff"		],
	[ "utf-16le"   => "\xff\xfe"		],
	[ "utf-32be"   => "\x00\x00\xfe\xff"	],
	[ "utf-32le"   => "\xff\xfe\x00\x00"	],
	[ "utf-1"      => "\xf7\x64\x4c"	],
	[ "utf-ebcdic" => "\xdd\x73\x66\x73"	],
	[ "scsu"       => "\x0e\xfe\xff"	],
	[ "bocu-1"     => "\xfb\xee\x28"	],
	[ "gb-18030"   => "\x84\x31\x95"	],
	) {
    my ($enc, $bom) = @$_;
    my $has_enc = 0;
    eval {
	open my $fh, ">", $fnm;
	binmode $fh;
	print $fh $bom;
	print $fh Encode::encode ($enc eq "none" ? "utf-8" : $enc, $str);
	close $fh;
	$has_enc = 1;
	};

    SKIP: {
	$has_enc or skip "Encoding $enc not supported", 7;
	$csv->column_names (undef);
	open my $fh, "<", $fnm;
	binmode $fh;
	ok (1, "$fnm opened for enc $enc");
	ok ($csv->header ($fh), "headers with BOM for $enc");
	is (($csv->column_names)[1], "b\x{00e5}r", "column name was decoded");
	ok (my $row = $csv->getline_hr ($fh), "getline_hr");
	is ($row->{"b\x{00e5}r"}, "1 \x{20ac} each", "Returned in Unicode");
	close $fh;

	ok (my $aoh = csv (in => $fnm, bom => 1), "csv (bom => 1)");
	is_deeply ($aoh,
	    [{ zoo => 1, "b\x{00e5}r" => "1 \x{20ac} each" }], "Returned data");
	}

    unlink $fnm;
    }
