#!/usr/bin/env perl
#
# Author: Gary Greene <greeneg@tolharadys.net>
# Copyright: 2019 JAFAX, Inc. All Rights Reserved
#
##########################################################################
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

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

