use strict;
use warnings;
use ExtUtils::MakeMaker;

# Normalize version strings like 6.30_02 to 6.3002,
# so that we can do numerical comparisons on it.
my $eumm_version = $ExtUtils::MakeMaker::VERSION;
$eumm_version =~ s/_//;

WriteMakefile(
    NAME                => 'Buyo',
    AUTHOR              => q{Gary Greene <webmaster at jafax dot org>},
    VERSION_FROM        => 'lib/Buyo.pm',
    ABSTRACT            => 'The Buyo Content Management Web Application',
    ($eumm_version >= 6.3001
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'YAML'       => 0,
        'Dancer2'     => 0.200002,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Buyo-*' },
);
