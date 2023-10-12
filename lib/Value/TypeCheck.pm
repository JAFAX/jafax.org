#!/usr/bin/env perl
#
# Author: Gary Greene <greeneg@tolharadys.net>
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
    use Return::Type;
    use Type::Library -base;
    use Type::Utils;
    use Types::Standard -all;

    our $VERSION = '0.0.2';

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

        my $err_struct = undef;
        my $result     = undef;
        my $check_msg  = undef;

        # first, check if the value is an array ref, which means that it has
        #  potentially TWO or more types.
        if (Scalar::Util::reftype $type eq 'ARRAY') {
            # it's an array, so we need to loop through both to set result and
            #  see if it is what we asked to check for it. IF it is, escape
            #  and return true, otherwise, throw an exception
            foreach my $t (@{$type}) {
                eval {
                    $result     = $type->check($value);
                    $check_msg  = $type->get_message($value);
                };
                if (! $result) {
                    next;
                } else {
                    return true;
                }
            }
            $err_struct = {
                'error' => 'Invalid type',
                'code'  => 22,
                'type'  => $e->error_string(22)->{'string'},
                'info'  => "\$value did not match any requested type constraint @{$type}: $check_msg",
                'trace' => $e->get_trace(),
                'msg'   => "Unable to match required data types!"
            };
            $e->err_msg($err_struct, __PACKAGE__);
            return false;
        } else {
            eval {
                $result = $type->check($value);
                $check_msg  = $type->get_message($value);
            };
            if (! $result) {
                $err_struct = {
                    'error' => 'Invalid type',
                    'code'  => 22,
                    'type'  => $e->error_string(22)->{'string'},
                    'info'  => "\$value did not match type constraint $type: $check_msg",
                    'trace' => $e->get_trace(),
                    'msg'   => "Unable to match required data type!"
                };
                $e->err_msg($err_struct, __PACKAGE__);
                return false;
            } else {
                return true;
            }
        }
    }

    true;
}
