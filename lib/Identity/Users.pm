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

package Identity::Users {
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

    our sub list_users ($self) {

    }

    true;
}