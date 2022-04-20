package File::IO {
    use strictures;
    use utf8;
    use English;

    use feature ":5.26";
    no warnings "experimental::signatures";
    no warnings "experimental::smartmatch";
    use feature "lexical_subs";
    use feature "signatures";
    use feature "switch";

    use boolean;
    use Return::Type;
    use Types::Standard -all;
    use Term::ANSIColor;
    use Throw qw(throw classify);
    use Try::Tiny qw(try catch);

    use FindBin;
    use lib "$FindBin::Bin/../lib";

    use Sys::Error 0.0.2;

    my $error = undef;

    my $VERSION = "0.0.2";

    $Throw::level = 1;

    our sub new :ReturnType(Object) ($class, $flags = undef) {
        my $self = {};

        $error = Sys::Error->new();

        bless($self, $class);
        return $self;
    }

    my sub mode_translate :ReturnType(Str) ($self, $mode_string) {
        my $mode = undef;
        given ($mode_string) {
            when ('r') {
                $mode = '<';
            }
            when ('rw') {
                $mode = '+<';
            }
            when ('tw') {
                $mode = '>';
            }
            when ('crw') {
                $mode = '+>';
            }
            when ('a') {
                $mode = '>>';
            }
            default {
                $mode = '<';
            }
        }
        return $mode;
    }

    our sub open :ReturnType(filehandle, Hash) ($self, $mode_string, $path) {
        my $fh = undef;
        my $mode = mode_translate($self, $mode_string);
        try {
            open($fh, $mode, $path) or throw(
                "Cannot open file", {
                    'trace' => 3,
                    'type'  => $error->error_string(int $OS_ERROR)->{'symbol'},
                    'info'  => "Attempted to open $path",
                    'code'  => int $OS_ERROR,
                    'msg'   => $error->error_string(int $OS_ERROR)->{'string'}
                }
            );
        } catch {
            classify(
                $ARG, {
                    default => sub {
                        # rethrow as a fatal
                        $error->err_msg($ARG, $error->error_string($ARG->{'string'}));
                        throw $ARG->{'error'}, {
                            'trace' => 3,
                            'type'  => $ARG->{'type'},
                            'code'  => $ARG->{'code'},
                            'msg'   => $ARG->{'msg'}
                        };
                    }
                }
            );
        };

        return ($fh, 
            {
                'type' => 'OK',
                'code' => 0,
                'msg'  => 'Successful operation'
            }
        );
    }

    our sub read :ReturnType(Str, Hash) ($self, $fh, $length) {
        my $content = undef;
        try {
            read($fh, $content, $length);
            if ($OS_ERROR != 0) {
                throw "Cannot read from filehandle", {
                    'trace' => 3,
                    'type'  => $error->error_string($OS_ERROR)->{'symbol'},
                    'code'  => $OS_ERROR,
                    'msg'   => $error->error_string($OS_ERROR)->{'string'}
                };
            }
        } catch {
            classify(
                $ARG, {
                    default => sub {
                        # rethrow as fatal
                        $error->err_msg($ARG, $error->error_string($ARG->{'string'}));
                        throw $ARG->{'error'}, {
                            'trace' => 3,
                            'type'  => $ARG->{'type'},
                            'code'  => $ARG->{'code'},
                            'msg'   => $ARG->{'msg'}
                        };
                    }
                }
            );
        };

        return ($content,
            {
                'type' => 'OK',
                'code' => 0,
                'msg'  => 'Successful operation'
            }
        );
    }

    our sub close :ReturnType(Hash) ($self, $fh) {
        try {
            close $fh or throw(
                "Cannot close filehandle", {
                    'trace' => 3,
                    'type'  => $error->error_string($OS_ERROR)->{'symbol'},
                    'code'  => $OS_ERROR,
                    'msg'   => $error->error_string($OS_ERROR)->{'string'}
                }
            );
        } catch {
            classify(
                $ARG, {
                    default => sub {
                        # rethrow as fatal
                        $error->err_msg($ARG, $error->error_string($ARG->{'string'}));
                        throw $ARG->{'error'}, {
                            'trace' => 3,
                            'type'  => $ARG->{'type'},
                            'code'  => $ARG->{'code'},
                            'msg'   => $ARG->{'msg'}
                        };
                    }
                }
            );
        };

        return {
            'type' => 'OK',
            'code' => 0,
            'msg'  => 'Successful operation'
        };
    }

    true;
}