package Text::CSV_PP;

################################################################################
#
# Text::CSV_PP - Text::CSV_XS compatible pure-Perl module
#
################################################################################
require 5.005;

use strict;
use Exporter ();
use vars qw($VERSION @ISA @EXPORT_OK);
use Carp;

$VERSION = '1.33';
@ISA = qw(Exporter);
@EXPORT_OK = qw(csv);

sub PV  { 0 }
sub IV  { 1 }
sub NV  { 2 }

sub IS_QUOTED () { 0x0001; }
sub IS_BINARY () { 0x0002; }
sub IS_ERROR ()  { 0x0004; }
sub IS_MISSING () { 0x0010; }

sub HOOK_ERROR () { 0x0001; }
sub HOOK_AFTER_PARSE () { 0x0002; }
sub HOOK_BEFORE_PRINT () { 0x0004; }

sub useIO_EOF () { 0x0010; }

my $ERRORS = {
        # Generic errors
        1000 => "INI - constructor failed",
        1001 => "INI - sep_char is equal to quote_char or escape_char",
        1002 => "INI - allow_whitespace with escape_char or quote_char SP or TAB",
        1003 => "INI - \\r or \\n in main attr not allowed",
        1004 => "INI - callbacks should be undef or a hashref",
        1005 => "INI - EOL too long",
        1006 => "INI - SEP too long",
        1007 => "INI - QUOTE too long",
        1008 => "INI - SEP undefined",

        1010 => "INI - the header is empty",
        1011 => "INI - the header contains more than one valid separator",
        1012 => "INI - the header contains an empty field",
        1013 => "INI - the header contains nun-unique fields",
        1014 => "INI - header called on undefined stream",

        # Parse errors
        2010 => "ECR - QUO char inside quotes followed by CR not part of EOL",
        2011 => "ECR - Characters after end of quoted field",
        2012 => "EOF - End of data in parsing input stream",
        2013 => "ESP - Specification error for fragments RFC7111",

        # EIQ - Error Inside Quotes
        2021 => "EIQ - NL char inside quotes, binary off",
        2022 => "EIQ - CR char inside quotes, binary off",
        2023 => "EIQ - QUO character not allowed",
        2024 => "EIQ - EOF cannot be escaped, not even inside quotes",
        2025 => "EIQ - Loose unescaped escape",
        2026 => "EIQ - Binary character inside quoted field, binary off",
        2027 => "EIQ - Quoted field not terminated",

        # EIF - Error Inside Field
        2030 => "EIF - NL char inside unquoted verbatim, binary off",
        2031 => "EIF - CR char is first char of field, not part of EOL",
        2032 => "EIF - CR char inside unquoted, not part of EOL",
        2034 => "EIF - Loose unescaped quote",
        2035 => "EIF - Escaped EOF in unquoted field",
        2036 => "EIF - ESC error",
        2037 => "EIF - Binary character in unquoted field, binary off",

        # Combine errors
        2110 => "ECB - Binary character in Combine, binary off",

        # IO errors
        2200 => "EIO - print to IO failed. See errno",

        # Hash-Ref errors
        3001 => "EHR - Unsupported syntax for column_names ()",
        3002 => "EHR - getline_hr () called before column_names ()",
        3003 => "EHR - bind_columns () and column_names () fields count mismatch",
        3004 => "EHR - bind_columns () only accepts refs to scalars",
        3006 => "EHR - bind_columns () did not pass enough refs for parsed fields",
        3007 => "EHR - bind_columns needs refs to writable scalars",
        3008 => "EHR - unexpected error in bound fields",
        3009 => "EHR - print_hr () called before column_names ()",
        3010 => "EHR - print_hr () called with invalid arguments",

        # PP Only Error
        4002 => "EIQ - Unescaped ESC in quoted field",
        4003 => "EIF - ESC CR",
        4004 => "EUF - Field is terminated by the escape character (escape_char)",

        0    => "",
};

BEGIN {
    if ( $] < 5.006 ) {
        $INC{'bytes.pm'} = 1 unless $INC{'bytes.pm'}; # dummy
        no strict 'refs';
        *{"utf8::is_utf8"} = sub { 0; };
        *{"utf8::decode"}  = sub { };
    }
    elsif ( $] < 5.008 ) {
        no strict 'refs';
        *{"utf8::is_utf8"} = sub { 0; };
        *{"utf8::decode"}  = sub { };
    }
    elsif ( !defined &utf8::is_utf8 ) {
       require Encode;
       *utf8::is_utf8 = *Encode::is_utf8;
    }

    eval q| require Scalar::Util |;
    if ( $@ ) {
        eval q| require B |;
        if ( $@ ) {
            Carp::croak $@;
        }
        else {
            my %tmap = qw(
                B::NULL   SCALAR
                B::HV     HASH
                B::AV     ARRAY
                B::CV     CODE
                B::IO     IO
                B::GV     GLOB
                B::REGEXP REGEXP
            );
            *Scalar::Util::reftype = sub (\$) {
                my $r = shift;
                return undef unless length(ref($r));
                my $t = ref(B::svref_2object($r));
                return
                    exists $tmap{$t} ? $tmap{$t}
                  : length(ref($$r)) ? 'REF'
                  :                    'SCALAR';
            };
            *Scalar::Util::readonly = sub (\$) {
                my $b = B::svref_2object( $_[0] );
                $b->FLAGS & 0x00800000; # SVf_READONLY?
            };
        }
    }
}

################################################################################
#
# Common pure perl methods, taken almost directly from Text::CSV_XS.
# (These should be moved into a common class eventually, so that
# both XS and PP don't need to apply the same changes.)
#
################################################################################

################################################################################
# version
################################################################################

sub version {
    return $VERSION;
}

################################################################################
# new
################################################################################

my %def_attr = (
    eol				=> '',
    sep_char			=> ',',
    quote_char			=> '"',
    escape_char			=> '"',
    binary			=> 0,
    decode_utf8			=> 1,
    auto_diag			=> 0,
    diag_verbose		=> 0,
    blank_is_undef		=> 0,
    empty_is_undef		=> 0,
    allow_whitespace		=> 0,
    allow_loose_quotes		=> 0,
    allow_loose_escapes		=> 0,
    allow_unquoted_escape	=> 0,
    always_quote		=> 0,
    quote_empty			=> 0,
    quote_space			=> 1,
    quote_binary		=> 1,
    escape_null			=> 1,
    keep_meta_info		=> 0,
    verbatim			=> 0,
    types			=> undef,
    callbacks			=> undef,

    _EOF			=> 0,
    _RECNO			=> 0,
    _STATUS			=> undef,
    _FIELDS			=> undef,
    _FFLAGS			=> undef,
    _STRING			=> undef,
    _ERROR_INPUT		=> undef,
    _COLUMN_NAMES		=> undef,
    _BOUND_COLUMNS		=> undef,
    _AHEAD			=> undef,
);

my %attr_alias = (
    quote_always		=> "always_quote",
    verbose_diag		=> "diag_verbose",
    quote_null			=> "escape_null",
    );

my $last_new_error = Text::CSV_PP->SetDiag(0);
my $last_error;

# NOT a method: is also used before bless
sub _unhealthy_whitespace {
    my $self = shift;
    $_[0] or return 0; # no checks needed without allow_whitespace

    my $quo = $self->{quote};
    defined $quo && length ($quo) or $quo = $self->{quote_char};
    my $esc = $self->{escape_char};

    (defined $quo && $quo =~ m/^[ \t]/) || (defined $esc && $esc =~ m/^[ \t]/) and
        return 1002;

    return 0;
    }

sub _check_sanity {
    my $self = shift;

    my $eol = $self->{eol};
    my $sep = $self->{sep};
    defined $sep && length ($sep) or $sep = $self->{sep_char};
    my $quo = $self->{quote};
    defined $quo && length ($quo) or $quo = $self->{quote_char};
    my $esc = $self->{escape_char};

#    use DP;::diag ("SEP: '", DPeek ($sep),
#                "', QUO: '", DPeek ($quo),
#                "', ESC: '", DPeek ($esc),"'");

    # sep_char should not be undefined
    if (defined $sep && $sep ne "") {
        length ($sep) > 16                and return 1006;
        $sep =~ m/[\r\n]/                and return 1003;
        }
    else {
                                            return 1008;
        }
    if (defined $quo) {
        defined $sep && $quo eq $sep        and return 1001;
        length ($quo) > 16                and return 1007;
        $quo =~ m/[\r\n]/                and return 1003;
        }
    if (defined $esc) {
        defined $sep && $esc eq $sep        and return 1001;
        $esc =~ m/[\r\n]/                and return 1003;
        }
    if (defined $eol) {
        length ($eol) > 16                and return 1005;
        }

    return _unhealthy_whitespace ($self, $self->{allow_whitespace});
    }

sub known_attributes {
    sort grep !m/^_/ => "sep", "quote", keys %def_attr;
    }

sub new {
    $last_new_error   = Text::CSV_PP->SetDiag(1000,
        'usage: my $csv = Text::CSV_PP->new ([{ option => value, ... }]);');

    my $proto = shift;
    my $class = ref ($proto) || $proto	or  return;
    @_ > 0 &&   ref $_[0] ne "HASH"	and return;
    my $attr  = shift || {};
    my %attr  = map {
        my $k = m/^[a-zA-Z]\w+$/ ? lc $_ : $_;
        exists $attr_alias{$k} and $k = $attr_alias{$k};
        $k => $attr->{$_};
        } keys %$attr;

    my $sep_aliased = 0;
    if (exists $attr{sep}) {
        $attr{sep_char} = delete $attr{sep};
        $sep_aliased = 1;
        }
    my $quote_aliased = 0;
    if (exists $attr{quote}) {
        $attr{quote_char} = delete $attr{quote};
        $quote_aliased = 1;
        }
    for (keys %attr) {
        if (m/^[a-z]/ && exists $def_attr{$_}) {
            # uncoverable condition false
            defined $attr{$_} && m/_char$/ and utf8::decode ($attr{$_});
            next;
            }
#        croak?
        $last_new_error = Text::CSV_PP->SetDiag(1000, "INI - Unknown attribute '$_'");
        $attr{auto_diag} and error_diag ();
        return;
        }
    if ($sep_aliased and defined $attr{sep_char}) {
        my @b = unpack "U0C*", $attr{sep_char};
        if (@b > 1) {
            $attr{sep} = $attr{sep_char};
            $attr{sep_char} = "\0";
            }
        else {
            $attr{sep} = undef;
            }
        }
    if ($quote_aliased and defined $attr{quote_char}) {
        my @b = unpack "U0C*", $attr{quote_char};
        if (@b > 1) {
            $attr{quote} = $attr{quote_char};
            $attr{quote_char} = "\0";
            }
        else {
            $attr{quote} = undef;
            }
        }

    my $self = { %def_attr, %attr };
    if (my $ec = _check_sanity ($self)) {
        $last_new_error   = Text::CSV_PP->SetDiag($ec);
        $attr{auto_diag} and error_diag ();
        return;
        }
    if (defined $self->{callbacks} && ref $self->{callbacks} ne "HASH") {
        Carp::carp "The 'callbacks' attribute is set but is not a hash: ignored\n";
        $self->{callbacks} = undef;
        }

    $last_new_error = Text::CSV_PP->SetDiag(0);
    defined $\ && !exists $attr{eol} and $self->{eol} = $\;
    bless $self, $class;
    defined $self->{types} and $self->types ($self->{types});
    $self;
}

# Keep in sync with XS!
my %_cache_id = ( # Only expose what is accessed from within PM
    quote_char			=>  0,
    escape_char			=>  1,
    sep_char			=>  2,
    sep				=> 39,	# 39 .. 55
    binary			=>  3,
    keep_meta_info		=>  4,
    always_quote		=>  5,
    allow_loose_quotes		=>  6,
    allow_loose_escapes		=>  7,
    allow_unquoted_escape	=>  8,
    allow_whitespace		=>  9,
    blank_is_undef		=> 10,
    eol				=> 11,
    quote			=> 15,
    verbatim			=> 22,
    empty_is_undef		=> 23,
    auto_diag			=> 24,
    diag_verbose		=> 33,
    quote_space			=> 25,
    quote_empty			=> 37,
    quote_binary		=> 32,
    escape_null			=> 31,
    decode_utf8			=> 35,
    _has_hooks			=> 36,
    _is_bound			=> 26,	# 26 .. 29
    );

my %_hidden_cache_id = qw(
    sep_len		38
    eol_len		12
    eol_is_cr		13
    quo_len		16
    _has_ahead		30
    has_error_input		34
);

my %_reverse_cache_id = (
    map({$_cache_id{$_} => $_} keys %_cache_id),
    map({$_hidden_cache_id{$_} => $_} keys %_hidden_cache_id),
);

# A `character'
sub _set_attr_C {
    my ($self, $name, $val, $ec) = @_;
    defined $val or $val = 0;
    utf8::decode ($val);
    $self->{$name} = $val;
    $ec = _check_sanity ($self) and
        croak ($self->SetDiag ($ec));
    $self->_cache_set ($_cache_id{$name}, $val);
    }

# A flag
sub _set_attr_X {
    my ($self, $name, $val) = @_;
    defined $val or $val = 0;
    $self->{$name} = $val;
    $self->_cache_set ($_cache_id{$name}, 0 + $val);
    }

# A number
sub _set_attr_N {
    my ($self, $name, $val) = @_;
    $self->{$name} = $val;
    $self->_cache_set ($_cache_id{$name}, 0 + $val);
    }

# Accessor methods.
#   It is unwise to change them halfway through a single file!
sub quote_char {
    my $self = shift;
    if (@_) {
        $self->_set_attr_C ("quote_char", shift);
        $self->_cache_set ($_cache_id{quote}, "");
        }
    $self->{quote_char};
    }

