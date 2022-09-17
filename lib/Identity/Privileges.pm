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

package Identity::Privileges {
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

    our %named_privileges = (
        'PRV_LOGIN'                 => 0,     # generic privilege to allow account to login. Assigned to any registered user that is not locked out. This is the only privilege assigned directly to accounts
        'PRV_READ_ACCOUNT_ID'       => 1,     # allow reading the account's internal UUID. Assigned only to the ADMINS role
        'PRV_READ_ACCOUNT_NAME'     => 2,     # allow reading the account's internal username. Assigned the SELF role
        'PRV_READ_DISPLAY_NAME'     => 3,     # allow reading the account's display name. Assigned to the AUTHD_USERS roles
        'PRV_READ_EMAIL_ADDRESS'    => 4,     # allow reading the account's email address. Assigned only to the SELF role
        'PRV_READ_ROLES'            => 5,     # allow reading the list of available roles on the system. Assigned to the AUTHD_USERS role
        'PRV_EDIT_ACCOUNT_ID'       => 101,   # allow editing the account's internal UUID. Assigned only to the ADMINS role
        'PRV_EDIT_ACCOUNT_NAME'     => 102,   # allow editing the acccunt's username. Assigned only to the ADMINS role
        'PRV_EDIT_DISPLAY_NAME'     => 103,   # allow editing the account's display name. Assigned only to the ADMINS and SELF roles
        'PRV_EDIT_EMAIL_ADDRESS'    => 104,   # allow editing the account's email address. Assigned only to the ADMINS and SELF roles
        'PRV_ASSIGN_ROLE'           => 105,   # allow assigning accounts to roles. Assigned only to the ADMINS role
        'PRV_UNASSIGN_ROLE'         => 106,   # allow unassigning accounts from roles. Assigned only to the ADMINS role
        'PRV_SET_PASSWD'            => 107,   # Set an account's initial password. Assigned only to the ADMINS role
        'PRV_CHANGE_PASSWD'         => 108,   # Change an account's password. Assigned to both the ADMINS and SELF roles. Note, this privilege is disabled for SELF if the account is locked out
        'PRV_LOCK_PASSWD'           => 109,   # Lock the password on an account, effectively locking the account out. Assigned only to the ADMINS role
        'PRV_CREATE_ROLE'           => 200,   # Create roles. Assigned only to the ADMINS role
        'PRV_EDIT_ROLE'             => 201,   # Edit a role's properties (assigned privileges, etc.). Assigned only to the ADMINS role
        'PRV_REMOVE_ROLE'           => 202,   # Delete a role. Assigned only to the ADMINS role
        'PRV_ASSIGN_PRIVILEGE'      => 203,   # Assign new privileges to a role. Assigned only to the ADMINS role
        'PRV_REVOKE_PRIVILEGE'      => 204,   # Remove privileges from a role. Assigned only to the ADMINS role
        'PRV_CREATE_ACCOUNT'        => 300,   # Create user account. Assigned to the ADMINS role
        'PRV_EDIT_ACCOUNT'          => 301,   # Edit all of an account's properties. This is an administrative privilege that rolls up all the edit privileges. Assigned to the ADMINS role
        'PRV_READ_ACCOUNT_DATA'     => 302,   # Read all of an account's properties. This is an administrative privilege that rolls up all the read privileges. Assigned to the ADMINS role
        'PRV_REMOVE_ACCOUNT'        => 303,   # Delete an account. Assigned to the ADMINS role
        'PRV_CREATE_NEWS_ARTICLE'   => 500,   # Create new news articles. Assigned by default to the ADMINS and CONTENT_EDITOR roles
        'PRV_EDIT_NEWS_ARTICLE'     => 501,   # Edit the content and properties of a news article. Assigned by default to the ADMINS and CONTENT_EDITOR roles
        'PRV_DELETE_NEWS_ARTICLE'   => 502,   # Delete news articles. Assigned by default to the ADMINS and CONTENT_EDITOR roles
        'PRV_ARCHIVE_NEWS_ARTICLE'  => 503,   # Archive news articles. Assigned by default to the ADMINS and CONTENT_EDITOR roles
        'PRV_IMPERSONATE_ACCOUNT'   => 65535  # Impersonate another user. This is an administrative privilege, and should NOT be assigned to any other role than ADMINS. By default this privilege is NOT assigned
    );

    our $privilege[0]   = 'PRV_LOGIN';
    our $privilege[1]   = 'PRV_READ_ACCOUNT_ID';
    our $privilege[2]   = 'PRV_READ_ACCOUNT_NAME';
    our $privilege[3]   = 'PRV_READ_DISPLAY_NAME';
    our $privilege[4]   = 'PRV_READ_EMAIL_ADDRESS';
    our $privilege[5]   = 'PRV_READ_ROLES';
    our $privilege[101] = 'PRV_EDIT_ACCOUNT_ID';
    our $privilege[102] = 'PRV_EDIT_ACCOUNT_NAME';
    our $privilege[103] = 'PRV_EDIT_DISPLAY_NAME';
    our $privilege[104] = 'PRV_EDIT_EMAIL_ADDRESS';
    our $privilege[105] = 'PRV_ASSIGN_ROLE';
    our $privilege[106] = 'PRV_UNASSIGN_ROLE';
    our $privilege[107] = 'PRV_SET_PASSWD';
    our $privilege[108] = 'PRV_CHANGE_PASSWD';
    our $privilege[109] = 'PRV_LOCK_PASSWD';
    our $privilege[200] = 'PRV_CREATE_ROLE';
    our $privilege[201] = 'PRV_EDIT_ROLE';
    our $privilege[202] = 'PRV_REMOVE_ROLE';
    our $privilege[203] = 'PRV_ASSIGN_PRIVILEGE';
    our $privilege[204] = 'PRV_REVOKE_PRIVILEGE';
    our $privilege[300] = 'PRV_CREATE_ACCOUNT';
    our $privilege[301] = 'PRV_EDIT_ACCOUNT';
    our $privilege[302] = 'PRV_READ_ACCOUNT_DATA';
    our $privilege[302] = 'PRV_REMOVE_ACCOUNT';
    our $privilege[500] = 'PRV_CREATE_NEWS_ARTICLE';
    our $privilege[501] = 'PRV_EDIT_NEWS_ARTICLE';
    our $privilege[502] = 'PRV_DELETE_NEWS_ARTICLE';
    our $privilege[503] = 'PRV_ARCHIVE_NEWS_ARTICLE';
    our $privilege[1024] = 'PRV_IMPERSONATE_ACCOUNT';

    our $VERSION = $Identity::Constants::VERSION;

    our sub new ($class) {
        my $self = {};

        bless($self, $class);
        return $self;
    }

    true;
}