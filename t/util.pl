use strict;

my %special = ( 9 => "\\t", 10 => "\\n", 13 => "\\r" );
my $ebcdic  = ord ("A") == 0xc1;
my @ebcdic  = (# Convert EBCDIC 2 ASCII
    0x00, 0x01, 0x02, 0x03, 0x9c, 0x09, 0x86, 0x7f, 0x97, 0x8d, 0x8e, 0x0b,
    0x0c, 0x0d, 0x0e, 0x0f, 0x10, 0x11, 0x12, 0x13, 0x9d, 0x0a, 0x08, 0x87,
    0x18, 0x19, 0x92, 0x8f, 0x1c, 0x1d, 0x1e, 0x1f, 0x80, 0x81, 0x82, 0x83,
    0x84, 0x85, 0x17, 0x1b, 0x88, 0x89, 0x8a, 0x8b, 0x8c, 0x05, 0x06, 0x07,
    0x90, 0x91, 0x16, 0x93, 0x94, 0x95, 0x96, 0x04, 0x98, 0x99, 0x9a, 0x9b,
    0x14, 0x15, 0x9e, 0x1a, 0x20, 0xa0, 0xe2, 0xe4, 0xe0, 0xe1, 0xe3, 0xe5,
    0xe7, 0xf1, 0xa2, 0x2e, 0x3c, 0x28, 0x2b, 0x7c, 0x26, 0xe9, 0xea, 0xeb,
    0xe8, 0xed, 0xee, 0xef, 0xec, 0xdf, 0x21, 0x24, 0x2a, 0x29, 0x3b, 0x5e,
    0x2d, 0x2f, 0xc2, 0xc4, 0xc0, 0xc1, 0xc3, 0xc5, 0xc7, 0xd1, 0xa6, 0x2c,
    0x25, 0x5f, 0x3e, 0x3f, 0xf8, 0xc9, 0xca, 0xcb, 0xc8, 0xcd, 0xce, 0xcf,
    0xcc, 0x60, 0x3a, 0x23, 0x40, 0x27, 0x3d, 0x22, 0xd8, 0x61, 0x62, 0x63,
    0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0xab, 0xbb, 0xf0, 0xfd, 0xfe, 0xb1,
    0xb0, 0x6a, 0x6b, 0x6c, 0x6d, 0x6e, 0x6f, 0x70, 0x71, 0x72, 0xaa, 0xba,
    0xe6, 0xb8, 0xc6, 0xa4, 0xb5, 0x7e, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78,
    0x79, 0x7a, 0xa1, 0xbf, 0xd0, 0x5b, 0xde, 0xae, 0xac, 0xa3, 0xa5, 0xb7,
    0xa9, 0xa7, 0xb6, 0xbc, 0xbd, 0xbe, 0xdd, 0xa8, 0xaf, 0x5d, 0xb4, 0xd7,
    0x7b, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0xad, 0xf4,
    0xf6, 0xf2, 0xf3, 0xf5, 0x7d, 0x4a, 0x4b, 0x4c, 0x4d, 0x4e, 0x4f, 0x50,
    0x51, 0x52, 0xb9, 0xfb, 0xfc, 0xf9, 0xfa, 0xff, 0x5c, 0xf7, 0x53, 0x54,
    0x55, 0x56, 0x57, 0x58, 0x59, 0x5a, 0xb2, 0xd4, 0xd6, 0xd2, 0xd3, 0xd5,
    0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0xb3, 0xdb,
    0xdc, 0xd9, 0xda, 0x9f );

sub _readable {
    defined $_[0] or return "--undef--";
    join "", map {
	my $cp = ord $_;
	$ebcdic and $cp = $ebcdic[$cp];
	$cp >= 0x20 && $cp <= 0x7e
	    ? $_
	    : $special{$cp} || sprintf "\\x{%02x}", $cp
	} split m//, $_[0];
    } # _readable

sub is_binary {
    my ($str, $exp, $tst) = @_;
    if ($str eq $exp) {
	ok (1,		$tst);
	}
    else {
	my ($hs, $he) = map { _readable $_ } $str, $exp;
	is ($hs, $he,	$tst);
	}
    } # is_binary

# The rest is a modified copy of CORE's t/charset_tools.pl
my @utf8_skip = $ebcdic ? (
    # This translates a utf-8-encoded byte into how many
    # bytes the full utf8 character occupies.

    # 0  1  2  3  4  5  6  7  8  9  A  B  C  D  E  F
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  # 0
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  # 1
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  # 2
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  # 3
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  # 4
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  # 5
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  # 6
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  # 7
   -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,  # 8
   -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,  # 9
   -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,  # A
   -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,  # B
   -1,-1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,  # C
    2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,  # D
    3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3,  # E
    4, 4, 4, 4, 4, 4, 4, 4, 5, 5, 5, 5, 6, 6, 7,13,  # F
    ) : ();

# Used for BOM testing
*byte_utf8a_to_utf8n = $ebcdic ? sub {
    # Convert a UTF-8 byte sequence into the platform's native UTF-8
    # equivalent, currently only UTF-8 and UTF-EBCDIC.

    my $string = shift;
    utf8::is_utf8 ($string) and return $string;

    my $length = length $string;
    #diag ($string);
    #diag ($length);
    my $out = "";
    for (my $i = 0; $i < $length; $i++) {
        my $byte = ord substr $string, $i, 1;
        my $byte_count = $utf8_skip[$byte];
        #diag ($byte);
        #diag ($byte_count);

	$byte_count < 0 and die "Illegal start byte";
        ($i + $byte_count) > $length and
            die "Attempt to read " . ($i + $byte_count - $length) . " beyond end-of-string";

        # Just translate UTF-8 invariants directly.
        if ($byte_count == 1) {
            $out .= chr utf8::unicode_to_native ($byte);
            next;
	    }

        # Otherwise calculate the code point ordinal represented by the
        # sequence beginning with this byte, using the algorithm adapted from
        # utf8.c.  We absorb each byte in the sequence as we go along
        my $ord = $byte & (0x1F >> ($byte_count - 2));
        my $bytes_remaining = $byte_count - 1;
        while ($bytes_remaining > 0) {
            $byte = ord substr $string, ++$i, 1;
            ($byte & 0xC0) == 0x80 or
                die sprintf "byte '%X' is not a valid continuation", $byte;
            $ord = $ord << 6 | ($byte & 0x3f);
            $bytes_remaining--;
	    }
        #diag ($byte);
        #diag ($ord);

        my $expected_bytes =
	    $ord < 0x00000080 ? 1 :
	    $ord < 0x00000800 ? 2 :
	    $ord < 0x00010000 ? 3 :
	    $ord < 0x00200000 ? 4 :
	    $ord < 0x04000000 ? 5 :
	    $ord < 0x80000000 ? 6 : 7; #: (uv) < UTF8_QUAD_MAX ? 7 : 13 )

        # Make sure is not an overlong sequence
        $byte_count == $expected_bytes or
            die sprintf "character U+%X should occupy %d bytes, not %d",
		$ord, $expected_bytes, $byte_count;

        # Now that we have found the code point the original UTF-8 meant, we
        # use the native chr function to get its native string equivalent.
        $out .= chr utf8::unicode_to_native ($ord);
	}

    utf8::encode ($out); # Turn off utf8 flag.
    #diag ($out);
    return $out;
    } : sub { return shift };

1;
