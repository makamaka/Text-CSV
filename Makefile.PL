use 5.00503;
use ExtUtils::MakeMaker;

use lib qw( ./lib );

$ENV{PERL_TEXT_CSV} = 'Text::CSV_PP';
eval q| require Text::CSV |;

if ($@) {
    print "Loading lib/Text/CSV.pm failed. No B module?\n";
    print "perl says : $@";
    print "Set the environmental variable 'PERL_DL_NONLAZY' with 0.\n";
    print "No Makefile created.\n";
    exit 0;
}

my $version     = Text::CSV->VERSION;
my $req_xs_ver  = Text::CSV->require_xs_version;
my $has_xs      = 0;
my $message;

eval q| require Text::CSV_XS |;

$has_xs = 1 unless ($@);

if ($has_xs) {
    my $xs_version = Text::CSV_XS->VERSION;
    if ($xs_version >= $req_xs_ver) {
        $message = "You have Text::CSV_XS (v.$xs_version), so Text::CSV can work very fast!!";
    }
    else {
        $message = "Your Text::CSV_XS version is $xs_version. If you install v.$req_xs_ver,\n"
                 . "Text::CSV will work faster.";
    }
}
else {
    $message = "If you install Text::CSV_XS v.$req_xs_ver, it makes Text::CSV faster.";
}
print <<EOF;
Welcome to Text::CSV (v.$version)
=============================
$message

EOF

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'Text::CSV',
    'VERSION_FROM'	=> 'lib/Text/CSV.pm', # finds $VERSION
    'ABSTRACT_FROM' => 'lib/Text/CSV.pm', # retrieve abstract from module
    'AUTHOR'     => 'Makamaka Hannyaharamitu, E<lt>makamaka[at]cpan.orgE<gt>',
    'PREREQ_PM' => {
		      "IO::Handle"	=> 0,
		      "Test::More"	=> 0,
		      "Test::Harness"	=> 0,
    },
    ( $ExtUtils::MakeMaker::VERSION >= 6.3002 ? ('LICENSE' => 'perl', ) : () ),

    ( $ExtUtils::MakeMaker::VERSION >= 6.46 ? (
        'META_MERGE' => {
            recommends => {
                'Text::CSV_XS' => Text::CSV->require_xs_version,
            },
            resources => {
                repository  =>      'http://github.com/makamaka/Text-CSV',
            },
        } ) : ()
    ),

);

