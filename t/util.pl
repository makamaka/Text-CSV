use strict;

my %special = ( 9 => "\\t", 10 => "\\n", 13 => "\\r" );
sub _readable
{
    defined $_[0] or return "--undef--";
    join "", map {
	my $cp = ord $_;
	$cp >= 0x20 && $cp <= 0x7e
	    ? $_
	    : $special{$cp} || sprintf "\\x{%02x}", $cp
	} split m//, $_[0];
    } # _readable

sub is_binary
{
    my ($str, $exp, $tst) = @_;
    if ($str eq $exp) {
	ok (1,		$tst);
	}
    else {
	my ($hs, $he) = map { _readable $_ } $str, $exp;
	is ($hs, $he,	$tst);
	}
    } # is_binary

1;
