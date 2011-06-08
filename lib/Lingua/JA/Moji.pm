package Lingua::JA::Moji;

use warnings;
use strict;

our $VERSION = '0.06';

use Carp;
#use Lingua::JA::Moji::Convertor qw/load_convertor make_convertors/;
use Convert::Moji qw/make_regex length_one unambiguous/;
use utf8;
use File::ShareDir 'dist_file';

require Exporter;

our @ISA = qw(Exporter);

our @EXPORT_OK = qw/
                    kana2romaji
                    romaji2hiragana
                    romaji_styles
                    romaji2kana
                    is_voiced
                    is_romaji
                    hira2kata
                    kata2hira
                    kana2hw
                    hw2katakana
                    InHankakuKatakana
                    wide2ascii
                    ascii2wide
                    InWideAscii
                    kana2morse
                    is_kana
                    is_hiragana
                    kana2katakana
                    kana2braille
                    braille2kana
                    kana2circled
                    circled2kana
                    normalize_romaji
                    new2old_kanji
                    old2new_kanji
                    /;

our %EXPORT_TAGS = (
    'all' => \@EXPORT_OK,
);

# Load a specified convertor from the shared directory.

sub load_convertor
{
    my ($in, $out) = @_;
    my $filename = $in."2".$out.'.txt';
    my $file = dist_file ('Lingua-JA-Moji', $filename);
    if (! $file || ! -f $file) {
	croak "Could not find distribution file '$filename'";
    }
    return Convert::Moji::load_convertor ($file);
}

sub add_boilerplate
{
    my ($code, $name) = @_;
    $code =<<EOSUB;
sub convert_$name
{
    my (\$conv,\$input,\$convert_type) = \@_;
    $code
    return \$input;
}
EOSUB
$code .= "\\\&".__PACKAGE__."::convert_$name;";
#    print $code,"\n";
    return $code;
}

sub ambiguous_reverse
{
    my ($table) = @_;
    my %inverted;
    for (keys %$table) {
	my $val = $table->{$_};
#	print "Valu is $val\n";
	push @{$inverted{$val}}, $_;
#	print "key $_ stuff ",join (' ',@{$inverted{$val}}),"\n";
    }
    return \%inverted;
}

# Callback

sub split_match
{
    my ($conv, $input, $convert_type) = @_;
    $convert_type = "all" if (!$convert_type);
#    print "Convert type is '$convert_type'\n";
    my @input = split '', $input;
    my @output;
    for (@input) {
	my $in = $conv->{out2in}->{$_};
#	print "$_ $in\n";
	# No conversion defined.
	if (! $in) {
	    push @output, $_;
	    next;
	}
	# Unambigous case
	if (@{$in} == 1) {
	    push @output, $in->[0];
	    next;
	}
	if ($convert_type eq 'all') {
	    push @output, $in;
	} elsif ($convert_type eq 'first') {
	    push @output, $in->[0];
	} elsif ($convert_type eq 'random') {
	    my $pos = int rand @$in;
#	    print "RANDOM $pos\n";
	    push @output, $in->[$pos];
	}
    }
    return \@output;
}

