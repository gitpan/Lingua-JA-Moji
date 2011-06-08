#!/home/ben/software/install/bin/perl
use warnings;
use strict;
use Table::Readable qw/read_table/;
use ReadTranslations qw/read_translations_table get_lang_trans/;
use Template;
use utf8;

my %vars;
my $trans = read_translations_table ('moji-trans.txt');
my $tt = Template->new (ENCODING => 'UTF8', STRICT => 1);

my %names = (
    kana => {
        en => 'kana',
        ja => '仮名',
    },
    hiragana => {
        en => 'hiragana',
        ja => 'ひらがな',
    },
    hira => {
        en => 'hiragana',
        ja => 'ひらがな',
    },
    katakana => {
        en => 'katakana',
        ja => 'カタカナ',
    },
    kata => {
        en => 'katakana',
        ja => 'カタカナ',
    },
    circled => {
        en => 'circled katakana',
        ja => '丸付けカタカナ',
    },
    romaji => {
        en => 'romaji',
        ja => 'ローマ字',
    },
    hw => {
        en => 'halfwidth katakana',
        ja => '半角カタカナ',
    },
    ascii => {
        en => 'printable ASCII characters',
        ja => '半角英数字',
    },
    wide => {
        en => 'wide ASCII characters',
        ja => '全角英数字',
    },
    braille => {
        en => 'Japanese braille',
        ja => '点字',
    },
    morse => {
        en => 'Japanese morse code (wabun code)',
        ja => '和文モールス符号',
    },
    new => {
        en => 'Modern kanji',
        ja => '親字体',
    },
    new_kanji => {
        en => 'Modern kanji',
        ja => '親字体',
    },
    old => {
        en => 'Pre-1949 kanji',
        ja => '旧字体',
    },
    old_kanji => {
        en => 'Pre-1949 kanji',
        ja => '旧字体',
    },
);

my @functions = read_table ('moji-functions.txt');

for my $function (@functions) {
    next if $function->{class};
    $function->{eg} =~ s/^\s+|\s+$//g;
    if ($function->{out} && $function->{expect}) {
        my $out;
        my $commands =<<EOF;
use lib '../lib';
use Lingua::JA::Moji '$function->{name}';
my $function->{out};
$function->{eg}
\$out = $function->{out};
EOF
        eval $commands;
        if ($@) {
            die "Eval died with $@ during\n$commands\n";
        }
        if ($out ne $function->{expect}) {
            die "Bad value '$out': expected $function->{expect}";
        }
    }

    if ($function->{name} =~ /^([a-z_]+)2([a-z_]+)$/ &&
        $names{$1} && $names{$2}) {
        my ($from, $to) = ($1, $2);
        $function->{abstract}->{en} = "Convert $names{$from}{en} to $names{$to}{en}";
        $function->{abstract}->{ja} = "$names{$from}{ja}を$names{$to}{ja}に";
    }
    $function->{desc} = {};
    $function->{desc}{en} = $function->{"desc.en"};
    $function->{desc}{ja} = $function->{"desc.ja"};
}

$vars{functions} = \@functions;

my %outputs = (
    en => 'Moji.pod',
    ja => 'Moji-ja.pod',
);

my $verbose;

$vars{module} = 'Lingua::JA::Moji';

my $dir = '../lib/Lingua/JA';

for my $lang (qw/en ja/) {
    get_lang_trans ($trans, \%vars, $lang, $verbose);
    $vars{lang} = $lang;
    $tt->process ('Moji.pod.tmpl', \%vars, "$dir/$outputs{$lang}",
                  {binmode => 'utf8'})
        or die "" . $tt->error ();
}

