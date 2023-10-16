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

    our $VERSION = "0.0.3";

    $Throw::level = 1;

    sub new :ReturnType(Object) ($class, $flags = undef) {
        my $self = {};

        $error = Sys::Error->new();

        bless($self, $class);
        return $self;
    }

    our sub mode_translate :ReturnType(Str) ($self, $mode_string) {
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

    our sub open :ReturnType(FileHandle, HashRef) ($self, $mode_string, $path) {
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

    our sub opendir :ReturnType(FileHandle, HashRef) ($self, $path) {
        my $dh = undef;

        try {
            opendir($dh, $path) or throw(
                "Cannot open directory", {
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

        return ($dh,
            {
                'type' => 'OK',
                'code' => 0,
                'msg'  => 'Successful operation'
            }
        );
    }

    our sub read :ReturnType(Str, HashRef) ($self, $fh, $length) {
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

    our sub readdir :ReturnType(ArrayRef, HashRef) ($self, $dh, $path, $options) {
        my @d_entries = ();

        my @tmp_d_entries = ();
        try {
            @tmp_d_entries = readdir $dh or throw("Cannot read from dirhandle",
                {
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
        foreach my $entry (@tmp_d_entries) {
            if (exists $options->{'skip'}) {
                next if ($entry ~~ @{$options->{'skip'}});
            }
            if (exists $options->{'fileext_filter'}) {
                next if (! $entry ~~ /^[a-zA-Z0-9-]\.@{$options->{'fileext_filter'}}$/);
            }
            push(@d_entries, $entry);
        }

        return (\@d_entries,
            {
                'type' => 'OK',
                'code' => 0,
                'msg'  => 'Successful operation'
            }
        );
    }

    our sub close :ReturnType(HashRef) ($self, $fh) {
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

    our sub closedir :ReturnType(HashRef) ($self, $dh) {
        try {
            closedir $dh or throw(
                "Cannot close dirhandle", {
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