sub make_convertors
{
    my $conv = {};
    my ($in, $out, $table) = @_;
    if (!$table) {
	$table = load_convertor ($in, $out);
    }
    $conv->{in2out} = $table;
    my @keys = keys %{$table};
    my @values = values %{$table};
    my $sub_in2out;
    my $sub_out2in;
    if (length_one(@keys)) {
	my $lhs = join '', @keys;

	# Improvement: one way tr/// for the ambiguous case lhs/rhs only.

	if (length_one(@values) && unambiguous($table)) {
#	    print "Not ambiguous\n";
	    # can use tr///;
	    my $rhs = join '', @values;
	    $sub_in2out = "\$input =~ tr/$lhs/$rhs/;";
	    $sub_out2in = "\$input =~ tr/$rhs/$lhs/;";
	}
        else {
	    $sub_in2out = "\$input =~ s/([$lhs])/\$conv->{in2out}->{\$1}/eg;";
	    my $rhs = make_regex (@values);
	    if (unambiguous($conv->{in2out})) {
		my %out2in_table = reverse %{$conv->{in2out}};
		$conv->{out2in} = \%out2in_table;
		$sub_out2in = "\$input =~ s/($rhs)/\$conv->{out2in}->{\$1}/eg;";
	    } else {
#		print "Unambiguous inversion is not possible with $in, $out.\n";
		$conv->{out2in} = ambiguous_reverse ($conv->{in2out});
		$sub_out2in = "\$input = \$conv->split_match (\$input, \$convert_type);";
	    }
	}
    }
    else {
	my $lhs = make_regex (@keys);
	$sub_in2out = "\$input =~ s/($lhs)/\$conv->{in2out}->{\$1}/eg;";
	my $rhs = make_regex (@values);
	if (unambiguous($conv->{in2out})) {
	    my %out2in_table = reverse %{$conv->{in2out}};
	    $conv->{out2in} = \%out2in_table;
	    $sub_out2in = "    \$input =~ s/($rhs)/\$conv->{out2in}->{\$1}/eg;";
	}
    }
    $sub_in2out = add_boilerplate ($sub_in2out, "${in}2$out");
    my $sub1 = eval $sub_in2out;
    $conv->{in2out_sub} = $sub1;
    if ($sub_out2in) {
	$sub_out2in = add_boilerplate ($sub_out2in, "${out}2$in");
	my $sub2 = eval $sub_out2in;
	if ($@) {
	    print "Errors are ",$@,"\n";
	    print "\$sub2 = ",$sub2,"\n";
	}
	$conv->{out2in_sub} = $sub2;
    }
    bless $conv;
    return $conv;
}

sub convert
{
    my ($conv, $input) = @_;
    return &{$conv->{in2out_sub}}($conv, $input);
}

sub invert
{
    my ($conv, $input, $convert_type) = @_;
    return &{$conv->{out2in_sub}}($conv, $input, $convert_type);
}


# Kana ordered by consonant. Adds bogus "q" gyou for small vowels and
# "x" gyou for youon (ya, yu, yo) to the usual ones.

my %行 = (
    a => [qw/ア イ ウ エ オ/],
    k => [qw/カ キ ク ケ コ/],
    g => [qw/ガ ギ グ ゲ ゴ/],
    s => [qw/サ シ ス セ ソ/],
    z => [qw/ザ ジ ズ ゼ ゾ/],
    t => [qw/タ チ ツ テ ト/],
    d => [qw/ダ ヂ ヅ デ ド/],
    n => [qw/ナ ニ ヌ ネ ノ/],
    h => [qw/ハ ヒ フ ヘ ホ/],
    b => [qw/バ ビ ブ ベ ボ/],
    p => [qw/パ ピ プ ペ ポ/],
    m => [qw/マ ミ ム メ モ/],
    y => [qw/ヤ    ユ    ヨ/],
    xy => [qw/ャ    ュ    ョ/],
    r => [qw/ラ リ ル レ ロ/],
    w => [qw/ワ ヰ    ヱ ヲ/],
    q => [qw/ァ ィ ゥ ェ ォ/],
    v => [qw/ヴ/],
);

# Kana => consonant mapping.

my %子音;

for my $consonant (keys %行) {
    for my $kana (@{$行{$consonant}}) {
        if ($consonant eq 'a') {
            $子音{$kana} = '';
        } else {
            $子音{$kana} = $consonant;
        }
    }
}

# Vowel => kana mapping.

my %段 = (a => [qw/ア カ ガ サ ザ タ ダ ナ ハ バ パ マ ヤ ラ ワ ャ ァ/],
	  i => [qw/イ キ ギ シ ジ チ ヂ ニ ヒ ビ ピ ミ リ ヰ ィ/],
	  u => [qw/ウ ク グ ス ズ ツ ヅ ヌ フ ブ プ ム ユ ル ュ ゥ ヴ/],
	  e => [qw/エ ケ ゲ セ ゼ テ デ ネ ヘ ベ ペ メ レ ヱ ェ/],
	  o => [qw/オ コ ゴ ソ ゾ ト ド ノ ホ ボ ポ モ ヨ ロ ヲ ョ ォ/]);

# Kana => vowel mapping

my %母音;

# List of kana with a certain vowel.

my %vowelclass;

for my $vowel (keys %段) {
    my @kana_list = @{$段{$vowel}};
    for my $kana (@kana_list) {
	$母音{$kana} = $vowel;
    }
    $vowelclass{$vowel} = join '', @kana_list;
}

# Kana gyou which can be preceded by a sokuon (small tsu).

