#!/usr/bin/env perl
#
# Author: Gary Greene <greeneg@tolharadys.net>
# Copyright: 2019-2023 JAFAX, Inc. All Rights Reserved
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
    use Type::Library -base;
    use Type::Utils;

    use Buyo::Constants;
    use Sys::Error;
    use Value::TypeCheck;

    our $VERSION = $Buyo::Constants::VERSION;

    my $debug = false;

    our sub new :ReturnType(Object) ($class, $debug = false) {
        type_check($class, Str);
        type_check($debug, Bool);

        my $self = {};

        bless($self, $class);
        return $self;
    }

    our sub get_application_prefix :ReturnType(Str) ($self) {
        type_check($self, Object);

        say STDERR "== DEBUGGING ==: Sub ". (caller(0))[3] if $debug eq true;
        my $prefix = "$FindBin::Bin/..";
        return $prefix;
    }

    END { }       # module clean-up code here (global destructor)

    true;  # don't forget to return a true value from the file
}
