# This script is to sync tests for Text::CSV with the ones for Text::CSV_XS

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use Path::Tiny;

my $root = path("$FindBin::Bin/../..");
my $xs_root = $root->parent->child('Text-CSV_XS');

die "Text::CSV_XS directory not found" unless -d $xs_root;

my $xs_doc = $xs_root->child('CSV_XS.pm');

my %xs_sections;
{
    my $title;
    for my $line ( split /\n/, $xs_doc->slurp ) {
        if ($line =~ /^=head1 (.+)/) {
            $title = $1;
            $xs_sections{$title} = '';
            next;
        }
        next unless $title;
        $xs_sections{$title} .= $line . "\n";
    }
}

for my $pm_name (qw/CSV CSV_PP/) {
    my $pm_file = $root->child("lib/Text/$pm_name.pm");
    my $doc = '';
    my $skip = 0;
    my $title = '';
    my $first_notice = 1;
    for my $line ( split /\n/, $pm_file->slurp ) {
        if ($line =~ /^=head1 (.+)/) {
            $title = $1;
            $skip = 0;
            if ($title =~ /^(SYNOPSIS|METHODS|FUNCTIONS|DIAGNOSTICS|NOTES)$/) {
                my $notice = "This section is also taken from Text::CSV_XS.";
                if ($first_notice) {
                    $notice =~ s/also //;
                    $first_notice = 0;
                }
                $doc .= $line . "\n\n" . $notice . "\n";
                my $section = $xs_sections{$title};
                if ($title eq 'NOTES') {
                    $section = $xs_sections{DESCRIPTION};
                    $section =~ s/^.+?=head2/\n=head2/s;
                }
                $section =~ s/CSV_[XC]S/$pm_name/g;
                $section =~ s/^X<[^>]+>$//gm;
                $section =~ s!^See also L</CAVEATS>$!!gm;
                $section =~ s!\s+\(Poor\s+creatures\s+who\s+are\s+better\s+to\s+use\s+Text::CSV(_PP)?\.\s+:\)!!s;
                $section =~ s/\n\n\n+/\n\n/gs;
                $doc .= $section;
                $skip = 1;
            }
        }
        next if $skip;
        $doc .= $line . "\n";
    }
    $pm_file->spew($doc);
}
