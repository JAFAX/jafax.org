package Identity::Constants {
    use strictures;
    use utf8;
    use English;

    use feature ":5.30";
    use feature 'lexical_subs';
    use feature 'signatures';
    use feature 'switch';
    no warnings "experimental::signatures";
    no warnings "experimental::smartmatch";

    use boolean;
    use base qw(Exporter);

    our $VERSION = '0.0.2';

    BEGIN {
    use Exporter   ();

        my (@EXPORT, @EXPORT_OK, %EXPORT_TAGS);

        # set the version for version checking
        @EXPORT      = qw();
        %EXPORT_TAGS = (
            All => [
            ]
        );     # eg: TAG => [ qw!name1 name2! ],

        # your exported package globals go here,
        # as well as any optionally exported functions
        @EXPORT_OK   = qw();
    }

    our @EXPORT_OK;

    END {}

    true;
}