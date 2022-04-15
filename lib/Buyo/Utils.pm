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

package Buyo::Utils {
    use strictures;
    use English qw(-no_match_vars);
    use utf8;

    use feature ":5.26";
    use feature 'lexical_subs';
    use feature 'signatures';
    no warnings "experimental::signatures";

    use boolean qw(:all);
    use base qw(Exporter);
    use Carp;
    use Data::Dumper;
    use Return::Type;
    use Types::Standard -all;

    use Buyo::Constants;
    use Sys::Error;

    my $VERSION = $Buyo::Constants::VERSION;

    BEGIN {
        use Exporter;
        our (@EXPORT, @EXPORT_OK);

        # set the version for version checking
        @EXPORT      = qw(
            err_log
            type_check
        );
        @EXPORT_OK   = qw();
    }

    my $debug = false;

    our sub err_log :ReturnType(Void) (@msg) {
        return print {*STDERR} "@msg\n";
    }

    our sub type_check :ReturnType(Bool) ($caller, $value, $type) {
        my $e = Sys::Error->new();
        eval {
            if (! is_${type}($value)) {
                my $err_struct = {
                    'error' => 'Invalid type',
                    'code'  => 22,
                    'type'  => $e->err_string(22),
                    'info'  => "\$value did not match type constraint $type",
                    'trace' => get_trace(undef, @{$caller})
                };
                $e->err_msg($err_struct, @{$caller}[0]);
                exit 22;
            } else {
                return true;
            }
        }
    }

    sub new :ReturnType(Object) ($class, $debug = false) {
        my $self = {};

        bless($self, $class);
        return $self;
    }

    our sub get_application_prefix :ReturnType(Str) ($self) {
        say STDERR "== DEBUGGING ==: Sub ". (caller(0))[3] if $debug eq true;
        my $prefix = "$FindBin::Bin/..";
        return $prefix;
    }

    END { }       # module clean-up code here (global destructor)

    true;  # don't forget to return a true value from the file
}