# Added d to the list for ウッド BKB 2010-07-20 23:27:07
# Added z for "badge" etc.

my @takes_sokuon_行 = qw/s t k p d z/;
my @takes_sokuon = (map {@{$行{$_}}} @takes_sokuon_行);
my $takes_sokuon = join '', @takes_sokuon;

# N

# Kana gyou which need an apostrophe when preceded by an "n" kana.

my $need_apostrophe = join '', (map {@{$行{$_}}} qw/a y/);

# Gyou which turn an "n" into an "m" in some kinds of romanization

my $need_m = join '', (map {@{$行{$_}}} qw/p b m/);

# YOUON

# Small ya, yu, yo.

my $youon = join '', (@{$行{xy}});
my %youon = qw/a ャ u ュ o ョ ou ョ/;

# HEPBURN

# Hepburn irregular romanization

my %hepburn = qw/シ sh ツ ts チ ch ジ j ヅ z ヂ j フ f/;

# Hepburn map from vowel to list of kana with that vowel.

my %hep_vowel = (i => 'シチジヂ', u => 'ヅツフ');
my $hep_list = join '', keys %hepburn;

# Hepburn irregular romanization of ッチ as "tch".

my %hepburn_sokuon = qw/チ t/;
my $hep_sok_list = join '', keys %hepburn_sokuon;

# Hepburn variants for the youon case.

my %hepburn_youon = qw/シ sh チ ch ジ j ヂ j/;
my $is_hepburn_youon = join '', keys %hepburn_youon;

# Kunrei romanization

my %kunrei = qw/ヅ z ヂ z/;

my $kun_list = join '', keys %kunrei;

my %kunrei_youon = qw/ヂ z/;
my $is_kunrei_youon = join '', keys %kunrei_youon;

# LONG VOWELS

# Long vowels, another bugbear of Japanese romanization.

my @あいうえお = qw/a i u e o ou/;

# Various ways to display the long vowels.

my %長音表記;
@{$長音表記{circumflex}}{@あいうえお} = qw/â  î  û  ê  ô  ô/;
@{$長音表記{macron}}{@あいうえお}     = qw/ā  ī  ū  ē  ō  ō/;
@{$長音表記{wapuro}}{@あいうえお}     = qw/aa ii uu ee oo ou/;
@{$長音表記{passport}}{@あいうえお}   = qw/a  i  u  e  oh oh/;
@{$長音表記{none}}{@あいうえお}       = qw/a  i  u  e  o  o/;

