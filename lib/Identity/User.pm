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

package Identity::User {
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

    use Identity::Privileges;

    our $VERSION = $Identity::Constants::VERSION;

    my $privileges = undef;

    our sub new ($class) {
        my $self = {};

        $privileges = Identity::Privileges->new();

        bless($self, $class);
        return $self;
    }

    our sub create_user ($self, $name, $display_name, $id, $email_address, $roles) {}

    our sub get_id ($self, $name) {}

    our sub get_email ($self, $name) {}

    our sub get_account_name ($self, $id) {}

    our sub get_display_name ($self, $name) {}

    our sub list_roles ($self) {}

    our sub get_user_obj ($self, $name) {}

    our sub update_display_name ($self, $name, $display_name) {}

    our sub rename_user ($self, $name, $new_name) {}

    our sub update_email_address ($self, $name, $email_address) {}

    our sub assign_role ($self, $name, $role_id) {}

    our sub has_role ($self, $name, $role_name) {}

    our sub has_privilege ($self, $name) {}

    our sub delete_user ($self, $name) {}

    true;
}