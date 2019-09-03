#!/usr/bin/env perl

use strict;
use warnings;
use English qw(-no_match_vars);
use utf8;

use feature qw{
    say
};

use boolean qw(:all);
use FindBin;
use lib "$FindBin::Bin/../lib";

BEGIN {
    # @INC path manipulation
    use Cwd qw(abs_path);
    use File::Basename qw(dirname);
    my $prefix = dirname(abs_path($0)) . "/../lib";
    # this evil is necessary to fool taint, which is too strict here.
    if ($prefix =~ /(.*)/) {
        $prefix = $1;
    } else {
        die; # should NEVER happen.
    }
    push @INC, $prefix;
}

use Buyo;
use Plack::Builder;
use Buyo::Utils qw(err_log);
use Buyo::Constants;

our $VERSION = $Buyo::Constants::version;
my $DEBUG = true;

sub main {
    say {*STDERR} '>> Starting the Buyo application server version '. $Buyo::Constants::version;
    say {*STDERR} '>> '. $Buyo::Constants::license;
    say {*STDERR} '-------------------------------------------------------------';
    err_log('== DEBUGGING ==: PERL INCLUDE PATH:') if $DEBUG;
    if ($DEBUG) {
        foreach my $p (@INC) {
            say {*STDERR} "== DEBUGGING ==:    $p";
        }
    }
    err_log('== DEBUGGING ==: MOUNTING PLACK::BUILDER ENDPOINTS') if $DEBUG;

    return builder {
        mount '/'         => Buyo->to_app;
    };
}

main();