sub kana2romaji
{
    # Parse the options

    my ($input, $options) = @_;
    if (! utf8::is_utf8 ($input)) {
        carp "Input is not flagged as unicode: conversion will fail.";
        return;
    }
    $input = kana2katakana ($input);
    $options = {} if ! $options;
    my $debug = $options->{debug};
    my $kunrei;
    my $hepburn;
    my $passport;
    if ($options->{style}) {
        my $style = $options->{style};
        $kunrei   = 1 if $style eq 'kunrei';
	$passport = 1 if $style eq 'passport';
	$hepburn  = 1 if $style eq 'hepburn';
        if (!$kunrei && !$passport && !$hepburn && $style ne "nihon") {
            die "Unknown romanization style $options->{style}";
        }
    }
    my $wapuro;
    $wapuro   = 1 if $options->{wapuro};
    my $use_m = 0;
    if ($hepburn || $passport) { $use_m = 1 }
    if (defined($options->{use_m})) { $use_m = $options->{use_m} }
    my $ve_type = 'circumflex'; # type of vowel extension to use.
    if ($hepburn) {
	$ve_type = 'macron';
    }
    if ($wapuro) {
        $ve_type = 'wapuro';
    }
    if ($passport) {
	$hepburn = 1;
	$ve_type = 'passport';
	$use_m = 1;
    }
    if ($options->{ve_type}) {
	$ve_type = $options->{ve_type};
    }
    unless ($長音表記{$ve_type}) {
	print STDERR "Warning: unrecognized long vowel type '$ve_type'\n";
	$ve_type = 'circumflex';
    }

    # Start of conversion

    # 撥音 (ん)
    $input =~ s/ン(?=[$need_apostrophe])/n\'/g;
    if ($use_m) {
	$input =~ s/ン(?=[$need_m])/m/g;
    }
    $input =~ s/ン/n/g;
    # 促音 (っ)
    if ($hepburn) {
	$input =~ s/ッ([$hep_sok_list])/$hepburn_sokuon{$1}$1/g;
    }
    $input =~ s/ッ([$takes_sokuon])/$子音{$1}$1/g;
    if ($debug) {
        print "* $input\n";
    }
    # 長音 (ー)
    for my $vowel (@あいうえお) {
	my $ve = $長音表記{$ve_type}->{$vowel};
	my $vowelclass;
	my $vowel_kana;
	if ($vowel eq 'ou') {
	    $vowelclass = $vowelclass{o};
	    $vowel_kana = 'ウ';
	} else {
	    $vowelclass = $vowelclass{$vowel};
	    $vowel_kana = $段{$vowel}->[0];
	}
	# 長音 (ー) + 拗音 (きょ)
	my $y = $youon{$vowel};
#        if ($debug) { print "Before youon: $input\n"; }
	if ($y) {
	    if ($hepburn) {
		$input =~ s/([$is_hepburn_youon])${y}[ー$vowel_kana]/$hepburn_youon{$1}$ve/g;
	    }
	    $input =~ s/([$vowelclass{i}])${y}[ー$vowel_kana]/$子音{$1}y$ve/g;
	}
#        if ($debug) { print "After youon: $input\n"; }
	if ($hepburn && $hep_vowel{$vowel}) {
	    $input =~ s/([$hep_vowel{$vowel}])[ー$vowel_kana]/$hepburn{$1}$ve/g;
	}
	$input =~ s/${vowel_kana}[ー$vowel_kana]/$ve/g;
#        if ($debug) { print "Before vowelclass: $input\n"; }
	$input =~ s/([$vowelclass])[ー$vowel_kana]/$子音{$1}$ve/g; 
#        if ($debug) { print "After vowelclass: $input\n"; }
    }
    if ($debug) {
        print "** $input\n";
    }
    # 拗音 (きょ)
    if ($hepburn) {
	$input =~ s/([$is_hepburn_youon])([$youon])/$hepburn_youon{$1}$母音{$2}/g;
    }
    elsif ($kunrei) {
	$input =~ s/([$is_kunrei_youon])([$youon])/$kunrei_youon{$1}y$母音{$2}/g;
    }
    $input =~ s/([$vowelclass{i}])([$youon])/$子音{$1}y$母音{$2}/g;
    if ($debug) {
        print "*** $input\n";
    }
    # その他
    $input =~ s/([アイウエオヲ])/$母音{$1}/g;
    $input =~ s/([ァィゥェォ])/q$母音{$1}/g;
    if ($debug) {
        print "**** $input\n";
    }
    if ($hepburn) {
	$input =~ s/([$hep_list])/$hepburn{$1}$母音{$1}/g;
    }
    elsif ($kunrei) {
	$input =~ s/([$kun_list])/$kunrei{$1}$母音{$1}/g;
    }
    $input =~ s/([カ-ヂツ-ヱヴ])/$子音{$1}$母音{$1}/g;
    $input =~ s/q([aiueo])/x$1/g;
    return $input;
}

sub romaji2hiragana
{
    my ($input, $options) = @_;
    if (! $options) {
        $options = {};
    }
    my $katakana = romaji2kana ($input, {wapuro => 1, %$options});
    #print "katakana = $katakana\n";
    return kata2hira ($katakana);
}

sub romaji_styles
{
    my ($check) = @_;
        my @styles = 
            (
         {
          abbrev    => "hepburn",
          full_name => "Hepburn",
      },
         {
          abbrev    => 'nihon',
          full_name => 'Nihon-shiki',
      },
         {
          abbrev    => 'kunrei',
          full_name => 'Kunrei-shiki',
      }
         );
    if (! defined ($check)) {
        return (@styles);
    } else {
        for my $style (@styles) {
            if ($check eq $style->{abbrev}) {
                return 1;
            }
        }
        return;
    }
}

# Check whether this vowel style is allowed.

sub romaji_vowel_styles
{
    my ($check) = @_;
    my @styles = (
    {
        abbrev    => "macron",
        full_name => "Macron",
    },
    {
        abbrev    => 'circumflex',
        full_name => 'Circumflex',
    },
    {
        abbrev    => 'wapuro',
        full_name => 'Wapuro',
    },
    {
        abbrev    => 'passport',
        full_name => 'Passport',
    },
    {
        abbrev    => 'none',
        full_name => "Do not indicate",
    },
    );
    if (! defined ($check)) {
        return (@styles);
    } else {
        for (@styles) {
            if ($check eq $_->{abbrev}) {
                return 1;
            }
            return;
        }
    }

}