sub quote {
    my $self = shift;
    if (@_) {
        my $quote = shift;
        defined $quote or $quote = "";
        utf8::decode ($quote);
        my @b = unpack "U0C*", $quote;
        if (@b > 1) {
            @b > 16 and croak ($self->SetDiag (1007));
            $self->quote_char ("\0");
            }
        else {
            $self->quote_char ($quote);
            $quote = "";
            }
        $self->{quote} = $quote;

        my $ec = _check_sanity ($self);
        $ec and croak ($self->SetDiag ($ec));

        $self->_cache_set ($_cache_id{quote}, $quote);
        }
    my $quote = $self->{quote};
    defined $quote && length ($quote) ? $quote : $self->{quote_char};
    }

sub escape_char {
    my $self = shift;
    @_ and $self->_set_attr_C ("escape_char", shift);
    $self->{escape_char};
    }

sub sep_char {
    my $self = shift;
    if (@_) {
        $self->_set_attr_C ("sep_char", shift);
        $self->_cache_set ($_cache_id{sep}, "");
        }
    $self->{sep_char};
}

sub sep {
    my $self = shift;
    if (@_) {
        my $sep = shift;
        defined $sep or $sep = "";
        utf8::decode ($sep);
        my @b = unpack "U0C*", $sep;
        if (@b > 1) {
            @b > 16 and croak ($self->SetDiag (1006));
            $self->sep_char ("\0");
            }
        else {
            $self->sep_char ($sep);
            $sep = "";
            }
        $self->{sep} = $sep;

        my $ec = _check_sanity ($self);
        $ec and croak ($self->SetDiag ($ec));

        $self->_cache_set ($_cache_id{sep}, $sep);
        }
    my $sep = $self->{sep};
    defined $sep && length ($sep) ? $sep : $self->{sep_char};
    }

sub eol {
    my $self = shift;
    if (@_) {
        my $eol = shift;
        defined $eol or $eol = "";
        length ($eol) > 16 and croak ($self->SetDiag (1005));
        $self->{eol} = $eol;
        $self->_cache_set ($_cache_id{eol}, $eol);
        }
    $self->{eol};
    }

sub always_quote {
    my $self = shift;
    @_ and $self->_set_attr_X ("always_quote", shift);
    $self->{always_quote};
    }

sub quote_space {
    my $self = shift;
    @_ and $self->_set_attr_X ("quote_space", shift);
    $self->{quote_space};
    }

sub quote_empty {
    my $self = shift;
    @_ and $self->_set_attr_X ("quote_empty", shift);
    $self->{quote_empty};
    }

sub escape_null {
    my $self = shift;
    @_ and $self->_set_attr_X ("escape_null", shift);
    $self->{escape_null};
    }

sub quote_null { goto &escape_null; }

sub quote_binary {
    my $self = shift;
    @_ and $self->_set_attr_X ("quote_binary", shift);
    $self->{quote_binary};
    }

sub binary {
    my $self = shift;
    @_ and $self->_set_attr_X ("binary", shift);
    $self->{binary};
    }

sub decode_utf8 {
    my $self = shift;
    @_ and $self->_set_attr_X ("decode_utf8", shift);
    $self->{decode_utf8};
}

sub keep_meta_info {
    my $self = shift;
    if (@_) {
        my $v = shift;
        !defined $v || $v eq "" and $v = 0;
        $v =~ m/^[0-9]/ or $v = lc $v eq "false" ? 0 : 1; # true/truth = 1
        $self->_set_attr_X ("keep_meta_info", $v);
        }
    $self->{keep_meta_info};
    }

sub allow_loose_quotes {
    my $self = shift;
    @_ and $self->_set_attr_X ("allow_loose_quotes", shift);
    $self->{allow_loose_quotes};
    }

sub allow_loose_escapes {
    my $self = shift;
    @_ and $self->_set_attr_X ("allow_loose_escapes", shift);
    $self->{allow_loose_escapes};
    }

sub allow_whitespace {
    my $self = shift;
    if (@_) {
        my $aw = shift;
        _unhealthy_whitespace ($self, $aw) and
            croak ($self->SetDiag (1002));
        $self->_set_attr_X ("allow_whitespace", $aw);
        }
    $self->{allow_whitespace};
    }

sub allow_unquoted_escape {
    my $self = shift;
    @_ and $self->_set_attr_X ("allow_unquoted_escape", shift);
    $self->{allow_unquoted_escape};
    }

sub blank_is_undef {
    my $self = shift;
    @_ and $self->_set_attr_X ("blank_is_undef", shift);
    $self->{blank_is_undef};
    }

sub empty_is_undef {
    my $self = shift;
    @_ and $self->_set_attr_X ("empty_is_undef", shift);
    $self->{empty_is_undef};
    }

sub verbatim {
    my $self = shift;
    @_ and $self->_set_attr_X ("verbatim", shift);
    $self->{verbatim};
    }

sub auto_diag {
    my $self = shift;
    if (@_) {
        my $v = shift;
        !defined $v || $v eq "" and $v = 0;
        $v =~ m/^[0-9]/ or $v = lc $v eq "false" ? 0 : 1; # true/truth = 1
        $self->_set_attr_X ("auto_diag", $v);
        }
    $self->{auto_diag};
    }

sub diag_verbose {
    my $self = shift;
    if (@_) {
        my $v = shift;
        !defined $v || $v eq "" and $v = 0;
        $v =~ m/^[0-9]/ or $v = lc $v eq "false" ? 0 : 1; # true/truth = 1
        $self->_set_attr_X ("diag_verbose", $v);
        }
    $self->{diag_verbose};
    }

################################################################################
# status
################################################################################

sub status {
    $_[0]->{_STATUS};
}

sub eof {
    $_[0]->{_EOF};
}

sub types {
    my $self = shift;

    if (@_) {
        if (my $types = shift) {
            $self->{'_types'} = join("", map{ chr($_) } @$types);
            $self->{'types'} = $types;
        }
        else {
            delete $self->{'types'};
            delete $self->{'_types'};
            undef;
        }
    }
    else {
        $self->{'types'};
    }
}

sub callbacks {
    my $self = shift;
    if (@_) {
        my $cb;
        my $hf = 0x00;
        if (defined $_[0]) {
            grep { !defined } @_ and croak ($self->SetDiag (1004));
            $cb = @_ == 1 && ref $_[0] eq "HASH" ? shift
                : @_ % 2 == 0                    ? { @_ }
                : croak ($self->SetDiag (1004));
            foreach my $cbk (keys %$cb) {
                (!ref $cbk && $cbk =~ m/^[\w.]+$/) && ref $cb->{$cbk} eq "CODE" or
                    croak ($self->SetDiag (1004));
                }
            exists $cb->{error}        and $hf |= 0x01;
            exists $cb->{after_parse}  and $hf |= 0x02;
            exists $cb->{before_print} and $hf |= 0x04;
            }
        elsif (@_ > 1) {
            # (undef, whatever)
            croak ($self->SetDiag (1004));
            }
        $self->_set_attr_X ("_has_hooks", $hf);
        $self->{callbacks} = $cb;
        }
    $self->{callbacks};
    }

################################################################################
# error_diag
################################################################################

sub error_diag {
    my $self = shift;
    my @diag = (0 + $last_new_error, $last_new_error, 0, 0, 0);

    if ($self && ref $self && # Not a class method or direct call
         $self->isa (__PACKAGE__) && defined $self->{_ERROR_DIAG}) {
        $diag[0] = 0 + $self->{_ERROR_DIAG};
        $diag[1] =     $self->{_ERROR_DIAG};
        $diag[2] = 1 + $self->{_ERROR_POS} if exists $self->{_ERROR_POS};
        $diag[3] =     $self->{_RECNO};
        $diag[4] =     $self->{_ERROR_FLD} if exists $self->{_ERROR_FLD};

        $diag[0] && $self && $self->{callbacks} && $self->{callbacks}{error} and
            return $self->{callbacks}{error}->(@diag);
        }

    my $context = wantarray;

    unless (defined $context) {	# Void context, auto-diag
        if ($diag[0] && $diag[0] != 2012) {
            my $msg = "# CSV_PP ERROR: $diag[0] - $diag[1] \@ rec $diag[3] pos $diag[2]\n";
            $diag[4] and $msg =~ s/$/ field $diag[4]/;

            unless ($self && ref $self) {        # auto_diag
                    # called without args in void context
                warn $msg;
                return;
                }

            if ($self->{diag_verbose} and $self->{_ERROR_INPUT}) {
                $msg .= "$self->{_ERROR_INPUT}'\n";
                $msg .= " " x ($diag[2] - 1);
                $msg .= "^\n";
                }

            my $lvl = $self->{auto_diag};
            if ($lvl < 2) {
                my @c = caller (2);
                if (@c >= 11 && $c[10] && ref $c[10] eq "HASH") {
                    my $hints = $c[10];
                    (exists $hints->{autodie} && $hints->{autodie} or
                     exists $hints->{"guard Fatal"} &&
                    !exists $hints->{"no Fatal"}) and
                        $lvl++;
                    # Future releases of autodie will probably set $^H{autodie}
                    #  to "autodie @args", like "autodie :all" or "autodie open"
                    #  so we can/should check for "open" or "new"
                    }
                }
            $lvl > 1 ? die $msg : warn $msg;
            }
        return;
        }

    return $context ? @diag : $diag[1];
}

sub record_number {
    return shift->{_RECNO};
}

################################################################################
# string
################################################################################

*string = \&_string;
sub _string {
    defined $_[0]->{_STRING} ? ${ $_[0]->{_STRING} } : undef;
}

################################################################################
# fields
################################################################################

*fields = \&_fields;
sub _fields {
    ref($_[0]->{_FIELDS}) ?  @{$_[0]->{_FIELDS}} : undef;
}

################################################################################
# meta_info
################################################################################

sub meta_info {
    $_[0]->{_FFLAGS} ? @{ $_[0]->{_FFLAGS} } : undef;
}

