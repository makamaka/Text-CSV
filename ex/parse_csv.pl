#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use Modern::Perl;
use IO::Interactive qw(is_interactive);
use Encode::Locale qw(decode_argv);
use Text::CSV;

&prepare_encoding_console();

my $csv = Text::CSV->new(
    {
        binary           => 1,
        auto_diag        => 1,
        sep_char         => '|',
        allow_whitespace => 1,
    }
);
my $file = $ARGV[0] or die "Need to get CSV file on the command line\n";
my @result = ();
open( my $data, '<:encoding(utf8)', $file )
  or die "Could not open '$file' $!\n";

while ( my $fields = $csv->getline($data) ) {
    push @result, ( join( ';', @{$fields}[ 1, 3 .. 5, 2 ] ) . ';' );
}
if ( not $csv->eof ) {
    $csv->error_diag();
}
close $data;
print join( "\n", @result );

sub prepare_encoding_console {
    if ( is_interactive() ) {
        binmode STDIN,  ':encoding(console_in)';
        binmode STDOUT, ':encoding(console_out)';
        binmode STDERR, ':encoding(console_out)';
    }
    Encode::Locale::decode_argv();
    return 1;
}
