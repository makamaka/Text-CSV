# This script is to sync tests for Text::CSV with the ones for Text::CSV_XS

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use Path::Tiny;

my $root = path("$FindBin::Bin/../..");
my $xs_root = $root->parent->child('Text-CSV_XS');
my $test_dir = $root->child('t');

die "Text::CSV_XS directory not found" unless -d $xs_root;

for my $xs_test ($xs_root->child('t')->children) {
    my $basename = $xs_test->basename;
    my $pp_test = $test_dir->child($basename);
    if ($basename =~ /\.t$/) {
        next if $basename =~ /01_pod/;
        my $content = $xs_test->slurp;

        # general stuff -------------------------------------------

#        $content =~ s|^#!/(usr|pro)/bin/perl\n+||s;
        $content =~ s!^(\s+)(use|require)_ok!$1\$ENV{PERL_TEXT_CSV} = \$ENV{TEST_PERL_TEXT_CSV} || 0;\n$1$2_ok!m;
        $content =~ s/Text::CSV_XS(::|\->|;| |\.|["',]|$)/Text::CSV$1/mg;

        # warnings -------------------------------------------------

        $content =~ s|use warnings;|\$^W = 1;|;
        if ($basename =~ /10_base|12_acc|15_flags/) {
            $content =~ s|\$\^W = 1;|\$^W = 1;	# use warnings core since 5.6|;
        }
        if ($basename =~ /20_file|21_lexicalio|22_scalario/) {
            $content =~ s|\$\^W = 1;|\$^W = 1;	# use warnings;|;
        }

        # skip_all -------------------------------------------------

        if ($basename =~ /21_lexicalio/) {
            $content =~ s|use Test::More tests => (\d+);|use Test::More;\n\nBEGIN {\n    if (\$] < 5.006) {\n        plan skip_all => "No lexical file handles in in this ancient perl version";\n    }\n    else {\n        plan tests => $1;\n    }\n}|;
        }

        # specific -------------------------------------------------

        if ($basename =~ /00_pod/) {
            $content = qq{print STDERR "# PERL_TEXT_CSV: ", (defined \$ENV{PERL_TEXT_CSV} ? "\$ENV{PERL_TEXT_CSV}" : "undef"), "\\n";\n}.$content;
        }

        if ($basename =~ /12_acc/) {
            $content =~ s/(my \$csv;)/my \$Backend = Text::CSV->backend;\n\n$1/;
            $content =~ s/(usage: my \\\$csv =) Text::CSV/${1} \$Backend/;
        }

        if ($basename =~ /15_flags/) {
            $content =~ s/tests => 225/tests => 229/;
            $content =~ s/my \$bintxt = chr \(0x20ac\)/my \$bintxt = chr (\$] < 5.006 ? 0xbf : 0x20ac)/;

            $content .= <<'EOT';
# https://rt.cpan.org/Public/Bug/Display.html?id=109097
ok (1, "Testing quote_char as undef");
{   my $csv = Text::CSV->new ({ quote_char => undef });
    is ($csv->escape_char, '"',		"Escape Char defaults to double quotes");
    ok ($csv->combine ('space here', '"quoted"', '"quoted and spaces"'),	"Combine");
    is ($csv->string, q{space here,""quoted"",""quoted and spaces""},		"String");
    }
EOT
        }

        if ($basename =~ /(?:41_null|47_comment|78_fragment)/) {
            $content =~ s/(use Text::CSV;)/BEGIN { \$ENV{PERL_TEXT_CSV} = \$ENV{TEST_PERL_TEXT_CSV} || 0; }\n$1/;
        }

        if ($basename =~ /(?:68_header)/) {
            $content =~ s/done_testing;//;
        }

        if ($basename =~ /80_diag/) {
            $content =~ s!open my \$fh, "<", "CSV_XS.xs"!open my \$fh, "<", "lib/Text/CSV_PP.pm"!;
            $content =~ s!Cannot read error messages from XS!Cannot read error messages from PP!;
            $content =~ s!^\tm/\^    \\\{ \(\[0\-9\]\{4\}\), "\(\[\^"\]\+\)"\\s\+\\\}/!        m/^        ([0-9]{4}) => "([^"]+)"/!m;
            $content =~ s!CSV_XS ERROR!CSV_(?:PP|XS) ERROR!g;
        }

        if ($basename =~ /81_subclass/) {
            $content =~ s/(package Text::CSV::Subclass;)/$1\n\nBEGIN {\n    \$ENV{PERL_TEXT_CSV} = \$ENV{TEST_PERL_TEXT_CSV} || 0;\n}\n\nBEGIN { require Text::CSV; }\t# needed for perl5.005/;
        }

        die $basename unless $content =~ /\$ENV{PERL_TEXT_CSV} =/;
        $pp_test->spew($content);
        print STDERR "copied $xs_test to $pp_test\n";
        next;
    }
    print STDERR "Skipped $xs_test\n";
}

sub _todo {
    my ($content, @line_nos) = @_;
    my @lines = split /\n/, $content;
    for my $line_no (@line_nos) {
        $lines[$line_no - 1] = "#TODO: $lines[$line_no - 1]";
    }
    join "\n", @lines, "";
}

sub _skip {
    my ($content, @line_nos) = @_;
    my @lines = split /\n/, $content;
    for my $line_no (@line_nos) {
        if (!ref $line_no) {
            $lines[$line_no - 1] = "TODO:{local \$TODO = 'failing'; $lines[$line_no - 1]}";
        } else {
            my ($start, $end) = @$line_no;
            $lines[$start - 1] = "TODO:{local \$TODO = 1; $lines[$start - 1]";
            $lines[$end - 1] = "$lines[$end - 1]}";
        }
    }
    join "\n", @lines, "";
}

sub _comment_out {
    my ($content, $key, @line_nos) = @_;
    my @lines = split /\n/, $content;
    for my $line_no (@line_nos) {
        $lines[$line_no - 1] = "#$key: $lines[$line_no - 1]";
    }
    join "\n", @lines;
}