sub is_quoted {
    return unless (defined $_[0]->{_FFLAGS});
    return if( $_[1] =~ /\D/ or $_[1] < 0 or  $_[1] > $#{ $_[0]->{_FFLAGS} } );

    $_[0]->{_FFLAGS}->[$_[1]] & IS_QUOTED ? 1 : 0;
}

sub is_binary {
    return unless (defined $_[0]->{_FFLAGS});
    return if( $_[1] =~ /\D/ or $_[1] < 0 or  $_[1] > $#{ $_[0]->{_FFLAGS} } );
    $_[0]->{_FFLAGS}->[$_[1]] & IS_BINARY ? 1 : 0;
}

sub is_missing {
    my ($self, $idx, $val) = @_;
    return unless $self->{keep_meta_info}; # FIXME
    $idx < 0 || !ref $self->{_FFLAGS} and return;
    $idx >= @{$self->{_FFLAGS}} and return 1;
    $self->{_FFLAGS}[$idx] & IS_MISSING ? 1 : 0;
}

################################################################################
# combine
################################################################################
*combine = \&_combine;
sub _combine {
    my ($self, @fields) = @_;
    my $str  = "";
    $self->{_FIELDS} = \@fields;
    $self->{_STATUS} = (@fields > 0) && $self->__combine(\$str, \@fields, 0);
    $self->{_STRING} = \$str;
    $self->{_STATUS};
    }

################################################################################
# parse
################################################################################
*parse = \&_parse;
sub _parse {
    my ($self, $str) = @_;

    my $fields = [];
    my $fflags = [];
    $self->{_STRING} = \$str;
    if (defined $str && $self->__parse ($fields, $fflags, $str, 0)) {
        $self->{_FIELDS} = $fields;
        $self->{_FFLAGS} = $fflags;
        $self->{_STATUS} = 1;
        }
    else {
        $self->{_FIELDS} = undef;
        $self->{_FFLAGS} = undef;
        $self->{_STATUS} = 0;
        }
    $self->{_STATUS};
    }

sub column_names {
    my ( $self, @columns ) = @_;

    @columns or return defined $self->{_COLUMN_NAMES} ? @{$self->{_COLUMN_NAMES}} : undef;
    @columns == 1 && ! defined $columns[0] and return $self->{_COLUMN_NAMES} = undef;

    if ( @columns == 1 && ref $columns[0] eq "ARRAY" ) {
        @columns = @{ $columns[0] };
    }
    elsif ( join "", map { defined $_ ? ref $_ : "" } @columns ) {
        croak $self->SetDiag( 3001 );
    }

    if ( $self->{_BOUND_COLUMNS} && @columns != @{$self->{_BOUND_COLUMNS}} ) {
        croak $self->SetDiag( 3003 );
    }

    $self->{_COLUMN_NAMES} = [ map { defined $_ ? $_ : "\cAUNDEF\cA" } @columns ];
    @{ $self->{_COLUMN_NAMES} };
}

sub header {
    my ($self, $fh, @args) = @_;

    $fh or croak ($self->SetDiag (1014));

    my (@seps, %args);
    for (@args) {
        if (ref $_ eq "ARRAY") {
            push @seps, @$_;
            next;
            }
        if (ref $_ eq "HASH") {
            %args = %$_;
            next;
            }
        croak (q{usage: $csv->header ($fh, [ seps ], { options })});
        }

    defined $args{detect_bom}         or $args{detect_bom}         = 1;
    defined $args{munge_column_names} or $args{munge_column_names} = "lc";
    defined $args{set_column_names}   or $args{set_column_names}   = 1;

    defined $args{sep_set} && ref $args{sep_set} eq "ARRAY" and
        @seps =  @{$args{sep_set}};

    my $hdr = <$fh>;
    defined $hdr && $hdr ne "" or croak ($self->SetDiag (1010));

    my %sep;
    @seps or @seps = (",", ";");
    foreach my $sep (@seps) {
        index ($hdr, $sep) >= 0 and $sep{$sep}++;
        }

    keys %sep >= 2 and croak ($self->SetDiag (1011));

    $self->sep (keys %sep);
    my $enc = "";
    if ($args{detect_bom}) { # UTF-7 is not supported
           if ($hdr =~ s/^\x00\x00\xfe\xff//) { $enc = "utf-32be"   }
        elsif ($hdr =~ s/^\xff\xfe\x00\x00//) { $enc = "utf-32le"   }
        elsif ($hdr =~ s/^\xfe\xff//)         { $enc = "utf-16be"   }
        elsif ($hdr =~ s/^\xff\xfe//)         { $enc = "utf-16le"   }
        elsif ($hdr =~ s/^\xef\xbb\xbf//)     { $enc = "utf-8"      }
        elsif ($hdr =~ s/^\xf7\x64\x4c//)     { $enc = "utf-1"      }
        elsif ($hdr =~ s/^\xdd\x73\x66\x73//) { $enc = "utf-ebcdic" }
        elsif ($hdr =~ s/^\x0e\xfe\xff//)     { $enc = "scsu"       }
        elsif ($hdr =~ s/^\xfb\xee\x28//)     { $enc = "bocu-1"     }
        elsif ($hdr =~ s/^\x84\x31\x95\x33//) { $enc = "gb-18030"   }

        if ($enc) {
            if ($enc =~ m/([13]).le$/) {
                my $l = 0 + $1;
                my $x;
                $hdr .= "\0" x $l;
                read $fh, $x, $l;
                }
            $enc = ":encoding($enc)";
            binmode $fh, $enc;
            }
        }

    $args{munge_column_names} eq "lc" and $hdr = lc $hdr;
    $args{munge_column_names} eq "uc" and $hdr = uc $hdr;

    my $hr = \$hdr; # Will cause croak on perl-5.6.x
    open my $h, "<$enc", $hr;
    my $row = $self->getline ($h) or croak;
    close $h;

    my @hdr = @$row   or  croak ($self->SetDiag (1010));
    ref $args{munge_column_names} eq "CODE" and
        @hdr = map { $args{munge_column_names}->($_) } @hdr;
    my %hdr = map { $_ => 1 } @hdr;
    exists $hdr{""}   and croak ($self->SetDiag (1012));
    keys %hdr == @hdr or  croak ($self->SetDiag (1013));
    $args{set_column_names} and $self->column_names (@hdr);
    wantarray ? @hdr : $self;
    }

sub bind_columns {
    my ( $self, @refs ) = @_;

    @refs or return defined $self->{_BOUND_COLUMNS} ? @{$self->{_BOUND_COLUMNS}} : undef;
    @refs == 1 && ! defined $refs[0] and return $self->{_BOUND_COLUMNS} = undef;

    if ( $self->{_COLUMN_NAMES} && @refs != @{$self->{_COLUMN_NAMES}} ) {
        croak $self->SetDiag( 3003 );
    }

    if ( grep { ref $_ ne "SCALAR" } @refs ) { # why don't use grep?
        croak $self->SetDiag( 3004 );
    }

    $self->_set_attr_N("_is_bound", scalar @refs);
    $self->{_BOUND_COLUMNS} = [ @refs ];
    @refs;
}

sub getline_hr {
    my ($self, @args, %hr) = @_;
    $self->{_COLUMN_NAMES} or croak ($self->SetDiag (3002));
    my $fr = $self->getline (@args) or return;
    if (ref $self->{_FFLAGS}) { # missing
        $self->{_FFLAGS}[$_] = IS_MISSING
            for (@$fr ? $#{$fr} + 1 : 0) .. $#{$self->{_COLUMN_NAMES}};
        @$fr == 1 && (!defined $fr->[0] || $fr->[0] eq "") and
            $self->{_FFLAGS}[0] ||= IS_MISSING;
        }
    @hr{@{$self->{_COLUMN_NAMES}}} = @$fr;
    \%hr;
}

sub getline_hr_all {
    my ( $self, $io, @args ) = @_;
    my %hr;

    unless ( $self->{_COLUMN_NAMES} ) {
        croak $self->SetDiag( 3002 );
    }

    my @cn = @{$self->{_COLUMN_NAMES}};

    return [ map { my %h; @h{ @cn } = @$_; \%h } @{ $self->getline_all( $io, @args ) } ];
}

sub say {
    my ($self, $io, @f) = @_;
    my $eol = $self->eol;
    defined $eol && $eol ne "" or $self->eol ($\ || $/);
    my $state = $self->print ($io, @f);
    $self->eol ($eol);
    return $state;
    }

sub print_hr {
    my ($self, $io, $hr) = @_;
    $self->{_COLUMN_NAMES} or croak($self->SetDiag(3009));
    ref $hr eq "HASH"      or croak($self->SetDiag(3010));
    $self->print ($io, [ map { $hr->{$_} } $self->column_names ]);
}

sub fragment {
    my ($self, $io, $spec) = @_;

    my $qd = qr{\s* [0-9]+ \s* }x;                # digit
    my $qs = qr{\s* (?: [0-9]+ | \* ) \s*}x;        # digit or star
    my $qr = qr{$qd (?: - $qs )?}x;                # range
    my $qc = qr{$qr (?: ; $qr )*}x;                # list
    defined $spec && $spec =~ m{^ \s*
        \x23 ? \s*                                # optional leading #
        ( row | col | cell ) \s* =
        ( $qc                                        # for row and col
        | $qd , $qd (?: - $qs , $qs)?                # for cell (ranges)
          (?: ; $qd , $qd (?: - $qs , $qs)? )*        # and cell (range) lists
        ) \s* $}xi or croak ($self->SetDiag (2013));
    my ($type, $range) = (lc $1, $2);

    my @h = $self->column_names ();

    my @c;
    if ($type eq "cell") {
        my @spec;
        my $min_row;
        my $max_row = 0;
        for (split m/\s*;\s*/ => $range) {
            my ($tlr, $tlc, $brr, $brc) = (m{
                    ^ \s* ([0-9]+     ) \s* , \s* ([0-9]+     ) \s*
                (?: - \s* ([0-9]+ | \*) \s* , \s* ([0-9]+ | \*) \s* )?
                    $}x) or croak ($self->SetDiag (2013));
            defined $brr or ($brr, $brc) = ($tlr, $tlc);
            $tlr == 0 || $tlc == 0 ||
                ($brr ne "*" && ($brr == 0 || $brr < $tlr)) ||
                ($brc ne "*" && ($brc == 0 || $brc < $tlc))
                    and croak ($self->SetDiag (2013));
            $tlc--;
            $brc-- unless $brc eq "*";
            defined $min_row or $min_row = $tlr;
            $tlr < $min_row and $min_row = $tlr;
            $brr eq "*" || $brr > $max_row and
                $max_row = $brr;
            push @spec, [ $tlr, $tlc, $brr, $brc ];
            }
        my $r = 0;
        while (my $row = $self->getline ($io)) {
            ++$r < $min_row and next;
            my %row;
            my $lc;
            foreach my $s (@spec) {
                my ($tlr, $tlc, $brr, $brc) = @$s;
                $r <  $tlr || ($brr ne "*" && $r > $brr) and next;
                !defined $lc || $tlc < $lc and $lc = $tlc;
                my $rr = $brc eq "*" ? $#$row : $brc;
                $row{$_} = $row->[$_] for $tlc .. $rr;
                }
            push @c, [ @row{sort { $a <=> $b } keys %row } ];
            if (@h) {
                my %h; @h{@h} = @{$c[-1]};
                $c[-1] = \%h;
                }
            $max_row ne "*" && $r == $max_row and last;
            }
        return \@c;
        }

    # row or col
    my @r;
    my $eod = 0;
    for (split m/\s*;\s*/ => $range) {
        my ($from, $to) = m/^\s* ([0-9]+) (?: \s* - \s* ([0-9]+ | \* ))? \s* $/x
            or croak ($self->SetDiag (2013));
        $to ||= $from;
        $to eq "*" and ($to, $eod) = ($from, 1);
        $from <= 0 || $to <= 0 || $to < $from and croak ($self->SetDiag (2013));
        $r[$_] = 1 for $from .. $to;
        }

    my $r = 0;
    $type eq "col" and shift @r;
    $_ ||= 0 for @r;
    while (my $row = $self->getline ($io)) {
        $r++;
        if ($type eq "row") {
            if (($r > $#r && $eod) || $r[$r]) {
                push @c, $row;
                if (@h) {
                    my %h; @h{@h} = @{$c[-1]};
                    $c[-1] = \%h;
                    }
                }
            next;
            }
        push @c, [ map { ($_ > $#r && $eod) || $r[$_] ? $row->[$_] : () } 0..$#$row ];
        if (@h) {
            my %h; @h{@h} = @{$c[-1]};
            $c[-1] = \%h;
            }
        }

    return \@c;
    }

my $csv_usage = q{usage: my $aoa = csv (in => $file);};

sub _csv_attr {
    my %attr = (@_ == 1 && ref $_[0] eq "HASH" ? %{$_[0]} : @_) or croak;

    $attr{binary} = 1;

    my $enc = delete $attr{enc} || delete $attr{encoding} || "";
    $enc eq "auto" and ($attr{detect_bom}, $enc) = (1, "");
    $enc =~ m/^[-\w.]+$/ and $enc = ":encoding($enc)";

    my $fh;
    my $cls = 0;        # If I open a file, I have to close it
    my $in  = delete $attr{in}  || delete $attr{file} or croak $csv_usage;
    my $out = delete $attr{out} || delete $attr{file};

    ref $in eq "CODE" || ref $in eq "ARRAY" and $out ||= \*STDOUT;

    if ($out) {
        $in or croak $csv_usage;        # No out without in
        defined $attr{eol} or $attr{eol} = "\r\n";
        if ((ref $out and ref $out ne "SCALAR") or "GLOB" eq ref \$out) {
            $fh = $out;
            }
        else {
            open $fh, ">", $out or croak "$out: $!";
            $cls = 1;
            }
        $enc and binmode $fh, $enc;
        }

    if (   ref $in eq "CODE" or ref $in eq "ARRAY") {
        # All done
        }
    elsif (ref $in eq "SCALAR") {
        # Strings with code points over 0xFF may not be mapped into in-memory file handles
        # "<$enc" does not change that :(
        open $fh, "<", $in or croak "Cannot open from SCALAR using PerlIO";
        $cls = 1;
        }
    elsif (ref $in or "GLOB" eq ref \$in) {
        if (!ref $in && $] < 5.008005) {
            $fh = \*$in; # uncoverable statement ancient perl version required
            }
        else {
            $fh = $in;
            }
        }
    else {
        open $fh, "<$enc", $in or croak "$in: $!";
        $cls = 1;
        }
    $fh or croak qq{No valid source passed. "in" is required};

    my $hdrs = delete $attr{headers};
    my $frag = delete $attr{fragment};
    my $key  = delete $attr{key};

    my $cbai = delete $attr{callbacks}{after_in}    ||
               delete $attr{after_in}               ||
               delete $attr{callbacks}{after_parse} ||
               delete $attr{after_parse};
    my $cbbo = delete $attr{callbacks}{before_out}  ||
               delete $attr{before_out};
    my $cboi = delete $attr{callbacks}{on_in}       ||
               delete $attr{on_in};

    my $hd_s = delete $attr{sep_set}                ||
               delete $attr{seps};
    my $hd_b = delete $attr{detect_bom}             ||
               delete $attr{bom};
    my $hd_m = delete $attr{munge}                  ||
               delete $attr{munge_column_names};
    my $hd_c = delete $attr{set_column_names};

    for ([ quo    => "quote"                ],
         [ esc    => "escape"                ],
         [ escape => "escape_char"        ],
         ) {
        my ($f, $t) = @$_;
        exists $attr{$f} and !exists $attr{$t} and $attr{$t} = delete $attr{$f};
        }

    my $fltr = delete $attr{filter};
    my %fltr = (
        not_blank => sub { @{$_[1]} > 1 or defined $_[1][0] && $_[1][0] ne "" },
        not_empty => sub { grep { defined && $_ ne "" } @{$_[1]} },
        filled    => sub { grep { defined && m/\S/    } @{$_[1]} },
        );
    defined $fltr && !ref $fltr && exists $fltr{$fltr} and
        $fltr = { 0 => $fltr{$fltr} };
    ref $fltr eq "HASH" or $fltr = undef;

    defined $attr{auto_diag}   or $attr{auto_diag}   = 1;
    defined $attr{escape_null} or $attr{escape_null} = 0;
    my $csv = delete $attr{csv} || Text::CSV_PP->new (\%attr)
        or croak $last_new_error;

    return {
        csv  => $csv,
        attr => { %attr },
        fh   => $fh,
        cls  => $cls,
        in   => $in,
        out  => $out,
        enc  => $enc,
        hdrs => $hdrs,
        key  => $key,
        frag => $frag,
        fltr => $fltr,
        cbai => $cbai,
        cbbo => $cbbo,
        cboi => $cboi,
        hd_s => $hd_s,
        hd_b => $hd_b,
        hd_m => $hd_m,
        hd_c => $hd_c,
        };
    }

sub csv {
    @_ && ref $_[0] eq __PACKAGE__ and splice @_, 0, 0, "csv";
    @_ or croak $csv_usage;

    my $c = _csv_attr (@_);

    my ($csv, $in, $fh, $hdrs) = @{$c}{"csv", "in", "fh", "hdrs"};
    my %hdr;
    if (ref $hdrs eq "HASH") {
        %hdr  = %$hdrs;
        $hdrs = "auto";
        }

    if ($c->{out}) {
        if (ref $in eq "CODE") {
            my $hdr = 1;
            while (my $row = $in->($csv)) {
                if (ref $row eq "ARRAY") {
                    $csv->print ($fh, $row);
                    next;
                    }
                if (ref $row eq "HASH") {
                    if ($hdr) {
                        $hdrs ||= [ map { $hdr{$_} || $_ } keys %$row ];
                        $csv->print ($fh, $hdrs);
                        $hdr = 0;
                        }
                    $csv->print ($fh, [ @{$row}{@$hdrs} ]);
                    }
                }
            }
        elsif (ref $in->[0] eq "ARRAY") { # aoa
            ref $hdrs and $csv->print ($fh, $hdrs);
            for (@{$in}) {
                $c->{cboi} and $c->{cboi}->($csv, $_);
                $c->{cbbo} and $c->{cbbo}->($csv, $_);
                $csv->print ($fh, $_);
                }
            }
        else { # aoh
            my @hdrs = ref $hdrs ? @{$hdrs} : keys %{$in->[0]};
            defined $hdrs or $hdrs = "auto";
            ref $hdrs || $hdrs eq "auto" and
                $csv->print ($fh, [ map { $hdr{$_} || $_ } @hdrs ]);
            for (@{$in}) {
                local %_;
                *_ = $_;
                $c->{cboi} and $c->{cboi}->($csv, $_);
                $c->{cbbo} and $c->{cbbo}->($csv, $_);
                $csv->print ($fh, [ @{$_}{@hdrs} ]);
                }
            }

        $c->{cls} and close $fh;
        return 1;
        }

    if (defined $c->{hd_s} || defined $c->{hd_b} || defined $c->{hd_m} || defined $c->{hd_c}) {
        my %harg;
        defined $c->{hd_s} and $harg{set_set}            = $c->{hd_s};
        defined $c->{hd_d} and $harg{detect_bom}         = $c->{hd_b};
        defined $c->{hd_m} and $harg{munge_column_names} = $hdrs ? "none" : $c->{hd_m};
        defined $c->{hd_c} and $harg{set_column_names}   = $hdrs ? 0      : $c->{hd_c};
        $csv->header ($fh, \%harg);
        my @hdr = $csv->column_names;
        @hdr and $hdrs ||= \@hdr;
        }

    my $key = $c->{key} and $hdrs ||= "auto";
    $c->{fltr} && grep m/\D/ => keys %{$c->{fltr}} and $hdrs ||= "auto";
    if (defined $hdrs) {
        if (!ref $hdrs) {
            if ($hdrs eq "skip") {
                $csv->getline ($fh); # discard;
                }
            elsif ($hdrs eq "auto") {
                my $h = $csv->getline ($fh) or return;
                $hdrs = [ map {      $hdr{$_} || $_ } @$h ];
                }
            elsif ($hdrs eq "lc") {
                my $h = $csv->getline ($fh) or return;
                $hdrs = [ map { lc ($hdr{$_} || $_) } @$h ];
                }
            elsif ($hdrs eq "uc") {
                my $h = $csv->getline ($fh) or return;
                $hdrs = [ map { uc ($hdr{$_} || $_) } @$h ];
                }
            }
        elsif (ref $hdrs eq "CODE") {
            my $h  = $csv->getline ($fh) or return;
            my $cr = $hdrs;
            $hdrs  = [ map {  $cr->($hdr{$_} || $_) } @$h ];
            }
        }

    if ($c->{fltr}) {
        my %f = %{$c->{fltr}};
        # convert headers to index
        my @hdr;
        if (ref $hdrs) {
            @hdr = @{$hdrs};
            for (0 .. $#hdr) {
                exists $f{$hdr[$_]} and $f{$_ + 1} = delete $f{$hdr[$_]};
                }
            }
        $csv->callbacks (after_parse => sub {
            my ($CSV, $ROW) = @_; # lexical sub-variables in caps
            foreach my $FLD (sort keys %f) {
                local $_ = $ROW->[$FLD - 1];
                local %_;
                @hdr and @_{@hdr} = @$ROW;
                $f{$FLD}->($CSV, $ROW) or return \"skip";
                $ROW->[$FLD - 1] = $_;
                }
            });
        }

    my $frag = $c->{frag};
    my $ref = ref $hdrs
        ? # aoh
          do {
            $csv->column_names ($hdrs);
            $frag ? $csv->fragment ($fh, $frag) :
            $key  ? { map { $_->{$key} => $_ } @{$csv->getline_hr_all ($fh)} }
                  : $csv->getline_hr_all ($fh);
            }
        : # aoa
            $frag ? $csv->fragment ($fh, $frag)
                  : $csv->getline_all ($fh);
    $ref or Text::CSV_PP->auto_diag;
    $c->{cls} and close $fh;
    if ($ref and $c->{cbai} || $c->{cboi}) {
        foreach my $r (@{$ref}) {
            local %_;
            ref $r eq "HASH" and *_ = $r;
            $c->{cbai} and $c->{cbai}->($csv, $r);
            $c->{cboi} and $c->{cboi}->($csv, $r);
            }
        }

    defined wantarray or
        return csv (%{$c->{attr}}, in => $ref, headers => $hdrs, %{$c->{attr}});

    return $ref;
    }

# The end of the common pure perl part.

################################################################################
#
# The following are methods implemented in XS in Text::CSV_XS or
# helper methods for Text::CSV_PP only
#
################################################################################

sub _setup_ctx {
    my $self = shift;

    $last_error = undef;

    my %ctx;
    if ($self->{_CACHE}) {
        %ctx = %{$self->{_CACHE}};
    } else {
        # $ctx{self}  = $self;
        $ctx{pself} = ref $self || $self;

        $ctx{sep} = ',';
        if (defined $self->{sep_char}) {
            $ctx{sep} = $self->{sep_char};
        }
        if (defined $self->{sep}) {
            $ctx{sep} = $self->{sep};
            my $sep_len = length($ctx{sep});
            $ctx{sep_len} = $sep_len if $sep_len > 1;
        }

        $ctx{quo} = '"';
        if (exists $self->{quote_char}) {
            my $quote_char = $self->{quote_char};
            if (defined $quote_char and length $quote_char) {
                $ctx{quo} = $quote_char;
            } else {
                $ctx{quo} = "\0";
            }
        }
        if (defined $self->{quote}) {
            $ctx{quo} = $self->{quote};
            my $quote_len = length($ctx{quo});
            $ctx{quo_len} = $quote_len if $quote_len > 1;
        }

        $ctx{escape_char} = '"';
        if (exists $self->{escape_char}) {
            my $escape_char = $self->{escape_char};
            if (defined $escape_char and length $escape_char) {
                $ctx{escape_char} = $escape_char;
            } else {
                $ctx{escape_char} = "\0";
            }
        }

        if (defined $self->{eol}) {
            my $eol = $self->{eol};
            my $eol_len = length($eol);
            $ctx{eol} = $eol;
            $ctx{eol_len} = $eol_len;
            if ($eol_len == 1 and $eol eq "\015") {
                $ctx{eol_is_cr} = 1;
            }
        }

        if (defined $self->{_types}) {
            $ctx{types} = $self->{_types};
            $ctx{types_len} = length($ctx{types});
        }

        if (defined $self->{_is_bound}) {
            $ctx{is_bound} = $self->{_is_bound};
        }

        if (defined $self->{callbacks}) {
            my $cb = $self->{callbacks};
            $ctx{has_hooks} = 0;
            if (defined $cb->{after_parse} and ref $cb->{after_parse} eq 'CODE') {
                $ctx{has_hooks} |= HOOK_AFTER_PARSE;
            }
            if (defined $cb->{before_print} and ref $cb->{before_print} eq 'CODE') {
                $ctx{has_hooks} |= HOOK_BEFORE_PRINT;
            }
        }

        for (qw/
            binary decode_utf8 always_quote quote_empty
            allow_loose_quotes allow_loose_escapes
            allow_unquoted_escape allow_whitespace blank_is_undef
            empty_is_undef verbatim auto_diag diag_verbose
            keep_meta_info
        /) {
            $ctx{$_} = defined $self->{$_} ? $self->{$_} : 0;
        }
        for (qw/quote_space escape_null quote_binary/) {
            $ctx{$_} = defined $self->{$_} ? $self->{$_} : 1;
        }
        # FIXME: readonly
        my $cache = \%ctx;
        $ctx{cache} = $cache;
        $self->{_CACHE} = $cache;
    }

    $ctx{utf8} = 0;
    $ctx{size} = 0;
    $ctx{used} = 0;

    if ($ctx{is_bound}) {
        my $bound = $self->{_BOUND_COLUMNS};
        if ($bound and ref $bound eq 'ARRAY') {
            $ctx{bound} = $bound;
        } else {
            $ctx{is_bound} = 0;
        }
    }

    $ctx{eol_pos} = -1;
    $ctx{eolx} = $ctx{eol_len}
        ? $ctx{verbatim} || $ctx{eol_len} >= 2
            ? 1
            : $ctx{eol} =~ /\A[\015|\012]/ ? 0 : 1
        : 0;

    if ($ctx{sep_len} and _is_valid_utf8($ctx{sep})) {
        $ctx{utf8} = 1;
    }
    if ($ctx{quo_len} and _is_valid_utf8($ctx{quo})) {
        $ctx{utf8} = 1;
    }

    \%ctx;
}

sub _cache_set {
    my ($self, $idx, $value) = @_;
    return unless exists $self->{_CACHE};
    my $cache = $self->{_CACHE};

    my $key = $_reverse_cache_id{$idx};
    if (!defined $key) {
        warn (sprintf "Unknown cache index %d ignored\n", $idx);
    } elsif ($key eq 'sep_char') {
        $cache->{sep} = $value;
        $cache->{sep_len} = 0;
    }
    elsif ($key eq 'quote_char') {
        $cache->{quo} = $value;
        $cache->{quo_len} = 0;
    }
    elsif ($key eq '_has_hooks') {
        $cache->{has_hooks} = $value;
    }
    elsif ($key eq '_is_bound') {
        $cache->{is_bound} = $value;
    }
    elsif ($key eq 'sep') {
        my $len = length($value);
        $cache->{sep} = $value if $len;
        $cache->{sep_len} = $len == 1 ? 0 : $len;
    }
    elsif ($key eq 'quote') {
        my $len = length($value);
        $cache->{quo} = $value if $len;
        $cache->{quo_len} = $len == 1 ? 0 : $len;
    }
    elsif ($key eq 'eol') {
        $cache->{eol} = $value if length($value);
        $cache->{eol_is_cr} = $value eq "\015" ? 1 : 0;
    }
    else {
        $cache->{$key} = $value;
    }
    return 1;
}

sub _cache_diag {
    my $self = shift;
    unless (exists $self->{_CACHE}) {
        warn ("CACHE: invalid\n");
        return;
    }

    my $cache = $self->{_CACHE};
    warn ("CACHE:\n");
    $self->__cache_show_char(quote_char => $cache->{quo});
    $self->__cache_show_char(escape_char => $cache->{escape_char});
    $self->__cache_show_char(sep_char => $cache->{sep});
    for (qw/
        binary decode_utf8 allow_loose_escapes allow_loose_quotes
        allow_whitespace always_quote quote_empty quote_space
        escape_null quote_binary auto_diag diag_verbose
        has_error_input blank_is_undef empty_is_undef has_ahead
        keep_meta_info verbatim has_hooks eol_is_cr eol_len
    /) {
        $self->__cache_show_byte($_ => $cache->{$_});
    }
    $self->__cache_show_str(eol => $cache->{eol_len}, $cache->{eol});
    $self->__cache_show_byte(sep_len => $cache->{sep_len});
    if ($cache->{sep_len} and $cache->{sep_len} > 1) {
        $self->__cache_show_str(sep => $cache->{sep_len}, $cache->{sep});
    }
    $self->__cache_show_byte(quo_len => $cache->{quo_len});
    if ($cache->{quo_len} and $cache->{quo_len} > 1) {
        $self->__cache_show_str(quote => $cache->{quo_len}, $cache->{quo});
    }
}

sub __cache_show_byte {
    my ($self, $key, $value) = @_;
    warn (sprintf "  %-21s %02x:%3d\n", $key, defined $value ? ord($value) : 0, defined $value ? $value : 0);
}

sub __cache_show_char {
    my ($self, $key, $value) = @_;
    my $v = $value;
    if (defined $value) {
        my @b = unpack "U0C*", $value;
        $v = pack "U*", $b[0];
    }
    warn (sprintf "  %-21s %02x:%s\n", $key, defined $v ? ord($v) : 0, $self->__pretty_str($v, 1));
}

sub __cache_show_str {
    my ($self, $key, $len, $value) = @_;
    warn (sprintf "  %-21s %02d:%s\n", $key, $len, $self->__pretty_str($value, $len));
}

sub __pretty_str { # FIXME
    my ($self, $str, $len) = @_;
    return '' unless defined $str;
    $str = substr($str, 0, $len);
    $str =~ s/"/\\"/g;
    $str =~ s/([^\x09\x20-\x7e])/sprintf '\\x{%x}', ord($1)/eg;
    qq{"$str"};
}

sub _hook {
    my ($self, $name, $fields) = @_;
    return 0 unless $self->{callbacks};

    my $cb = $self->{callbacks}{$name};
    return 0 unless $cb && ref $cb eq 'CODE';

    my $res = $cb->($self, $fields);
    $res = 0 if $res eq "skip";
    $res;
}

################################################################################
# methods for combine
################################################################################

sub __combine {
    my ($self, $dst, $fields, $useIO) = @_;

    my $ctx = $self->_setup_ctx;

    my ($binary, $quot, $sep, $esc, $quote_space) = @{$ctx}{qw/binary quo sep escape_char quote_space/};

    if(!defined $quot or $quot eq "\0"){ $quot = ''; }

    my $re_esc;
    if ($quot ne '') {
      $re_esc = $self->{_re_comb_escape}->{$quot}->{$esc} ||= qr/(\Q$quot\E|\Q$esc\E)/;
    } else {
      $re_esc = $self->{_re_comb_escape}->{$quot}->{$esc} ||= qr/(\Q$esc\E)/;
    }

    my $re_sp  = $self->{_re_comb_sp}->{$sep}->{$quote_space} ||= ( $quote_space ? qr/[\s\Q$sep\E]/ : qr/[\Q$sep\E]/ );

    my $bound = 0;
    my $n = @$fields - 1;
    if ($n < 0 and $ctx->{is_bound}) {
        $n = $ctx->{is_bound} - 1;
        $bound = 1;
    }

    my $check_meta = ($ctx->{keep_meta_info} >= 10 and @{$self->{_FFLAGS} || []} >= $n) ? 1 : 0;

    my $must_be_quoted;
    my @results;
    for(my $i = 0; $i <= $n; $i++) {
        my $v_ref;
        if ($bound) {
            $v_ref = $self->__bound_field($ctx, $i, 1);
        } else {
            if (@$fields > $i) {
                $v_ref = \($fields->[$i]);
            }
        }
        next unless $v_ref;

        my $value = $$v_ref;

        unless (defined $value) {
            push @results, '';
            next;
        }
        elsif ( !$binary ) {
            $binary = 1 if utf8::is_utf8 $value;
        }

        if (!$binary and $value =~ /[^\x09\x20-\x7E]/) {
            # an argument contained an invalid character...
            $self->{_ERROR_INPUT} = $value;
            $self->SetDiag(2110);
            return 0;
        }

        $must_be_quoted = 0;
        if ($value eq '') {
            $must_be_quoted++ if $ctx->{quote_empty} or ($check_meta && $self->is_quoted($i));
        }
        else {
            if($value =~ s/$re_esc/$esc$1/g and $quot ne ''){
                $must_be_quoted++;
            }
            if($value =~ /$re_sp/){
                $must_be_quoted++;
            }

            if( $binary and $ctx->{escape_null} ){
                use bytes;
                $must_be_quoted++ if ( $value =~ s/\0/${esc}0/g || ($ctx->{quote_binary} && $value =~ /[\x00-\x1f\x7f-\xa0]/) );
            }
        }

        if($ctx->{always_quote} or $must_be_quoted or ($check_meta && $self->is_quoted($i))){
            $value = $quot . $value . $quot;
        }
        push @results, $value;
    }

    $$dst = join($sep, @results) . ( defined $ctx->{eol} ? $ctx->{eol} : '' );

    return 1;
}

sub print {
    my ($self, $io, $fields) = @_;

    require IO::Handle;

    if (!defined $fields) {
        $fields = [];
    } elsif(ref($fields) ne 'ARRAY'){
        Carp::croak("Expected fields to be an array ref");
    }

    $self->_hook(before_print => $fields);

    my $str = "";
    $self->__combine(\$str, $fields, 1) or return '';

    local $\ = '';

    $io->print( $str ) or $self->_set_error_diag(2200);
}

################################################################################
# methods for parse
################################################################################


sub __parse { # cx_xsParse
    my ($self, $fields, $fflags, $src, $useIO) = @_;

    my $ctx = $self->_setup_ctx;
    my $state = $self->___parse($ctx, $fields, $fflags, $src, $useIO);
    if ($state and ($ctx->{has_hooks} || 0) & HOOK_AFTER_PARSE) {
        $self->_hook(after_parse => $fields);
    }
    return $state || !$last_error;
}

sub ___parse { # cx_c_xsParse
    my ($self, $ctx, $fields, $fflags, $src, $useIO) = @_;

    local $/ = $ctx->{eol} if $ctx->{eolx} or $ctx->{eol_is_cr};

    if ($ctx->{useIO} = $useIO) {
        require IO::Handle;

        $ctx->{tmp} = undef;
        if ($ctx->{has_ahead} and defined $self->{_AHEAD}) {
            $ctx->{tmp} = $self->{_AHEAD};
            $ctx->{size} = length $ctx->{tmp};
            $ctx->{used} = 0;
        }
    } else {
        $ctx->{tmp} = $src;
        $ctx->{size} = length $src;
        $ctx->{used} = 0;
        $ctx->{utf8} = utf8::is_utf8($src);
    }
    if ($ctx->{has_error_input}) {
        $self->{_ERROR_INPUT} = undef;
        $ctx->{has_error_input} = 0;
    }

    my $result = $self->____parse($ctx, $src, $fields, $fflags);
    $self->{_RECNO} = ++($ctx->{recno});
    $self->{_EOF} = '';
    if ($ctx->{useIO}) {
        if (defined $ctx->{tmp} and $ctx->{used} < $ctx->{size} and $ctx->{has_ahead}) {
            $self->{_AHEAD} = substr($ctx->{tmp}, $ctx->{used}, $ctx->{size} - $ctx->{used});
        } else {
            $ctx->{has_ahead} = 0;
            if ($ctx->{useIO} & useIO_EOF) {
                $self->{_EOF} = 1;
            }
        }
        %{$ctx->{cache}} = %$ctx;

        if ($fflags) {
            if ($ctx->{keep_meta_info}) {
                $self->{_FFLAGS} = $fflags;
            } else {
                undef $fflags;
            }
        }
    }
    else {
        %{$ctx->{cache}} = %$ctx;
    }

    if ($result and $ctx->{types}) {
        my $len = @$fields;
        for(my $i = 0; $i <= $len && $i <= $ctx->{types_len}; $i++) {
            my $value = $fields->[$i];
            next unless defined $value;
            my $type = ord(substr($ctx->{types}, $i, 1));
            if ($type == IV) {
                $fields->[$i] = int($value);
            } elsif ($type == NV) {
                $fields->[$i] = $value + 0.0;
            }
        }
    }

    $result;
}

sub ____parse { # cx_Parse
    my ($self, $ctx, $src, $fields, $fflags) = @_;

    my ($quot, $sep, $esc, $eol) = @{$ctx}{qw/quo sep escape_char eol/};
    my $seenSomething =  0;
    my $waitingForField = 1;
    my $flag = 0;
    my ($value, $v_ref);
    $ctx->{fld_idx} = my $fnum = 0;

    my $re_str = join '|', map({quotemeta($_)} grep {defined $_ and $_ ne '' and $_ ne "\0"} $sep, $quot, $esc, $eol), "\015", "\012", "\x09", " ";
    my $re = qr/$re_str|[^\x09\x20-\x7E]|$/;
LOOP:
    while($self->__get_from_src($ctx, $src)) {
        while($ctx->{tmp} =~ /\G(.*?)($re)/gs) {
            my ($hit, $c) = ($1, $2);
            $ctx->{used} = pos($ctx->{tmp});
            if (!$waitingForField and $c eq '' and $hit ne '' and $ctx->{useIO} and !($ctx->{useIO} & useIO_EOF)) {
                $self->{_AHEAD} = $hit;
                $ctx->{has_ahead} = 1;
                last;
            }
            last if $seenSomething and $hit eq '' and $c eq ''; # EOF

            # new field
            if (!$v_ref) {
                if ($ctx->{is_bound}) {
                    $v_ref = $self->__bound_field($ctx, $fnum++, 0);
                } else {
                    $value = '';
                    $v_ref = \$value;
                }
                return unless $v_ref;
                $flag = 0;    
                $ctx->{fld_idx}++;
            }

            $seenSomething = 1;

            if (defined $hit and $hit ne '') {
                if ($waitingForField) {
                    $waitingForField = 0;
                }
                if ($hit =~ /[^\x09\x20-\x7E]/) {
                    $flag |= IS_BINARY;
                }
                $$v_ref .= $hit;
            }

RESTART:
            if (defined $c and defined $sep and $sep ne "\0" and $c eq $sep) {
                if ($waitingForField) {
                    # ,1,"foo, 3",,bar,
                    # ^           ^
                    if ($ctx->{blank_is_undef} or $ctx->{empty_is_undef}) {
                        $$v_ref = undef;
                    } else {
                        $$v_ref = "";
                    }
                    unless ($ctx->{is_bound}) {
                        push @$fields, $$v_ref;
                    }
                    $v_ref = undef;
                    if ($ctx->{keep_meta_info} and $fflags) {
                        push @$fflags, $flag;
                    }
                } elsif ($flag & IS_QUOTED) {
                    # ,1,"foo, 3",,bar,
                    #        ^
                    $$v_ref .= $c;
                } else {
                    # ,1,"foo, 3",,bar,
                    #   ^        ^    ^
                    $self->__push_value($ctx, $v_ref, $fields, $fflags, $flag);
                    $v_ref = undef;
                    $waitingForField = 1;
                }
            }
            elsif (defined $c and defined $quot and $quot ne "\0" and $c eq $quot) {
                if ($waitingForField) {
                    # ,1,"foo, 3",,bar,\r\n
                    #    ^
                    $flag |= IS_QUOTED;
                    $waitingForField = 0;
                    next;
                }
                if ($flag & IS_QUOTED) {
                    # ,1,"foo, 3",,bar,\r\n
                    #           ^
                    my $quoesc = 0;
                    my $c2 = $self->__get($ctx);

                    if ($ctx->{allow_whitespace}) {
                        # , 1 , "foo, 3" , , bar , \r\n
                        #               ^
                        while($self->__is_whitespace($ctx, $c2)) {
                            if ($ctx->{allow_loose_quotes} and !(defined $esc and $c2 eq $esc)) {
                                $$v_ref .= $c;
                                $c = $c2;
                            }
                            $c2 = $self->__get($ctx);
                        }
                    }

                    if (!defined $c2) { # EOF
                        # ,1,"foo, 3"
                        #            ^
                        $self->__push_value($ctx, $v_ref, $fields, $fflags, $flag);
                        return 1;
                    }

                    if (defined $c2 and defined $sep and $c2 eq $sep) {
                        # ,1,"foo, 3",,bar,\r\n
                        #            ^
                        $self->__push_value($ctx, $v_ref, $fields, $fflags, $flag);
                        $v_ref = undef;
                        $waitingForField = 1;
                        next;
                    }
                    if (defined $c2 and ($c2 eq "\012" or (defined $eol and $c2 eq $eol))) { # FIXME: EOLX
                        # ,1,"foo, 3",,"bar"\n
                        #                   ^
                        $self->__push_value($ctx, $v_ref, $fields, $fflags, $flag);
                        return 1;
                    }

                    if (defined $esc and $c eq $esc) {
                        $quoesc = 1;
                        if (defined $c2 and $c2 eq '0') {
                            # ,1,"foo, 3"056",,bar,\r\n
                            #            ^
                            $$v_ref .= "\0";
                            next;
                        }
                        if (defined $c2 and defined $quot and $c2 eq $quot) {
                            # ,1,"foo, 3""56",,bar,\r\n
                            #            ^
                            if ($ctx->{utf8}) {
                                $flag |= IS_BINARY;
                            }
                            $$v_ref .= $c2;
                            next;
                        }
                        if ($ctx->{allow_loose_escapes} and defined $c2 and $c2 ne "\015") {
                            # ,1,"foo, 3"56",,bar,\r\n
                            #            ^
                            $$v_ref .= $c;
                            $c = $c2;
                            goto RESTART;
                        }
                    }
                    if (defined $c2 and $c2 eq "\015") {
                        if ($ctx->{eol_is_cr}) {
                            # ,1,"foo, 3"\r
                            #            ^
                            $self->__push_value($ctx, $v_ref, $fields, $fflags, $flag);
                            return 1;
                        }

                        my $c3 = $self->__get($ctx);
                        if (defined $c3 and $c3 eq "\012") {
                            # ,1,"foo, 3"\r\n
                            #              ^
                            $self->__push_value($ctx, $v_ref, $fields, $fflags, $flag);
                            return 1;
                        }

                        if ($ctx->{useIO} and !$ctx->{eol_len} and $c3 !~ /[^\x09\x20-\x7E]/) {
                            # ,1,"foo\n 3",,"bar"\r
                            # baz,4
                            # ^
                            $self->__set_eol_is_cr($ctx);
                            $ctx->{used}--;
                            $ctx->{has_ahead} = 1;
                            $self->__push_value($ctx, $v_ref, $fields, $fflags, $flag);
                            return 1;
                        }

                        $self->__parse_error($ctx, $quoesc ? 2023 : 2010, $ctx->{used} - 2);
                        return;
                    }

                    if ($ctx->{allow_loose_quotes} and !$quoesc) {
                        # ,1,"foo, 3"456",,bar,\r\n
                        #            ^
                        $$v_ref .= $c;
                        $c = $c2;
                        goto RESTART;
                    }
                    # 1,"foo" ",3
                    #        ^
                    if ($quoesc) {
                        $ctx->{used}--;
                        $self->__error_inside_quotes($ctx, 2023);
                        return;
                    }
                    $self->__error_inside_quotes($ctx, 2011);
                    return;
                }
                # !waitingForField, !InsideQuotes
                if ($ctx->{allow_loose_quotes}) { # 1,foo "boo" d'uh,1
                    $flag |= IS_ERROR;
                    $$v_ref .= $c;
                } else {
                    $self->__error_inside_field($ctx, 2034);
                    return;
                }
            }
            elsif (defined $c and defined $esc and $esc ne "\0" and $c eq $esc) {
                # This means quote_char != escape_char
                if ($waitingForField) {
                    $waitingForField = 0;
                    if ($ctx->{allow_unquoted_escape}) {
                        # The escape character is the first character of an
                        # unquoted field
                        # ... get and store next character
                        my $c2 = $self->__get($ctx);
                        $$v_ref = "";

                        if (!defined $c2) { # EOF
                            $ctx->{used}--;
                            $self->__error_inside_field($ctx, 2035);
                            return;
                        }
                        if ($c2 eq '0') {
                            $$v_ref .= "\0";
                        }
                        elsif (
                            (defined $quot and $c2 eq $quot) or
                            (defined $sep and $c2 eq $sep) or
                            (defined $esc and $c2 eq $esc) or
                            $ctx->{allow_loose_escapes}
                        ) {
                            if ($ctx->{utf8}) {
                                $flag |= IS_BINARY;
                            }
                            $$v_ref .= $c2;
                        } else {
                            $self->__parse_inside_quotes($ctx, 2025);
                            return;
                        }
                    }
                }
                elsif ($flag & IS_QUOTED) {
                    my $c2 = $self->__get($ctx);
                    if (!defined $c2) { # EOF
                        $ctx->{used}--;
                        $self->__error_inside_quotes($ctx, 2024);
                        return;
                    }
                    if ($c2 eq '0') {
                        $$v_ref .= "\0";
                    }
                    elsif (
                        (defined $quot and $c2 eq $quot) or
                        (defined $sep and $c2 eq $sep) or
                        (defined $esc and $c2 eq $esc) or
                        $ctx->{allow_loose_escapes}
                    ) {
                        if ($ctx->{utf8}) {
                            $flag |= IS_BINARY;
                        }
                        $$v_ref .= $c2;
                    } else {
                        $ctx->{used}--;
                        $self->__error_inside_quotes($ctx, 2025);
                        return;
                    }
                }
                elsif ($v_ref) {
                    my $c2 = $self->__get($ctx);
                    if (!defined $c2) { # EOF
                        $ctx->{used}--;
                        $self->__error_inside_field($ctx, 2035);
                        return;
                    }
                    $$v_ref .= $c2;
                }
                else {
                    $self->__error_inside_field($ctx, 2036);
                    return;
                }
            }
            elsif (defined $c and ($c eq "\012" or $c eq '' or (defined $eol and $c eq $eol and $eol ne "\015"))) { # EOL
    EOLX:
                if ($waitingForField) {
                    # ,1,"foo, 3",,bar,
                    #                  ^
                    if ($ctx->{blank_is_undef} or $ctx->{empty_is_undef}) {
                        $$v_ref = undef;
                    } else {
                        $$v_ref = "";
                    }
                    unless ($ctx->{is_bound}) {
                        push @$fields, $$v_ref;
                    }
                    if ($ctx->{keep_meta_info} and $fflags) {
                        push @$fflags, $flag;
                    }
                    return 1;
                }
                if ($flag & IS_QUOTED) {
                    # ,1,"foo\n 3",,bar,
                    #        ^
                    $flag |= IS_BINARY;
                    unless ($ctx->{binary}) {
                        $self->__error_inside_quotes($ctx, 2021);
                        return;
                    }
                    $$v_ref .= $c;
                }
                elsif ($ctx->{verbatim}) {
                    # ,1,foo\n 3,,bar,
                    # This feature should be deprecated
                    $flag |= IS_BINARY;
                    unless ($ctx->{binary}) {
                        $self->__error_inside_field($ctx, 2030);
                        return;
                    }
                    $$v_ref .= $c unless $ctx->{eol} eq $c and $ctx->{useIO};
                }
                else {
                    # sep=,
                    #      ^
                    # FIXME or fix getline

                    # ,1,"foo\n 3",,bar
                    #                  ^
                    $self->__push_value($ctx, $v_ref, $fields, $fflags, $flag);
                    return 1;
                }
            }
            elsif (defined $c and $c eq "\015" and !$ctx->{verbatim}) {
                if ($waitingForField) {
                    $waitingForField = 0;
                    if ($ctx->{eol_is_cr}) {
                        # ,1,"foo\n 3",,bar,\r
                        #                   ^
                        $c = "\012";
                        goto RESTART;
                    }

                    my $c2 = $self->__get($ctx);
                    if (!defined $c2) { # EOF
                        # ,1,"foo\n 3",,bar,\r
                        #                     ^
                        $c = undef;
                        goto RESTART;
                    }
                    if ($c2 eq "\012") { # \r is not optional before EOLX!
                        # ,1,"foo\n 3",,bar,\r\n
                        #                     ^
                        $c = $c2;
                        goto RESTART;
                    }

                    if ($ctx->{useIO} and !$ctx->{eol_len} and $c2 !~ /[^\x09\x20-\x7E]/) {
                        # ,1,"foo\n 3",,bar,\r
                        # baz,4
                        # ^
                        $self->__set_eol_is_cr($ctx);
                        $ctx->{used}--;
                        $ctx->{has_ahead} = 1;
                        $self->__push_value($ctx, $v_ref, $fields, $fflags, $flag);
                        return 1;
                    }

                    # ,1,"foo\n 3",,bar,\r\t
                    #                     ^
                    $ctx->{used}--;
                    $self->__error_inside_field($ctx, 2031);
                    return;
                }
                if ($flag & IS_QUOTED) {
                    # ,1,"foo\r 3",,bar,\r\t
                    #        ^
                    $flag |= IS_BINARY;
                    unless ($ctx->{binary}) {
                        $self->__error_inside_quotes($ctx, 2022);
                        return;
                    }
                    $$v_ref .= $c;
                }
                else {
                    if ($ctx->{eol_is_cr}) {
                        # ,1,"foo\n 3",,bar\r
                        #                  ^
                        $self->__push_value($ctx, $v_ref, $fields, $fflags, $flag);
                        return 1;
                    }

                    my $c2 = $self->__get($ctx);
                    if (defined $c2 and $c2 eq "\012") { # \r is not optional before EOLX!
                        # ,1,"foo\n 3",,bar\r\n
                        #                    ^
                        $self->__push_value($ctx, $v_ref, $fields, $fflags, $flag);
                        return 1;
                    }

                    if ($ctx->{useIO} and !$ctx->{eol_len} and $c2 !~ /[^\x09\x20-\x7E]/) {
                        # ,1,"foo\n 3",,bar\r
                        # baz,4
                        # ^
                        $self->__set_eol_is_cr($ctx);
                        $ctx->{used}--;
                        $ctx->{has_ahead} = 1;
                        $self->__push_value($ctx, $v_ref, $fields, $fflags, $flag);
                        return 1;
                    }

                    # ,1,"foo\n 3",,bar\r\t
                    #                    ^
                    $self->__error_inside_field($ctx, 2032);
                    return;
                }
            }
            else {
                if ($ctx->{eolx} and $c eq $eol) {
                    $c = '';
                    goto EOLX;
                }

                if ($waitingForField) {
                    if ($ctx->{allow_whitespace} and $self->__is_whitespace($ctx, $c)) {
                        do {
                            $c = $self->__get($ctx);
                            last if !defined $c;
                        } while $self->__is_whitespace($ctx, $c);
                        goto RESTART;
                    }
                    $waitingForField = 0;
                    goto RESTART;
                }
                if ($flag & IS_QUOTED) {
                    if (!defined $c or $c =~ /[^\x09\x20-\x7E]/) {
                        $flag |= IS_BINARY;
                        unless ($ctx->{binary} or $ctx->{utf8}) {
                            $self->__error_inside_quotes($ctx, 2026);
                            return;
                        }
                    }
                    $$v_ref .= $c;
                } else {
                    if (!defined $c or $c =~ /[^\x09\x20-\x7E]/) {
                        $flag |= IS_BINARY;
                        unless ($ctx->{binary} or $ctx->{utf8}) {
                            $self->__error_inside_field($ctx, 2037);
                            return;
                        }
                    }
                    $$v_ref .= $c;
                }
            }
            last LOOP if $ctx->{useIO} and $ctx->{verbatim} and $ctx->{used} == $ctx->{size};
        }
    }

    if ($waitingForField) {
        if ($seenSomething or !$ctx->{useIO}) {
            # new field
            if (!$v_ref) {
                if ($ctx->{is_bound}) {
                    $v_ref = $self->__bound_field($ctx, $fnum++, 0);
                } else {
                    $value = '';
                    $v_ref = \$value;
                }
                return unless $v_ref;
                $flag = 0;
                $ctx->{fld_idx}++;
            }
            if ($ctx->{blank_is_undef} or $ctx->{empty_is_undef}) {
                $$v_ref = undef;
            } else {
                $$v_ref = "";
            }
            unless ($ctx->{is_bound}) {
                push @$fields, $$v_ref;
            }
            if ($ctx->{keep_meta_info} and $fflags) {
                push @$fflags, $flag;
            }
            return 1;
        }
        $self->SetDiag(2012);
        return;
    }

    if ($flag & IS_QUOTED) {
        $self->__error_inside_quotes($ctx, 2027);
        return;
    }

    if ($v_ref) {
        $self->__push_value($ctx, $v_ref, $fields, $fflags, $flag);
    }
    return 1;
}

sub __get_from_src {
    my ($self, $ctx, $src) = @_;
    return 1 if defined $ctx->{tmp} and $ctx->{used} <= 0;
    return 1 if $ctx->{used} < $ctx->{size};
    return unless $ctx->{useIO};
    my $res = $src->getline;
    if (defined $res) {
        if ($ctx->{has_ahead}) {
            $ctx->{tmp} = $self->{_AHEAD};
            $ctx->{tmp} .= $ctx->{eol} if $ctx->{eol_len};
            $ctx->{tmp} .= $res;
            $ctx->{ahead} = 0;
        } else {
            $ctx->{tmp} = $res;
        }
        $ctx->{used} = -1;
        $ctx->{size} = length $res;
        $ctx->{utf8} = 1 if utf8::is_utf8($res);
        pos($ctx->{tmp}) = 0;
        return 1 if $ctx->{size};
    }
    $ctx->{tmp} = '' unless defined $ctx->{tmp};
    $ctx->{useIO} |= useIO_EOF;
    return;
}

sub __set_eol_is_cr {
    my ($self, $ctx) = @_;
    $ctx->{eol} = "\015";
    $ctx->{eol_is_cr} = 1;
    $ctx->{eol_len} = 1;

    %{$ctx->{cache}} = %$ctx;
    $self->{eol} = $ctx->{eol};
}

sub __bound_field {
    my ($self, $ctx, $i, $keep) = @_;
    if ($i >= $ctx->{is_bound}) {
        $self->SetDiag(3006);
        return;
    }
    if (ref $ctx->{bound} eq 'ARRAY') {
        my $ref = $ctx->{bound}[$i];
        if (ref $ref) {
            if ($keep) {
                return $ref;
            }
            unless (Scalar::Util::readonly($$ref)) {
                $$ref = "";
                return $ref;
            }
        }
    }
    $self->SetDiag(3008);
    return;
}

sub __get {
    my ($self, $ctx) = @_;
    return unless defined $ctx->{used};
    return if $ctx->{used} >= $ctx->{size};
    my $c = substr($ctx->{tmp}, $ctx->{used}++, 1);
    pos($ctx->{tmp}) = $ctx->{used};
    $c;
}

sub __error_inside_quotes {
    my ($self, $ctx, $error) = @_;
    $self->__parse_error($ctx, $error, $ctx->{used} - 1);
}

sub __error_inside_field {
    my ($self, $ctx, $error) = @_;
    $self->__parse_error($ctx, $error, $ctx->{used} - 1);
}

sub __parse_error {
    my ($self, $ctx, $error, $pos) = @_;
    $self->{_ERROR_POS} = $pos;
    $self->{_ERROR_FLD} = $ctx->{fld_idx};
    $self->{_ERROR_INPUT} = $ctx->{tmp} if $ctx->{tmp};
    $self->SetDiag($error);
    return;
}

sub __is_whitespace {
    my ($self, $ctx, $c) = @_;
    return unless defined $c;
    return (
        (!defined $ctx->{sep} or $c ne $ctx->{sep}) &&
        (!defined $ctx->{quo} or $c ne $ctx->{quo}) &&
        (!defined $ctx->{escape_char} or $c ne $ctx->{escape_char}) &&
        ($c eq " " or $c eq "\t")
    );
}

sub __push_value { # AV_PUSH (part of)
    my ($self, $ctx, $v_ref, $fields, $fflags, $flag) = @_;
    utf8::encode($$v_ref) if $ctx->{utf8};
    if (
        (!defined $$v_ref or $$v_ref eq '') and
        ($ctx->{empty_is_undef} or (!($flag & IS_QUOTED) and $ctx->{blank_is_undef}))
    ) {
        $$v_ref = undef;
    } else {
        if ($ctx->{allow_whitespace} && !($flag & IS_QUOTED)) {
            $$v_ref =~ s/[ \t]+$//;
        }
        if ($flag & IS_BINARY and $ctx->{decode_utf8} and ($ctx->{utf8} || _is_valid_utf8($$v_ref))) {
            utf8::decode($$v_ref);
        }
    }
    unless ($ctx->{is_bound}) {
        push @$fields, $$v_ref;
    }
    if ($ctx->{keep_meta_info} and $fflags) {
        push @$fflags, $flag;
    }
}

sub getline {
    my ($self, $io) = @_;

    my (@fields, @fflags);
    my $res = $self->__parse(\@fields, \@fflags, $io, 1);
    $res ? \@fields : undef;
}

sub getline_all {
    my ( $self, $io, $offset, $len ) = @_;

    my $ctx = $self->_setup_ctx;

    my $tail = 0;
    my $n = 0;
    $offset ||= 0;

    if ( $offset < 0 ) {
        $tail = -$offset;
        $offset = -1;
    }

    my (@row, @list);
    while ($self->___parse($ctx, \@row, undef, $io, 1)) {
        $ctx = $self->_setup_ctx;

        if ($offset > 0) {
            $offset--;
            @row = ();
            next;
        }
        if ($n++ >= $tail and $tail) {
            shift @list;
            $n--;
        }
        if (($ctx->{has_hooks} || 0) & HOOK_AFTER_PARSE) {
            unless ($self->_hook(after_parse => \@row)) {
                @row = ();
                next;
            }
        }
        push @list, [@row];
        @row = ();

        last if defined $len && $n >= $len and $offset >= 0;   # exceeds limit size
    }

    if ( defined $len && $n > $len ) {
        @list = splice( @list, 0, $len);
    }

    return \@list;
}

sub _is_valid_utf8 {
    return ( $_[0] =~ /^(?:
         [\x00-\x7F]
        |[\xC2-\xDF][\x80-\xBF]
        |[\xE0][\xA0-\xBF][\x80-\xBF]
        |[\xE1-\xEC][\x80-\xBF][\x80-\xBF]
        |[\xED][\x80-\x9F][\x80-\xBF]
        |[\xEE-\xEF][\x80-\xBF][\x80-\xBF]
        |[\xF0][\x90-\xBF][\x80-\xBF][\x80-\xBF]
        |[\xF1-\xF3][\x80-\xBF][\x80-\xBF][\x80-\xBF]
        |[\xF4][\x80-\x8F][\x80-\xBF][\x80-\xBF]
    )+$/x )  ? 1 : 0;
}

################################################################################
# methods for errors
################################################################################

sub _set_error_diag {
    my ( $self, $error, $pos ) = @_;

    $self->SetDiag($error);

    if (defined $pos) {
        $_[0]->{_ERROR_POS} = $pos;
    }

    return;
}

sub error_input {
    my $self = shift;
    if ($self and (Scalar::Util::reftype($self) || '') eq 'HASH') {
        return $self->{_ERROR_INPUT};
    }
    return;
}

sub _sv_diag {
    my ($self, $error) = @_;
    bless [$error, $ERRORS->{$error}], 'Text::CSV::ErrorDiag';
}

sub _set_diag {
    my ($self, $ctx, $error) = @_;

    $last_error = $self->_sv_diag($error);
    $self->{_ERROR_DIAG} = $last_error;
    if ($error == 0) {
        $self->{_ERROR_POS} = 0;
        $self->{_ERROR_FLD} = 0;
        $self->{_ERROR_INPUT} = undef;
        $ctx->{has_error_input} = 0;
    }
    if ($error == 2012) { # EOF
        $self->{_EOF} = 1;
    }
    if ($ctx->{auto_diag}) {
        $self->error_diag;
    }
    return $last_error;
}

sub SetDiag {
    my ($self, $error, $errstr) = @_;
    my $res;
    if (ref $self) {
        my $ctx = $self->_setup_ctx;
        $res = $self->_set_diag($ctx, $error);

    } else {
        $res = $self->_sv_diag($error);
    }
    if (defined $errstr) {
        $res->[1] = $errstr;
    }
    $res;
}

################################################################################
package Text::CSV::ErrorDiag;

use strict;
use overload (
    '""' => \&stringify,
    '+'  => \&numeric,
    '-'  => \&numeric,
    '*'  => \&numeric,
    '/'  => \&numeric,
    fallback => 1,
);


sub numeric {
    my ($left, $right) = @_;
    return ref $left ? $left->[0] : $right->[0];
}


sub stringify {
    $_[0]->[1];
}
################################################################################
1;
__END__

=head1 NAME

Text::CSV_PP - Text::CSV_XS compatible pure-Perl module


=head1 SYNOPSIS

 use Text::CSV_PP;

 $csv = Text::CSV_PP->new();     # create a new object
 # If you want to handle non-ascii char.
 $csv = Text::CSV_PP->new({binary => 1});

 $status = $csv->combine(@columns);    # combine columns into a string
 $line   = $csv->string();             # get the combined string

 $status  = $csv->parse($line);        # parse a CSV string into fields
 @columns = $csv->fields();            # get the parsed fields

 $status       = $csv->status ();      # get the most recent status
 $bad_argument = $csv->error_input (); # get the most recent bad argument
 $diag         = $csv->error_diag ();  # if an error occurred, explains WHY

 $status = $csv->print ($io, $colref); # Write an array of fields
                                       # immediately to a file $io
 $colref = $csv->getline ($io);        # Read a line from file $io,
                                       # parse it and return an array
                                       # ref of fields
 $csv->column_names (@names);          # Set column names for getline_hr ()
 $ref = $csv->getline_hr ($io);        # getline (), but returns a hashref
 $eof = $csv->eof ();                  # Indicate if last parse or
                                       # getline () hit End Of File

 $csv->types(\@t_array);               # Set column types


=head1 DESCRIPTION

Text::CSV_PP has almost same functions of L<Text::CSV_XS> which
provides facilities for the composition and decomposition of
comma-separated values. As its name suggests, L<Text::CSV_XS>
is a XS module and Text::CSV_PP is a Pure Perl one.

=head1 VERSION

    1.33

This module is compatible with Text::CSV_XS B<0.99>.
(except for diag_verbose and allow_unquoted_escape)

=head2 Unicode (UTF8)

On parsing (both for C<getline ()> and C<parse ()>), if the source is
marked being UTF8, then parsing that source will mark all fields that
are marked binary will also be marked UTF8.

On combining (C<print ()> and C<combine ()>), if any of the combining
fields was marked UTF8, the resulting string will be marked UTF8.

=head1 FUNCTIONS

These methods are almost same as Text::CSV_XS.
Most of the documentation was shamelessly copied and replaced from Text::CSV_XS.

See to L<Text::CSV_XS>.

=head2 version ()

(Class method) Returns the current backend module version.
If you want the module version, you can use the C<VERSION> method,

 print Text::CSV->VERSION;      # This module version
 print Text::CSV->version;      # The version of the worker module
                                # same as Text::CSV->backend->version

=head2 new (\%attr)

(Class method) Returns a new instance of Text::CSV_XS. The objects
attributes are described by the (optional) hash ref C<\%attr>.
Currently the following attributes are available:

=over 4

=item eol

An end-of-line string to add to rows. C<undef> is replaced with an
empty string. The default is C<$\>. Common values for C<eol> are
C<"\012"> (Line Feed) or C<"\015\012"> (Carriage Return, Line Feed).
Cannot be longer than 7 (ASCII) characters.

If both C<$/> and C<eol> equal C<"\015">, parsing lines that end on
only a Carriage Return without Line Feed, will be C<parse>d correct.
Line endings, whether in C<$/> or C<eol>, other than C<undef>,
C<"\n">, C<"\r\n">, or C<"\r"> are not (yet) supported for parsing.

=item sep_char

The char used for separating fields, by default a comma. (C<,>).
Limited to a single-byte character, usually in the range from 0x20
(space) to 0x7e (tilde).

The separation character can not be equal to the quote character.
The separation character can not be equal to the escape character.

See also L<Text::CSV_XS/CAVEATS>

=item allow_whitespace

When this option is set to true, whitespace (TAB's and SPACE's)
surrounding the separation character is removed when parsing. If
either TAB or SPACE is one of the three major characters C<sep_char>,
C<quote_char>, or C<escape_char> it will not be considered whitespace.

So lines like:

  1 , "foo" , bar , 3 , zapp

are now correctly parsed, even though it violates the CSV specs.

Note that B<all> whitespace is stripped from start and end of each
field. That would make it more a I<feature> than a way to be able
to parse bad CSV lines, as

 1,   2.0,  3,   ape  , monkey

will now be parsed as

 ("1", "2.0", "3", "ape", "monkey")

even if the original line was perfectly sane CSV.

=item blank_is_undef

Under normal circumstances, CSV data makes no distinction between
quoted- and unquoted empty fields. They both end up in an empty
string field once read, so

 1,"",," ",2

is read as

 ("1", "", "", " ", "2")

When I<writing> CSV files with C<always_quote> set, the unquoted empty
field is the result of an undefined value. To make it possible to also
make this distinction when reading CSV data, the C<blank_is_undef> option
will cause unquoted empty fields to be set to undef, causing the above to
be parsed as

 ("1", "", undef, " ", "2")

=item empty_is_undef

Going one step further than C<blank_is_undef>, this attribute converts
all empty fields to undef, so

 1,"",," ",2

is read as

 (1, undef, undef, " ", 2)

Note that this only effects fields that are I<really> empty, not fields
that are empty after stripping allowed whitespace. YMMV.

=item quote_char

The char used for quoting fields containing blanks, by default the
double quote character (C<">). A value of undef suppresses
quote chars. (For simple cases only).
Limited to a single-byte character, usually in the range from 0x20
(space) to 0x7e (tilde).

The quote character can not be equal to the separation character.

=item allow_loose_quotes

By default, parsing fields that have C<quote_char> characters inside
an unquoted field, like

 1,foo "bar" baz,42

would result in a parse error. Though it is still bad practice to
allow this format, we cannot help there are some vendors that make
their applications spit out lines styled like this.

In case there is B<really> bad CSV data, like

 1,"foo "bar" baz",42

or

 1,""foo bar baz"",42

there is a way to get that parsed, and leave the quotes inside the quoted
field as-is. This can be achieved by setting C<allow_loose_quotes> B<AND>
making sure that the C<escape_char> is I<not> equal to C<quote_char>.

=item escape_char

The character used for escaping certain characters inside quoted fields.
Limited to a single-byte character, usually in the range from 0x20
(space) to 0x7e (tilde).

The C<escape_char> defaults to being the literal double-quote mark (C<">)
in other words, the same as the default C<quote_char>. This means that
doubling the quote mark in a field escapes it:

  "foo","bar","Escape ""quote mark"" with two ""quote marks""","baz"

If you change the default quote_char without changing the default
escape_char, the escape_char will still be the quote mark.  If instead
you want to escape the quote_char by doubling it, you will need to change
the escape_char to be the same as what you changed the quote_char to.

The escape character can not be equal to the separation character.

=item allow_loose_escapes

By default, parsing fields that have C<escape_char> characters that
escape characters that do not need to be escaped, like:

 my $csv = Text::CSV->new ({ escape_char => "\\" });
 $csv->parse (qq{1,"my bar\'s",baz,42});

would result in a parse error. Though it is still bad practice to
allow this format, this option enables you to treat all escape character
sequences equal.

=item binary

If this attribute is TRUE, you may use binary characters in quoted fields,
including line feeds, carriage returns and NULL bytes. (The latter must
be escaped as C<"0>.) By default this feature is off.

If a string is marked UTF8, binary will be turned on automatically when
binary characters other than CR or NL are encountered. Note that a simple
string like C<"\x{00a0}"> might still be binary, but not marked UTF8, so
setting C<{ binary =E<gt> 1 }> is still a wise option.

=item types

A set of column types; this attribute is immediately passed to the
I<types> method below. You must not set this attribute otherwise,
except for using the I<types> method. For details see the description
of the I<types> method below.

=item always_quote

By default the generated fields are quoted only, if they need to, for
example, if they contain the separator. If you set this attribute to
a TRUE value, then all defined fields will be quoted. This is typically
easier to handle in external applications.

=item quote_space

By default, a space in a field would trigger quotation. As no rule
exists this to be forced in CSV, nor any for the opposite, the default
is true for safety. You can exclude the space from this trigger by
setting this option to 0.

=item quote_null

By default, a NULL byte in a field would be escaped. This attribute
enables you to treat the NULL byte as a simple binary character in
binary mode (the C<{ binary =E<gt> 1 }> is set). The default is true.
You can prevent NULL escapes by setting this attribute to 0.

=item keep_meta_info

By default, the parsing of input lines is as simple and fast as
possible. However, some parsing information - like quotation of
the original field - is lost in that process. Set this flag to
true to be able to retrieve that information after parsing with
the methods C<meta_info ()>, C<is_quoted ()>, and C<is_binary ()>
described below.  Default is false.

=item verbatim

This is a quite controversial attribute to set, but it makes hard
things possible.

The basic thought behind this is to tell the parser that the normally
special characters newline (NL) and Carriage Return (CR) will not be
special when this flag is set, and be dealt with as being ordinary
binary characters. This will ease working with data with embedded
newlines.

When C<verbatim> is used with C<getline ()>, C<getline ()>
auto-chomp's every line.

Imagine a file format like

  M^^Hans^Janssen^Klas 2\n2A^Ja^11-06-2007#\r\n

where, the line ending is a very specific "#\r\n", and the sep_char
is a ^ (caret). None of the fields is quoted, but embedded binary
data is likely to be present. With the specific line ending, that
shouldn't be too hard to detect.

By default, Text::CSV' parse function however is instructed to only
know about "\n" and "\r" to be legal line endings, and so has to deal
with the embedded newline as a real end-of-line, so it can scan the next
line if binary is true, and the newline is inside a quoted field.
With this attribute however, we can tell parse () to parse the line
as if \n is just nothing more than a binary character.

For parse () this means that the parser has no idea about line ending
anymore, and getline () chomps line endings on reading.

=item auto_diag

Set to true will cause C<error_diag ()> to be automatically be called
in void context upon errors.

If set to a value greater than 1, it will die on errors instead of
warn.

To check future plans and a difference in XS version,
please see to L<Text::CSV_XS/auto_diag>.

=back

To sum it up,

 $csv = Text::CSV_PP->new ();

is equivalent to

 $csv = Text::CSV_PP->new ({
     quote_char          => '"',
     escape_char         => '"',
     sep_char            => ',',
     eol                 => $\,
     always_quote        => 0,
     quote_space         => 1,
     quote_null          => 1,
     binary              => 0,
     keep_meta_info      => 0,
     allow_loose_quotes  => 0,
     allow_loose_escapes => 0,
     allow_whitespace    => 0,
     blank_is_undef      => 0,
     empty_is_undef      => 0,
     verbatim            => 0,
     auto_diag           => 0,
     });


For all of the above mentioned flags, there is an accessor method
available where you can inquire for the current value, or change
the value

 my $quote = $csv->quote_char;
 $csv->binary (1);

It is unwise to change these settings halfway through writing CSV
data to a stream. If however, you want to create a new stream using
the available CSV object, there is no harm in changing them.

If the C<new ()> constructor call fails, it returns C<undef>, and makes
the fail reason available through the C<error_diag ()> method.

 $csv = Text::CSV->new ({ ecs_char => 1 }) or
     die "" . Text::CSV->error_diag ();

C<error_diag ()> will return a string like

 "INI - Unknown attribute 'ecs_char'"

=head2 print

 $status = $csv->print ($io, $colref);

Similar to C<combine () + string () + print>, but more efficient. It
expects an array ref as input (not an array!) and the resulting string is
not really created (XS version), but immediately written to the I<$io> object, typically
an IO handle or any other object that offers a I<print> method. Note, this
implies that the following is wrong in perl 5.005_xx and older:

 open FILE, ">", "whatever";
 $status = $csv->print (\*FILE, $colref);

as in perl 5.005 and older, the glob C<\*FILE> is not an object, thus it
doesn't have a print method. The solution is to use an IO::File object or
to hide the glob behind an IO::Wrap object. See L<IO::File> and L<IO::Wrap>
for details.

For performance reasons the print method doesn't create a result string.
(If its backend is PP version, result strings are created internally.)
In particular the I<$csv-E<gt>string ()>, I<$csv-E<gt>status ()>,
I<$csv->fields ()> and I<$csv-E<gt>error_input ()> methods are meaningless
after executing this method.

=head2 combine

 $status = $csv->combine (@columns);

This object function constructs a CSV string from the arguments, returning
success or failure.  Failure can result from lack of arguments or an argument
containing an invalid character.  Upon success, C<string ()> can be called to
retrieve the resultant CSV string.  Upon failure, the value returned by
C<string ()> is undefined and C<error_input ()> can be called to retrieve an
invalid argument.

=head2 string

 $line = $csv->string ();

This object function returns the input to C<parse ()> or the resultant CSV
string of C<combine ()>, whichever was called more recently.

=head2 getline

 $colref = $csv->getline ($io);

This is the counterpart to print, like parse is the counterpart to
combine: It reads a row from the IO object $io using $io->getline ()
and parses this row into an array ref. This array ref is returned
by the function or undef for failure.

When fields are bound with C<bind_columns ()>, the return value is a
reference to an empty list.

The I<$csv-E<gt>string ()>, I<$csv-E<gt>fields ()> and I<$csv-E<gt>status ()>
methods are meaningless, again.

=head2 getline_all

 $arrayref = $csv->getline_all ($io);
 $arrayref = $csv->getline_all ($io, $offset);
 $arrayref = $csv->getline_all ($io, $offset, $length);

This will return a reference to a list of C<getline ($io)> results.
In this call, C<keep_meta_info> is disabled. If C<$offset> is negative,
as with C<splice ()>, only the last C<abs ($offset)> records of C<$io>
are taken into consideration.

Given a CSV file with 10 lines:

 lines call
 ----- ---------------------------------------------------------
 0..9  $csv->getline_all ($io)         # all
 0..9  $csv->getline_all ($io,  0)     # all
 8..9  $csv->getline_all ($io,  8)     # start at 8
 -     $csv->getline_all ($io,  0,  0) # start at 0 first 0 rows
 0..4  $csv->getline_all ($io,  0,  5) # start at 0 first 5 rows
 4..5  $csv->getline_all ($io,  4,  2) # start at 4 first 2 rows
 8..9  $csv->getline_all ($io, -2)     # last 2 rows
 6..7  $csv->getline_all ($io, -4,  2) # first 2 of last  4 rows

=head2 parse

 $status = $csv->parse ($line);

This object function decomposes a CSV string into fields, returning
success or failure.  Failure can result from a lack of argument or the
given CSV string is improperly formatted.  Upon success, C<fields ()> can
be called to retrieve the decomposed fields .  Upon failure, the value
returned by C<fields ()> is undefined and C<error_input ()> can be called
to retrieve the invalid argument.

You may use the I<types ()> method for setting column types. See the
description below.

=head2 getline_hr

The C<getline_hr ()> and C<column_names ()> methods work together to allow
you to have rows returned as hashrefs. You must call C<column_names ()>
first to declare your column names.

 $csv->column_names (qw( code name price description ));
 $hr = $csv->getline_hr ($io);
 print "Price for $hr->{name} is $hr->{price} EUR\n";

C<getline_hr ()> will croak if called before C<column_names ()>.

=head2 getline_hr_all

 $arrayref = $csv->getline_hr_all ($io);

This will return a reference to a list of C<getline_hr ($io)> results.
In this call, C<keep_meta_info> is disabled.

C<getline_hr_all ()> will croak if called before C<column_names ()>.

=head2 column_names

Set the keys that will be used in the C<getline_hr ()> calls. If no keys
(column names) are passed, it'll return the current setting.

C<column_names ()> accepts a list of scalars (the column names) or a
single array_ref, so you can pass C<getline ()>

  $csv->column_names ($csv->getline ($io));

C<column_names ()> does B<no> checking on duplicates at all, which might
lead to unwanted results. Undefined entries will be replaced with the
string C<"\cAUNDEF\cA">, so

  $csv->column_names (undef, "", "name", "name");
  $hr = $csv->getline_hr ($io);

Will set C<$hr->{"\cAUNDEF\cA"}> to the 1st field, C<$hr->{""}> to the
2nd field, and C<$hr->{name}> to the 4th field, discarding the 3rd field.

C<column_names ()> croaks on invalid arguments.

=head2 print_hr

 $csv->print_hr ($io, $ref);

Provides an easy way to print a C<$ref> as fetched with L<getline_hr>
provided the column names are set with L<column_names>.

It is just a wrapper method with basic parameter checks over

 $csv->print ($io, [ map { $ref->{$_} } $csv->column_names ]);

=head2 bind_columns

Takes a list of references to scalars to store the fields fetched
C<getline ()> in. When you don't pass enough references to store the
fetched fields in, C<getline ()> will fail. If you pass more than there are
fields to return, the remaining references are left untouched.

  $csv->bind_columns (\$code, \$name, \$price, \$description);
  while ($csv->getline ($io)) {
      print "The price of a $name is \x{20ac} $price\n";
      }

=head2 eof

 $eof = $csv->eof ();

If C<parse ()> or C<getline ()> was used with an IO stream, this
method will return true (1) if the last call hit end of file, otherwise
it will return false (''). This is useful to see the difference between
a failure and end of file.

=head2 types

 $csv->types (\@tref);

This method is used to force that columns are of a given type. For
example, if you have an integer column, two double columns and a
string column, then you might do a

 $csv->types ([Text::CSV_PP::IV (),
               Text::CSV_PP::NV (),
               Text::CSV_PP::NV (),
               Text::CSV_PP::PV ()]);

Column types are used only for decoding columns, in other words
by the I<parse ()> and I<getline ()> methods.

You can unset column types by doing a

 $csv->types (undef);

or fetch the current type settings with

 $types = $csv->types ();

=over 4

=item IV

Set field type to integer.

=item NV

Set field type to numeric/float.

=item PV

Set field type to string.

=back

=head2 fields

 @columns = $csv->fields ();

This object function returns the input to C<combine ()> or the resultant
decomposed fields of successful C<parse ()>, whichever was called more
recently.

Note that the return value is undefined after using C<getline ()>, which
does not fill the data structures returned by C<parse ()>.

=head2 meta_info

 @flags = $csv->meta_info ();

This object function returns the flags of the input to C<combine ()> or
the flags of the resultant decomposed fields of C<parse ()>, whichever
was called more recently.

For each field, a meta_info field will hold flags that tell something about
the field returned by the C<fields ()> method or passed to the C<combine ()>
method. The flags are bitwise-or'd like:

=over 4

=item 0x0001

The field was quoted.

=item 0x0002

The field was binary.

=back

See the C<is_*** ()> methods below.

=head2 is_quoted

  my $quoted = $csv->is_quoted ($column_idx);

Where C<$column_idx> is the (zero-based) index of the column in the
last result of C<parse ()>.

This returns a true value if the data in the indicated column was
enclosed in C<quote_char> quotes. This might be important for data
where C<,20070108,> is to be treated as a numeric value, and where
C<,"20070108",> is explicitly marked as character string data.

This method is only valid when L</keep_meta_info> is set to a true value.

=head2 is_binary

  my $binary = $csv->is_binary ($column_idx);

Where C<$column_idx> is the (zero-based) index of the column in the
last result of C<parse ()>.

This returns a true value if the data in the indicated column
contained any byte in the range [\x00-\x08,\x10-\x1F,\x7F-\xFF]

This method is only valid when L</keep_meta_info> is set to a true value.

=head2 status

 $status = $csv->status ();

This object function returns a true value for success and false for failure,
for C<combine ()> or C<parse ()>, whichever was called more recently.

=head2 error_input

 $bad_argument = $csv->error_input ();

This object function returns the erroneous argument (if it exists) of
C<combine ()> or C<parse ()>, whichever was called more recently.

=head2 error_diag

 Text::CSV_PP->error_diag ();
 $csv->error_diag ();
 $error_code   = 0  + $csv->error_diag ();
 $error_str    = "" . $csv->error_diag ();
 ($cde, $str, $pos) = $csv->error_diag ();

If (and only if) an error occurred, this function returns the diagnostics
of that error.

If called in void context, it will print the internal error code and the
associated error message to STDERR.

If called in list context, it will return the error code and the error
message in that order. If the last error was from parsing, the third
value returned is the best guess at the location within the line that was
being parsed. It's value is 1-based.

Note: C<$pos> does not show the error point in many cases.
It is for conscience's sake.

If called in scalar context, it will return the diagnostics in a single
scalar, a-la $!. It will contain the error code in numeric context, and
the diagnostics message in string context.

To achieve this behavior with CSV_PP, the returned diagnostics is blessed object.

=head2 SetDiag

 $csv->SetDiag (0);

Use to reset the diagnostics if you are dealing with errors.

=head1 DIAGNOSTICS

If an error occurred, $csv->error_diag () can be used to get more information
on the cause of the failure. Note that for speed reasons, the internal value
is never cleared on success, so using the value returned by error_diag () in
normal cases - when no error occurred - may cause unexpected results.

Note: CSV_PP's diagnostics is different from CSV_XS's:

Text::CSV_XS parses csv strings by dividing one character
while Text::CSV_PP by using the regular expressions.
That difference makes the different cause of the failure.

Currently these errors are available:

=over 2

=item 1001 "sep_char is equal to quote_char or escape_char"

The separation character cannot be equal to either the quotation character
or the escape character, as that will invalidate all parsing rules.

=item 1002 "INI - allow_whitespace with escape_char or quote_char SP or TAB"

Using C<allow_whitespace> when either C<escape_char> or C<quote_char> is
equal to SPACE or TAB is too ambiguous to allow.

=item 1003 "INI - \r or \n in main attr not allowed"

Using default C<eol> characters in either C<sep_char>, C<quote_char>, or
C<escape_char> is not allowed.

=item 2010 "ECR - QUO char inside quotes followed by CR not part of EOL"

=item 2011 "ECR - Characters after end of quoted field"

=item 2021 "EIQ - NL char inside quotes, binary off"

=item 2022 "EIQ - CR char inside quotes, binary off"

=item 2025 "EIQ - Loose unescaped escape"

=item 2026 "EIQ - Binary character inside quoted field, binary off"

=item 2027 "EIQ - Quoted field not terminated"

=item 2030 "EIF - NL char inside unquoted verbatim, binary off"

=item 2031 "EIF - CR char is first char of field, not part of EOL",

=item 2032 "EIF - CR char inside unquoted, not part of EOL",

=item 2034 "EIF - Loose unescaped quote",

=item 2037 "EIF - Binary character in unquoted field, binary off",

=item 2110 "ECB - Binary character in Combine, binary off"

=item 2200 "EIO - print to IO failed. See errno"

=item 4002 "EIQ - Unescaped ESC in quoted field"

=item 4003 "EIF - ESC CR"

=item 4004 "EUF - "

=item 3001 "EHR - Unsupported syntax for column_names ()"

=item 3002 "EHR - getline_hr () called before column_names ()"

=item 3003 "EHR - bind_columns () and column_names () fields count mismatch"

=item 3004 "EHR - bind_columns () only accepts refs to scalars"

=item 3006 "EHR - bind_columns () did not pass enough refs for parsed fields"

=item 3007 "EHR - bind_columns needs refs to writable scalars"

=item 3008 "EHR - unexpected error in bound fields"

=back

=head1 AUTHOR

Makamaka Hannyaharamitu, E<lt>makamaka[at]cpan.orgE<gt>

Text::CSV_XS was written by E<lt>joe[at]ispsoft.deE<gt>
and maintained by E<lt>h.m.brand[at]xs4all.nlE<gt>.

Text::CSV was written by E<lt>alan[at]mfgrtl.comE<gt>.


=head1 COPYRIGHT AND LICENSE

Copyright 2005-2015 by Makamaka Hannyaharamitu, E<lt>makamaka[at]cpan.orgE<gt>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Text::CSV_XS>, L<Text::CSV>

I got many regexp bases from L<http://www.din.or.jp/~ohzaki/perl.htm>

=cut
