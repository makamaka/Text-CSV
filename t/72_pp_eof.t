#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use Text::CSV_PP;

BEGIN {
    package FakeFileHandle;

    sub new { return bless { line => "foo,bar,baz\n" }, shift }

    sub getline {
        my $self = shift;
        return delete $self->{line};
    }

    sub eof {
        my $self = shift;
        return not exists $self->{line};
    }
};

my $pp = Text::CSV_PP->new({binary => 1});
my $fh = FakeFileHandle->new;
eval {
    is_deeply( $pp->getline($fh), [qw[ foo bar baz ]]);
};
is($@, '', "no exception thrown");

done_testing;
