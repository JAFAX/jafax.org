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

    our $VERSION = $Buyo::Constants::VERSION;

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
