package Buyo::Logger {
    use strictures;
    use utf8;
    use English;

    use feature ":5.26";
    use feature 'lexical_subs';
    use feature 'signatures';
    use feature 'switch';
    no warnings "experimental::signatures";
    no warnings "experimental::smartmatch";

    use boolean;
    use CGI::Carp qw(carp croak fatalsToBrowser);
    use JSON qw();
    use Data::Dumper;
    use Return::Type;
    use Types::Standard -all;
    use Try::Tiny qw(try catch);
    use Throw qw(throw classify);

    use FindBin;
    use lib "$FindBin::Bin/..";
    use Buyo::Constants;

    use Value::TypeCheck qw(type_check);

    sub new :ReturnType(Object) ($class, $flags) {
        type_check($class, Str);
        type_check($flags, HashRef);

        my $self = {};

        bless($self, $class);
        return $self;
    }

    our sub err_log :ReturnType(Void) ($self, $msg) {
        type_check($msg, Str);

        return print {*STDERR} "$msg\n";
    }

    our sub error_msg :ReturnType(Void) ($self, $error_struct, $class) {
        type_check($error_struct, HashRef);
        type_check($class, Str);

        say STDERR "Error struct dump: ". Dumper($error_struct);

        my $error   = $error_struct->{'error'};
        my $info    = $error_struct->{'info'};
        my $log_msg = $error_struct->{'log_message'};
        my $type    = $error_struct->{'type'};
        my $err_str = $error_struct->{'error_string'};

        my $msg = "== ERROR ==: $error: $class\n" .
                  "== ERROR ==: $info\n" .
                  "== ERROR ==: $log_msg\n" .
                  "== ERROR ==: error type: $type, $err_str\n";
        croak($msg);
    }

    true;
}
