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

package Identity::Role {
    use strictures;
    use English qw(-no_match_vars);
    use utf8;

    use boolean qw(:all);
    use JSON qw();
    use Data::Dumper;
    use Try::Tiny qw(try catch);
    use Throw qw(throw classify);

    use feature ":5.26";
    use feature 'lexical_subs';
    use feature 'signatures';
    use feature 'switch';
    no warnings "experimental::signatures";
    no warnings "experimental::smartmatch";

    use FindBin;
    use lib "$FindBin::Bin/../lib";

    use Identity::Constants;

    use File::IO;
    use Identity::Privileges;
    use Sys::Error;

    our $VERSION = $Identity::Constants::VERSION;

    # need to know where the conf.d/Identity directory is
    my $identity_root = "$FindBin::Bin/../conf.d/Identity";

    my $err        = undef;
    my $fio        = undef;
    my $privileges = undef;

    our sub new ($class) {
        my $self = {};

        $err        = Sys::Error->new();
        $fio        = File::IO->new();
        $privileges = Identity::Privileges->new();

        bless($self, $class);
        return $self;
    }

    our sub create_role ($self, $name, $display_name, $id, $privs) {
        # roles have the following layout:
        #
        # - name         (SCALAR: string)
        # - display_name (SCALAR: string)
        # - id           (SCALAR: string(UUID))
        # - privileges   (LIST:   integers )
        #
        # these are stored as JSON files in conf.d/Identity. No authentication secrets are in the JSON files

        # check if the role already exists
        unless (role_exists($name)) {
            # open new json storage file
            my $fc     = undef;
            my $fh     = undef;
            my $status = undef;
            try {
                ($fh, $status) = $fio->open('crw', $identity_root/Roles/${name}.json);
            } catch {
                $err->err_msg($status, __PACKAGE__);
            };
            # create the actual role struct
            my $role = {
                'id'            => $id,
                'name'          => $name,
                'displayName'   => $display_name,
                'privileges'    => @${privs}
            };
            # convert from perl hash to JSON
            my $role_json_string = undef;
            try {
                $role_json_string = encode_json($role_json_string);
            } catch {
                $err->err_msg($ARG, __PACKAGE__);
            };
            # write content to file
            try {
                say $fh $role_json_string;
            } catch {
                $err->err_msg($ARG, __PACKAGE__);
            };
            # close the role file
            try {
                ($fc, $status) = $fio->close($fh);
            } catch {
                $err->err_msg($status, __PACKAGE__);
            };

            return true;
        }

        return false;
    }

    our sub get_role_id ($self, $name) {
        if (role_exists($name)) {

        }
    }

    our sub get_role_name ($self, $id) {}

    our sub list_privileges ($self, $role) {}

    our sub get_role_obj ($self, $role) {}

    our sub update_privileges ($self, $role, $privs) {}

    our sub rename_role ($self, $role_name, $new_role_name) {}

    our sub delete_role ($self, $role) {}

    our sub role_exists ($self, $name) {
        if (-f "$identity_root/Roles/${name}.json" or
            -f "$identity_root/Roles/BUILTIN/${name}.json") {
            return true;
        }

        return false;
    }

    true;
}