use inc::Module::Install;

name 'Lingua-JA-Moji',
all_from 'lib/Lingua/JA/Moji.pm',
requires ('File::ShareDir');
requires ('Convert::Moji' => 0.03);
build_requires 'Test::More';
install_share;
auto_install;
WriteAll;