my $romaji2katakana;
my $romaji_regex;

my %longvowels;
@longvowels{qw/â  î  û  ê  ô/}  = qw/aー iー uー eー oー/;
@longvowels{qw/ā  ī  ū  ē  ō/}  = qw/aー iー uー eー oー/;
my $longvowels = join '|', sort {length($a)<=>length($b)} keys %longvowels;

sub romaji2kana
{
    if (! defined $romaji2katakana) {
	$romaji2katakana = load_convertor ('romaji','katakana');
	$romaji_regex = make_regex (keys %$romaji2katakana);
    }
    my ($input, $options) = @_;
    $input = lc $input;
    #print "input = $input\n";
    # Deal with long vowels
    $input =~ s/($longvowels)/$longvowels{$1}/g;
    if (!$options || !$options->{wapuro}) {
        # Doubled vowels to chouon
        $input =~ s/([aiueo])\1/$1ー/g;
    }
    # Deal with double consonants
    # danna -> だんな
    $input =~ s/n(?=n[aiueo])/ン/g;
    # shimbun -> しんぶん
    $input =~ s/m(?=[pb]y?[aiueo])/ン/g;
    # tcha, ccha -> っちゃ
    $input =~ s/[ct](?=(ch|t)[aiueo])/ッ/g;
    # kkya -> っきゃ etc.
    $input =~ s/([ksthmrgzdbp])(?=\1y?[aiueo])/ッ/g;
    # ssha -> っしゃ
    $input =~ s/([s])(?=\1h[aiueo])/ッ/g;
    # oh{consonant} -> oo
    $input =~ s/oh(?=[ksthmrgzdbp])/オオ/g;
    # Substitute all the kana.
    $input =~ s/($romaji_regex)/$romaji2katakana->{$1}/g;
    return $input;
}

sub is_voiced
{
    my ($sound) = @_;
    if (is_kana ($sound)) {
        $sound = kana2romaji ($sound);
    }
    elsif (my $romaji = is_romaji ($sound)) {
        # Normalize to nihon shiki so that we don't have to worry
        # about ch, j, ts, etc. at the start of the sound.
        $sound = $romaji;
    }
    if ($sound =~ /^[aiueogzbpmnry]/) {
        return 1;
    } else {
        return;
    }
}

