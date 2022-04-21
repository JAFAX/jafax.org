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

package Value::TypeCheck {
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
    use Type::Library -base;
    use Type::Utils;
    use Return::Type;

    our $VERSION = '0.0.1';

    BEGIN {
        use Exporter;
        our (@EXPORT, @EXPORT_OK);

        # set the version for version checking
        @EXPORT      = qw(
            type_check
        );
        @EXPORT_OK   = qw();
    }

    our sub type_check :ReturnType(Bool) ($value, $type) {
        my $e = Sys::Error->new();

        my $result = undef;
        eval {
            $result = $type->check($value);
        };

        if (! $result) {
            my $err_struct = {
                'error' => 'Invalid type',
                'code'  => 22,
                'type'  => $e->error_string(22)->{'string'},
                'info'  => "\$value did not match type constraint $type",
                'trace' => $e->get_trace(),
                'msg'   => "Unable to match required data type!"
            };
            $e->err_msg($err_struct, __PACKAGE__);
            return false;
        } else {
            return true;
        }
    }

    true;
}