sub is_romaji
{
    my ($romaji) = @_;
    if ($romaji =~ /[^\sa-zāīūēōâîûêô'-]/i) {
        return;
    }
    my $kana = romaji2kana ($romaji, {wapuro => 1});
#    print "$kana\n";
    if ($kana =~ /^[ア-ンー\s]+$/) {
#    print kana2romaji ($kana, {wapuro => 1}), "\n";
        return kana2romaji ($kana, {wapuro => 1});
    }
    return;
}

sub hira2kata
{
    my (@input) = @_;
    for (@input) {tr/ぁ-ん/ァ-ン/}
    return wantarray ? @input : "@input";
}

sub kata2hira
{
    my (@input) = @_;
    for (@input) {tr/ァ-ン/ぁ-ん/}
    return wantarray ? @input : "@input";
}

# Make the list of dakuon stuff.

sub make_dak_list
{
#    my @gyou = @_;
    my @dak_list;
    for (@_) {
	push @dak_list, @{$行{$_}};
	push @dak_list, hira2kata (@{$行{$_}});
    }
    return @dak_list;
}

my $strip_daku;

sub load_strip_daku
{
    if (!$strip_daku) {
	my %濁点;
	@濁点{(make_dak_list (qw/g d z b/))} = 
	    map {$_."゛"} (make_dak_list (qw/k t s h/));
	@濁点{(make_dak_list ('p'))} = map {$_."゜"} (make_dak_list ('h'));
	my $濁点 = join '', keys %濁点;
	$strip_daku = make_convertors ("ten_joined", "ten_split", \%濁点);
    }
}

my %濁点;
@濁点{(make_dak_list (qw/g d z b/))} = 
    map {$_."゛"} (make_dak_list (qw/k t s h/));
@濁点{(make_dak_list ('p'))} = map {$_."゜"} (make_dak_list ('h'));


#my %kata2hw = reverse %{$hwtable};
#my $kata2hw = \%kata2hw;

#my $hwregex = join '|',sort { length($b) <=> length($a) } keys %{$hwtable};
#print $hwregex,"\n";

sub kana2hw2
{
    my $conv = Convert::Moji->new (["oneway", "tr", "あ-ん", "ア-ン"],
				   ["file",
				    getdistfile ("katakana2hw_katakana")]);
    return $conv;
}

my $kata2hw;

sub kana2hw
{
   my ($input) = @_;
   $input = hira2kata ($input);
   if (!$kata2hw) {
       $kata2hw = make_convertors ('katakana','hw_katakana');
   }
   return $kata2hw->convert ($input);
}

sub hw2katakana
{
    my ($input) = @_;
   if (!$kata2hw) {
       $kata2hw = make_convertors ('katakana','hw_katakana');
   }
    return $kata2hw->invert ($input);
}

sub InHankakuKatakana
{
    return <<'END';
+utf8::Katakana
&utf8::InHalfwidthAndFullwidthForms
END
}

sub wide2ascii
{
    my ($input) = @_;
    $input =~ tr/\x{3000}\x{FF01}-\x{FF5E}/ -~/;
    return $input;
}

sub ascii2wide
{
    my ($input) = @_;
    $input =~ tr/ -~/\x{3000}\x{FF01}-\x{FF5E}/;
    return $input;
}

sub InWideAscii
{
    return <<'END';
FF01 FF5E
3000
END
}

my $kana2morse;

sub load_kana2morse
{
    if (!$kana2morse) {
	$kana2morse = make_convertors ('katakana', 'morse');
    }
}

sub kana2morse
{
    my ($input) = @_;
    load_kana2morse;
    $input = hira2kata ($input);
    $input =~ tr/ァィゥェォャュョ/アイウエオヤユヨ/;
    load_strip_daku;
    $input = $strip_daku->convert ($input);
    $input = join ' ', (split '', $input);
    $input = $kana2morse->convert ($input);
    return $input;
}


sub getdistfile
{
    my ($filename) = @_;
    my $file = dist_file ('Lingua-JA-Moji', $filename.".txt");
    return $file;
}

sub sin {my @y=split ''; join ' ',@y}
sub sout {my @y=split ' '; join '',@y}

sub kana2morse2
{
    my $file = getdistfile ('katakana2morse');
    my $conv = Convert::Moji->new (["oneway","tr", "あ-ん", "ア-ン"],
				   ["oneway","tr", "ァィゥェォャュョ", "アイウエオヤユヨ"],
				   ["table", \%濁点],
				   ["code", \&sin , \&sout],
				   ["file", $file],
			       );
    return $conv;
}

sub morse2kana
{
    my ($input) = @_;
    load_kana2morse;
    my @input = split ' ',$input;
    for (@input) {
	$_ = $kana2morse->invert ($_);
    }
    $input = join '',@input;
    $input = $strip_daku->invert ($input);
    return $input;
}

my $kana2braille;

sub load_kana2braille
{
    if (!$kana2braille) {
	$kana2braille = Lingua::JA::Moji::make_convertors ('katakana', 'braille');
    }
}

my %nippon2kana;

for my $k (keys %行) {
    for my $ar (@{$行{$k}}) {
	my $vowel = $母音{$ar};
	my $nippon = $k.$vowel;
	$nippon2kana{$nippon} = $ar;
# 	print "$nippon $ar\n";
    }
}

sub is_kana
{
    my ($may_be_kana) = @_;
    if ($may_be_kana =~ /^[あ-んア-ン]+$/) {
        return 1;
    }
    return;
}

sub is_hiragana
{
    my ($may_be_kana) = @_;
    if ($may_be_kana =~ /^[あ-ん]+$/) {
        return 1;
    }
    return;
}

sub kana2katakana
{
    my ($input) = @_;
    $input = hira2kata($input);
    if ($input =~ /\p{InHankakuKatakana}/) {
	$input = hw2katakana($input);
    }
    return $input;
}

sub brailleon
{
    s/(.)゛([ャュョ])/'⠘'.$nippon2kana{$子音{$1}.$母音{$2}}/eg;
    s/(.)゜([ャュョ])/'⠨'.$nippon2kana{$子音{$1}.$母音{$2}}/eg;
    s/(.)([ャュョ])/'⠈'.$nippon2kana{$子音{$1}.$母音{$2}}/eg;
    s/([$vowelclass{o}])ウ/$1ー/g;
    return $_;
}

sub brailleback
{
    s/⠘(.)/$nippon2kana{$子音{$1}.'i'}.'゛'.$youon{$母音{$1}}/eg;
    s/⠨(.)/$nippon2kana{$子音{$1}.'i'}.'゜'.$youon{$母音{$1}}/eg;
    s/⠈(.)/$nippon2kana{$子音{$1}.'i'}.$youon{$母音{$1}}/eg;
    return $_;
}

sub brailletrans {s/(.)([⠐⠠])/$2$1/g;return $_}
sub brailletransinv {s/([⠐⠠])(.)/$2$1/g;return $_}

sub kana2braille2
{
    my $conv = Convert::Moji->new (["table", \%濁点],
				   ["code", \&brailleon,\&brailleback],
				   ["file", getdistfile ("katakana2braille")],
				   ["code", \&brailletrans,\&brailletransinv],
			       );
    return $conv;
}


sub kana2braille
{
    my ($input) = @_;
    load_kana2braille;
    $input = kana2katakana ($input);
    load_strip_daku;
    $input = $strip_daku->convert ($input);
    $input =~ s/(.)゛([ャュョ])/'⠘'.$nippon2kana{$子音{$1}.$母音{$2}}/eg;
    $input =~ s/(.)゜([ャュョ])/'⠨'.$nippon2kana{$子音{$1}.$母音{$2}}/eg;
    $input =~ s/(.)([ャュョ])/'⠈'.$nippon2kana{$子音{$1}.$母音{$2}}/eg;
    $input =~ s/([$vowelclass{o}])ウ/$1ー/g;
#    print $input,"\n";
    $input = $kana2braille->convert ($input);
    $input =~ s/(.)([⠐⠠])/$2$1/g;
#    print $input,"\n";
    return $input;
}

sub braille2kana
{
    my ($input) = @_;
    load_kana2braille;
    $input =~ s/([⠐⠠])(.)/$2$1/g;
    $input = $kana2braille->invert ($input);
    $input =~ s/⠘(.)/$nippon2kana{$子音{$1}.'i'}.'゛'.$youon{$母音{$1}}/eg;
    $input =~ s/⠨(.)/$nippon2kana{$子音{$1}.'i'}.'゜'.$youon{$母音{$1}}/eg;
    $input =~ s/⠈(.)/$nippon2kana{$子音{$1}.'i'}.$youon{$母音{$1}}/eg;
    $input = $strip_daku->invert ($input);
    return $input;
}

my $circled_conv;

sub load_circled_conv
{
    if (!$circled_conv) {
	$circled_conv = make_convertors ("katakana", "circled");

    }
}

sub kana2circled
{
    my ($input) = @_;
    $input = kana2katakana($input);
    load_strip_daku;
    $input = $strip_daku->convert($input);
    load_circled_conv;
    $input = $circled_conv->convert ($input);
    return $input;
}

sub circled2kana
{
    my ($input) = @_;
    load_circled_conv;
    load_strip_daku;
    $input = $circled_conv->invert ($input);
    $input = $strip_daku->invert ($input);
    return $input;
}

sub normalize_romaji
{
    my ($romaji) = @_;
    my $kana = romaji2kana ($romaji, {ve_type => 'wapuro'});
    $kana =~ s/[っッ]/xtu/g;
    my $romaji_out = kana2romaji ($kana, {ve_type => 'wapuro'});
}

my $new2old_kanji;

sub load_new2old_kanji
{
    $new2old_kanji = Convert::Moji->new (
        ['file', getdistfile ('new_kanji2old_kanji')],
    );
}

sub new2old_kanji
{
    my ($new_kanji) = @_;
    if (! $new2old_kanji) {
        load_new2old_kanji ();
    }
    my $old_kanji = $new2old_kanji->convert ($new_kanji);
    return $old_kanji;
}

sub old2new_kanji
{
    my ($old_kanji) = @_;
    if (! $new2old_kanji) {
        load_new2old_kanji ();
    }
    my $new_kanji = $new2old_kanji->invert ($old_kanji);
    return $new_kanji;
}

1; 
